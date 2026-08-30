#pragma once

#include <memory>
#include <mutex>
#include <unordered_map>

#include <convertor/job.hpp>
#include <convertor/conversion_request.hpp>

#include "job_queue.hpp"
#include "worker_pool.hpp"

namespace convertor {

class JobManager {
public:
    explicit JobManager(size_t num_workers = 4);
    ~JobManager();

    JobManager(const JobManager&) = delete;
    JobManager& operator=(const JobManager&) = delete;

    void start();
    void stop();

    JobId submit(ConversionRequest request, JobCallback callback = nullptr);

    shared_ptr<Job> get_job(JobId id) const;
    bool cancel_job(JobId id);

    size_t active_workers() const;
    size_t pending_jobs() const;

private:
    void process_job(shared_ptr<Job> job);

    JobQueue queue_;
    unique_ptr<WorkerPool> pool_;
    mutable mutex jobs_mutex_;
    unordered_map<JobId, shared_ptr<Job>> jobs_;
    atomic<uint64_t> next_id_{1};
};

} // namespace convertor
