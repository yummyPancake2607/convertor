#pragma once

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
#include <libavfilter/avfilter.h>
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
}

#include <memory>

namespace convertor::ffmpeg {

struct AVFrameDeleter {
    void operator()(AVFrame* p) const { if (p) av_frame_free(&p); }
};

struct AVPacketDeleter {
    void operator()(AVPacket* p) const { if (p) av_packet_free(&p); }
};

struct AVFormatContextDeleter {
    void operator()(AVFormatContext* p) const { if (p) avformat_close_input(&p); }
};

struct AVOutputFormatContextDeleter {
    void operator()(AVFormatContext* p) const { if (p) avformat_free_context(p); }
};

struct AVCodecContextDeleter {
    void operator()(AVCodecContext* p) const { if (p) avcodec_free_context(&p); }
};

struct AVFilterGraphDeleter {
    void operator()(AVFilterGraph* p) const { if (p) avfilter_graph_free(&p); }
};

struct SwsContextDeleter {
    void operator()(SwsContext* p) const { if (p) sws_freeContext(p); }
};

struct SwrContextDeleter {
    void operator()(SwrContext* p) const { if (p) swr_free(&p); }
};

using UniqueAVFrame         = std::unique_ptr<AVFrame, AVFrameDeleter>;
using UniqueAVPacket        = std::unique_ptr<AVPacket, AVPacketDeleter>;
using UniqueAVFormatCtx     = std::unique_ptr<AVFormatContext, AVFormatContextDeleter>;
using UniqueAVOutputFmtCtx  = std::unique_ptr<AVFormatContext, AVOutputFormatContextDeleter>;
using UniqueAVCodecCtx      = std::unique_ptr<AVCodecContext, AVCodecContextDeleter>;
using UniqueAVFilterGraph   = std::unique_ptr<AVFilterGraph, AVFilterGraphDeleter>;
using UniqueSwsContext      = std::unique_ptr<SwsContext, SwsContextDeleter>;
using UniqueSwrContext      = std::unique_ptr<SwrContext, SwrContextDeleter>;

inline UniqueAVFrame make_frame() {
    return UniqueAVFrame(av_frame_alloc());
}

inline UniqueAVPacket make_packet() {
    return UniqueAVPacket(av_packet_alloc());
}

} // namespace convertor::ffmpeg
