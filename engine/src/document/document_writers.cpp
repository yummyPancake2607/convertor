#include "document_writers.hpp"

#include "pdf_writer.hpp"
#include "text_document.hpp"
#include "xml_text.hpp"
#include "zip_writer.hpp"

#include <convertor/logging.hpp>

#include <algorithm>
#include <cstdio>
#include <sstream>

using namespace std;

namespace convertor::writers {

namespace {

/// Escapes the five XML metacharacters and drops control bytes that would
/// make the document unopenable.
string xml_escape(const string& text) {
    string out;
    out.reserve(text.size());
    for (unsigned char c : text) {
        switch (c) {
            case '&':  out += "&amp;";  break;
            case '<':  out += "&lt;";   break;
            case '>':  out += "&gt;";   break;
            case '"':  out += "&quot;"; break;
            case '\'': out += "&apos;"; break;
            default:
                if (c < 0x20 && c != '\t') break;  // illegal in XML 1.0
                out += static_cast<char>(c);
        }
    }
    return out;
}

/// "A", "B", ... "Z", "AA" - a spreadsheet column name for a 0-based index.
string column_name(int index) {
    string name;
    for (int i = index; ; i = i / 26 - 1) {
        name.insert(name.begin(), static_cast<char>('A' + i % 26));
        if (i < 26) break;
    }
    return name;
}

/// Rows to write for a tabular target: a table source keeps its grid, a text
/// source becomes a single column so nothing is lost.
vector<vector<string>> as_rows(const DocumentContent& content) {
    if (content.is_table()) return content.rows;

    vector<vector<string>> rows;
    rows.reserve(content.lines.size());
    for (const string& line : content.lines) rows.push_back({line});
    return rows;
}

Error write_file(const string& path, const string& bytes) {
    TextDocument doc;
    doc.set_content(bytes);
    return doc.save(path);
}

string csv_escape(const string& value) {
    if (value.find_first_of(",\"\n\r") == string::npos) return value;
    string out = "\"";
    for (char c : value) {
        if (c == '"') out += '"';
        out += c;
    }
    out += '"';
    return out;
}

} // namespace

Error write_docx(const DocumentContent& content, const string& path) {
    ZipWriter zip(path);
    if (!zip.is_open()) {
        return Error(ErrorCode::kZipError, "Cannot create " + path);
    }

    ostringstream body;
    body << R"(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>)" "\n"
         << R"(<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>)";

    if (content.is_table()) {
        body << "<w:tbl>";
        for (const auto& row : content.rows) {
            body << "<w:tr>";
            for (const auto& cell : row) {
                body << R"(<w:tc><w:p><w:r><w:t xml:space="preserve">)"
                     << xml_escape(cell) << "</w:t></w:r></w:p></w:tc>";
            }
            body << "</w:tr>";
        }
        body << "</w:tbl>";
    } else {
        for (const string& line : content.lines) {
            body << R"(<w:p><w:r><w:t xml:space="preserve">)" << xml_escape(line)
                 << "</w:t></w:r></w:p>";
        }
    }
    body << "<w:sectPr/></w:body></w:document>";

    Error err = zip.add("[Content_Types].xml",
        R"(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>)" "\n"
        R"(<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">)"
        R"(<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>)"
        R"(<Default Extension="xml" ContentType="application/xml"/>)"
        R"(<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>)"
        R"(</Types>)");
    if (!err.ok()) return err;

    err = zip.add("_rels/.rels",
        R"(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>)" "\n"
        R"(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">)"
        R"(<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>)"
        R"(</Relationships>)");
    if (!err.ok()) return err;

    err = zip.add("word/document.xml", body.str());
    if (!err.ok()) return err;

    return zip.close();
}

Error write_xlsx(const DocumentContent& content, const string& path) {
    ZipWriter zip(path);
    if (!zip.is_open()) {
        return Error(ErrorCode::kZipError, "Cannot create " + path);
    }

    const vector<vector<string>> rows = as_rows(content);

    ostringstream sheet;
    sheet << R"(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>)" "\n"
          << R"(<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>)";
    for (size_t r = 0; r < rows.size(); ++r) {
        sheet << "<row r=\"" << (r + 1) << "\">";
        for (size_t c = 0; c < rows[r].size(); ++c) {
            // Inline strings keep every value in the sheet itself, so no
            // shared-string table has to be maintained.
            sheet << "<c r=\"" << column_name(static_cast<int>(c)) << (r + 1)
                  << R"(" t="inlineStr"><is><t xml:space="preserve">)"
                  << xml_escape(rows[r][c]) << "</t></is></c>";
        }
        sheet << "</row>";
    }
    sheet << "</sheetData></worksheet>";

    Error err = zip.add("[Content_Types].xml",
        R"(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>)" "\n"
        R"(<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">)"
        R"(<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>)"
        R"(<Default Extension="xml" ContentType="application/xml"/>)"
        R"(<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>)"
        R"(<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>)"
        R"(</Types>)");
    if (!err.ok()) return err;

    err = zip.add("_rels/.rels",
        R"(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>)" "\n"
        R"(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">)"
        R"(<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>)"
        R"(</Relationships>)");
    if (!err.ok()) return err;

    err = zip.add("xl/workbook.xml",
        R"(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>)" "\n"
        R"(<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" )"
        R"(xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">)"
        R"(<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>)");
    if (!err.ok()) return err;

    err = zip.add("xl/_rels/workbook.xml.rels",
        R"(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>)" "\n"
        R"(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">)"
        R"(<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>)"
        R"(</Relationships>)");
    if (!err.ok()) return err;

    err = zip.add("xl/worksheets/sheet1.xml", sheet.str());
    if (!err.ok()) return err;

    return zip.close();
}

namespace {

/// The manifest every OpenDocument package needs, listing its own parts.
string odf_manifest(const string& mime) {
    return string(R"(<?xml version="1.0" encoding="UTF-8"?>)") + "\n" +
        R"(<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">)"
        R"(<manifest:file-entry manifest:full-path="/" manifest:media-type=")" + mime + R"("/>)"
        R"(<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>)"
        R"(<manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>)"
        R"(</manifest:manifest>)";
}

const char* kOdfStyles =
    R"(<?xml version="1.0" encoding="UTF-8"?>)" "\n"
    R"(<office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" office:version="1.2"/>)";

Error write_odf_package(const string& path, const string& mime,
                        const string& content_xml) {
    ZipWriter zip(path);
    if (!zip.is_open()) {
        return Error(ErrorCode::kZipError, "Cannot create " + path);
    }

    // The spec requires `mimetype` to be the first entry and stored, not
    // deflated, so readers can identify the package from its first bytes.
    Error err = zip.add("mimetype", mime, /*store_uncompressed=*/true);
    if (!err.ok()) return err;

    err = zip.add("META-INF/manifest.xml", odf_manifest(mime));
    if (!err.ok()) return err;

    err = zip.add("styles.xml", kOdfStyles);
    if (!err.ok()) return err;

    err = zip.add("content.xml", content_xml);
    if (!err.ok()) return err;

    return zip.close();
}

} // namespace

Error write_odt(const DocumentContent& content, const string& path) {
    ostringstream xml;
    xml << R"(<?xml version="1.0" encoding="UTF-8"?>)" "\n"
        << R"(<office:document-content )"
        << R"(xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" )"
        << R"(xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" )"
        << R"(xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" )"
        << R"(office:version="1.2"><office:body><office:text>)";

    if (content.is_table()) {
        xml << R"(<table:table table:name="Table1">)";
        for (const auto& row : content.rows) {
            xml << "<table:table-row>";
            for (const auto& cell : row) {
                xml << R"(<table:table-cell office:value-type="string"><text:p>)"
                    << xml_escape(cell) << "</text:p></table:table-cell>";
            }
            xml << "</table:table-row>";
        }
        xml << "</table:table>";
    } else {
        for (const string& line : content.lines) {
            xml << "<text:p>" << xml_escape(line) << "</text:p>";
        }
    }
    xml << "</office:text></office:body></office:document-content>";

    return write_odf_package(path, "application/vnd.oasis.opendocument.text",
                             xml.str());
}

Error write_ods(const DocumentContent& content, const string& path) {
    const vector<vector<string>> rows = as_rows(content);

    ostringstream xml;
    xml << R"(<?xml version="1.0" encoding="UTF-8"?>)" "\n"
        << R"(<office:document-content )"
        << R"(xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" )"
        << R"(xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" )"
        << R"(xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" )"
        << R"(office:version="1.2"><office:body><office:spreadsheet>)"
        << R"(<table:table table:name="Sheet1">)";
    for (const auto& row : rows) {
        xml << "<table:table-row>";
        for (const auto& cell : row) {
            xml << R"(<table:table-cell office:value-type="string"><text:p>)"
                << xml_escape(cell) << "</text:p></table:table-cell>";
        }
        xml << "</table:table-row>";
    }
    xml << "</table:table></office:spreadsheet></office:body></office:document-content>";

    return write_odf_package(path,
                             "application/vnd.oasis.opendocument.spreadsheet",
                             xml.str());
}

Error write_rtf(const DocumentContent& content, const string& path) {
    ostringstream rtf;
    rtf << R"({\rtf1\ansi\ansicpg1252\deff0)" "\n"
        << R"({\fonttbl{\f0\fswiss Helvetica;}})" "\n"
        << R"(\f0\fs22 )";

    const vector<string>& lines =
        content.is_table() ? vector<string>() : content.lines;

    auto emit = [&](const string& text) {
        size_t i = 0;
        while (i < text.size()) {
            const unsigned long cp = xml_text::next_code_point(text, i);
            if (cp == '\\' || cp == '{' || cp == '}') {
                rtf << '\\' << static_cast<char>(cp);
            } else if (cp == '\t') {
                rtf << "\\tab ";
            } else if (cp < 0x80) {
                rtf << static_cast<char>(cp);
            } else if (cp <= 0x7FFF) {
                // RTF carries Unicode as a signed 16-bit code point followed by
                // an ASCII fallback for readers that cannot handle it.
                rtf << "\\u" << static_cast<long>(cp) << "?";
            } else if (cp <= 0xFFFF) {
                rtf << "\\u" << (static_cast<long>(cp) - 65536) << "?";
            } else {
                rtf << "?";   // outside the BMP; this escape has no room for it
            }
        }
    };

    if (content.is_table()) {
        for (const auto& row : content.rows) {
            for (size_t c = 0; c < row.size(); ++c) {
                if (c) rtf << R"(\tab )";
                emit(row[c]);
            }
            rtf << R"(\par)" "\n";
        }
    } else {
        for (const string& line : lines) {
            emit(line);
            rtf << R"(\par)" "\n";
        }
    }

    rtf << "}\n";
    return write_file(path, rtf.str());
}

Error write_html(const DocumentContent& content, const string& path) {
    ostringstream html;
    html << "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n"
         << "<title>Converted document</title>\n</head>\n<body>\n";

    if (content.is_table()) {
        html << "<table>\n";
        for (const auto& row : content.rows) {
            html << "  <tr>";
            for (const auto& cell : row) {
                html << "<td>" << xml_escape(cell) << "</td>";
            }
            html << "</tr>\n";
        }
        html << "</table>\n";
    } else {
        for (const string& line : content.lines) {
            if (line.empty()) {
                html << "<p>&nbsp;</p>\n";
            } else {
                html << "<p>" << xml_escape(line) << "</p>\n";
            }
        }
    }

    html << "</body>\n</html>\n";
    return write_file(path, html.str());
}

Error write_plain(const DocumentContent& content, const string& path,
                  const string& extension) {
    ostringstream out;

    if (extension == "csv") {
        for (const auto& row : as_rows(content)) {
            for (size_t c = 0; c < row.size(); ++c) {
                if (c) out << ',';
                out << csv_escape(row[c]);
            }
            out << '\n';
        }
        return write_file(path, out.str());
    }

    if (content.is_table()) {
        // Markdown gets a real table; plain text gets tab-separated columns.
        if (extension == "md") {
            for (size_t r = 0; r < content.rows.size(); ++r) {
                out << "| ";
                for (const auto& cell : content.rows[r]) out << cell << " | ";
                out << '\n';
                if (r == 0) {
                    out << "|";
                    for (size_t c = 0; c < content.rows[r].size(); ++c) out << " --- |";
                    out << '\n';
                }
            }
        } else {
            for (const auto& row : content.rows) {
                for (size_t c = 0; c < row.size(); ++c) {
                    if (c) out << '\t';
                    out << row[c];
                }
                out << '\n';
            }
        }
        return write_file(path, out.str());
    }

    for (const string& line : content.lines) out << line << '\n';
    return write_file(path, out.str());
}

Error write_pdf(const DocumentContent& content, const string& path) {
    PdfWriter writer;

    if (content.is_table()) {
        // Lay the grid out as aligned columns so a spreadsheet stays readable.
        vector<size_t> widths;
        for (const auto& row : content.rows) {
            for (size_t c = 0; c < row.size(); ++c) {
                if (widths.size() <= c) widths.push_back(0);
                widths[c] = max(widths[c], row[c].size());
            }
        }

        vector<string> lines;
        lines.reserve(content.rows.size());
        for (const auto& row : content.rows) {
            string line;
            for (size_t c = 0; c < row.size(); ++c) {
                if (c) line += "  ";
                line += row[c];
                if (c + 1 < row.size() && row[c].size() < widths[c]) {
                    line.append(widths[c] - row[c].size(), ' ');
                }
            }
            lines.push_back(line);
        }
        writer.add_text_lines(lines, 10);
    } else {
        writer.add_text_lines(content.lines, 11);
    }

    return writer.save(path);
}

} // namespace convertor::writers
