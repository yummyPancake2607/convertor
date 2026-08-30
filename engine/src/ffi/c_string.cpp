#include "c_string.hpp"

#include <cstring>

using namespace std;

namespace convertor::ffi {

CString::CString(const string& str) : size_(str.size()) {
    data_ = new char[size_ + 1];
    memcpy(data_, str.c_str(), size_ + 1);
}

CString::~CString() {
    delete[] data_;
}

const char* CString::c_str() const { return data_; }
uint32_t CString::size() const { return size_; }

} // namespace convertor::ffi
