#pragma once

#include <cstdint>
#include <optional>
#include <string>

using namespace std;

namespace convertor {

struct VideoSettings {
    optional<string> codec;
    optional<int> width;
    optional<int> height;
    optional<double> frame_rate;
    optional<int64_t> bit_rate;
    optional<int> crf;

    enum class Preset : uint32_t {
        kUltraFast = 0,
        kSuperFast,
        kVeryFast,
        kFaster,
        kFast,
        kMedium,
        kSlow,
        kSlower,
        kVerySlow,
    };

    optional<Preset> preset;
};

struct AudioSettings {
    optional<string> codec;
    optional<int> sample_rate;
    optional<int> channels;
    optional<string> channel_layout;
    optional<int64_t> bit_rate;
    optional<int> quality;
};

struct ImageSettings {
    optional<string> codec;
    optional<int> quality;
    optional<int> width;
    optional<int> height;
};

struct DocumentSettings {
    optional<int> dpi;
    optional<bool> extract_text;
    optional<string> page_range;
};

struct ConversionSettings {
    VideoSettings video;
    AudioSettings audio;
    ImageSettings image;
    DocumentSettings document;

    bool fast_start = false;
    bool overwrite = false;
    string temp_dir;
};

} // namespace convertor
