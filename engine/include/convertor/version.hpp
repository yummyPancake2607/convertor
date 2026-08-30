#pragma once

#include <cstdint>

namespace convertor {

struct Version {
    int major;
    int minor;
    int patch;

    static Version current();
};

} // namespace convertor
