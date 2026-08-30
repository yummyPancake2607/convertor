#include "text_layout.hpp"
#include "pdf_writer.hpp"

#include <convertor/logging.hpp>

using namespace std;

namespace convertor {

TextLayout::TextLayout(int page_width, int page_height, int margin)
    : page_width_(page_width), page_height_(page_height), margin_(margin) {}

void TextLayout::add_text(const string& text, int font_size) {
    TextBlock block;
    block.text = text;
    block.font_size = font_size;
    block.x = static_cast<float>(margin_);
    block.y = static_cast<float>(margin_ + blocks_.size() * (font_size + 4));
    block.width = static_cast<float>(page_width_ - 2 * margin_);
    block.height = static_cast<float>(font_size);
    blocks_.push_back(block);
}

vector<TextBlock> TextLayout::layout() const {
    return blocks_;
}

Error TextLayout::render_to_pdf(const string& output_path) {
    PdfWriter writer(page_width_, page_height_, margin_);

    int font_size = 11;
    vector<string> lines;
    lines.reserve(blocks_.size());
    for (const auto& block : blocks_) {
        lines.push_back(block.text);
        font_size = block.font_size;
    }

    writer.add_text_lines(lines, font_size);
    return writer.save(output_path);
}

} // namespace convertor
