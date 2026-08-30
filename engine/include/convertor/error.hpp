#pragma once

#include <cstdint>
#include <string>
#include <variant>

using namespace std;

namespace convertor {

enum class ErrorCode : uint32_t {
    kOk = 0,
    kUnknown = 1,

    kFileNotFound = 100,
    kFileExists = 101,
    kPermissionDenied = 102,
    kDiskFull = 103,

    kInvalidArgument = 200,
    kInvalidPath = 201,
    kUnsupportedFormat = 202,

    kFFmpegError = 300,
    kFFmpegInit = 301,
    kFFmpegOpen = 302,
    kFFmpegDecode = 303,
    kFFmpegEncode = 304,
    kFFmpegMux = 305,

    kPDFError = 400,
    kPDFRender = 401,
    kPDFTextExtract = 402,

    kZipError = 500,
    kXmlParseError = 501,

    kJobCancelled = 600,
    kJobFailed = 601,
    kJobTimeout = 602,

    kOutOfMemory = 700,
    kInternal = 800,
};

class Error {
public:
    Error();
    explicit Error(ErrorCode code);
    Error(ErrorCode code, string message);
    Error(ErrorCode code, string message, string details);

    bool ok() const;
    ErrorCode code() const;
    const string& message() const;
    const string& details() const;

    string to_string() const;

    static Error success();

private:
    ErrorCode code_;
    string message_;
    string details_;
};

template <typename T>
class Result {
public:
    Result(T value);
    Result(Error error);
    Result(const Result&) = default;
    Result& operator=(const Result&) = default;
    Result(Result&&) noexcept = default;
    Result& operator=(Result&&) noexcept = default;

    bool ok() const;
    const T& value() const;
    T& value();
    const Error& error() const;

    T value_or(T default_value) const;

private:
    variant<T, Error> data_;
};

template <>
class Result<void> {
public:
    Result();
    Result(Error error);
    Result(const Result&) = default;
    Result& operator=(const Result&) = default;

    bool ok() const;
    const Error& error() const;

private:
    variant<monostate, Error> data_;
};

} // namespace convertor
