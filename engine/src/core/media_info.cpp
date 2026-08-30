#include <convertor/media_info.hpp>

using namespace std;

namespace convertor {

bool MediaInfo::has_video() const { return video_stream() != nullptr; }
bool MediaInfo::has_audio() const { return audio_stream() != nullptr; }

const StreamInfo* MediaInfo::video_stream() const {
    for (const auto& s : streams)
        if (s.media_type == MediaType::kVideo) return &s;
    return nullptr;
}

const StreamInfo* MediaInfo::audio_stream() const {
    for (const auto& s : streams)
        if (s.media_type == MediaType::kAudio) return &s;
    return nullptr;
}

} // namespace convertor
