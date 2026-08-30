#include "document_readers.hpp"

#include "ooxml_reader.hpp"
#include "pdf_document.hpp"
#include "text_document.hpp"
#include "zip_reader.hpp"
#include "xml_text.hpp"

#include <convertor/logging.hpp>

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <sstream>

using namespace std;

namespace convertor::readers {

namespace {

vector<string> split_lines(const string& text) {
    vector<string> lines;
    istringstream stream(text);
    string line;
    while (getline(stream, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        lines.push_back(line);
    }
    return lines;
}

/// Splits one CSV record, honouring quoted fields and doubled quotes.
vector<string> parse_csv_row(const string& line) {
    vector<string> cells;
    string cell;
    bool quoted = false;

    for (size_t i = 0; i < line.size(); ++i) {
        const char c = line[i];
        if (quoted) {
            if (c == '"') {
                if (i + 1 < line.size() && line[i + 1] == '"') { cell += '"'; ++i; }
                else quoted = false;
            } else {
                cell += c;
            }
        } else if (c == '"') {
            quoted = true;
        } else if (c == ',') {
            cells.push_back(cell);
            cell.clear();
        } else if (c != '\r') {
            cell += c;
        }
    }
    cells.push_back(cell);
    return cells;
}

/// Reads an OpenDocument package: paragraphs for text, a grid for sheets.
Error read_odf(const string& path, DocumentContent& out) {
    ZipReader zip(path);
    if (!zip.is_open()) {
        return Error(ErrorCode::kZipError, "Not a readable OpenDocument file");
    }

    const string xml = zip.read_entry("content.xml");
    if (xml.empty()) {
        return Error(ErrorCode::kXmlParseError, "No content.xml in " + path);
    }

    vector<string> row;
    string cell;
    bool in_cell = false;

    xml_text::walk(xml, [&](const xml_text::Event& event) {
        if (event.is_text) {
            if (in_cell) {
                cell += event.text;
            } else if (!out.lines.empty()) {
                // Whitespace between the container's own tags arrives before
                // the first paragraph opens; there is nothing to append it to.
                out.lines.back() += event.text;
            }
            return;
        }
        if (!event.closing && event.name == "table:table-cell") {
            in_cell = true;
            cell.clear();
            if (event.self_closing) {
                row.push_back(cell);
                in_cell = false;
            }
        } else if (event.closing && event.name == "table:table-cell") {
            row.push_back(cell);
            in_cell = false;
        } else if (event.closing && event.name == "table:table-row") {
            out.rows.push_back(row);
            row.clear();
        } else if (!event.closing && event.name == "text:p") {
            if (!in_cell) out.lines.emplace_back();
        } else if (!event.closing && event.name == "text:line-break") {
            if (!in_cell) out.lines.emplace_back();
        } else if (!event.closing && event.name == "text:tab") {
            if (in_cell) cell += '\t';
            else if (!out.lines.empty()) out.lines.back() += '\t';
        }
    });

    // A cell's own <text:p> should not also become a document line.
    if (!out.rows.empty()) {
        out.lines.clear();
        for (const auto& r : out.rows) {
            string line;
            for (size_t i = 0; i < r.size(); ++i) {
                if (i) line += '\t';
                line += r[i];
            }
            out.lines.push_back(line);
        }
    }
    return Error::success();
}

/// Reads an EPUB by following its spine and stripping the XHTML.
Error read_epub(const string& path, DocumentContent& out) {
    ZipReader zip(path);
    if (!zip.is_open()) {
        return Error(ErrorCode::kZipError, "Not a readable EPUB file");
    }

    // container.xml points at the package document, which lists reading order.
    const string container = zip.read_entry("META-INF/container.xml");
    string opf_path;
    if (!container.empty()) {
        const size_t pos = container.find("full-path=\"");
        if (pos != string::npos) {
            const size_t start = pos + 11;
            const size_t end = container.find('"', start);
            if (end != string::npos) opf_path = container.substr(start, end - start);
        }
    }
    if (opf_path.empty()) {
        return Error(ErrorCode::kXmlParseError, "EPUB has no package document");
    }

    const string opf = zip.read_entry(opf_path);
    if (opf.empty()) {
        return Error(ErrorCode::kXmlParseError, "Cannot read " + opf_path);
    }

    string base;
    const size_t slash = opf_path.rfind('/');
    if (slash != string::npos) base = opf_path.substr(0, slash + 1);

    // manifest: id -> href, then spine gives the order to read them in.
    vector<pair<string, string>> manifest;
    vector<string> spine;
    xml_text::walk(opf, [&](const xml_text::Event& event) {
        if (event.is_text || event.closing) return;
        if (event.name == "item") {
            const string id = xml_text::attribute(event.tag, "id");
            const string href = xml_text::attribute(event.tag, "href");
            if (!id.empty() && !href.empty()) manifest.emplace_back(id, href);
        } else if (event.name == "itemref") {
            const string idref = xml_text::attribute(event.tag, "idref");
            if (!idref.empty()) spine.push_back(idref);
        }
    });

    for (const string& idref : spine) {
        string href;
        for (const auto& [id, target] : manifest) {
            if (id == idref) { href = target; break; }
        }
        if (href.empty()) continue;

        const string chapter = zip.read_entry(base + href);
        if (chapter.empty()) continue;

        for (const string& line : split_lines(xml_text::strip_markup(chapter))) {
            out.lines.push_back(line);
        }
    }

    if (out.lines.empty()) {
        return Error(ErrorCode::kXmlParseError, "No readable text in " + path);
    }
    return Error::success();
}

/// Reads RTF by walking its control words and keeping the literal text.
Error read_rtf(const string& path, DocumentContent& out) {
    TextDocument doc;
    Error err = doc.load(path);
    if (!err.ok()) return err;

    const string& rtf = doc.content();
    string line;
    int skip_depth = 0;          // inside a destination we do not render
    int depth = 0;

    for (size_t i = 0; i < rtf.size(); ++i) {
        const char c = rtf[i];

        if (c == '{') {
            ++depth;
            continue;
        }
        if (c == '}') {
            if (skip_depth && depth <= skip_depth) skip_depth = 0;
            --depth;
            continue;
        }

        if (c == '\\') {
            // Escaped literal characters.
            if (i + 1 < rtf.size() &&
                (rtf[i + 1] == '\\' || rtf[i + 1] == '{' || rtf[i + 1] == '}')) {
                if (!skip_depth) line += rtf[i + 1];
                ++i;
                continue;
            }

            size_t j = i + 1;
            string word;
            while (j < rtf.size() && isalpha(static_cast<unsigned char>(rtf[j]))) {
                word += rtf[j++];
            }

            string parameter;
            if (j < rtf.size() && (rtf[j] == '-' || isdigit(static_cast<unsigned char>(rtf[j])))) {
                if (rtf[j] == '-') parameter += rtf[j++];
                while (j < rtf.size() && isdigit(static_cast<unsigned char>(rtf[j]))) {
                    parameter += rtf[j++];
                }
            }
            if (j < rtf.size() && rtf[j] == ' ') ++j;  // delimiting space

            if (word == "par" || word == "line") {
                if (!skip_depth) { out.lines.push_back(line); line.clear(); }
            } else if (word == "tab") {
                if (!skip_depth) line += '\t';
            } else if (word == "u" && !parameter.empty()) {
                if (!skip_depth) {
                    const long cp = strtol(parameter.c_str(), nullptr, 10);
                    xml_text::append_utf8(line, cp < 0 ? cp + 65536 : cp);
                }
                // The following ASCII fallback character is not ours to keep.
                if (j < rtf.size() && rtf[j] == '?') ++j;
            } else if (word == "fonttbl" || word == "colortbl" || word == "stylesheet" ||
                       word == "info" || word == "pict" || word == "themedata" ||
                       word == "generator" || word == "datastore" || word == "listtable" ||
                       word == "rsidtbl" || word == "xmlnstbl") {
                if (!skip_depth) skip_depth = depth;
            }

            i = j - 1;
            continue;
        }

        if (c == '\r' || c == '\n') continue;   // layout only, not content
        if (!skip_depth) line += c;
    }

    if (!line.empty()) out.lines.push_back(line);
    if (out.lines.empty()) {
        return Error(ErrorCode::kXmlParseError, "No readable text in " + path);
    }
    return Error::success();
}

Error read_pdf(const string& path, DocumentContent& out) {
    PDFDocument pdf(path);
    if (!pdf.is_open()) {
        return Error(ErrorCode::kPDFError, "Cannot open PDF: " + path);
    }

    string text;
    Error err = pdf.extract_text(text);
    if (!err.ok()) return err;

    out.lines = split_lines(text);
    return Error::success();
}

Error read_office(const string& path, const string& extension,
                  DocumentContent& out) {
    OOXMLReader reader(path);
    if (!reader.is_open()) {
        return Error(ErrorCode::kZipError, "Not a readable Office file: " + path);
    }

    if (extension == "xlsx") {
        const auto cells = reader.extract_cells();
        if (cells.empty()) {
            return Error(ErrorCode::kXmlParseError, "No cells found in " + path);
        }

        int max_row = 0, max_col = 0;
        for (const auto& c : cells) {
            max_row = max(max_row, c.row);
            max_col = max(max_col, c.col);
        }
        out.rows.assign(max_row + 1, vector<string>(max_col + 1));
        for (const auto& c : cells) out.rows[c.row][c.col] = c.value;

        for (const auto& row : out.rows) {
            string line;
            for (size_t i = 0; i < row.size(); ++i) {
                if (i) line += '\t';
                line += row[i];
            }
            out.lines.push_back(line);
        }
        return Error::success();
    }

    const string text = reader.extract_text();
    if (text.empty()) {
        return Error(ErrorCode::kXmlParseError, "No text found in " + path);
    }
    out.lines = split_lines(text);
    return Error::success();
}

Error read_text(const string& path, const string& extension,
                DocumentContent& out) {
    TextDocument doc;
    Error err = doc.load(path);
    if (!err.ok()) return err;

    if (extension == "html" || extension == "htm") {
        out.lines = split_lines(xml_text::strip_markup(doc.content()));
        return Error::success();
    }

    if (extension == "csv") {
        for (const string& line : split_lines(doc.content())) {
            if (line.empty() && out.rows.empty()) continue;
            out.rows.push_back(parse_csv_row(line));
        }
        // Trailing newline should not become an empty final row.
        while (!out.rows.empty() && out.rows.back().size() == 1 &&
               out.rows.back()[0].empty()) {
            out.rows.pop_back();
        }
        out.lines = split_lines(doc.content());
        return Error::success();
    }

    out.lines = split_lines(doc.content());
    return Error::success();
}

} // namespace

bool can_read(const string& extension) {
    // Only the formats the app actually offers. Readers for the other office
    // and text formats exist below and still work, but nothing routes to them
    // while Word and PDF are the only documents on offer.
    static const char* kReadable[] = {"pdf", "docx"};
    return any_of(begin(kReadable), end(kReadable),
                  [&](const char* e) { return extension == e; });
}

Error read_document(const string& path, const string& extension,
                    DocumentContent& out) {
    out = DocumentContent();

    if (!can_read(extension)) {
        return Error(ErrorCode::kUnsupportedFormat,
                     "Cannot read documents of type: " + extension);
    }

    if (extension == "pdf")  return read_pdf(path, out);
    if (extension == "rtf")  return read_rtf(path, out);
    if (extension == "epub") return read_epub(path, out);
    if (extension == "odt" || extension == "ods" || extension == "odp") {
        return read_odf(path, out);
    }
    if (extension == "docx" || extension == "pptx" || extension == "xlsx") {
        return read_office(path, extension, out);
    }
    if (extension == "txt" || extension == "md" || extension == "csv" ||
        extension == "html" || extension == "htm") {
        return read_text(path, extension, out);
    }

    return Error(ErrorCode::kUnsupportedFormat,
                 "Cannot read documents of type: " + extension);
}

} // namespace convertor::readers
