#include "job_manager.hpp"

#include <convertor/logging.hpp>

#include "../document/converter_registry.hpp"
#include "../document/media_prober.hpp"

using namespace std;

namespace convertor {

JobManager::JobManager(size_t num_workers)
    : pool_(make_unique<WorkerPool>(num_workers)) {}

JobManager::~JobManager() {
    stop();
}

void JobManager::start() {
    pool_->start(queue_, [this](shared_ptr<Job> job) {
        process_job(job);
    });
    Logger::instance().info("JobManager started with " + to_string(pool_->thread_count()) + " workers");
}

void JobManager::stop() {
    queue_.cancel_all();
    queue_.shutdown();
    pool_->stop();
    Logger::instance().info("JobManager stopped");
}

JobId JobManager::submit(ConversionRequest request, JobCallback callback) {
    JobId id = next_id_.fetch_add(1);
    auto job = make_shared<Job>(id, move(request));
    if (callback) job->set_callback(move(callback));

    {
        lock_guard<mutex> lock(jobs_mutex_);
        jobs_[id] = job;
    }

    queue_.push(job);
    return id;
}

shared_ptr<Job> JobManager::get_job(JobId id) const {
    lock_guard<mutex> lock(jobs_mutex_);
    auto it = jobs_.find(id);
    return it != jobs_.end() ? it->second : nullptr;
}

bool JobManager::cancel_job(JobId id) {
    auto job = get_job(id);
    if (!job) return false;
    if (job->status() == JobStatus::kRunning) {
        job->set_status(JobStatus::kCancelled);
        return true;
    }
    return false;
}

size_t JobManager::active_workers() const { return pool_->thread_count(); }
size_t JobManager::pending_jobs() const { return queue_.size(); }

void JobManager::process_job(shared_ptr<Job> job) {
    job->set_status(JobStatus::kRunning);
    job->notify();

    Logger::instance().info("Processing job " + to_string(job->id()));

    // Probe input
    MediaInfo input_info;
    Error probe_err;
    input_info = MediaProber::probe(job->request().input_path(), probe_err);
    if (!probe_err.ok()) {
        job->set_error(move(probe_err));
        job->set_status(JobStatus::kFailed);
        job->notify();
        return;
    }

    // Find and run a converter. More than one can accept a request - a stream
    // copy is tried before a full transcode - so fall through to the next
    // candidate when one fails rather than failing the whole job.
    auto& registry = ConverterRegistry::instance();
    auto converters = registry.find_converters(job->request(), input_info);
    if (converters.empty()) {
        job->set_error(Error(ErrorCode::kUnsupportedFormat, "No converter found"));
        job->set_status(JobStatus::kFailed);
        job->notify();
        return;
    }

    auto start_time = chrono::steady_clock::now();
    Error err;
    for (size_t i = 0; i < converters.size(); ++i) {
        job->set_progress(0.0f);
        err = converters[i]->convert(job->request(), input_info, [job](float pct) {
            job->set_progress(pct);
            job->notify();
        });
        if (err.ok()) break;

        if (i + 1 < converters.size()) {
            Logger::instance().info(
                converters[i]->name() + " could not handle this file (" +
                err.message() + "), trying " + converters[i + 1]->name());
        }
    }
    auto elapsed = chrono::steady_clock::now() - start_time;
    double seconds = chrono::duration<double>(elapsed).count();

    if (err.ok()) {
        ConversionResult result(job->request().output_path(), 0, seconds);
        job->set_result(move(result));
        job->set_status(JobStatus::kCompleted);
    } else {
        job->set_error(move(err));
        job->set_status(JobStatus::kFailed);
    }
    job->notify();
}

} // namespace convertor
