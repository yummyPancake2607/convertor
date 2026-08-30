#pragma once

#include <string>
#include <vector>

#include <convertor/media_type.hpp>

using namespace std;

namespace convertor {

class FileFormat {
public:
    FileFormat();
    FileFormat(string id, string name, string extension,
              MediaType media_type, vector<string> mime_types);

    const string& id() const;
    const string& name() const;
    const string& extension() const;
    MediaType media_type() const;
    const vector<string>& mime_types() const;

    bool supports_conversion_to(const string& target_format_id) const;
    void add_conversion_target(const string& target_format_id);

    bool operator==(const FileFormat& other) const;
    bool operator<(const FileFormat& other) const;

private:
    string id_;
    string name_;
    string extension_;
    MediaType media_type_;
    vector<string> mime_types_;
    vector<string> conversion_targets_;
};

} // namespace convertor
