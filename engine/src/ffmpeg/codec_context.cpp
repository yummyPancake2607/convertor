#include "codec_context.hpp"

extern "C" {
#include <libavcodec/avcodec.h>
}

#include "ffmpeg_error.hpp"

using namespace std;

namespace convertor::ffmpeg {

CodecContext::CodecContext() = default;
CodecContext::~CodecContext() = default;

CodecContext::CodecContext(CodecContext&&) noexcept = default;
CodecContext& CodecContext::operator=(CodecContext&&) noexcept = default;

Error CodecContext::open_decoder(const AVCodecParameters* params) {
    codec_ = avcodec_find_decoder(params->codec_id);
    if (!codec_) return Error(ErrorCode::kFFmpegOpen, "Decoder not found");

    ctx_.reset(avcodec_alloc_context3(codec_));
    if (!ctx_) return Error(ErrorCode::kOutOfMemory, "Failed to alloc codec context");

    int ret = avcodec_parameters_to_context(ctx_.get(), params);
    if (ret < 0) return ffmpeg_error(ret);

    ctx_->thread_count = 0; // auto-detect
    ret = avcodec_open2(ctx_.get(), codec_, nullptr);
    if (ret < 0) return ffmpeg_error(ret);
    return Error::success();
}

Error CodecContext::open_encoder(const AVCodecParameters* params) {
    return open_encoder_by_name("", params);
}

Error CodecContext::open_encoder_by_name(const string& name,
                                         const AVCodecParameters* params) {
    if (name.empty()) {
        codec_ = avcodec_find_encoder(params->codec_id);
    } else {
        codec_ = avcodec_find_encoder_by_name(name.c_str());
    }
    if (!codec_) return Error(ErrorCode::kFFmpegOpen, "Encoder not found: " + name);

    ctx_.reset(avcodec_alloc_context3(codec_));
    if (!ctx_) return Error(ErrorCode::kOutOfMemory, "Failed to alloc codec context");

    return Error::success();
}

Error CodecContext::send_frame(const AVFrame* frame) {
    int ret = avcodec_send_frame(ctx_.get(), frame);
    if (ret < 0) return ffmpeg_encode_error();
    return Error::success();
}

Error CodecContext::send_packet(const AVPacket* pkt) {
    int ret = avcodec_send_packet(ctx_.get(), pkt);
    if (ret < 0) return ffmpeg_decode_error();
    return Error::success();
}

Error CodecContext::receive_frame(AVFrame* frame) {
    int ret = avcodec_receive_frame(ctx_.get(), frame);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
        return Error(ErrorCode::kInternal, "Need more input");
    }
    if (ret < 0) return ffmpeg_decode_error();
    return Error::success();
}

Error CodecContext::receive_packet(AVPacket* pkt) {
    int ret = avcodec_receive_packet(ctx_.get(), pkt);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
        return Error(ErrorCode::kInternal, "Need more input");
    }
    if (ret < 0) return ffmpeg_encode_error();
    return Error::success();
}

AVCodecContext* CodecContext::ctx() const { return ctx_.get(); }
const AVCodec* CodecContext::codec() const { return codec_; }

Error CodecContext::copy_params_from(const AVCodecParameters* params) {
    int ret = avcodec_parameters_to_context(ctx_.get(), params);
    if (ret < 0) return ffmpeg_error(ret);
    return Error::success();
}

} // namespace convertor::ffmpeg
