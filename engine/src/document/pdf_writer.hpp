#pragma once

#include <string>
#include <vector>

#include <convertor/error.hpp>

namespace convertor {

/// Minimal PDF 1.4 generator.
///
/// Enough to lay text out on paged A4 and to wrap a JPEG as a full-page image,
/// which covers every "... -> pdf" conversion the engine offers. Text is drawn
/// with the standard Helvetica Type1 font, so no font file has to be embedded.
class PdfWriter {
public:
    PdfWriter(double page_width = 595.0, double page_height = 842.0,
              double margin = 50.0);

    /// Flows lines onto as many pages as needed, wrapping over-long ones.
    void add_text_lines(const std::vector<std::string>& lines, int font_size = 11);

    /// Appends one page holding a JPEG scaled to fit, preserving aspect ratio.
    void add_jpeg_page(const std::string& jpeg_data, int width, int height);

    /// True when nothing has been added yet.
    bool empty() const;

    Error save(const std::string& output_path);

private:
    struct Page {
        std::string content;          // content stream
        std::string image_data;       // non-empty for image pages
        int image_width = 0;
        int image_height = 0;
    };

    double width_;
    double height_;
    double margin_;
    std::vector<Page> pages_;
};

} // namespace convertor
