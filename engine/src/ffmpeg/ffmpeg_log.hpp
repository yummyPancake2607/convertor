#pragma once

#include <convertor/logging.hpp>

namespace convertor::ffmpeg {

class FFmpegLog {
public:
    static void init();
    static void set_level(int level);

private:
    static void callback(void* ptr, int level, const char* fmt, va_list args);
};

} // namespace convertor::ffmpeg
