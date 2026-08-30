#include "ffmpeg_error.hpp"

extern "C" {
#include <libavutil/error.h>
}

using namespace std;

namespace convertor::ffmpeg {

Error ffmpeg_error(int av_error) {
    if (av_error >= 0) return Error::success();
    char buf[256];
    av_strerror(av_error, buf, sizeof(buf));
    return Error(ErrorCode::kFFmpegError, "FFmpeg error", buf);
}

Error ffmpeg_open_error(const string& path) {
    return Error(ErrorCode::kFFmpegOpen, "Failed to open: " + path);
}

Error ffmpeg_decode_error() {
    return Error(ErrorCode::kFFmpegDecode, "Decode failed");
}

Error ffmpeg_encode_error() {
    return Error(ErrorCode::kFFmpegEncode, "Encode failed");
}

Error ffmpeg_mux_error() {
    return Error(ErrorCode::kFFmpegMux, "Mux/write failed");
}

} // namespace convertor::ffmpeg
