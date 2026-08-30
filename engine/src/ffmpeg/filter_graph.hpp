#pragma once

extern "C" {
#include <libavfilter/avfilter.h>
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
}

#include "av_deleters.hpp"
#include <convertor/error.hpp>

namespace convertor::ffmpeg {

class FilterGraph {
public:
    FilterGraph();
    ~FilterGraph();

    FilterGraph(const FilterGraph&) = delete;
    FilterGraph& operator=(const FilterGraph&) = delete;

    convertor::Error init_video(const std::string& filter_desc,
                                int width, int height, int format, double time_base);
    convertor::Error init_audio(const std::string& filter_desc,
                                int sample_rate, int channels, int format);

    convertor::Error add_frame(AVFrame* frame);
    convertor::Error get_frame(AVFrame* frame);

    void flush();

private:
    UniqueAVFilterGraph graph_;
    const AVFilterContext* src_ctx_ = nullptr;
    const AVFilterContext* sink_ctx_ = nullptr;
};

} // namespace convertor::ffmpeg
