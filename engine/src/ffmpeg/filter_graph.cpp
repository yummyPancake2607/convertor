#include "filter_graph.hpp"

extern "C" {
#include <libavutil/opt.h>
}

#include "ffmpeg_error.hpp"

using namespace std;

namespace convertor::ffmpeg {

FilterGraph::FilterGraph() = default;
FilterGraph::~FilterGraph() = default;

Error FilterGraph::init_video(const string& desc, int w, int h, int fmt, double tb) {
    graph_.reset(avfilter_graph_alloc());
    if (!graph_) return Error(ErrorCode::kOutOfMemory, "Failed to alloc filter graph");

    char args[512];
    snprintf(args, sizeof(args),
             "video_size=%dx%d:pix_fmt=%d:time_base=%f:pixel_aspect=1/1",
             w, h, fmt, tb);

    const AVFilter* buffersrc = avfilter_get_by_name("buffer");
    const AVFilter* buffersink = avfilter_get_by_name("buffersink");
    if (!buffersrc || !buffersink)
        return Error(ErrorCode::kFFmpegError, "Filters not found");

    AVFilterContext* src = nullptr;
    AVFilterContext* sink = nullptr;

    int ret = avfilter_graph_create_filter(&src, buffersrc, "in", args, nullptr, graph_.get());
    if (ret < 0) return ffmpeg_error(ret);
    src_ctx_ = src;

    ret = avfilter_graph_create_filter(&sink, buffersink, "out", nullptr, nullptr, graph_.get());
    if (ret < 0) return ffmpeg_error(ret);
    sink_ctx_ = sink;

    AVFilterInOut* outputs = avfilter_inout_alloc();
    AVFilterInOut* inputs  = avfilter_inout_alloc();
    outputs->name = av_strdup("in");
    outputs->filter_ctx = src;
    outputs->pad_idx = 0;
    outputs->next = nullptr;
    inputs->name = av_strdup("out");
    inputs->filter_ctx = sink;
    inputs->pad_idx = 0;
    inputs->next = nullptr;

    ret = avfilter_graph_parse_ptr(graph_.get(), desc.c_str(),
                                   &inputs, &outputs, nullptr);
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);
    if (ret < 0) return ffmpeg_error(ret);

    ret = avfilter_graph_config(graph_.get(), nullptr);
    if (ret < 0) return ffmpeg_error(ret);
    return Error::success();
}

Error FilterGraph::init_audio(const string& desc, int sample_rate, int channels, int fmt) {
    graph_.reset(avfilter_graph_alloc());
    if (!graph_) return Error(ErrorCode::kOutOfMemory, "Failed to alloc filter graph");

    char args[256];
    snprintf(args, sizeof(args),
             "sample_rate=%d:sample_fmt=%d:channels=%d:channel_layout=stereo",
             sample_rate, fmt, channels);

    const AVFilter* buffersrc = avfilter_get_by_name("abuffer");
    const AVFilter* buffersink = avfilter_get_by_name("abuffersink");
    if (!buffersrc || !buffersink)
        return Error(ErrorCode::kFFmpegError, "Audio filters not found");

    AVFilterContext* src = nullptr;
    AVFilterContext* sink = nullptr;

    int ret = avfilter_graph_create_filter(&src, buffersrc, "in", args, nullptr, graph_.get());
    if (ret < 0) return ffmpeg_error(ret);
    src_ctx_ = src;

    ret = avfilter_graph_create_filter(&sink, buffersink, "out", nullptr, nullptr, graph_.get());
    if (ret < 0) return ffmpeg_error(ret);
    sink_ctx_ = sink;

    AVFilterInOut* outputs = avfilter_inout_alloc();
    AVFilterInOut* inputs  = avfilter_inout_alloc();
    outputs->name = av_strdup("in");
    outputs->filter_ctx = src;
    outputs->pad_idx = 0;
    outputs->next = nullptr;
    inputs->name = av_strdup("out");
    inputs->filter_ctx = sink;
    inputs->pad_idx = 0;
    inputs->next = nullptr;

    ret = avfilter_graph_parse_ptr(graph_.get(), desc.c_str(),
                                   &inputs, &outputs, nullptr);
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);
    if (ret < 0) return ffmpeg_error(ret);

    ret = avfilter_graph_config(graph_.get(), nullptr);
    if (ret < 0) return ffmpeg_error(ret);
    return Error::success();
}

Error FilterGraph::add_frame(AVFrame* frame) {
    int ret = av_buffersrc_add_frame_flags(
        const_cast<AVFilterContext*>(src_ctx_), frame, AV_BUFFERSRC_FLAG_KEEP_REF);
    if (ret < 0) return ffmpeg_error(ret);
    return Error::success();
}

Error FilterGraph::get_frame(AVFrame* frame) {
    int ret = av_buffersink_get_frame(const_cast<AVFilterContext*>(sink_ctx_), frame);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
        return Error(ErrorCode::kInternal, "Filter needs more input");
    }
    if (ret < 0) return ffmpeg_error(ret);
    return Error::success();
}

void FilterGraph::flush() {
    if (src_ctx_) {
        AVFrame* null_frame = nullptr;
        av_buffersrc_add_frame(const_cast<AVFilterContext*>(src_ctx_), null_frame);
    }
}

} // namespace convertor::ffmpeg
