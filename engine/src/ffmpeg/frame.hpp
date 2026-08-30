#pragma once

#include "av_deleters.hpp"
#include <convertor/error.hpp>

namespace convertor::ffmpeg {

class Frame {
public:
    Frame();
    ~Frame() = default;

    Frame(const Frame&) = delete;
    Frame& operator=(const Frame&) = delete;
    Frame(Frame&&) noexcept;
    Frame& operator=(Frame&&) noexcept;

    convertor::Error allocate(int width, int height, int format);
    convertor::Error allocate_audio(int nb_samples, int format, int channels);

    AVFrame* frame() const;
    AVFrame* get();

    int width() const;
    int height() const;
    int format() const;

    void set_pts(int64_t pts);

private:
    UniqueAVFrame frame_;
};

} // namespace convertor::ffmpeg
