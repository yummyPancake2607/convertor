#pragma once

#include <memory>
#include <string>
#include <vector>

#include <convertor/error.hpp>

namespace convertor {

/// Creates ZIP archives, which is what DOCX, XLSX and the OpenDocument
/// formats actually are.
///
/// Entry content is copied and held until the archive is closed, because
/// libzip reads from the caller's buffers lazily at that point.
class ZipWriter {
public:
    explicit ZipWriter(const std::string& path);
    ~ZipWriter();

    ZipWriter(const ZipWriter&) = delete;
    ZipWriter& operator=(const ZipWriter&) = delete;

    bool is_open() const;

    /// Adds one entry. `store_uncompressed` is needed for the OpenDocument
    /// `mimetype` entry, which the spec requires to be stored verbatim.
    Error add(const std::string& name, std::string content,
              bool store_uncompressed = false);

    /// Writes the archive out. Called by the destructor if not called first.
    Error close();

private:
    void* archive_ = nullptr;
    std::string path_;
    std::vector<std::unique_ptr<std::string>> buffers_;
    bool closed_ = false;
};

} // namespace convertor
