#pragma once

#include "converter.hpp"
#include "../ffmpeg/format_context.hpp"

#include <convertor/format_catalog.hpp>

namespace convertor {

class Remuxer : public IConverter {
public:
    string name() const override { return "Remuxer"; }

    bool can_handle(const ConversionRequest& request,
                    const MediaInfo& input_info) const override;

    Error convert(const ConversionRequest& request,
                  const MediaInfo& input_info,
                  ProgressCallback progress = nullptr) override;
};

} // namespace convertor
