#pragma once

#include "converter.hpp"

#include <convertor/format_catalog.hpp>

#include <memory>
#include <vector>

namespace convertor {

class ConverterRegistry {
public:
    static ConverterRegistry& instance();

    void register_converter(std::unique_ptr<IConverter> converter);

    IConverter* find_converter(const ConversionRequest& request,
                              const MediaInfo& input_info) const;

    /// Every converter that accepts the request, in registration order.
    ///
    /// Callers try them in turn: the fast paths (stream copy) are registered
    /// first but cannot always tell in advance whether a container will accept
    /// a codec, so a failure falls through to the general converter.
    std::vector<IConverter*> find_converters(const ConversionRequest& request,
                                             const MediaInfo& input_info) const;

    std::vector<IConverter*> all_converters() const;

private:
    ConverterRegistry() = default;
    std::vector<std::unique_ptr<IConverter>> converters_;
};

} // namespace convertor
