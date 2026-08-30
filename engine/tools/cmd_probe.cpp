#include "cmd_probe.hpp"

#include <convertor/engine.hpp>
#include <convertor/logging.hpp>

#include <iostream>

using namespace std;

int cmd_probe(int argc, char* argv[]) {
    if (argc < 2) {
        cerr << "Usage: convertor probe <file>\n";
        return 1;
    }

    convertor::Engine engine;
    engine.initialize();

    convertor::Error err;
    auto info = engine.probe(argv[1], err);

    if (!err.ok()) {
        cerr << "Probe failed: " << err.to_string() << "\n";
        return 1;
    }

    cout << "File:      " << info.file_path << "\n";
    cout << "Format:    " << info.format_name << " (" << info.format_long_name << ")\n";
    cout << "Type:      " << convertor::media_type_name(info.media_type) << "\n";
    cout << "Duration:  " << (info.duration_us / 1000000.0) << "s\n";
    cout << "Bitrate:   " << (info.bit_rate / 1000) << " kbps\n";
    cout << "Streams:   " << info.streams.size() << "\n";

    for (const auto& s : info.streams) {
        cout << "  [" << s.index << "] "
             << convertor::media_type_name(s.media_type)
             << " " << s.codec_name;
        if (s.media_type == convertor::MediaType::kVideo) {
            cout << " " << s.width << "x" << s.height;
            if (s.frame_rate > 0) cout << " " << s.frame_rate << " fps";
        }
        if (s.media_type == convertor::MediaType::kAudio) {
            cout << " " << s.sample_rate << "Hz " << s.channels << "ch";
        }
        cout << "\n";
    }

    return 0;
}
