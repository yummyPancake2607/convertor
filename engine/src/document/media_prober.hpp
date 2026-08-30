#pragma once

#include <convertor/error.hpp>
#include <convertor/media_info.hpp>

namespace convertor {

class MediaProber {
public:
    static MediaInfo probe(const std::string& path, Error& err);
};

} // namespace convertor
