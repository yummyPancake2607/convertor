#pragma once

#include <string>

namespace convertor::fs {

/// The platform's scratch directory: $TMPDIR when set (Android gives every app
/// its own), otherwise /tmp. Android has no /tmp at all, so the old hard-coded
/// default silently produced unusable paths there.
std::string default_temp_dir();

class TempFile {
public:
    explicit TempFile(const std::string& dir = std::string());
    ~TempFile();

    TempFile(const TempFile&) = delete;
    TempFile& operator=(const TempFile&) = delete;
    TempFile(TempFile&& other) noexcept;
    TempFile& operator=(TempFile&& other) noexcept;

    const std::string& path() const;
    void release();
    void remove_file();

private:
    std::string path_;
    bool owned_ = true;
};

} // namespace convertor::fs
