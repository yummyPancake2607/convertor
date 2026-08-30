#pragma once

#include <atomic>
#include <functional>
#include <thread>
#include <vector>

#include "job_queue.hpp"

namespace convertor {

class WorkerPool {
public:
    explicit WorkerPool(size_t num_threads);
    ~WorkerPool();

    WorkerPool(const WorkerPool&) = delete;
    WorkerPool& operator=(const WorkerPool&) = delete;

    void start(JobQueue& queue, std::function<void(shared_ptr<Job>)> worker_fn);
    void stop();
    size_t thread_count() const;

private:
    size_t num_threads_;
    vector<thread> threads_;
    atomic<bool> running_{false};
};

} // namespace convertor
