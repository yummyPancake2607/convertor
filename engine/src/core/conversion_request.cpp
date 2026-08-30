#include <convertor/conversion_request.hpp>
#include "../fs/path_utils.hpp"

using namespace std;

namespace convertor {

ConversionRequest::ConversionRequest() = default;

ConversionRequest::ConversionRequest(string input_path, string output_path)
    : input_path_(move(input_path)), output_path_(move(output_path)) {}

ConversionRequest::ConversionRequest(string input_path, string output_path,
                                     ConversionSettings settings)
    : input_path_(move(input_path)), output_path_(move(output_path)),
      settings_(move(settings)) {}

const string& ConversionRequest::input_path() const { return input_path_; }
const string& ConversionRequest::output_path() const { return output_path_; }
const ConversionSettings& ConversionRequest::settings() const { return settings_; }
ConversionSettings& ConversionRequest::settings() { return settings_; }

void ConversionRequest::set_input_path(string path) { input_path_ = move(path); }
void ConversionRequest::set_output_path(string path) { output_path_ = move(path); }
void ConversionRequest::set_settings(ConversionSettings settings) { settings_ = move(settings); }

string ConversionRequest::input_extension() const { return fs::extension(input_path_); }
string ConversionRequest::output_extension() const { return fs::extension(output_path_); }

} // namespace convertor
