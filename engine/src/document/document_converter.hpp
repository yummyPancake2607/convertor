#pragma once

#include "converter.hpp"

#include <convertor/error.hpp>
#include <memory>

namespace convertor {

/// Converts between Word and PDF, and wraps an image into a PDF page.
///
/// Sources are read into one shared representation and written back out from
/// it, so widening the offering is a matter of listing more formats rather
/// than adding a branch per pair.
class DocumentConverter : public IConverter {
public:
    string name() const override { return "DocumentConverter"; }

    bool can_handle(const ConversionRequest& request,
                    const MediaInfo& input_info) const override;

    Error convert(const ConversionRequest& request,
                  const MediaInfo& input_info,
                  ProgressCallback progress = nullptr) override;

private:
    Error image_to_pdf(const ConversionRequest& request, const MediaInfo& input_info, ProgressCallback progress);
};

} // namespace convertor
