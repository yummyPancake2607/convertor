#pragma once

extern "C" {
#include <libavcodec/avcodec.h>
}

#include "av_deleters.hpp"
#include <convertor/error.hpp>

namespace convertor::ffmpeg {

class CodecContext {
public:
    CodecContext();
    ~CodecContext();

    CodecContext(const CodecContext&) = delete;
    CodecContext& operator=(const CodecContext&) = delete;
    CodecContext(CodecContext&&) noexcept;
    CodecContext& operator=(CodecContext&&) noexcept;

    convertor::Error open_decoder(const AVCodecParameters* params);
    convertor::Error open_encoder(const AVCodecParameters* params);
    convertor::Error open_encoder_by_name(const std::string& name,
                                          const AVCodecParameters* params);

    convertor::Error send_frame(const AVFrame* frame);
    convertor::Error send_packet(const AVPacket* pkt);
    convertor::Error receive_frame(AVFrame* frame);
    convertor::Error receive_packet(AVPacket* pkt);

    AVCodecContext* ctx() const;
    const AVCodec* codec() const;

    convertor::Error copy_params_from(const AVCodecParameters* params);

private:
    UniqueAVCodecCtx ctx_;
    const AVCodec* codec_ = nullptr;
};

} // namespace convertor::ffmpeg
