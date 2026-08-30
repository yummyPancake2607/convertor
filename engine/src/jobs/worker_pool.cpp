#include "worker_pool.hpp"

using namespace std;

namespace convertor {

WorkerPool::WorkerPool(size_t num_threads) : num_threads_(num_threads) {}

WorkerPool::~WorkerPool() {
    stop();
}

void WorkerPool::start(JobQueue& queue, function<void(shared_ptr<Job>)> worker_fn) {
    running_ = true;
    for (size_t i = 0; i < num_threads_; ++i) {
        threads_.emplace_back([&queue, worker_fn, this] {
            while (running_) {
                auto job = queue.pop();
                if (!job) break;
                worker_fn(job);
            }
        });
    }
}

void WorkerPool::stop() {
    running_ = false;
    for (auto& t : threads_) {
        if (t.joinable()) t.join();
    }
    threads_.clear();
}

size_t WorkerPool::thread_count() const { return num_threads_; }

} // namespace convertor
