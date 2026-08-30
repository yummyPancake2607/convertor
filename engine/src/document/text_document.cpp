#include "text_document.hpp"

#include <fstream>
#include <sstream>

using namespace std;

namespace convertor {

TextDocument::TextDocument(const string& path) {
    load(path);
}

Error TextDocument::load(const string& path) {
    ifstream file(path);
    if (!file.is_open())
        return Error(ErrorCode::kFileNotFound, "Cannot open: " + path);

    stringstream ss;
    ss << file.rdbuf();
    content_ = ss.str();
    return Error::success();
}

Error TextDocument::save(const string& path) {
    ofstream file(path);
    if (!file.is_open())
        return Error(ErrorCode::kFileNotFound, "Cannot write: " + path);

    file << content_;
    return Error::success();
}

const string& TextDocument::content() const { return content_; }
void TextDocument::set_content(const string& text) { content_ = text; }

vector<string> TextDocument::lines() const {
    vector<string> result;
    istringstream stream(content_);
    string line;
    while (getline(stream, line)) result.push_back(line);
    return result;
}

} // namespace convertor
