#include "progress_reporter.hpp"

using namespace std;

namespace convertor {

ProgressReporter::ProgressReporter() = default;
ProgressReporter::ProgressReporter(ProgressCallback callback)
    : callback_(move(callback)) {}

void ProgressReporter::set_callback(ProgressCallback callback) {
    callback_ = move(callback);
}

void ProgressReporter::report(float progress) {
    current_ = progress;
    if (callback_) callback_(progress);
}

float ProgressReporter::current_progress() const { return current_; }

} // namespace convertor
