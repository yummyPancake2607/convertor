#include "zip_reader.hpp"

#include <convertor/logging.hpp>
#include "../fs/path_utils.hpp"

#include <zip.h>

#include <fstream>
#include <vector>

using namespace std;

namespace convertor {

namespace {
zip_t* as_zip(void* p) { return static_cast<zip_t*>(p); }
} // namespace

ZipReader::ZipReader(const string& path) : path_(path) {
    int err = 0;
    archive_ = zip_open(path.c_str(), ZIP_RDONLY, &err);
    if (!archive_) {
        Logger::instance().warn("ZipReader: cannot open " + path +
                                " (libzip error " + to_string(err) + ")");
        return;
    }
    Logger::instance().info("ZipReader: opened " + path);
}

ZipReader::~ZipReader() {
    if (archive_) {
        zip_close(as_zip(archive_));
        archive_ = nullptr;
    }
}

bool ZipReader::is_open() const { return archive_ != nullptr; }

vector<string> ZipReader::entry_names() const {
    vector<string> names;
    if (!archive_) return names;

    zip_int64_t count = zip_get_num_entries(as_zip(archive_), 0);
    for (zip_int64_t i = 0; i < count; ++i) {
        const char* name = zip_get_name(as_zip(archive_), i, 0);
        if (name) names.emplace_back(name);
    }
    return names;
}

string ZipReader::read_entry(const string& name) {
    if (!archive_) return {};

    zip_stat_t st;
    zip_stat_init(&st);
    if (zip_stat(as_zip(archive_), name.c_str(), 0, &st) != 0) return {};

    zip_file_t* file = zip_fopen(as_zip(archive_), name.c_str(), 0);
    if (!file) return {};

    string content;
    content.resize(static_cast<size_t>(st.size));
    zip_int64_t total = 0;
    while (total < static_cast<zip_int64_t>(st.size)) {
        zip_int64_t n = zip_fread(file, content.data() + total,
                                  st.size - static_cast<zip_uint64_t>(total));
        if (n <= 0) break;
        total += n;
    }
    zip_fclose(file);

    content.resize(static_cast<size_t>(total));
    return content;
}

Error ZipReader::extract_entry(const string& name, const string& output_path) {
    if (!archive_) return Error(ErrorCode::kZipError, "Archive not open");

    string content = read_entry(name);
    if (content.empty()) {
        return Error(ErrorCode::kZipError, "No such entry: " + name);
    }

    ofstream out(output_path, ios::binary);
    if (!out.is_open()) {
        return Error(ErrorCode::kPermissionDenied, "Cannot write: " + output_path);
    }
    out.write(content.data(), static_cast<streamsize>(content.size()));
    return out.good() ? Error::success()
                      : Error(ErrorCode::kZipError, "Failed writing " + output_path);
}

Error ZipReader::extract_all(const string& output_dir) {
    if (!archive_) return Error(ErrorCode::kZipError, "Archive not open");

    for (const auto& name : entry_names()) {
        if (!name.empty() && name.back() == '/') continue;  // directory entry
        auto err = extract_entry(name, fs::join(output_dir, fs::filename(name)));
        if (!err.ok()) return err;
    }
    return Error::success();
}

} // namespace convertor
