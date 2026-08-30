#include "ffmpeg_log.hpp"

extern "C" {
#include <libavutil/log.h>
}

#include <cstdarg>
#include <cstdio>

using namespace std;

namespace convertor::ffmpeg {

void FFmpegLog::init() {
    av_log_set_level(AV_LOG_INFO);
    av_log_set_callback(callback);
}

void FFmpegLog::set_level(int level) {
    av_log_set_level(level);
}

void FFmpegLog::callback(void* /*ptr*/, int level, const char* fmt, va_list args) {
    auto& log = convertor::Logger::instance();
    convertor::LogLevel our_level;
    if (level <= AV_LOG_PANIC)   our_level = convertor::LogLevel::kFatal;
    else if (level <= AV_LOG_FATAL) our_level = convertor::LogLevel::kFatal;
    else if (level <= AV_LOG_ERROR) our_level = convertor::LogLevel::kError;
    else if (level <= AV_LOG_WARNING) our_level = convertor::LogLevel::kWarn;
    else if (level <= AV_LOG_INFO)  our_level = convertor::LogLevel::kInfo;
    else if (level <= AV_LOG_VERBOSE) our_level = convertor::LogLevel::kDebug;
    else our_level = convertor::LogLevel::kTrace;

    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, args);
    log.log(our_level, string("[FFmpeg] ") + buf);
}

} // namespace convertor::ffmpeg
