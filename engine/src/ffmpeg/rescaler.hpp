#pragma once

extern "C" {
#include <libswscale/swscale.h>
}

#include "av_deleters.hpp"
#include <convertor/error.hpp>

namespace convertor::ffmpeg {

class Rescaler {
public:
    Rescaler();
    ~Rescaler();

    Rescaler(const Rescaler&) = delete;
    Rescaler& operator=(const Rescaler&) = delete;

    convertor::Error init(int out_width, int out_height, int out_format,
                          int in_width, int in_height, int in_format);

    convertor::Error scale(AVFrame* in, AVFrame* out);

private:
    UniqueSwsContext ctx_;
    int out_width_ = 0;
    int out_height_ = 0;
};

} // namespace convertor::ffmpeg
