#include "frame.hpp"

extern "C" {
#include <libavutil/frame.h>
}

#include "ffmpeg_error.hpp"

using namespace std;

namespace convertor::ffmpeg {

Frame::Frame() : frame_(make_frame()) {}
Frame::Frame(Frame&&) noexcept = default;
Frame& Frame::operator=(Frame&&) noexcept = default;

Error Frame::allocate(int width, int height, int format) {
    frame_->width = width;
    frame_->height = height;
    frame_->format = format;
    int ret = av_frame_get_buffer(frame_.get(), 0);
    if (ret < 0) return ffmpeg_error(ret);
    return Error::success();
}

Error Frame::allocate_audio(int nb_samples, int format, int channels) {
    frame_->nb_samples = nb_samples;
    frame_->format = format;
    av_channel_layout_default(&frame_->ch_layout, channels);
    int ret = av_frame_get_buffer(frame_.get(), 0);
    if (ret < 0) return ffmpeg_error(ret);
    return Error::success();
}

AVFrame* Frame::frame() const { return frame_.get(); }
AVFrame* Frame::get() { return frame_.get(); }

int Frame::width() const { return frame_->width; }
int Frame::height() const { return frame_->height; }
int Frame::format() const { return frame_->format; }

void Frame::set_pts(int64_t pts) { frame_->pts = pts; }

} // namespace convertor::ffmpeg
