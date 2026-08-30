#include "rescaler.hpp"

#include "ffmpeg_error.hpp"

using namespace std;

namespace convertor::ffmpeg {

Rescaler::Rescaler() = default;
Rescaler::~Rescaler() = default;

Error Rescaler::init(int out_w, int out_h, int out_fmt,
                     int in_w, int in_h, int in_fmt) {
    ctx_.reset(sws_getContext(in_w, in_h, (AVPixelFormat)in_fmt,
                              out_w, out_h, (AVPixelFormat)out_fmt,
                              SWS_BILINEAR, nullptr, nullptr, nullptr));
    if (!ctx_) return Error(ErrorCode::kOutOfMemory, "Failed to alloc SwsContext");
    out_width_ = out_w;
    out_height_ = out_h;
    return Error::success();
}

Error Rescaler::scale(AVFrame* in, AVFrame* out) {
    out->width = out_width_;
    out->height = out_height_;
    out->format = in->format;
    int ret = av_frame_make_writable(out);
    if (ret < 0) return ffmpeg_error(ret);

    sws_scale(ctx_.get(),
              in->data, in->linesize, 0, in->height,
              out->data, out->linesize);
    return Error::success();
}

} // namespace convertor::ffmpeg
