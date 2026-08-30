#include "cmd_convert.hpp"

#include <convertor/engine.hpp>
#include <convertor/logging.hpp>

#include <iostream>

using namespace std;

int cmd_convert(int argc, char* argv[]) {
    if (argc < 3) {
        cerr << "Usage: convertor convert <input> <output>\n";
        return 1;
    }

    convertor::Engine engine;
    engine.initialize();

    convertor::ConversionRequest request(argv[1], argv[2]);

    cerr << "Converting " << argv[1] << " -> " << argv[2] << "...\n";

    convertor::Error err;
    auto result = engine.convert_sync(request, err);
    if (result.success) {
        cerr << "Done in " << result.elapsed_seconds << "s\n";
        return 0;
    } else {
        cerr << "Conversion failed: " << err.to_string() << "\n";
        return 1;
    }
}
