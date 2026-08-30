#pragma once

#include <string>

#include <convertor/error.hpp>

#include "document_content.hpp"

namespace convertor::writers {

/// Word document (WordprocessingML in a ZIP).
Error write_docx(const DocumentContent& content, const std::string& path);

/// Excel workbook (SpreadsheetML in a ZIP), using inline strings.
Error write_xlsx(const DocumentContent& content, const std::string& path);

/// OpenDocument text.
Error write_odt(const DocumentContent& content, const std::string& path);

/// OpenDocument spreadsheet.
Error write_ods(const DocumentContent& content, const std::string& path);

/// Rich Text Format.
Error write_rtf(const DocumentContent& content, const std::string& path);

/// HTML, as a table when the source was tabular.
Error write_html(const DocumentContent& content, const std::string& path);

/// Plain text, Markdown, or CSV, chosen by `extension`.
Error write_plain(const DocumentContent& content, const std::string& path,
                  const std::string& extension);

/// A paginated PDF.
Error write_pdf(const DocumentContent& content, const std::string& path);

} // namespace convertor::writers
