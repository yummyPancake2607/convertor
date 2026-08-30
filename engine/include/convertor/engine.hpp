#pragma once

#include <memory>
#include <string>

#include <convertor/error.hpp>
#include <convertor/conversion_request.hpp>
#include <convertor/conversion_result.hpp>
#include <convertor/job.hpp>
#include <convertor/media_info.hpp>

namespace convertor {

class JobManager;

class Engine {
public:
    Engine();
    ~Engine();

    Engine(const Engine&) = delete;
    Engine& operator=(const Engine&) = delete;

    void initialize();
    void shutdown();

    MediaInfo probe(const std::string& path, Error& err);

    JobId convert(ConversionRequest request, JobCallback callback = nullptr);

    ConversionResult convert_sync(const ConversionRequest& request, Error& err);

    bool cancel_job(JobId id);
    std::shared_ptr<Job> get_job(JobId id) const;

    size_t pending_jobs() const;

private:
    std::unique_ptr<JobManager> job_manager_;
    bool initialized_ = false;
};

} // namespace convertor
