#include "converter_registry.hpp"
#include "converter.hpp"

using namespace std;

namespace convertor {

ConverterRegistry& ConverterRegistry::instance() {
    static ConverterRegistry s_instance;
    return s_instance;
}

void ConverterRegistry::register_converter(unique_ptr<IConverter> converter) {
    converters_.push_back(move(converter));
}

IConverter* ConverterRegistry::find_converter(const ConversionRequest& request,
                                               const MediaInfo& input_info) const {
    for (const auto& c : converters_) {
        if (c->can_handle(request, input_info)) {
            return c.get();
        }
    }
    return nullptr;
}

vector<IConverter*> ConverterRegistry::find_converters(
        const ConversionRequest& request, const MediaInfo& input_info) const {
    vector<IConverter*> result;
    for (const auto& c : converters_) {
        if (c->can_handle(request, input_info)) result.push_back(c.get());
    }
    return result;
}

vector<IConverter*> ConverterRegistry::all_converters() const {
    vector<IConverter*> result;
    for (const auto& c : converters_) result.push_back(c.get());
    return result;
}

} // namespace convertor
