#pragma once

#include <condition_variable>
#include <mutex>
#include <queue>
#include <vector>

#include <convertor/job.hpp>

namespace convertor {

class JobQueue {
public:
    void push(std::shared_ptr<Job> job);
    std::shared_ptr<Job> pop();
    bool empty() const;
    size_t size() const;

    void cancel_all();
    void shutdown();

private:
    mutable std::mutex mutex_;
    std::condition_variable cv_;
    std::queue<std::shared_ptr<Job>> queue_;
    bool stopped_ = false;
};

} // namespace convertor
