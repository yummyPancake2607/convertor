#include "cmd_formats.hpp"

#include <convertor/format_catalog.hpp>
#include <convertor/logging.hpp>

#include <iostream>

using namespace std;

int cmd_formats(int argc, char* argv[]) {
    auto& catalog = convertor::FormatCatalog::instance();
    catalog.load_defaults();

    auto formats = catalog.all_formats();

    cout << "Supported formats (" << formats.size() << "):\n\n";

    for (const auto* fmt : formats) {
        cout << "  " << fmt->id() << "\t" << fmt->name()
             << "\t." << fmt->extension()
             << "\t" << convertor::media_type_name(fmt->media_type()) << "\n";
    }

    return 0;
}
