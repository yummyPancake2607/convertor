#pragma once

#include "converter.hpp"
#include "../ffmpeg/frame.hpp"
#include "../ffmpeg/rescaler.hpp"

#include <convertor/format_catalog.hpp>

#include <optional>

namespace convertor {

namespace image_ops {

/// Decodes the first frame of any image FFmpeg can read and re-encodes it as
/// baseline JPEG, reporting the bytes and pixel dimensions. Used to embed
/// arbitrary images into generated PDFs.
/// `scratch_dir` is where the intermediate file is written; pass a directory
/// known to be writable (the conversion's own output directory, say) rather
/// than relying on a system temp location.
Error encode_to_jpeg(const string& input_path, string& jpeg_out,
                     int& width, int& height, int quality = 90,
                     const string& scratch_dir = string());

/// Encodes a packed RGB24 buffer into `output_path`, choosing the codec from
/// the file extension. `stride` is the byte length of one source row, which
/// may be larger than width * 3.
Error write_rgb24_as_image(const unsigned char* rgb, int width, int height,
                           int stride, const string& output_path,
                           std::optional<int> quality = std::nullopt);

/// Encodes a decoded frame into `output_path`, choosing the codec from the
/// file extension and muxing it so container-based formats (GIF, WebP, TIFF)
/// come out as valid files rather than a bare codec packet.
Error write_frame_as_image(AVFrame* frame, const string& output_path,
                           std::optional<int> quality = std::nullopt);

} // namespace image_ops

class ImageConverter : public IConverter {
public:
    string name() const override { return "ImageConverter"; }

    bool can_handle(const ConversionRequest& request,
                    const MediaInfo& input_info) const override;

    Error convert(const ConversionRequest& request,
                  const MediaInfo& input_info,
                  ProgressCallback progress = nullptr) override;
};

} // namespace convertor
