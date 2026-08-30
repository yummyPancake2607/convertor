#pragma once

#include <cstdint>
#include <string>

using namespace std;

namespace convertor {

enum class MediaType : uint32_t {
    kUnknown = 0,
    kVideo,
    kAudio,
    kImage,
    kDocument,
    kSubtitle,
    kAttachment,
};

enum class ConversionType : uint32_t {
    kNone = 0,
    kTranscode,
    kRemux,
    kExtractAudio,
    kExtractFrames,
    kImageToImage,
    kDocumentToDocument,
    kDocumentToImage,
    kTextToDocument,
};

MediaType media_type_from_extension(const string& ext);
MediaType media_type_from_mime(const string& mime);

const char* media_type_name(MediaType type);
const char* conversion_type_name(ConversionType type);

} // namespace convertor
