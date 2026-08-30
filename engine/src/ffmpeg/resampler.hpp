#pragma once

extern "C" {
#include <libswresample/swresample.h>
}

#include "av_deleters.hpp"
#include <convertor/error.hpp>

namespace convertor::ffmpeg {

class Resampler {
public:
    Resampler();
    ~Resampler();

    Resampler(const Resampler&) = delete;
    Resampler& operator=(const Resampler&) = delete;

    convertor::Error init(int out_sample_rate, int out_channels,
                          int out_sample_format,
                          int in_sample_rate, int in_channels,
                          int in_sample_format);

    convertor::Error convert(AVFrame* in, AVFrame* out);
    void flush();

    SwrContext* ctx() const { return ctx_.get(); }

private:
    UniqueSwrContext ctx_;
};

} // namespace convertor::ffmpeg
