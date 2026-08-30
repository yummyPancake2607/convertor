#pragma once

#include <cstdint>
#include <string>

using namespace std;

namespace convertor {

struct ConversionResult {
    string output_path;
    int64_t output_size_bytes;
    double elapsed_seconds;
    bool success;

    ConversionResult();
    ConversionResult(string path, int64_t size, double elapsed);
};

} // namespace convertor
