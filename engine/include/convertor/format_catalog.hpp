#pragma once

#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include <convertor/file_format.hpp>
#include <convertor/media_type.hpp>

using namespace std;

namespace convertor {

class FormatCatalog {
public:
    static FormatCatalog& instance();

    void register_format(const FileFormat& format);

    const FileFormat* find_by_id(const string& id) const;
    const FileFormat* find_by_extension(const string& ext) const;
    const FileFormat* find_by_mime(const string& mime) const;

    vector<const FileFormat*> all_formats() const;
    vector<const FileFormat*> formats_for_type(MediaType type) const;

    vector<string> outputs_for_id(const string& id) const;

    bool can_convert(const string& from_id, const string& to_id) const;
    ConversionType conversion_type_for(const string& from_id,
                                       const string& to_id) const;

    void load_defaults();

private:
    FormatCatalog() = default;
    vector<FileFormat> formats_;
    bool loaded_ = false;
};

} // namespace convertor
