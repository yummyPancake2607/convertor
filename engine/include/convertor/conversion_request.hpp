#pragma once

#include <cstdint>
#include <string>

#include <convertor/conversion_settings.hpp>
#include <convertor/file_format.hpp>

using namespace std;

namespace convertor {

class ConversionRequest {
public:
    ConversionRequest();
    ConversionRequest(string input_path, string output_path);
    ConversionRequest(string input_path, string output_path,
                      ConversionSettings settings);

    const string& input_path() const;
    const string& output_path() const;
    const ConversionSettings& settings() const;
    ConversionSettings& settings();

    void set_input_path(string path);
    void set_output_path(string path);
    void set_settings(ConversionSettings settings);

    string input_extension() const;
    string output_extension() const;

private:
    string input_path_;
    string output_path_;
    ConversionSettings settings_;
};

} // namespace convertor
