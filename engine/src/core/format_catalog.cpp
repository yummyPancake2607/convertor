#include <convertor/format_catalog.hpp>

using namespace std;

namespace convertor {

FormatCatalog& FormatCatalog::instance() {
    static FormatCatalog s_instance;
    return s_instance;
}

void FormatCatalog::register_format(const FileFormat& format) {
    formats_.push_back(format);
}

const FileFormat* FormatCatalog::find_by_id(const string& id) const {
    for (const auto& f : formats_)
        if (f.id() == id) return &f;
    return nullptr;
}

const FileFormat* FormatCatalog::find_by_extension(const string& ext) const {
    for (const auto& f : formats_)
        if (f.extension() == ext) return &f;
    return nullptr;
}

const FileFormat* FormatCatalog::find_by_mime(const string& mime) const {
    for (const auto& f : formats_)
        for (const auto& m : f.mime_types())
            if (m == mime) return &f;
    return nullptr;
}

vector<const FileFormat*> FormatCatalog::all_formats() const {
    vector<const FileFormat*> result;
    result.reserve(formats_.size());
    for (const auto& f : formats_) result.push_back(&f);
    return result;
}

vector<const FileFormat*> FormatCatalog::formats_for_type(MediaType type) const {
    vector<const FileFormat*> result;
    for (const auto& f : formats_)
        if (f.media_type() == type) result.push_back(&f);
    return result;
}

vector<string> FormatCatalog::outputs_for_id(const string& id) const {
    const auto* from = find_by_id(id);
    if (!from) return {};
    vector<string> result;
    for (const auto& f : formats_) {
        if (f.id() != id && from->supports_conversion_to(f.id()))
            result.push_back(f.id());
    }
    return result;
}

bool FormatCatalog::can_convert(const string& from_id, const string& to_id) const {
    const auto* from = find_by_id(from_id);
    if (!from) return false;
    return from->supports_conversion_to(to_id);
}

ConversionType FormatCatalog::conversion_type_for(const string& from_id,
                                                   const string& to_id) const {
    const auto* from = find_by_id(from_id);
    const auto* to = find_by_id(to_id);
    if (!from || !to || !from->supports_conversion_to(to_id))
        return ConversionType::kNone;

    if (from->media_type() == MediaType::kVideo && to->media_type() == MediaType::kAudio)
        return ConversionType::kExtractAudio;
    if (from->media_type() == MediaType::kVideo && to->media_type() == MediaType::kImage)
        return ConversionType::kExtractFrames;
    if (from->media_type() == MediaType::kImage && to->media_type() == MediaType::kImage)
        return ConversionType::kImageToImage;
    if (from->media_type() == MediaType::kDocument && to->media_type() == MediaType::kDocument)
        return ConversionType::kDocumentToDocument;
    if (from->media_type() == MediaType::kDocument && to->media_type() == MediaType::kImage)
        return ConversionType::kDocumentToImage;
    if (from->media_type() == to->media_type())
        return ConversionType::kTranscode;

    return ConversionType::kNone;
}

void FormatCatalog::load_defaults() {
    if (loaded_) return;
    loaded_ = true;

    // Video containers. The read-only ones can be opened as input but the
    // engine does not offer them as conversion targets.
    register_format({"mp4",  "MP4",       "mp4",  MediaType::kVideo, {"video/mp4"}});
    register_format({"mkv",  "Matroska",  "mkv",  MediaType::kVideo, {"video/x-matroska"}});
    register_format({"mov",  "QuickTime", "mov",  MediaType::kVideo, {"video/quicktime"}});
    register_format({"webm", "WebM",      "webm", MediaType::kVideo, {"video/webm"}});
    register_format({"flv",  "Flash",     "flv",  MediaType::kVideo, {"video/x-flv"}});
    register_format({"ts",   "MPEG-TS",   "ts",   MediaType::kVideo, {"video/mp2t"}});
    register_format({"avi",  "AVI",       "avi",  MediaType::kVideo, {"video/x-msvideo"}});
    register_format({"wmv",  "WMV",       "wmv",  MediaType::kVideo, {"video/x-ms-wmv"}});
    register_format({"m4v",  "M4V",       "m4v",  MediaType::kVideo, {"video/x-m4v"}});
    register_format({"3gp",  "3GP",       "3gp",  MediaType::kVideo, {"video/3gpp"}});
    register_format({"mpeg", "MPEG",      "mpeg", MediaType::kVideo, {"video/mpeg"}});
    register_format({"ogv",  "Ogg Video", "ogv",  MediaType::kVideo, {"video/ogg"}});

    // Audio
    register_format({"mp3",  "MP3",        "mp3",  MediaType::kAudio, {"audio/mpeg"}});
    register_format({"wav",  "WAV",        "wav",  MediaType::kAudio, {"audio/wav"}});
    register_format({"flac", "FLAC",       "flac", MediaType::kAudio, {"audio/flac"}});
    register_format({"aac",  "AAC",        "aac",  MediaType::kAudio, {"audio/aac"}});
    register_format({"ogg",  "Ogg Vorbis", "ogg",  MediaType::kAudio, {"audio/ogg"}});
    register_format({"m4a",  "M4A",        "m4a",  MediaType::kAudio, {"audio/mp4"}});
    register_format({"opus", "Opus",       "opus", MediaType::kAudio, {"audio/opus"}});
    register_format({"wma",  "WMA",        "wma",  MediaType::kAudio, {"audio/x-ms-wma"}});
    register_format({"aiff", "AIFF",       "aiff", MediaType::kAudio, {"audio/aiff"}});

    // Image
    register_format({"jpg",  "JPEG", "jpg",  MediaType::kImage, {"image/jpeg"}});
    register_format({"png",  "PNG",  "png",  MediaType::kImage, {"image/png"}});
    register_format({"gif",  "GIF",  "gif",  MediaType::kImage, {"image/gif"}});
    register_format({"bmp",  "BMP",  "bmp",  MediaType::kImage, {"image/bmp"}});
    register_format({"webp", "WebP", "webp", MediaType::kImage, {"image/webp"}});
    register_format({"tiff", "TIFF", "tiff", MediaType::kImage, {"image/tiff"}});
    register_format({"ico",  "Icon", "ico",  MediaType::kImage, {"image/x-icon"}});
    register_format({"avif", "AVIF", "avif", MediaType::kImage, {"image/avif"}});

    // Documents. Word and PDF only: those are the two the app converts
    // between, and offering a format with no conversion behind it would just
    // be a dead end in the picker.
    register_format({"pdf",  "PDF",  "pdf",  MediaType::kDocument, {"application/pdf"}});
    register_format({"docx", "Word", "docx", MediaType::kDocument,
                     {"application/vnd.openxmlformats-officedocument.wordprocessingml.document"}});

    // Conversion targets. This table is the engine's contract with the UI, so
    // it lists only pairs a converter genuinely implements.
    auto add_all = [&](const vector<string>& from_ids,
                       const vector<string>& to_ids) {
        for (const auto& from_id : from_ids) {
            auto* fmt = const_cast<FileFormat*>(find_by_id(from_id));
            if (!fmt) continue;
            for (const auto& to_id : to_ids) {
                if (from_id != to_id) fmt->add_conversion_target(to_id);
            }
        }
    };

    const vector<string> video_in = {"mp4", "mkv", "mov", "webm", "flv", "ts",
                                     "avi", "wmv", "m4v", "3gp", "mpeg", "ogv"};
    const vector<string> video_out = {"mp4", "mkv", "mov", "webm", "ts", "flv"};
    const vector<string> audio_in = {"mp3", "wav", "flac", "aac", "ogg",
                                     "m4a", "opus", "wma", "aiff"};
    const vector<string> audio_out = {"mp3", "wav", "flac", "aac", "ogg",
                                      "m4a", "opus"};
    const vector<string> image_out = {"jpg", "png", "gif", "bmp", "webp", "tiff"};
    const vector<string> image_in = {"jpg", "png", "gif", "bmp", "webp", "tiff",
                                     "ico", "avif"};
    const vector<string> text_in = {"txt", "md", "html", "csv"};

    // Video: transcode to another container, or strip out the audio track.
    // Exporting a still frame is deliberately not offered - a video is not a
    // picture, and one arbitrary frame is rarely what someone asked for.
    add_all(video_in, video_out);
    add_all(video_in, audio_out);

    // Audio: transcode between audio containers.
    add_all(audio_in, audio_out);

    // Images: convert between formats, or wrap into a PDF page.
    add_all(image_in, image_out);
    add_all(image_in, {"pdf"});

    // Documents convert between Word and PDF, in both directions.
    add_all({"pdf"}, {"docx"});
    add_all({"docx"}, {"pdf"});
}

} // namespace convertor
