#include "temp_file.hpp"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>

using namespace std;

namespace convertor::fs {

string default_temp_dir() {
    if (const char* env = getenv("TMPDIR")) {
        if (env[0] != '\0') return env;
    }
    return "/tmp";
}

TempFile::TempFile(const string& dir) {
    const string base = dir.empty() ? default_temp_dir() : dir;
    string tmpl = base + "/convertor_XXXXXX";
    char* buf = new char[tmpl.size() + 1];
    strcpy(buf, tmpl.c_str());
    int fd = mkstemp(buf);
    if (fd >= 0) {
        close(fd);
        path_ = buf;
    }
    delete[] buf;
}

TempFile::~TempFile() {
    if (owned_ && !path_.empty()) {
        remove_file();
    }
}

TempFile::TempFile(TempFile&& other) noexcept
    : path_(move(other.path_)), owned_(other.owned_) {
    other.owned_ = false;
}

TempFile& TempFile::operator=(TempFile&& other) noexcept {
    if (this != &other) {
        if (owned_ && !path_.empty()) remove_file();
        path_ = move(other.path_);
        owned_ = other.owned_;
        other.owned_ = false;
    }
    return *this;
}

const string& TempFile::path() const { return path_; }

void TempFile::release() { owned_ = false; }

void TempFile::remove_file() {
    if (!path_.empty()) unlink(path_.c_str());
}

} // namespace convertor::fs
