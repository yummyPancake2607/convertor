#pragma once

#include <cstdint>
#include <string>

namespace convertor::ffi {

class CString {
public:
    explicit CString(const std::string& str);
    ~CString();

    CString(const CString&) = delete;
    CString& operator=(const CString&) = delete;

    const char* c_str() const;
    uint32_t size() const;

private:
    char* data_;
    uint32_t size_;
};

} // namespace convertor::ffi
