#pragma once

#include <cstdint>
#include <string>

namespace convertor::fs {

bool exists(const std::string& path);
int64_t file_size(const std::string& path);
bool is_writable(const std::string& path);
bool is_readable(const std::string& path);
std::string unique_output_path(const std::string& path);

} // namespace convertor::fs
