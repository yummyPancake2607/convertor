#pragma once

#include <atomic>

namespace convertor {

class CancellationToken {
public:
    CancellationToken();

    void cancel();
    bool is_cancelled() const;
    void reset();

private:
    std::atomic<bool> cancelled_{false};
};

} // namespace convertor
