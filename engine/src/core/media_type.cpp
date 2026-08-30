#include <convertor/media_type.hpp>

using namespace std;

namespace convertor {

MediaType media_type_from_extension(const string& ext) {
    string lower = ext;
    for (auto& c : lower) c = tolower(c);

    if (lower == "mp4" || lower == "mkv" || lower == "avi" || lower == "mov" ||
        lower == "webm" || lower == "flv" || lower == "wmv" || lower == "m4v" ||
        lower == "ts" || lower == "mts" || lower == "m2ts" || lower == "3gp" ||
        lower == "mpeg" || lower == "mpg" || lower == "ogv")
        return MediaType::kVideo;

    if (lower == "mp3" || lower == "wav" || lower == "flac" || lower == "aac" ||
        lower == "ogg" || lower == "wma" || lower == "m4a" || lower == "opus" ||
        lower == "aiff" || lower == "aif")
        return MediaType::kAudio;

    if (lower == "jpg" || lower == "jpeg" || lower == "png" || lower == "gif" ||
        lower == "bmp" || lower == "webp" || lower == "tiff" || lower == "tif" ||
        lower == "svg" || lower == "ico" || lower == "heic" || lower == "avif")
        return MediaType::kImage;

    if (lower == "pdf" || lower == "docx" || lower == "xlsx" || lower == "pptx" ||
        lower == "doc" || lower == "xls" || lower == "ppt" || lower == "odt" ||
        lower == "ods" || lower == "odp" || lower == "txt" || lower == "md" ||
        lower == "csv" || lower == "html" || lower == "htm" || lower == "rtf" ||
        lower == "epub" || lower == "odg")
        return MediaType::kDocument;

    if (lower == "srt" || lower == "ass" || lower == "ssa" || lower == "vtt" ||
        lower == "sub")
        return MediaType::kSubtitle;

    return MediaType::kUnknown;
}

MediaType media_type_from_mime(const string& mime) {
    if (mime.find("video/") == 0) return MediaType::kVideo;
    if (mime.find("audio/") == 0) return MediaType::kAudio;
    if (mime.find("image/") == 0) return MediaType::kImage;
    if (mime.find("application/pdf") != string::npos ||
        mime.find("application/msword") != string::npos ||
        mime.find("application/vnd.") != string::npos ||
        mime.find("text/") == 0)
        return MediaType::kDocument;
    return MediaType::kUnknown;
}

const char* media_type_name(MediaType type) {
    switch (type) {
        case MediaType::kUnknown:    return "Unknown";
        case MediaType::kVideo:      return "Video";
        case MediaType::kAudio:      return "Audio";
        case MediaType::kImage:      return "Image";
        case MediaType::kDocument:   return "Document";
        case MediaType::kSubtitle:   return "Subtitle";
        case MediaType::kAttachment: return "Attachment";
    }
    return "Unknown";
}

const char* conversion_type_name(ConversionType type) {
    switch (type) {
        case ConversionType::kNone:              return "None";
        case ConversionType::kTranscode:         return "Transcode";
        case ConversionType::kRemux:             return "Remux";
        case ConversionType::kExtractAudio:      return "Extract Audio";
        case ConversionType::kExtractFrames:     return "Extract Frames";
        case ConversionType::kImageToImage:      return "Image Convert";
        case ConversionType::kDocumentToDocument: return "Document Convert";
        case ConversionType::kDocumentToImage:   return "Document to Image";
        case ConversionType::kTextToDocument:    return "Text to Document";
    }
    return "Unknown";
}

} // namespace convertor
