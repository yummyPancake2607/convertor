#include <convertor/format_catalog.hpp>
#include <cassert>
#include <iostream>

using namespace convertor;
using namespace std;

void test_format_catalog() {
    auto& catalog = FormatCatalog::instance();
    catalog.load_defaults();

    auto mp4 = catalog.find_by_id("mp4");
    assert(mp4 != nullptr);
    assert(mp4->extension() == "mp4");
    assert(mp4->media_type() == MediaType::kVideo);

    auto jpg = catalog.find_by_extension("jpg");
    assert(jpg != nullptr);
    assert(jpg->media_type() == MediaType::kImage);

    assert(catalog.can_convert("mp4", "mkv"));
    assert(catalog.can_convert("mp4", "mp3"));
    assert(!catalog.can_convert("mp4", "pdf"));

    auto ct = catalog.conversion_type_for("mp4", "mp3");
    assert(ct == ConversionType::kExtractAudio);

    auto all = catalog.all_formats();
    assert(all.size() > 10);
}
