#pragma once

#include <string>
#include <vector>

#include <convertor/error.hpp>

namespace convertor {

class ZipReader {
public:
    explicit ZipReader(const std::string& path);
    ~ZipReader();

    ZipReader(const ZipReader&) = delete;
    ZipReader& operator=(const ZipReader&) = delete;

    bool is_open() const;
    std::vector<std::string> entry_names() const;
    Error extract_entry(const std::string& name, const std::string& output_path);
    Error extract_all(const std::string& output_dir);

    std::string read_entry(const std::string& name);

private:
    void* archive_ = nullptr;
    std::string path_;
};

} // namespace convertor
