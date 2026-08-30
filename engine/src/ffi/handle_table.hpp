#pragma once

#include <mutex>
#include <unordered_map>
#include <cstdint>

namespace convertor::ffi {

class HandleTable {
public:
    static HandleTable& instance();

    uint64_t insert(void* ptr);
    void* get(uint64_t handle) const;
    void erase(uint64_t handle);

private:
    HandleTable() = default;
    mutable std::mutex mutex_;
    std::unordered_map<uint64_t, void*> handles_;
    uint64_t next_ = 1;
};

} // namespace convertor::ffi
