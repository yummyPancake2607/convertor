#pragma once

#include <string>
#include <vector>

#include <convertor/error.hpp>

namespace convertor {

struct PdfPageInfo {
    int page_number;
    int width;
    int height;
};

/// One rendered page as packed RGB24 pixels.
struct RenderedPage {
    int width = 0;
    int height = 0;
    int stride = 0;              ///< bytes per row, may exceed width * 3
    std::vector<unsigned char> pixels;
};

class PDFDocument {
public:
    explicit PDFDocument(const std::string& path);
    ~PDFDocument();

    PDFDocument(const PDFDocument&) = delete;
    PDFDocument& operator=(const PDFDocument&) = delete;

    bool is_open() const;
    int page_count() const;
    /// Renders one page into memory. Writing the image out is left to the
    /// caller so the encoder is the same one used everywhere else, rather than
    /// depending on poppler being built with libpng/libjpeg.
    convertor::Error render_page(int page_number, RenderedPage& out, int dpi = 150);
    /// Extracts the whole document's text into memory.
    convertor::Error extract_text(std::string& out_text);

    /// Convenience wrapper that writes the extracted text to a file.
    convertor::Error extract_text_to_file(const std::string& output_path);

private:
    void* doc_ = nullptr;
    std::string path_;
};

} // namespace convertor
