#include "handle_table.hpp"

using namespace std;

namespace convertor::ffi {

HandleTable& HandleTable::instance() {
    static HandleTable s_instance;
    return s_instance;
}

uint64_t HandleTable::insert(void* ptr) {
    lock_guard<mutex> lock(mutex_);
    uint64_t handle = next_++;
    handles_[handle] = ptr;
    return handle;
}

void* HandleTable::get(uint64_t handle) const {
    lock_guard<mutex> lock(mutex_);
    auto it = handles_.find(handle);
    return it != handles_.end() ? it->second : nullptr;
}

void HandleTable::erase(uint64_t handle) {
    lock_guard<mutex> lock(mutex_);
    handles_.erase(handle);
}

} // namespace convertor::ffi
