#include "pdf_document.hpp"

#include <convertor/logging.hpp>
#include <poppler-document.h>
#include <poppler-page.h>
#include <poppler-page-renderer.h>
#include <poppler-image.h>

#include <fstream>
#include <memory>

using namespace std;

namespace convertor {

namespace {

poppler::document* as_doc(void* p) {
    return static_cast<poppler::document*>(p);
}

// poppler hands back UTF-8 bytes in a ustring; go through to_utf8() so the
// text keeps its encoding instead of being flattened to Latin-1.
string ustring_to_utf8(const poppler::ustring& s) {
    poppler::byte_array bytes = s.to_utf8();
    return string(bytes.begin(), bytes.end());
}

} // namespace

PDFDocument::PDFDocument(const string& path) : path_(path) {
    doc_ = poppler::document::load_from_file(path);
    if (!doc_) {
        Logger::instance().warn("PDFDocument: cannot load " + path);
        return;
    }
    if (as_doc(doc_)->is_locked()) {
        Logger::instance().warn("PDFDocument: " + path + " is password protected");
        delete as_doc(doc_);
        doc_ = nullptr;
        return;
    }
    Logger::instance().info("PDFDocument: opened " + path + " (" +
                            to_string(as_doc(doc_)->pages()) + " pages)");
}

PDFDocument::~PDFDocument() {
    delete as_doc(doc_);
    doc_ = nullptr;
}

bool PDFDocument::is_open() const { return doc_ != nullptr; }

int PDFDocument::page_count() const {
    return doc_ ? as_doc(doc_)->pages() : 0;
}

Error PDFDocument::render_page(int page_number, RenderedPage& out, int dpi) {
    if (!doc_) return Error(ErrorCode::kPDFError, "PDF not open");

    unique_ptr<poppler::page> page(as_doc(doc_)->create_page(page_number));
    if (!page) {
        return Error(ErrorCode::kPDFRender,
                     "No such page: " + to_string(page_number));
    }

    poppler::page_renderer renderer;
    renderer.set_render_hint(poppler::page_renderer::antialiasing, true);
    renderer.set_render_hint(poppler::page_renderer::text_antialiasing, true);
    renderer.set_image_format(poppler::image::format_rgb24);

    poppler::image img = renderer.render_page(page.get(), dpi, dpi);
    if (!img.is_valid()) {
        return Error(ErrorCode::kPDFRender,
                     "Failed to render page " + to_string(page_number));
    }

    out.width = img.width();
    out.height = img.height();
    out.stride = img.bytes_per_row();
    out.pixels.assign(
        reinterpret_cast<const unsigned char*>(img.const_data()),
        reinterpret_cast<const unsigned char*>(img.const_data()) +
            static_cast<size_t>(out.stride) * out.height);

    Logger::instance().info("PDFDocument: rendered page " +
                            to_string(page_number) + " at " +
                            to_string(out.width) + "x" + to_string(out.height));
    return Error::success();
}

Error PDFDocument::extract_text(string& out_text) {
    if (!doc_) return Error(ErrorCode::kPDFError, "PDF not open");

    out_text.clear();
    const int pages = as_doc(doc_)->pages();
    for (int i = 0; i < pages; ++i) {
        unique_ptr<poppler::page> page(as_doc(doc_)->create_page(i));
        if (!page) continue;
        out_text += ustring_to_utf8(page->text());
        if (i + 1 < pages) out_text += "\n\n";
    }

    Logger::instance().info("PDFDocument: extracted " + to_string(out_text.size()) +
                            " bytes of text from " + path_);
    return Error::success();
}

Error PDFDocument::extract_text_to_file(const string& output_path) {
    string text;
    Error err = extract_text(text);
    if (!err.ok()) return err;

    ofstream out(output_path, ios::binary);
    if (!out.is_open()) {
        return Error(ErrorCode::kPermissionDenied, "Cannot write: " + output_path);
    }
    out << text;
    if (!out.good()) {
        return Error(ErrorCode::kPDFTextExtract,
                     "Failed writing text to " + output_path);
    }
    return Error::success();
}

} // namespace convertor
