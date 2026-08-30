#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include <convertor/media_type.hpp>

using namespace std;

namespace convertor {

struct StreamInfo {
    uint32_t index = 0;
    MediaType media_type = MediaType::kUnknown;
    string codec_name;
    string codec_long_name;

    int width = 0;
    int height = 0;
    double frame_rate = 0.0;

    int sample_rate = 0;
    int channels = 0;
    string channel_layout;

    int64_t duration_us = 0;
    int64_t bit_rate = 0;
};

struct MediaInfo {
    string file_path;
    string format_name;
    string format_long_name;
    MediaType media_type = MediaType::kUnknown;

    int64_t duration_us = 0;
    int64_t bit_rate = 0;
    double start_time = 0.0;

    vector<StreamInfo> streams;

    bool has_video() const;
    bool has_audio() const;

    const StreamInfo* video_stream() const;
    const StreamInfo* audio_stream() const;
};

} // namespace convertor
