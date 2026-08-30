#include "image_converter.hpp"

#include "../ffmpeg/ffmpeg_error.hpp"
#include "../ffmpeg/format_context.hpp"
#include "../ffmpeg/codec_context.hpp"
#include "../ffmpeg/packet.hpp"
#include "../fs/path_utils.hpp"
#include "../fs/temp_file.hpp"
#include <convertor/logging.hpp>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
}

#include <fstream>
#include <optional>
#include <cstdio>
#include <cstring>

using namespace std;

namespace convertor {

namespace {

// Prefers keeping the source pixel format when the encoder accepts it, so a
// conversion does not lose colour precision for no reason.
AVPixelFormat pick_pixel_format(const AVCodec* encoder, AVPixelFormat source) {
    const void* configs = nullptr;
    int num_configs = 0;
    if (avcodec_get_supported_config(nullptr, encoder, AV_CODEC_CONFIG_PIX_FORMAT,
                                     0, &configs, &num_configs) < 0 ||
        !configs || num_configs <= 0) {
        return AV_PIX_FMT_RGB24;
    }

    const AVPixelFormat* list = static_cast<const AVPixelFormat*>(configs);
    for (int i = 0; i < num_configs; ++i) {
        if (list[i] == source) return source;
    }
    return list[0];
}

// Decodes the first frame of an image file.
Error decode_first_frame(const string& path, ffmpeg::Frame& out_frame) {
    ffmpeg::FormatContext in_ctx;
    Error err = in_ctx.open_input(path);
    if (!err.ok()) return err;

    AVFormatContext* fmt = in_ctx.input_ctx();
    int stream_index = av_find_best_stream(fmt, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (stream_index < 0) {
        return Error(ErrorCode::kFFmpegDecode, "No image stream in " + path);
    }

    ffmpeg::CodecContext decoder;
    err = decoder.open_decoder(fmt->streams[stream_index]->codecpar);
    if (!err.ok()) return err;

    // Images are one packet, but animated sources may need a few reads before
    // the decoder yields the first frame.
    while (true) {
        ffmpeg::Packet pkt;
        int ret = av_read_frame(fmt, pkt.get());
        if (ret < 0) break;

        if (pkt.get()->stream_index != stream_index) {
            av_packet_unref(pkt.get());
            continue;
        }

        err = decoder.send_packet(pkt.get());
        av_packet_unref(pkt.get());
        if (!err.ok() && err.code() != ErrorCode::kInternal) return err;

        err = decoder.receive_frame(out_frame.get());
        if (err.ok()) return Error::success();
        if (err.code() != ErrorCode::kInternal) return err;
    }

    // Flush.
    decoder.send_packet(nullptr);
    err = decoder.receive_frame(out_frame.get());
    if (err.ok()) return Error::success();

    return Error(ErrorCode::kFFmpegDecode, "Could not decode image: " + path);
}

} // namespace

namespace image_ops {

Error write_frame_as_image(AVFrame* source, const string& output_path,
                           optional<int> quality) {
    ffmpeg::FormatContext out_ctx;
    Error err = out_ctx.open_output(output_path);
    if (!err.ok()) return err;

    AVFormatContext* out_fmt = out_ctx.output_ctx();

    // Ask for the codec that matches the filename, not the muxer's default:
    // the image2 muxer handles png/bmp/tiff/jpeg alike but defaults to MJPEG,
    // which silently produced JPEG bytes inside a file named .png.
    AVCodecID codec_id = av_guess_codec(out_fmt->oformat, nullptr,
                                        output_path.c_str(), nullptr,
                                        AVMEDIA_TYPE_VIDEO);
    if (codec_id == AV_CODEC_ID_NONE) codec_id = out_fmt->oformat->video_codec;

    const AVCodec* encoder = avcodec_find_encoder(codec_id);
    if (!encoder) {
        return Error(ErrorCode::kUnsupportedFormat,
                     "No encoder for " + fs::extension(output_path));
    }

    const AVPixelFormat enc_pix_fmt =
        pick_pixel_format(encoder, static_cast<AVPixelFormat>(source->format));

    ffmpeg::UniqueAVCodecCtx enc_ctx(avcodec_alloc_context3(encoder));
    if (!enc_ctx) return Error(ErrorCode::kOutOfMemory, "Cannot allocate encoder");

    enc_ctx->width = source->width;
    enc_ctx->height = source->height;
    enc_ctx->pix_fmt = enc_pix_fmt;
    enc_ctx->time_base = AVRational{1, 25};
    enc_ctx->framerate = AVRational{25, 1};
    if (encoder->id == AV_CODEC_ID_MJPEG) {
        enc_ctx->color_range = AVCOL_RANGE_JPEG;
    }
    if (out_fmt->oformat->flags & AVFMT_GLOBALHEADER) {
        enc_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    // Quality maps to the codec's quantiser scale: 1 is best, 31 is worst.
    if (quality.has_value()) {
        const int q = max(1, min(100, quality.value()));
        const int qscale = max(1, min(31, 32 - (q * 31) / 100));
        enc_ctx->flags |= AV_CODEC_FLAG_QSCALE;
        enc_ctx->global_quality = FF_QP2LAMBDA * qscale;
    }

    err = ffmpeg::ffmpeg_error(avcodec_open2(enc_ctx.get(), encoder, nullptr));
    if (!err.ok()) return err;

    AVStream* out_stream = avformat_new_stream(out_fmt, nullptr);
    if (!out_stream) return Error(ErrorCode::kOutOfMemory, "Cannot create stream");
    out_stream->time_base = enc_ctx->time_base;
    err = ffmpeg::ffmpeg_error(
        avcodec_parameters_from_context(out_stream->codecpar, enc_ctx.get()));
    if (!err.ok()) return err;

    // Convert to the encoder's pixel format if it differs from the source.
    ffmpeg::Frame converted;
    AVFrame* to_encode = source;
    if (enc_pix_fmt != static_cast<AVPixelFormat>(source->format)) {
        err = converted.allocate(source->width, source->height, enc_pix_fmt);
        if (!err.ok()) return err;

        ffmpeg::Rescaler rescaler;
        err = rescaler.init(source->width, source->height, enc_pix_fmt,
                            source->width, source->height, source->format);
        if (!err.ok()) return err;
        err = rescaler.scale(source, converted.get());
        if (!err.ok()) return err;
        to_encode = converted.get();
    }
    to_encode->pts = 0;

    err = out_ctx.write_header();
    if (!err.ok()) return err;

    err = ffmpeg::ffmpeg_error(avcodec_send_frame(enc_ctx.get(), to_encode));
    if (!err.ok()) return err;
    avcodec_send_frame(enc_ctx.get(), nullptr);  // flush

    bool wrote_any = false;
    while (true) {
        ffmpeg::Packet pkt;
        int ret = avcodec_receive_packet(enc_ctx.get(), pkt.get());
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
        if (ret < 0) return ffmpeg::ffmpeg_error(ret);

        pkt.get()->stream_index = 0;
        av_packet_rescale_ts(pkt.get(), enc_ctx->time_base, out_stream->time_base);
        err = out_ctx.write_packet(pkt.get());
        av_packet_unref(pkt.get());
        if (!err.ok()) return err;
        wrote_any = true;
    }

    if (!wrote_any) {
        return Error(ErrorCode::kFFmpegEncode,
                     "Encoder produced no data for " + output_path);
    }

    return out_ctx.write_trailer();
}

Error write_rgb24_as_image(const unsigned char* rgb, int width, int height,
                           int stride, const string& output_path,
                           optional<int> quality) {
    if (!rgb || width <= 0 || height <= 0) {
        return Error(ErrorCode::kInvalidArgument, "Empty image buffer");
    }

    ffmpeg::Frame frame;
    Error err = frame.allocate(width, height, AV_PIX_FMT_RGB24);
    if (!err.ok()) return err;

    AVFrame* f = frame.frame();
    const int row_bytes = width * 3;
    for (int y = 0; y < height; ++y) {
        memcpy(f->data[0] + static_cast<ptrdiff_t>(y) * f->linesize[0],
               rgb + static_cast<ptrdiff_t>(y) * stride, row_bytes);
    }

    return write_frame_as_image(f, output_path, quality);
}

Error encode_to_jpeg(const string& input_path, string& jpeg_out,
                     int& width, int& height, int quality,
                     const string& scratch_dir) {
    ffmpeg::Frame frame;
    Error err = decode_first_frame(input_path, frame);
    if (!err.ok()) return err;

    width = frame.frame()->width;
    height = frame.frame()->height;

    // The JPEG muxer needs a filename to pick the format from, so encode via a
    // temp file and read the bytes back for embedding.
    fs::TempFile temp(scratch_dir);
    if (temp.path().empty()) {
        return Error(ErrorCode::kPermissionDenied,
                     "Cannot create a scratch file in " +
                         (scratch_dir.empty() ? fs::default_temp_dir() : scratch_dir));
    }
    const string jpeg_path = temp.path() + ".jpg";

    err = write_frame_as_image(frame.frame(), jpeg_path, quality);
    if (!err.ok()) { ::remove(jpeg_path.c_str()); return err; }

    ifstream in(jpeg_path, ios::binary);
    if (!in.is_open()) {
        ::remove(jpeg_path.c_str());
        return Error(ErrorCode::kInternal, "Cannot read encoded JPEG");
    }
    jpeg_out.assign(istreambuf_iterator<char>(in), istreambuf_iterator<char>());
    in.close();
    ::remove(jpeg_path.c_str());

    if (jpeg_out.empty()) {
        return Error(ErrorCode::kFFmpegEncode, "Empty JPEG for " + input_path);
    }
    return Error::success();
}

} // namespace image_ops

bool ImageConverter::can_handle(const ConversionRequest& request,
                                 const MediaInfo& input_info) const {
    if (input_info.media_type != MediaType::kImage) return false;

    const auto* to_fmt =
        FormatCatalog::instance().find_by_extension(request.output_extension());
    return to_fmt && to_fmt->media_type() == MediaType::kImage;
}

Error ImageConverter::convert(const ConversionRequest& request,
                               const MediaInfo&,
                               ProgressCallback progress) {
    Logger::instance().info("ImageConverter: " + request.input_extension() +
                            " -> " + request.output_extension());

    ffmpeg::Frame frame;
    Error err = decode_first_frame(request.input_path(), frame);
    if (!err.ok()) return err;

    if (progress) progress(0.5f);

    err = image_ops::write_frame_as_image(frame.frame(), request.output_path(),
                                          request.settings().image.quality);
    if (!err.ok()) return err;

    if (progress) progress(1.0f);
    return Error::success();
}

} // namespace convertor
