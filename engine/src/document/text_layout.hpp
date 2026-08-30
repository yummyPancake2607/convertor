#pragma once

#include <string>
#include <vector>

#include <convertor/error.hpp>

namespace convertor {

struct TextBlock {
    std::string text;
    float x, y, width, height;
    int font_size;
};

class TextLayout {
public:
    TextLayout(int page_width, int page_height, int margin = 50);

    void add_text(const std::string& text, int font_size = 12);
    std::vector<TextBlock> layout() const;

    Error render_to_pdf(const std::string& output_path);

private:
    int page_width_;
    int page_height_;
    int margin_;
    std::vector<TextBlock> blocks_;
};

} // namespace convertor
