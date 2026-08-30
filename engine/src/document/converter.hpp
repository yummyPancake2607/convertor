#pragma once

#include <string>
#include <functional>

#include <convertor/error.hpp>
#include <convertor/conversion_request.hpp>
#include <convertor/conversion_result.hpp>
#include <convertor/media_info.hpp>

namespace convertor {

using ProgressCallback = std::function<void(float)>;

class IConverter {
public:
    virtual ~IConverter() = default;

    virtual std::string name() const = 0;

    virtual bool can_handle(const ConversionRequest& request,
                            const MediaInfo& input_info) const = 0;

    virtual Error convert(const ConversionRequest& request,
                          const MediaInfo& input_info,
                          ProgressCallback progress = nullptr) = 0;
};

} // namespace convertor
