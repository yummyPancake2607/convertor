#include <convertor/file_format.hpp>

using namespace std;

namespace convertor {

FileFormat::FileFormat() : media_type_(MediaType::kUnknown) {}

FileFormat::FileFormat(string id, string name, string extension,
                       MediaType media_type, vector<string> mime_types)
    : id_(move(id)), name_(move(name)), extension_(move(extension)),
      media_type_(media_type), mime_types_(move(mime_types)) {}

const string& FileFormat::id() const { return id_; }
const string& FileFormat::name() const { return name_; }
const string& FileFormat::extension() const { return extension_; }
MediaType FileFormat::media_type() const { return media_type_; }
const vector<string>& FileFormat::mime_types() const { return mime_types_; }

bool FileFormat::supports_conversion_to(const string& target_format_id) const {
    for (const auto& id : conversion_targets_) {
        if (id == target_format_id) return true;
    }
    return false;
}

void FileFormat::add_conversion_target(const string& target_format_id) {
    if (!supports_conversion_to(target_format_id)) {
        conversion_targets_.push_back(target_format_id);
    }
}

bool FileFormat::operator==(const FileFormat& other) const { return id_ == other.id_; }
bool FileFormat::operator<(const FileFormat& other) const { return id_ < other.id_; }

} // namespace convertor
