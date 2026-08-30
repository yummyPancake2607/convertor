#pragma once

#include <string>

#include "av_deleters.hpp"
#include <convertor/error.hpp>

namespace convertor::ffmpeg {

class FormatContext {
public:
    FormatContext();
    ~FormatContext();

    FormatContext(const FormatContext&) = delete;
    FormatContext& operator=(const FormatContext&) = delete;
    FormatContext(FormatContext&&) noexcept;
    FormatContext& operator=(FormatContext&&) noexcept;

    convertor::Error open_input(const std::string& path);
    convertor::Error open_output(const std::string& path);
    convertor::Error write_header();
    convertor::Error write_packet(AVPacket* pkt);
    convertor::Error write_trailer();

    AVFormatContext* input_ctx() const;
    AVFormatContext* output_ctx() const;

    bool is_open() const;

private:
    UniqueAVFormatCtx input_ctx_;
    UniqueAVOutputFmtCtx output_ctx_;
};

} // namespace convertor::ffmpeg
