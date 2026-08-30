#include <convertor/conversion_result.hpp>

using namespace std;

namespace convertor {

ConversionResult::ConversionResult()
    : output_size_bytes(0), elapsed_seconds(0.0), success(false) {}

ConversionResult::ConversionResult(string path, int64_t size, double elapsed)
    : output_path(move(path)), output_size_bytes(size),
      elapsed_seconds(elapsed), success(true) {}

} // namespace convertor
