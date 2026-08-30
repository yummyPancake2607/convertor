#include "resampler.hpp"

extern "C" {
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>
}

#include "ffmpeg_error.hpp"

using namespace std;

namespace convertor::ffmpeg {

Resampler::Resampler() = default;
Resampler::~Resampler() = default;

Error Resampler::init(int out_rate, int out_channels, int out_fmt,
                      int in_rate, int in_channels, int in_fmt) {
    if (ctx_) {
        SwrContext* raw = ctx_.release();
        swr_free(&raw);
    }

    AVChannelLayout in_layout = {};
    av_channel_layout_default(&in_layout, in_channels);

    AVChannelLayout out_layout = {};
    av_channel_layout_default(&out_layout, out_channels);

    SwrContext* swr = nullptr;
    int ret = swr_alloc_set_opts2(&swr,
                                  &out_layout, (AVSampleFormat)out_fmt, out_rate,
                                  &in_layout,  (AVSampleFormat)in_fmt,  in_rate,
                                  0, nullptr);
    av_channel_layout_uninit(&in_layout);
    av_channel_layout_uninit(&out_layout);

    if (ret < 0 || !swr) return ffmpeg_error(ret);

    ret = swr_init(swr);
    if (ret < 0) {
        swr_free(&swr);
        return ffmpeg_error(ret);
    }
    ctx_.reset(swr);
    return Error::success();
}

Error Resampler::convert(AVFrame* in, AVFrame* out) {
    int out_samples = av_rescale_rnd(
        swr_get_delay(ctx_.get(), in->sample_rate) + in->nb_samples,
        out->sample_rate, in->sample_rate, AV_ROUND_UP);

    out->nb_samples = out_samples;
    int ret = av_frame_make_writable(out);
    if (ret < 0) return ffmpeg_error(ret);

    uint8_t** out_buf = out->extended_data;
    ret = swr_convert(ctx_.get(), out_buf, out_samples,
                      const_cast<const uint8_t**>(in->extended_data), in->nb_samples);
    if (ret < 0) return ffmpeg_error(ret);
    return Error::success();
}

void Resampler::flush() {
    if (ctx_) swr_convert(ctx_.get(), nullptr, 0, nullptr, 0);
}

} // namespace convertor::ffmpeg
