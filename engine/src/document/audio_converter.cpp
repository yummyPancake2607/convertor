#include "audio_converter.hpp"
#include "audio_transcoder.hpp"

#include "../ffmpeg/ffmpeg_error.hpp"
#include "../ffmpeg/packet.hpp"
#include <convertor/logging.hpp>

extern "C" {
#include <libavcodec/avcodec.h>
}

#include <algorithm>

using namespace std;

namespace convertor {

bool AudioConverter::can_handle(const ConversionRequest& request,
                                 const MediaInfo& input_info) const {
    if (input_info.media_type != MediaType::kAudio) return false;
    if (!input_info.has_audio()) return false;

    const auto* to_fmt =
        FormatCatalog::instance().find_by_extension(request.output_extension());
    return to_fmt && to_fmt->media_type() == MediaType::kAudio;
}

Error AudioConverter::convert(const ConversionRequest& request,
                               const MediaInfo& input_info,
                               ProgressCallback progress) {
    Logger::instance().info("AudioConverter: " + request.input_extension() +
                            " -> " + request.output_extension());

    ffmpeg::FormatContext in_ctx;
    Error err = in_ctx.open_input(request.input_path());
    if (!err.ok()) return err;

    AVFormatContext* in_fmt = in_ctx.input_ctx();
    const StreamInfo* audio_info = input_info.audio_stream();
    if (!audio_info) return Error(ErrorCode::kInvalidArgument, "No audio stream");

    ffmpeg::FormatContext out_ctx;
    err = out_ctx.open_output(request.output_path());
    if (!err.ok()) return err;

    AudioTranscoder transcoder;
    err = transcoder.open(in_fmt, audio_info->index, out_ctx,
                          request.settings().audio);
    if (!err.ok()) return err;

    err = out_ctx.write_header();
    if (!err.ok()) return err;

    const double total_seconds = input_info.duration_us / 1000000.0;

    while (true) {
        ffmpeg::Packet pkt;
        if (av_read_frame(in_fmt, pkt.get()) < 0) break;

        if (pkt.get()->stream_index != static_cast<int>(transcoder.in_index())) {
            av_packet_unref(pkt.get());
            continue;
        }

        err = transcoder.feed(pkt.get(), out_ctx);
        av_packet_unref(pkt.get());
        if (!err.ok()) return err;

        if (progress && total_seconds > 0) {
            progress(static_cast<float>(
                min(1.0, transcoder.seconds_encoded() / total_seconds)));
        }
    }

    err = transcoder.finish(out_ctx);
    if (!err.ok()) return err;

    if (progress) progress(1.0f);
    return out_ctx.write_trailer();
}

} // namespace convertor
