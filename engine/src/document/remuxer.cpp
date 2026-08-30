#include "remuxer.hpp"
#include "../ffmpeg/ffmpeg_error.hpp"
#include "../ffmpeg/packet.hpp"
#include <convertor/logging.hpp>

extern "C" {
#include <libavformat/avformat.h>
}

#include <algorithm>
#include <vector>

using namespace std;

namespace convertor {

namespace {

// True when every stream in the source can be copied into the target
// container untouched. Declaring a pair in the catalogue is not enough: MP4
// and WebM are both "video", but WebM will not accept an H.264 track, and
// claiming the job here would fail the mux instead of falling through to the
// transcoding converter.
bool container_accepts_all_streams(const string& output_path,
                                   const MediaInfo& input_info,
                                   const string& input_path) {
    const AVOutputFormat* out_format =
        av_guess_format(nullptr, output_path.c_str(), nullptr);
    if (!out_format) return false;

    AVFormatContext* probe_ctx = nullptr;
    if (avformat_open_input(&probe_ctx, input_path.c_str(), nullptr, nullptr) < 0) {
        return false;
    }
    if (avformat_find_stream_info(probe_ctx, nullptr) < 0) {
        avformat_close_input(&probe_ctx);
        return false;
    }

    bool all_ok = probe_ctx->nb_streams > 0;
    for (unsigned i = 0; i < probe_ctx->nb_streams && all_ok; ++i) {
        const AVCodecParameters* par = probe_ctx->streams[i]->codecpar;

        // Data and attachment streams are dropped rather than copied, so they
        // do not decide whether a remux is possible.
        if (par->codec_type != AVMEDIA_TYPE_VIDEO &&
            par->codec_type != AVMEDIA_TYPE_AUDIO &&
            par->codec_type != AVMEDIA_TYPE_SUBTITLE) {
            continue;
        }
        if (avformat_query_codec(out_format, par->codec_id,
                                 FF_COMPLIANCE_NORMAL) != 1) {
            all_ok = false;
        }
    }

    // A stream copy can only preserve timestamps that exist. MPEG program
    // streams in particular hand out packets with no DTS, which produces a
    // file with duplicate timestamps, so sample the head of the file and let
    // those sources take the re-encoding path instead.
    if (all_ok) {
        constexpr int kPacketsToSample = 64;
        AVPacket* pkt = av_packet_alloc();
        for (int i = 0; i < kPacketsToSample && pkt; ++i) {
            if (av_read_frame(probe_ctx, pkt) < 0) break;
            const bool timestamped = pkt->dts != AV_NOPTS_VALUE;
            av_packet_unref(pkt);
            if (!timestamped) { all_ok = false; break; }
        }
        av_packet_free(&pkt);
    }

    avformat_close_input(&probe_ctx);
    (void)input_info;
    return all_ok;
}

} // namespace

bool Remuxer::can_handle(const ConversionRequest& request,
                          const MediaInfo& input_info) const {
    if (input_info.media_type != MediaType::kVideo) return false;

    auto& catalog = FormatCatalog::instance();
    const auto* from = catalog.find_by_extension(request.input_extension());
    const auto* to = catalog.find_by_extension(request.output_extension());
    if (!from || !to) return false;
    if (from->media_type() != to->media_type()) return false;
    if (!catalog.can_convert(from->id(), to->id())) return false;

    return container_accepts_all_streams(request.output_path(), input_info,
                                         request.input_path());
}

Error Remuxer::convert(const ConversionRequest& request,
                        const MediaInfo& input_info,
                        ProgressCallback progress) {
    Logger::instance().info("Remuxer: " + request.input_extension() + " -> " +
                            request.output_extension() + " (stream copy)");

    ffmpeg::FormatContext in_ctx;
    Error err = in_ctx.open_input(request.input_path());
    if (!err.ok()) return err;

    AVFormatContext* in_fmt = in_ctx.input_ctx();

    ffmpeg::FormatContext out_ctx;
    err = out_ctx.open_output(request.output_path());
    if (!err.ok()) return err;

    AVFormatContext* out_fmt = out_ctx.output_ctx();

    // Map only the streams the target container will take; -1 means dropped.
    vector<int> stream_map(in_fmt->nb_streams, -1);
    for (unsigned i = 0; i < in_fmt->nb_streams; ++i) {
        AVStream* in_stream = in_fmt->streams[i];
        const AVCodecParameters* par = in_stream->codecpar;

        if (par->codec_type != AVMEDIA_TYPE_VIDEO &&
            par->codec_type != AVMEDIA_TYPE_AUDIO &&
            par->codec_type != AVMEDIA_TYPE_SUBTITLE) {
            continue;
        }
        if (avformat_query_codec(out_fmt->oformat, par->codec_id,
                                 FF_COMPLIANCE_NORMAL) != 1) {
            continue;
        }

        AVStream* out_stream = avformat_new_stream(out_fmt, nullptr);
        if (!out_stream) return Error(ErrorCode::kOutOfMemory, "Failed to create stream");

        err = ffmpeg::ffmpeg_error(avcodec_parameters_copy(out_stream->codecpar, par));
        if (!err.ok()) return err;
        out_stream->codecpar->codec_tag = 0;
        out_stream->time_base = in_stream->time_base;
        stream_map[i] = out_stream->index;
    }

    if (out_fmt->nb_streams == 0) {
        return Error(ErrorCode::kUnsupportedFormat,
                     "No stream can be copied into " + request.output_extension());
    }

    err = out_ctx.write_header();
    if (!err.ok()) return err;

    const int64_t total_duration = input_info.duration_us;

    // Some sources (MPEG program streams especially) carry timestamps that are
    // missing or run backwards. They cannot be copied verbatim, so bail out and
    // let the caller fall through to the transcoding converter, which rebuilds
    // timestamps from scratch.
    vector<int64_t> last_dts(out_fmt->nb_streams, INT64_MIN);

    while (true) {
        ffmpeg::Packet pkt;
        if (av_read_frame(in_fmt, pkt.get()) < 0) break;

        AVPacket* p = pkt.get();
        const int out_index =
            p->stream_index < static_cast<int>(stream_map.size())
                ? stream_map[p->stream_index]
                : -1;
        if (out_index < 0) { av_packet_unref(p); continue; }

        AVStream* in_stream = in_fmt->streams[p->stream_index];
        AVStream* out_stream = out_fmt->streams[out_index];

        // Some containers (MPEG-PS) hand out packets without timestamps; the
        // muxer rejects those, so let it interpolate instead of writing junk.
        if (p->pts != AV_NOPTS_VALUE) {
            p->pts = av_rescale_q_rnd(p->pts, in_stream->time_base,
                                      out_stream->time_base,
                                      static_cast<AVRounding>(AV_ROUND_NEAR_INF |
                                                              AV_ROUND_PASS_MINMAX));
        }
        if (p->dts != AV_NOPTS_VALUE) {
            p->dts = av_rescale_q_rnd(p->dts, in_stream->time_base,
                                      out_stream->time_base,
                                      static_cast<AVRounding>(AV_ROUND_NEAR_INF |
                                                              AV_ROUND_PASS_MINMAX));
        }
        p->duration = av_rescale_q(p->duration, in_stream->time_base,
                                   out_stream->time_base);
        p->pos = -1;
        p->stream_index = out_index;

        if (p->dts == AV_NOPTS_VALUE) {
            av_packet_unref(p);
            return Error(ErrorCode::kFFmpegMux,
                         "Source timestamps are missing; re-encoding instead");
        }
        if (last_dts[out_index] != INT64_MIN && p->dts <= last_dts[out_index]) {
            av_packet_unref(p);
            return Error(ErrorCode::kFFmpegMux,
                         "Source timestamps are not monotonic; re-encoding instead");
        }
        last_dts[out_index] = p->dts;

        const int64_t pts_for_progress = p->pts;
        err = out_ctx.write_packet(p);
        av_packet_unref(p);
        if (!err.ok()) return err;

        if (progress && total_duration > 0 && pts_for_progress != AV_NOPTS_VALUE) {
            const double seconds =
                pts_for_progress * av_q2d(out_stream->time_base);
            progress(static_cast<float>(
                min(1.0, seconds / (total_duration / 1000000.0))));
        }
    }

    if (progress) progress(1.0f);
    return out_ctx.write_trailer();
}

} // namespace convertor
