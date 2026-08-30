#include "packet.hpp"

using namespace std;

namespace convertor::ffmpeg {

Packet::Packet() : pkt_(make_packet()) {}
Packet::Packet(Packet&&) noexcept = default;
Packet& Packet::operator=(Packet&&) noexcept = default;

AVPacket* Packet::packet() const { return pkt_.get(); }
AVPacket* Packet::get() { return pkt_.get(); }

void Packet::set_stream_index(int index) { pkt_->stream_index = index; }
void Packet::set_pts(int64_t pts) { pkt_->pts = pts; }
void Packet::set_dts(int64_t dts) { pkt_->dts = dts; }

} // namespace convertor::ffmpeg
