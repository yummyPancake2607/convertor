#include "cmd_convert.hpp"
#include "cmd_probe.hpp"
#include "cmd_formats.hpp"

#include <convertor/logging.hpp>
#include <convertor/version.hpp>

#include <iostream>
#include <string>

using namespace std;

void print_usage() {
    cout << "Convertor Engine v"
         << convertor::Version::current().major << "."
         << convertor::Version::current().minor << "."
         << convertor::Version::current().patch << "\n\n";
    cout << "Usage: convertor <command> [options]\n\n";
    cout << "Commands:\n";
    cout << "  convert <input> <output>  Convert a file\n";
    cout << "  probe <file>              Probe a file's info\n";
    cout << "  formats                   List supported formats\n";
    cout << "  help                      Show this help\n";
}

int main(int argc, char* argv[]) {
    convertor::Logger::instance().set_level(convertor::LogLevel::kInfo);

    if (argc < 2) {
        print_usage();
        return 0;
    }

    string cmd = argv[1];
    if (cmd == "convert") return cmd_convert(argc - 1, argv + 1);
    if (cmd == "probe")   return cmd_probe(argc - 1, argv + 1);
    if (cmd == "formats") return cmd_formats(argc - 1, argv + 1);
    if (cmd == "help")    { print_usage(); return 0; }

    cerr << "Unknown command: " << cmd << "\n";
    print_usage();
    return 1;
}
