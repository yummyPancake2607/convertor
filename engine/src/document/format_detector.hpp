#pragma once

#include <string>

#include <convertor/error.hpp>
#include <convertor/media_info.hpp>

namespace convertor {

class FormatDetector {
public:
    static FormatDetector& instance();

    std::string detect(const std::string& path) const;
    MediaType detect_type(const std::string& path) const;

private:
    FormatDetector() = default;
};

} // namespace convertor
