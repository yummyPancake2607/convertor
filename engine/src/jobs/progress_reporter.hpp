#pragma once

#include <functional>

namespace convertor {

using ProgressCallback = std::function<void(float)>;

class ProgressReporter {
public:
    ProgressReporter();
    explicit ProgressReporter(ProgressCallback callback);

    void set_callback(ProgressCallback callback);
    void report(float progress);
    float current_progress() const;

private:
    ProgressCallback callback_;
    float current_ = 0.0f;
};

} // namespace convertor
