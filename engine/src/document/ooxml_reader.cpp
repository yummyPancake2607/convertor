#include "ooxml_reader.hpp"
#include "zip_reader.hpp"

#include <convertor/logging.hpp>

#include <algorithm>
#include <cctype>
#include <cstdlib>

using namespace std;

namespace convertor {

namespace {

// Appends a code point to a UTF-8 string.
void append_utf8(string& out, uint32_t cp) {
    if (cp < 0x80) {
        out += static_cast<char>(cp);
    } else if (cp < 0x800) {
        out += static_cast<char>(0xC0 | (cp >> 6));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
        out += static_cast<char>(0xE0 | (cp >> 12));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else {
        out += static_cast<char>(0xF0 | (cp >> 18));
        out += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    }
}

// Resolves the XML entities OOXML actually emits.
string decode_entities(const string& in) {
    string out;
    out.reserve(in.size());
    for (size_t i = 0; i < in.size(); ++i) {
        if (in[i] != '&') { out += in[i]; continue; }

        size_t end = in.find(';', i);
        if (end == string::npos || end - i > 10) { out += in[i]; continue; }

        string entity = in.substr(i + 1, end - i - 1);
        if (entity == "amp")        out += '&';
        else if (entity == "lt")    out += '<';
        else if (entity == "gt")    out += '>';
        else if (entity == "quot")  out += '"';
        else if (entity == "apos")  out += '\'';
        else if (entity.size() > 1 && entity[0] == '#') {
            const bool hex = entity[1] == 'x' || entity[1] == 'X';
            const uint32_t cp = static_cast<uint32_t>(
                strtoul(entity.c_str() + (hex ? 2 : 1), nullptr, hex ? 16 : 10));
            if (cp) append_utf8(out, cp); else out += '?';
        } else {
            out += in.substr(i, end - i + 1);  // leave unknown entities intact
            i = end;
            continue;
        }
        i = end;
    }
    return out;
}

// Returns the name of the tag starting at `pos` (which points at '<').
string tag_name(const string& xml, size_t pos) {
    size_t i = pos + 1;
    if (i < xml.size() && (xml[i] == '/' || xml[i] == '?' || xml[i] == '!')) ++i;
    size_t start = i;
    while (i < xml.size() && !isspace(static_cast<unsigned char>(xml[i])) &&
           xml[i] != '>' && xml[i] != '/') {
        ++i;
    }
    return xml.substr(start, i - start);
}

// Reads an attribute value out of a start tag.
string tag_attribute(const string& tag, const string& attr) {
    size_t pos = tag.find(attr + "=\"");
    if (pos == string::npos) return {};
    pos += attr.size() + 2;
    size_t end = tag.find('"', pos);
    if (end == string::npos) return {};
    return tag.substr(pos, end - pos);
}

// Text content between a start tag ending at `from` and its matching close.
string text_until_close(const string& xml, size_t from, const string& close_tag) {
    size_t end = xml.find(close_tag, from);
    if (end == string::npos) return {};
    return decode_entities(xml.substr(from, end - from));
}

// "BC12" -> column 54 (0-based), row 11 (0-based).
bool parse_cell_ref(const string& ref, int& row, int& col) {
    size_t i = 0;
    int c = 0;
    while (i < ref.size() && isalpha(static_cast<unsigned char>(ref[i]))) {
        c = c * 26 + (toupper(static_cast<unsigned char>(ref[i])) - 'A' + 1);
        ++i;
    }
    if (i == 0 || i >= ref.size()) return false;
    const int r = atoi(ref.c_str() + i);
    if (r <= 0) return false;
    col = c - 1;
    row = r - 1;
    return true;
}

// Escapes a value for CSV output.
string csv_escape(const string& value) {
    const bool needs_quotes =
        value.find_first_of(",\"\n\r") != string::npos;
    if (!needs_quotes) return value;

    string out = "\"";
    for (char ch : value) {
        if (ch == '"') out += '"';
        out += ch;
    }
    out += '"';
    return out;
}

} // namespace

OOXMLReader::OOXMLReader(const string& path) : path_(path), open_(false) {
    ZipReader zip(path);
    open_ = zip.is_open();
    if (!open_) {
        Logger::instance().warn("OOXMLReader: not a readable OOXML package: " + path);
        return;
    }
    Logger::instance().info("OOXMLReader: opened " + path);
}

bool OOXMLReader::is_open() const { return open_; }

string OOXMLReader::extract_text() {
    ZipReader zip(path_);
    if (!zip.is_open()) return {};

    // Word keeps the body in word/document.xml; presentations spread their
    // text across slideN.xml parts, which use the same a:t run element.
    string xml = zip.read_entry("word/document.xml");
    if (xml.empty()) {
        vector<string> slides;
        for (const auto& name : zip.entry_names()) {
            if (name.rfind("ppt/slides/slide", 0) == 0 &&
                name.size() > 4 && name.substr(name.size() - 4) == ".xml") {
                slides.push_back(name);
            }
        }
        sort(slides.begin(), slides.end());
        for (const auto& slide : slides) xml += zip.read_entry(slide);
    }
    if (xml.empty()) return {};

    string text;
    size_t i = 0;
    while (i < xml.size()) {
        size_t lt = xml.find('<', i);
        if (lt == string::npos) break;
        size_t gt = xml.find('>', lt);
        if (gt == string::npos) break;

        const string name = tag_name(xml, lt);
        const bool closing = xml[lt + 1] == '/';

        if (!closing && (name == "w:t" || name == "a:t")) {
            text += text_until_close(xml, gt + 1, "</" + name + ">");
        } else if (!closing && (name == "w:br" || name == "w:cr")) {
            text += '\n';
        } else if (!closing && name == "w:tab") {
            text += '\t';
        } else if (closing && (name == "w:p" || name == "a:p")) {
            text += '\n';
        }
        i = gt + 1;
    }

    return text;
}

vector<TableCell> OOXMLReader::extract_cells() {
    vector<TableCell> cells;

    ZipReader zip(path_);
    if (!zip.is_open()) return cells;

    // Shared strings are referenced by index from cells marked t="s".
    vector<string> shared;
    const string shared_xml = zip.read_entry("xl/sharedStrings.xml");
    if (!shared_xml.empty()) {
        size_t i = 0;
        bool in_item = false;
        string item;
        while (i < shared_xml.size()) {
            size_t lt = shared_xml.find('<', i);
            if (lt == string::npos) break;
            size_t gt = shared_xml.find('>', lt);
            if (gt == string::npos) break;

            const string name = tag_name(shared_xml, lt);
            const bool closing = shared_xml[lt + 1] == '/';

            if (!closing && name == "si") { in_item = true; item.clear(); }
            else if (closing && name == "si") { shared.push_back(item); in_item = false; }
            else if (in_item && !closing && name == "t") {
                item += text_until_close(shared_xml, gt + 1, "</t>");
            }
            i = gt + 1;
        }
    }

    // Use the first worksheet part; that is what the UI offers as "the sheet".
    string sheet_name;
    for (const auto& name : zip.entry_names()) {
        if (name.rfind("xl/worksheets/sheet", 0) == 0 &&
            name.size() > 4 && name.substr(name.size() - 4) == ".xml") {
            if (sheet_name.empty() || name < sheet_name) sheet_name = name;
        }
    }
    if (sheet_name.empty()) return cells;

    const string sheet = zip.read_entry(sheet_name);
    size_t i = 0;
    while (i < sheet.size()) {
        size_t lt = sheet.find('<', i);
        if (lt == string::npos) break;
        size_t gt = sheet.find('>', lt);
        if (gt == string::npos) break;

        const string name = tag_name(sheet, lt);
        if (name != "c" || sheet[lt + 1] == '/') { i = gt + 1; continue; }

        const string tag = sheet.substr(lt, gt - lt + 1);
        int row = 0, col = 0;
        if (!parse_cell_ref(tag_attribute(tag, "r"), row, col)) { i = gt + 1; continue; }

        const string type = tag_attribute(tag, "t");
        const bool self_closing = gt > lt && sheet[gt - 1] == '/';

        string value;
        if (!self_closing) {
            const size_t cell_end = sheet.find("</c>", gt);
            const string body =
                sheet.substr(gt + 1, cell_end == string::npos ? string::npos
                                                             : cell_end - gt - 1);
            if (type == "inlineStr") {
                const size_t t_open = body.find("<t");
                const size_t t_start = t_open == string::npos
                                           ? string::npos
                                           : body.find('>', t_open);
                if (t_start != string::npos) {
                    value = text_until_close(body, t_start + 1, "</t>");
                }
            } else {
                const size_t v_open = body.find("<v>");
                if (v_open != string::npos) {
                    value = text_until_close(body, v_open + 3, "</v>");
                }
            }

            if (type == "s") {
                const long idx = strtol(value.c_str(), nullptr, 10);
                value = (idx >= 0 && idx < static_cast<long>(shared.size()))
                            ? shared[static_cast<size_t>(idx)]
                            : string();
            }
            if (cell_end != string::npos) i = cell_end + 4; else i = gt + 1;
        } else {
            i = gt + 1;
        }

        cells.push_back(TableCell{row, col, value});
    }

    return cells;
}

string OOXMLReader::cells_to_csv(const vector<TableCell>& cells) {
    if (cells.empty()) return {};

    int max_row = 0, max_col = 0;
    for (const auto& c : cells) {
        max_row = max(max_row, c.row);
        max_col = max(max_col, c.col);
    }

    vector<vector<string>> grid(max_row + 1, vector<string>(max_col + 1));
    for (const auto& c : cells) grid[c.row][c.col] = c.value;

    string csv;
    for (int r = 0; r <= max_row; ++r) {
        for (int c = 0; c <= max_col; ++c) {
            if (c > 0) csv += ',';
            csv += csv_escape(grid[r][c]);
        }
        csv += '\n';
    }
    return csv;
}

} // namespace convertor
