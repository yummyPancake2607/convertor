#include "document_converter.hpp"

#include "document_content.hpp"
#include "document_readers.hpp"
#include "document_writers.hpp"
#include "image_converter.hpp"
#include "pdf_document.hpp"
#include "pdf_writer.hpp"

#include <convertor/format_catalog.hpp>
#include <convertor/logging.hpp>
#include "../fs/path_utils.hpp"
#include "../fs/temp_file.hpp"

#include <cstdio>

using namespace std;

namespace convertor {

namespace {

/// The document targets the app offers. Writers for the other office and text
/// formats exist in document_writers.cpp and still work; nothing routes to them
/// while Word and PDF are the only documents on offer.
bool can_write_document(const string& ext) {
    return ext == "pdf" || ext == "docx";
}

Error write_as(const DocumentContent& content, const string& path,
               const string& ext) {
    if (ext == "pdf")  return writers::write_pdf(content, path);
    if (ext == "docx") return writers::write_docx(content, path);
    if (ext == "xlsx") return writers::write_xlsx(content, path);
    if (ext == "odt")  return writers::write_odt(content, path);
    if (ext == "ods")  return writers::write_ods(content, path);
    if (ext == "rtf")  return writers::write_rtf(content, path);
    if (ext == "html") return writers::write_html(content, path);
    if (ext == "txt" || ext == "md" || ext == "csv") {
        return writers::write_plain(content, path, ext);
    }
    return Error(ErrorCode::kUnsupportedFormat,
                 "Cannot write documents of type: " + ext);
}

} // namespace

bool DocumentConverter::can_handle(const ConversionRequest& request,
                                   const MediaInfo& input_info) const {
    const string to_ext = request.output_extension();
    const auto* to_fmt = FormatCatalog::instance().find_by_extension(to_ext);
    if (!to_fmt) return false;

    // Images become PDFs here too: that is a document conversion even though
    // the input is a picture.
    if (input_info.media_type == MediaType::kImage) return to_ext == "pdf";

    if (input_info.media_type != MediaType::kDocument) return false;
    if (!readers::can_read(request.input_extension())) return false;

    return can_write_document(to_ext);
}

Error DocumentConverter::convert(const ConversionRequest& request,
                                 const MediaInfo& input_info,
                                 ProgressCallback progress) {
    const string from_ext = request.input_extension();
    const string to_ext = request.output_extension();

    Logger::instance().info("DocumentConverter: " + from_ext + " -> " + to_ext);

    if (input_info.media_type == MediaType::kImage && to_ext == "pdf") {
        return image_to_pdf(request, input_info, progress);
    }

    DocumentContent content;
    Error err = readers::read_document(request.input_path(), from_ext, content);
    if (!err.ok()) return err;
    if (content.empty()) {
        return Error(ErrorCode::kXmlParseError,
                     "No readable content in " + request.input_path());
    }
    if (progress) progress(0.5f);

    err = write_as(content, request.output_path(), to_ext);
    if (progress) progress(1.0f);
    return err;
}

Error DocumentConverter::image_to_pdf(const ConversionRequest& request,
                                      const MediaInfo&, ProgressCallback progress) {
    string jpeg;
    int width = 0, height = 0;

    const int quality = request.settings().image.quality.value_or(90);
    Error err = image_ops::encode_to_jpeg(request.input_path(), jpeg,
                                          width, height, quality,
                                          fs::parent_dir(request.output_path()));
    if (!err.ok()) return err;

    if (progress) progress(0.6f);

    PdfWriter writer;
    writer.add_jpeg_page(jpeg, width, height);
    err = writer.save(request.output_path());

    if (progress) progress(1.0f);
    return err;
}

} // namespace convertor
