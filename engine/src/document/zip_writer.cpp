#include "zip_writer.hpp"

#include <convertor/logging.hpp>

#include <zip.h>

using namespace std;

namespace convertor {

namespace {
zip_t* as_zip(void* p) { return static_cast<zip_t*>(p); }
} // namespace

ZipWriter::ZipWriter(const string& path) : path_(path) {
    int err = 0;
    archive_ = zip_open(path.c_str(), ZIP_CREATE | ZIP_TRUNCATE, &err);
    if (!archive_) {
        Logger::instance().warn("ZipWriter: cannot create " + path +
                                " (libzip error " + to_string(err) + ")");
    }
}

ZipWriter::~ZipWriter() {
    if (!closed_ && archive_) {
        // Discard rather than half-write a package nobody asked to keep.
        zip_discard(as_zip(archive_));
        archive_ = nullptr;
    }
}

bool ZipWriter::is_open() const { return archive_ != nullptr; }

Error ZipWriter::add(const string& name, string content, bool store_uncompressed) {
    if (!archive_) return Error(ErrorCode::kZipError, "Archive not open");

    buffers_.push_back(make_unique<string>(move(content)));
    const string& held = *buffers_.back();

    zip_source_t* source =
        zip_source_buffer(as_zip(archive_), held.data(), held.size(), 0);
    if (!source) {
        return Error(ErrorCode::kZipError, "Cannot buffer entry: " + name);
    }

    const zip_int64_t index =
        zip_file_add(as_zip(archive_), name.c_str(), source, ZIP_FL_OVERWRITE);
    if (index < 0) {
        zip_source_free(source);
        return Error(ErrorCode::kZipError, "Cannot add entry: " + name);
    }

    if (store_uncompressed) {
        zip_set_file_compression(as_zip(archive_), static_cast<zip_uint64_t>(index),
                                 ZIP_CM_STORE, 0);
    }
    return Error::success();
}

Error ZipWriter::close() {
    if (closed_) return Error::success();
    if (!archive_) return Error(ErrorCode::kZipError, "Archive not open");

    closed_ = true;
    if (zip_close(as_zip(archive_)) < 0) {
        const string message = zip_strerror(as_zip(archive_));
        zip_discard(as_zip(archive_));
        archive_ = nullptr;
        return Error(ErrorCode::kZipError, "Cannot write " + path_ + ": " + message);
    }
    archive_ = nullptr;
    buffers_.clear();
    return Error::success();
}

} // namespace convertor
