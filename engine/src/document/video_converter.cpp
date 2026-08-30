#include "video_converter.hpp"

#include "../ffmpeg/ffmpeg_error.hpp"
#include "../ffmpeg/format_context.hpp"
#include "../ffmpeg/codec_context.hpp"
#include "../ffmpeg/packet.hpp"
#include "../ffmpeg/frame.hpp"
#include "../ffmpeg/rescaler.hpp"
#include "audio_transcoder.hpp"
#include <convertor/logging.hpp>

extern "C" {
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
}

#include <algorithm>
#include <memory>
#include <vector>

using namespace std;

namespace convertor {

namespace {

AVPixelFormat pick_pixel_format(const AVCodec* encoder, AVPixelFormat source) {
    const void* configs = nullptr;
    int count = 0;
    if (avcodec_get_supported_config(nullptr, encoder, AV_CODEC_CONFIG_PIX_FORMAT,
                                     0, &configs, &count) < 0 ||
        !configs || count <= 0) {
        return AV_PIX_FMT_YUV420P;
    }
    const AVPixelFormat* list = static_cast<const AVPixelFormat*>(configs);
    for (int i = 0; i < count; ++i) {
        if (list[i] == source) return source;
    }
    return list[0];
}

} // namespace

bool VideoConverter::can_handle(const ConversionRequest& request,
                                 const MediaInfo& input_info) const {
    if (input_info.media_type != MediaType::kVideo) return false;
    if (!input_info.has_video()) return false;

    const auto* to_fmt =
        FormatCatalog::instance().find_by_extension(request.output_extension());
    return to_fmt && to_fmt->media_type() == MediaType::kVideo;
}

Error VideoConverter::convert(const ConversionRequest& request,
                               const MediaInfo& input_info,
                               ProgressCallback progress) {
    Logger::instance().info("VideoConverter: " + request.input_extension() +
                            " -> " + request.output_extension());

    ffmpeg::FormatContext in_ctx;
    Error err = in_ctx.open_input(request.input_path());
    if (!err.ok()) return err;

    AVFormatContext* in_fmt = in_ctx.input_ctx();
    const StreamInfo* video_info = input_info.video_stream();
    if (!video_info) return Error(ErrorCode::kInvalidArgument, "No video stream");

    const unsigned vs_idx = video_info->index;
    AVStream* in_video = in_fmt->streams[vs_idx];

    ffmpeg::CodecContext decoder;
    err = decoder.open_decoder(in_video->codecpar);
    if (!err.ok()) return err;

    const auto& settings = request.settings();
    AVCodecContext* dec_ctx = decoder.ctx();
    const int out_w = settings.video.width.value_or(dec_ctx->width);
    const int out_h = settings.video.height.value_or(dec_ctx->height);

    ffmpeg::FormatContext out_ctx;
    err = out_ctx.open_output(request.output_path());
    if (!err.ok()) return err;

    AVFormatContext* out_fmt = out_ctx.output_ctx();
    const AVCodec* encoder = avcodec_find_encoder(out_fmt->oformat->video_codec);
    if (!encoder) {
        return Error(ErrorCode::kUnsupportedFormat,
                     "No video encoder for " + request.output_extension());
    }

    // Frames are re-stamped with a simple frame counter, so the stream time
    // base must be the frame duration. Using the input's time base here is
    // what collapsed converted files to a fraction of a second.
    AVRational frame_rate = av_guess_frame_rate(in_fmt, in_video, nullptr);
    if (frame_rate.num <= 0 || frame_rate.den <= 0) frame_rate = AVRational{25, 1};
    if (settings.video.frame_rate.has_value()) {
        frame_rate = av_d2q(settings.video.frame_rate.value(), 1000000);
    }

    const AVPixelFormat enc_pix_fmt =
        pick_pixel_format(encoder, static_cast<AVPixelFormat>(dec_ctx->pix_fmt));

    ffmpeg::UniqueAVCodecCtx enc_ctx(avcodec_alloc_context3(encoder));
    if (!enc_ctx) return Error(ErrorCode::kOutOfMemory, "Cannot allocate encoder");

    enc_ctx->width = out_w;
    enc_ctx->height = out_h;
    enc_ctx->pix_fmt = enc_pix_fmt;
    enc_ctx->time_base = av_inv_q(frame_rate);
    enc_ctx->framerate = frame_rate;
    enc_ctx->sample_aspect_ratio = dec_ctx->sample_aspect_ratio;
    enc_ctx->gop_size = 12;
    if (settings.video.bit_rate.has_value()) {
        enc_ctx->bit_rate = settings.video.bit_rate.value();
    }
    if (out_fmt->oformat->flags & AVFMT_GLOBALHEADER) {
        enc_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
    if (settings.video.crf.has_value()) {
        av_opt_set_int(enc_ctx->priv_data, "crf", settings.video.crf.value(), 0);
    }

    err = ffmpeg::ffmpeg_error(avcodec_open2(enc_ctx.get(), encoder, nullptr));
    if (!err.ok()) return err;

    // Build the output. The audio track is copied when the container takes
    // the source codec and transcoded when it does not - but a muxer can still
    // reject a codec that avformat_query_codec approved (Opus in MOV, say), so
    // fall back through progressively safer layouts instead of failing.
    enum class AudioPlan { kCopy, kTranscode, kNone };

    const StreamInfo* audio_info = input_info.audio_stream();
    vector<AudioPlan> plans;
    if (audio_info) {
        AVStream* in_audio = in_fmt->streams[audio_info->index];
        if (avformat_query_codec(out_fmt->oformat, in_audio->codecpar->codec_id,
                                 FF_COMPLIANCE_NORMAL) == 1) {
            plans.push_back(AudioPlan::kCopy);
        }
        plans.push_back(AudioPlan::kTranscode);
    }
    plans.push_back(AudioPlan::kNone);

    unique_ptr<AudioTranscoder> audio_transcoder;
    int audio_copy_in = -1;
    int audio_copy_out = -1;
    AVStream* out_video = nullptr;
    int out_video_index = 0;

    for (size_t attempt = 0; attempt < plans.size(); ++attempt) {
        const AudioPlan plan = plans[attempt];

        if (attempt > 0) {
            // Start from a clean context: streams cannot be removed once added.
            out_ctx = ffmpeg::FormatContext();
            err = out_ctx.open_output(request.output_path());
            if (!err.ok()) return err;
            out_fmt = out_ctx.output_ctx();
            audio_transcoder.reset();
            audio_copy_in = -1;
            audio_copy_out = -1;
        }

        out_video = avformat_new_stream(out_fmt, nullptr);
        if (!out_video) return Error(ErrorCode::kOutOfMemory, "Cannot create stream");
        out_video->time_base = enc_ctx->time_base;
        out_video->avg_frame_rate = frame_rate;
        err = ffmpeg::ffmpeg_error(
            avcodec_parameters_from_context(out_video->codecpar, enc_ctx.get()));
        if (!err.ok()) return err;
        out_video_index = out_video->index;

        if (plan == AudioPlan::kCopy) {
            AVStream* in_audio = in_fmt->streams[audio_info->index];
            AVStream* out_audio = avformat_new_stream(out_fmt, nullptr);
            if (out_audio &&
                avcodec_parameters_copy(out_audio->codecpar, in_audio->codecpar) >= 0) {
                out_audio->codecpar->codec_tag = 0;
                out_audio->time_base = in_audio->time_base;
                audio_copy_in = static_cast<int>(audio_info->index);
                audio_copy_out = out_audio->index;
            }
        } else if (plan == AudioPlan::kTranscode) {
            auto transcoder = make_unique<AudioTranscoder>();
            Error audio_err = transcoder->open(in_fmt, audio_info->index, out_ctx,
                                               settings.audio);
            if (audio_err.ok()) {
                audio_transcoder = move(transcoder);
            } else {
                Logger::instance().warn("VideoConverter: cannot transcode audio (" +
                                        audio_err.message() + ")");
                continue;
            }
        }

        err = out_ctx.write_header();
        if (err.ok()) {
            if (plan == AudioPlan::kTranscode) {
                Logger::instance().info(
                    "VideoConverter: transcoding audio for this container");
            } else if (plan == AudioPlan::kNone && audio_info) {
                Logger::instance().warn(
                    "VideoConverter: this container cannot carry the audio track");
            }
            break;
        }

        if (attempt + 1 == plans.size()) return err;
        Logger::instance().info("VideoConverter: retrying with a different audio "
                                "layout (" + err.message() + ")");
    }

    ffmpeg::Rescaler rescaler;
    bool rescaler_ready = false;
    const bool needs_rescale = enc_pix_fmt != dec_ctx->pix_fmt ||
                               out_w != dec_ctx->width || out_h != dec_ctx->height;

    const int64_t total_us = input_info.duration_us;
    int64_t frame_index = 0;

    auto drain_video_encoder = [&]() -> Error {
        while (true) {
            ffmpeg::Packet pkt;
            int ret = avcodec_receive_packet(enc_ctx.get(), pkt.get());
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
            if (ret < 0) return ffmpeg::ffmpeg_error(ret);

            av_packet_rescale_ts(pkt.get(), enc_ctx->time_base, out_video->time_base);
            pkt.get()->stream_index = out_video_index;
            Error write_err = out_ctx.write_packet(pkt.get());
            av_packet_unref(pkt.get());
            if (!write_err.ok()) return write_err;
        }
        return Error::success();
    };

    while (true) {
        ffmpeg::Packet in_pkt;
        int ret = av_read_frame(in_fmt, in_pkt.get());
        if (ret < 0) break;

        const int pkt_index = in_pkt.get()->stream_index;

        if (pkt_index == static_cast<int>(vs_idx)) {
            err = decoder.send_packet(in_pkt.get());
            av_packet_unref(in_pkt.get());
            if (!err.ok() && err.code() != ErrorCode::kInternal) return err;

            while (true) {
                ffmpeg::Frame frame;
                ret = avcodec_receive_frame(dec_ctx, frame.get());
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
                if (ret < 0) return ffmpeg::ffmpeg_error(ret);

                AVFrame* to_encode = frame.frame();
                ffmpeg::Frame converted;
                if (needs_rescale) {
                    err = converted.allocate(out_w, out_h, enc_pix_fmt);
                    if (!err.ok()) return err;
                    if (!rescaler_ready) {
                        err = rescaler.init(out_w, out_h, enc_pix_fmt,
                                            frame.frame()->width, frame.frame()->height,
                                            frame.frame()->format);
                        if (!err.ok()) return err;
                        rescaler_ready = true;
                    }
                    err = rescaler.scale(frame.frame(), converted.get());
                    if (!err.ok()) return err;
                    to_encode = converted.get();
                }

                to_encode->pts = frame_index++;
                ret = avcodec_send_frame(enc_ctx.get(), to_encode);
                if (ret < 0) return ffmpeg::ffmpeg_error(ret);

                err = drain_video_encoder();
                if (!err.ok()) return err;

                if (progress && total_us > 0) {
                    const double seconds =
                        frame_index * av_q2d(enc_ctx->time_base);
                    progress(static_cast<float>(
                        min(1.0, seconds / (total_us / 1000000.0))));
                }
            }
        } else if (audio_transcoder &&
                   pkt_index == static_cast<int>(audio_transcoder->in_index())) {
            err = audio_transcoder->feed(in_pkt.get(), out_ctx);
            av_packet_unref(in_pkt.get());
            if (!err.ok()) return err;
        } else if (pkt_index == audio_copy_in) {
            AVStream* in_audio = in_fmt->streams[audio_copy_in];
            AVStream* out_audio = out_fmt->streams[audio_copy_out];
            av_packet_rescale_ts(in_pkt.get(), in_audio->time_base,
                                 out_audio->time_base);
            in_pkt.get()->stream_index = audio_copy_out;
            in_pkt.get()->pos = -1;
            err = out_ctx.write_packet(in_pkt.get());
            av_packet_unref(in_pkt.get());
            if (!err.ok()) return err;
        } else {
            av_packet_unref(in_pkt.get());
        }
    }

    // Flush the video encoder, then the audio one.
    avcodec_send_frame(enc_ctx.get(), nullptr);
    err = drain_video_encoder();
    if (!err.ok()) return err;

    if (audio_transcoder) {
        err = audio_transcoder->finish(out_ctx);
        if (!err.ok()) return err;
    }

    if (progress) progress(1.0f);
    return out_ctx.write_trailer();
}

} // namespace convertor
