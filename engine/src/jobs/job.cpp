#include <convertor/job.hpp>

using namespace std;

namespace convertor {

Job::Job(JobId id, ConversionRequest request)
    : id_(id), request_(move(request)) {}

JobId Job::id() const { return id_; }
JobStatus Job::status() const { return status_; }
const ConversionRequest& Job::request() const { return request_; }
const ConversionResult& Job::result() const { return result_; }
const Error& Job::error() const { return error_; }
float Job::progress() const { return progress_; }
const string& Job::stage() const { return stage_; }

void Job::set_status(JobStatus status) { status_ = status; }
void Job::set_result(ConversionResult result) { result_ = move(result); }
void Job::set_error(Error error) { error_ = move(error); }
void Job::set_callback(JobCallback callback) { callback_ = move(callback); }
void Job::set_progress(float progress) { progress_ = progress; }
void Job::set_stage(string stage) { stage_ = move(stage); }

void Job::notify() {
    if (callback_) callback_(id_, status_);
}

} // namespace convertor
