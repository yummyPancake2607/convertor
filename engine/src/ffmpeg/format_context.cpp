#include "format_context.hpp"

extern "C" {
#include <libavformat/avformat.h>
}

#include "ffmpeg_error.hpp"

using namespace std;

namespace convertor::ffmpeg {

FormatContext::FormatContext() = default;
FormatContext::~FormatContext() = default;

FormatContext::FormatContext(FormatContext&&) noexcept = default;
FormatContext& FormatContext::operator=(FormatContext&&) noexcept = default;

Error FormatContext::open_input(const string& path) {
    AVFormatContext* ctx = nullptr;
    int ret = avformat_open_input(&ctx, path.c_str(), nullptr, nullptr);
    if (ret < 0) return ffmpeg_open_error(path);
    input_ctx_.reset(ctx);
    ret = avformat_find_stream_info(input_ctx_.get(), nullptr);
    if (ret < 0) return ffmpeg_error(ret);
    return Error::success();
}

Error FormatContext::open_output(const string& path) {
    AVFormatContext* ctx = nullptr;
    int ret = avformat_alloc_output_context2(&ctx, nullptr, nullptr, path.c_str());
    if (ret < 0) return ffmpeg_error(ret);
    output_ctx_.reset(ctx);
    return Error::success();
}

Error FormatContext::write_header() {
    if (!(output_ctx_->oformat->flags & AVFMT_NOFILE)) {
        int ret = avio_open(&output_ctx_->pb, output_ctx_->url, AVIO_FLAG_WRITE);
        if (ret < 0) return ffmpeg_error(ret);
    }
    int ret = avformat_write_header(output_ctx_.get(), nullptr);
    if (ret < 0) return ffmpeg_error(ret);
    return Error::success();
}

Error FormatContext::write_packet(AVPacket* pkt) {
    int ret = av_interleaved_write_frame(output_ctx_.get(), pkt);
    if (ret < 0) return ffmpeg_mux_error();
    return Error::success();
}

Error FormatContext::write_trailer() {
    av_write_trailer(output_ctx_.get());
    if (output_ctx_ && !(output_ctx_->oformat->flags & AVFMT_NOFILE)) {
        avio_closep(&output_ctx_->pb);
    }
    return Error::success();
}

AVFormatContext* FormatContext::input_ctx() const { return input_ctx_.get(); }
AVFormatContext* FormatContext::output_ctx() const { return output_ctx_.get(); }
bool FormatContext::is_open() const { return input_ctx_ != nullptr || output_ctx_ != nullptr; }

} // namespace convertor::ffmpeg
