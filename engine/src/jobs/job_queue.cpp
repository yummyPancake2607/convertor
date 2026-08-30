#include "job_queue.hpp"

using namespace std;

namespace convertor {

void JobQueue::push(shared_ptr<Job> job) {
    lock_guard<mutex> lock(mutex_);
    queue_.push(move(job));
    cv_.notify_one();
}

shared_ptr<Job> JobQueue::pop() {
    unique_lock<mutex> lock(mutex_);
    cv_.wait(lock, [this] { return !queue_.empty() || stopped_; });
    if (stopped_ && queue_.empty()) return nullptr;
    auto job = move(queue_.front());
    queue_.pop();
    return job;
}

bool JobQueue::empty() const {
    lock_guard<mutex> lock(mutex_);
    return queue_.empty();
}

size_t JobQueue::size() const {
    lock_guard<mutex> lock(mutex_);
    return queue_.size();
}

void JobQueue::cancel_all() {
    lock_guard<mutex> lock(mutex_);
    while (!queue_.empty()) {
        auto job = queue_.front();
        queue_.pop();
        job->set_status(JobStatus::kCancelled);
        job->notify();
    }
}

void JobQueue::shutdown() {
    lock_guard<mutex> lock(mutex_);
    stopped_ = true;
    cv_.notify_all();
}

} // namespace convertor
