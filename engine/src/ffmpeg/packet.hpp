#pragma once

#include "av_deleters.hpp"
#include <convertor/error.hpp>

namespace convertor::ffmpeg {

class Packet {
public:
    Packet();
    ~Packet() = default;

    Packet(const Packet&) = delete;
    Packet& operator=(const Packet&) = delete;
    Packet(Packet&&) noexcept;
    Packet& operator=(Packet&&) noexcept;

    AVPacket* packet() const;
    AVPacket* get();

    void set_stream_index(int index);
    void set_pts(int64_t pts);
    void set_dts(int64_t dts);

private:
    UniqueAVPacket pkt_;
};

} // namespace convertor::ffmpeg
