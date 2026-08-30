#pragma once

#include <cstdint>
#include <string>
#include <functional>

#include <convertor/conversion_request.hpp>
#include <convertor/conversion_result.hpp>
#include <convertor/error.hpp>

namespace convertor {

enum class JobStatus : uint32_t {
    kPending = 0,
    kRunning,
    kCompleted,
    kFailed,
    kCancelled,
};

using JobId = uint64_t;
using JobCallback = std::function<void(JobId, JobStatus)>;

class Job {
public:
    Job(JobId id, ConversionRequest request);

    JobId id() const;
    JobStatus status() const;
    const ConversionRequest& request() const;
    const ConversionResult& result() const;
    const Error& error() const;

    float progress() const;
    const string& stage() const;

    void set_status(JobStatus status);
    void set_result(ConversionResult result);
    void set_error(Error error);
    void set_callback(JobCallback callback);
    void set_progress(float progress);
    void set_stage(string stage);

    void notify();

private:
    JobId id_;
    JobStatus status_ = JobStatus::kPending;
    ConversionRequest request_;
    ConversionResult result_;
    Error error_;
    JobCallback callback_;
    float progress_ = 0.0f;
    string stage_;
};

} // namespace convertor
