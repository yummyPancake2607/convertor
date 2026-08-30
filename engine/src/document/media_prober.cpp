#include "media_prober.hpp"

#include "../ffmpeg/format_context.hpp"
#include "../ffmpeg/ffmpeg_error.hpp"

#include "../fs/path_utils.hpp"

#include <cstdio>

using namespace std;

namespace convertor {

namespace {

// True when the file exists and can be read. Distinguishes "FFmpeg does not
// understand this container" from "there is nothing there to convert".
bool file_is_readable(const string& path) {
    FILE* f = fopen(path.c_str(), "rb");
    if (!f) return false;
    fclose(f);
    return true;
}

} // namespace

MediaInfo MediaProber::probe(const string& path, Error& err) {
    MediaInfo info;
    info.file_path = path;

    string ext = fs::extension(path);
    info.media_type = media_type_from_extension(ext);

    ffmpeg::FormatContext ctx;
    Error open_err = ctx.open_input(path);
    if (!open_err.ok()) {
        // FFmpeg only knows media containers. Documents (PDF, DOCX, TXT ...)
        // are expected to fail here, and they are still perfectly convertible
        // by the document pipeline, so report what the extension tells us
        // instead of failing the whole job.
        if (!file_is_readable(path)) {
            err = Error(ErrorCode::kFileNotFound, "Cannot read: " + path);
            return info;
        }
        if (info.media_type == MediaType::kUnknown) {
            err = open_err;
            return info;
        }
        info.format_name = ext;
        info.duration_us = 0;
        info.bit_rate = 0;
        err = Error::success();
        return info;
    }

    auto* fmt_ctx = ctx.input_ctx();
    info.format_name = fmt_ctx->iformat->name;
    info.format_long_name = fmt_ctx->iformat->long_name;
    info.duration_us = fmt_ctx->duration;
    info.bit_rate = fmt_ctx->bit_rate;
    info.start_time = fmt_ctx->start_time;

    for (unsigned i = 0; i < fmt_ctx->nb_streams; ++i) {
        AVStream* stream = fmt_ctx->streams[i];
        StreamInfo si;
        si.index = i;
        si.codec_name = avcodec_get_name(stream->codecpar->codec_id);
        si.bit_rate = stream->codecpar->bit_rate;

        switch (stream->codecpar->codec_type) {
            case AVMEDIA_TYPE_VIDEO:
                si.media_type = MediaType::kVideo;
                si.width = stream->codecpar->width;
                si.height = stream->codecpar->height;
                if (stream->avg_frame_rate.den > 0) {
                    si.frame_rate = av_q2d(stream->avg_frame_rate);
                }
                break;
            case AVMEDIA_TYPE_AUDIO:
                si.media_type = MediaType::kAudio;
                si.sample_rate = stream->codecpar->sample_rate;
                si.channels = stream->codecpar->ch_layout.nb_channels;
                break;
            case AVMEDIA_TYPE_SUBTITLE:
                si.media_type = MediaType::kSubtitle;
                break;
            default:
                si.media_type = MediaType::kUnknown;
                break;
        }

        info.streams.push_back(si);
    }

    // A still image decodes as a single "video" stream in FFmpeg. Trust the
    // extension over the stream layout so image files are not mistaken for
    // video by the converters that key off has_video().
    if (info.media_type == MediaType::kUnknown) {
        if (!info.streams.empty()) {
            bool any_video = false, any_audio = false;
            for (const auto& s : info.streams) {
                if (s.media_type == MediaType::kVideo) any_video = true;
                if (s.media_type == MediaType::kAudio) any_audio = true;
            }
            info.media_type = any_video ? MediaType::kVideo
                            : any_audio ? MediaType::kAudio
                                        : MediaType::kUnknown;
        }
    }

    err = Error::success();
    return info;
}

} // namespace convertor
