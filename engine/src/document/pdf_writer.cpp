#include "pdf_writer.hpp"

#include <convertor/logging.hpp>

#include <cstdio>
#include <fstream>
#include <sstream>

using namespace std;

namespace convertor {

namespace {

// Helvetica advance widths are close enough to a flat 0.5em for wrapping
// purposes; digits and caps run a little wider, so bias upwards slightly to
// avoid text spilling past the right margin.
constexpr double kAvgCharWidth = 0.52;

// Decodes UTF-8 to a code point, advancing i past the sequence.
uint32_t next_code_point(const string& s, size_t& i) {
    unsigned char c = static_cast<unsigned char>(s[i]);
    if (c < 0x80) { i += 1; return c; }
    if ((c & 0xE0) == 0xC0 && i + 1 < s.size()) {
        uint32_t cp = ((c & 0x1Fu) << 6) |
                      (static_cast<unsigned char>(s[i + 1]) & 0x3Fu);
        i += 2;
        return cp;
    }
    if ((c & 0xF0) == 0xE0 && i + 2 < s.size()) {
        uint32_t cp = ((c & 0x0Fu) << 12) |
                      ((static_cast<unsigned char>(s[i + 1]) & 0x3Fu) << 6) |
                      (static_cast<unsigned char>(s[i + 2]) & 0x3Fu);
        i += 3;
        return cp;
    }
    if ((c & 0xF8) == 0xF0 && i + 3 < s.size()) {
        uint32_t cp = ((c & 0x07u) << 18) |
                      ((static_cast<unsigned char>(s[i + 1]) & 0x3Fu) << 12) |
                      ((static_cast<unsigned char>(s[i + 2]) & 0x3Fu) << 6) |
                      (static_cast<unsigned char>(s[i + 3]) & 0x3Fu);
        i += 4;
        return cp;
    }
    i += 1;
    return '?';
}

// Maps a code point onto WinAnsiEncoding, which is what the page font declares.
// Anything outside it becomes '?' rather than corrupting the stream.
int to_win_ansi(uint32_t cp) {
    if (cp >= 0x20 && cp <= 0x7E) return static_cast<int>(cp);
    if (cp >= 0xA0 && cp <= 0xFF) return static_cast<int>(cp);
    switch (cp) {
        case 0x2018: return 0x91;  // left single quote
        case 0x2019: return 0x92;  // right single quote
        case 0x201C: return 0x93;  // left double quote
        case 0x201D: return 0x94;  // right double quote
        case 0x2013: return 0x96;  // en dash
        case 0x2014: return 0x97;  // em dash
        case 0x2022: return 0x95;  // bullet
        case 0x2026: return 0x85;  // ellipsis
        case 0x20AC: return 0x80;  // euro
        case 0x2122: return 0x99;  // trademark
        case 0x00A0: return 0x20;  // nbsp -> space
        case 0x0009: return 0x20;  // tab -> space
        default:     return -1;
    }
}

// Escapes a UTF-8 string into a PDF literal string body.
string pdf_escape(const string& utf8) {
    string out;
    out.reserve(utf8.size() + 8);
    size_t i = 0;
    while (i < utf8.size()) {
        int b = to_win_ansi(next_code_point(utf8, i));
        if (b < 0) b = '?';
        char ch = static_cast<char>(b);
        if (ch == '(' || ch == ')' || ch == '\\') out += '\\';
        if (b < 0x20) { out += ' '; continue; }
        out += ch;
    }
    return out;
}

// Length of the string once mapped to WinAnsi, in characters.
size_t display_length(const string& utf8) {
    size_t n = 0, i = 0;
    while (i < utf8.size()) { next_code_point(utf8, i); ++n; }
    return n;
}

// Splits a UTF-8 string at a character (not byte) offset.
void split_at(const string& utf8, size_t chars, string& head, string& tail) {
    size_t i = 0, n = 0;
    while (i < utf8.size() && n < chars) { next_code_point(utf8, i); ++n; }
    head = utf8.substr(0, i);
    tail = utf8.substr(i);
}

// Wraps one logical line to at most max_chars per output line, breaking on
// whitespace when there is a sensible break point.
vector<string> wrap_line(const string& line, size_t max_chars) {
    vector<string> out;
    if (max_chars == 0) { out.push_back(line); return out; }

    string rest = line;
    while (display_length(rest) > max_chars) {
        string head, tail;
        split_at(rest, max_chars, head, tail);

        size_t brk = head.find_last_of(" \t");
        if (brk != string::npos && brk > 0) {
            tail = head.substr(brk + 1) + tail;
            head = head.substr(0, brk);
        }
        out.push_back(head);
        rest = tail;
        if (head.empty()) break;  // no progress possible; avoid spinning
    }
    out.push_back(rest);
    return out;
}

} // namespace

PdfWriter::PdfWriter(double page_width, double page_height, double margin)
    : width_(page_width), height_(page_height), margin_(margin) {}

bool PdfWriter::empty() const { return pages_.empty(); }

void PdfWriter::add_text_lines(const vector<string>& lines, int font_size) {
    const double leading = font_size * 1.35;
    const double usable_width = width_ - 2 * margin_;
    const size_t max_chars =
        static_cast<size_t>(usable_width / (font_size * kAvgCharWidth));
    const double top = height_ - margin_;

    ostringstream content;
    double y = top;
    bool page_open = false;

    auto flush_page = [&]() {
        if (!page_open) return;
        Page p;
        p.content = content.str();
        pages_.push_back(move(p));
        content.str("");
        content.clear();
        page_open = false;
    };

    for (const auto& raw : lines) {
        for (const auto& piece : wrap_line(raw, max_chars)) {
            if (y < margin_) {
                flush_page();
                y = top;
            }
            if (!page_open) {
                page_open = true;
                y = top;
            }
            content << "BT /F1 " << font_size << " Tf "
                    << margin_ << " " << y << " Td ("
                    << pdf_escape(piece) << ") Tj ET\n";
            y -= leading;
        }
    }

    // An empty document still deserves a (blank) page so the output is valid.
    if (!page_open && pages_.empty()) page_open = true;
    flush_page();
}

void PdfWriter::add_jpeg_page(const string& jpeg_data, int width, int height) {
    if (jpeg_data.empty() || width <= 0 || height <= 0) return;

    const double usable_w = width_ - 2 * margin_;
    const double usable_h = height_ - 2 * margin_;
    double scale = min(usable_w / width, usable_h / height);
    if (scale > 1.0) scale = 1.0;  // never upscale

    const double draw_w = width * scale;
    const double draw_h = height * scale;
    const double x = (width_ - draw_w) / 2.0;
    const double y = (height_ - draw_h) / 2.0;

    ostringstream content;
    content << "q " << draw_w << " 0 0 " << draw_h << " " << x << " " << y
            << " cm /Im0 Do Q\n";

    Page p;
    p.content = content.str();
    p.image_data = jpeg_data;
    p.image_width = width;
    p.image_height = height;
    pages_.push_back(move(p));
}

Error PdfWriter::save(const string& output_path) {
    if (pages_.empty()) add_text_lines({}, 11);

    // Object layout: 1 = catalog, 2 = page tree, 3 = font, then per page a
    // page object, its content stream, and optionally its image XObject.
    vector<string> objects;
    auto add_object = [&](string body) -> int {
        objects.push_back(move(body));
        return static_cast<int>(objects.size());  // 1-based object number
    };

    add_object("");  // 1: catalog, filled in below
    add_object("");  // 2: page tree
    add_object("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
               "/Encoding /WinAnsiEncoding >>");  // 3: font

    vector<int> page_object_numbers;
    page_object_numbers.reserve(pages_.size());

    for (const auto& page : pages_) {
        int image_obj = 0;
        if (!page.image_data.empty()) {
            ostringstream img;
            img << "<< /Type /XObject /Subtype /Image /Width " << page.image_width
                << " /Height " << page.image_height
                << " /ColorSpace /DeviceRGB /BitsPerComponent 8 "
                   "/Filter /DCTDecode /Length " << page.image_data.size()
                << " >>\nstream\n" << page.image_data << "\nendstream";
            image_obj = add_object(img.str());
        }

        ostringstream stream;
        stream << "<< /Length " << page.content.size() << " >>\nstream\n"
               << page.content << "endstream";
        int content_obj = add_object(stream.str());

        ostringstream page_obj;
        page_obj << "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 "
                 << width_ << " " << height_ << "] /Resources << /Font << /F1 3 0 R >>";
        if (image_obj) page_obj << " /XObject << /Im0 " << image_obj << " 0 R >>";
        page_obj << " >> /Contents " << content_obj << " 0 R >>";
        page_object_numbers.push_back(add_object(page_obj.str()));
    }

    objects[0] = "<< /Type /Catalog /Pages 2 0 R >>";

    ostringstream tree;
    tree << "<< /Type /Pages /Count " << page_object_numbers.size() << " /Kids [";
    for (size_t i = 0; i < page_object_numbers.size(); ++i) {
        if (i) tree << " ";
        tree << page_object_numbers[i] << " 0 R";
    }
    tree << "] >>";
    objects[1] = tree.str();

    // Serialise, recording byte offsets for the cross-reference table.
    ostringstream pdf;
    pdf << "%PDF-1.4\n";
    vector<size_t> offsets(objects.size() + 1, 0);
    for (size_t i = 0; i < objects.size(); ++i) {
        offsets[i + 1] = static_cast<size_t>(pdf.tellp());
        pdf << (i + 1) << " 0 obj\n" << objects[i] << "\nendobj\n";
    }

    size_t xref_offset = static_cast<size_t>(pdf.tellp());
    pdf << "xref\n0 " << (objects.size() + 1) << "\n";
    pdf << "0000000000 65535 f \n";
    for (size_t i = 1; i <= objects.size(); ++i) {
        char entry[24];
        snprintf(entry, sizeof(entry), "%010zu 00000 n \n", offsets[i]);
        pdf << entry;
    }
    pdf << "trailer\n<< /Size " << (objects.size() + 1)
        << " /Root 1 0 R >>\nstartxref\n" << xref_offset << "\n%%EOF\n";

    ofstream out(output_path, ios::binary);
    if (!out.is_open()) {
        return Error(ErrorCode::kPermissionDenied, "Cannot write: " + output_path);
    }
    const string bytes = pdf.str();
    out.write(bytes.data(), static_cast<streamsize>(bytes.size()));
    if (!out.good()) {
        return Error(ErrorCode::kPDFError, "Failed writing " + output_path);
    }

    Logger::instance().info("PdfWriter: wrote " + to_string(pages_.size()) +
                            " page(s) to " + output_path);
    return Error::success();
}

} // namespace convertor
