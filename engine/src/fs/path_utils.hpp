#pragma once

#include <string>

namespace convertor::fs {

std::string join(const std::string& dir, const std::string& file);
std::string parent_dir(const std::string& path);
std::string filename(const std::string& path);
std::string stem(const std::string& path);
std::string extension(const std::string& path);
std::string change_extension(const std::string& path, const std::string& ext);

} // namespace convertor::fs
