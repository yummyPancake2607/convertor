#include "format_detector.hpp"

#include <convertor/format_catalog.hpp>
#include "../fs/path_utils.hpp"

using namespace std;

namespace convertor {

FormatDetector& FormatDetector::instance() {
    static FormatDetector s_instance;
    return s_instance;
}

string FormatDetector::detect(const string& path) const {
    string ext = fs::extension(path);
    auto* fmt = FormatCatalog::instance().find_by_extension(ext);
    return fmt ? fmt->id() : "";
}

MediaType FormatDetector::detect_type(const string& path) const {
    string ext = fs::extension(path);
    return media_type_from_extension(ext);
}

} // namespace convertor
