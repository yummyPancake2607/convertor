#pragma once

#include "converter.hpp"
#include "../ffmpeg/format_context.hpp"
#include "../ffmpeg/codec_context.hpp"
#include "../ffmpeg/frame.hpp"
#include "../ffmpeg/packet.hpp"
#include "../ffmpeg/rescaler.hpp"

#include <convertor/format_catalog.hpp>

namespace convertor {

class VideoConverter : public IConverter {
public:
    string name() const override { return "VideoConverter"; }

    bool can_handle(const ConversionRequest& request,
                    const MediaInfo& input_info) const override;

    Error convert(const ConversionRequest& request,
                  const MediaInfo& input_info,
                  ProgressCallback progress = nullptr) override;
};

} // namespace convertor
