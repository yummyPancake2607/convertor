#include "path_utils.hpp"

using namespace std;

namespace convertor::fs {

string join(const string& dir, const string& file) {
    if (dir.empty()) return file;
    if (dir.back() == '/') return dir + file;
    return dir + "/" + file;
}

string parent_dir(const string& path) {
    auto pos = path.rfind('/');
    if (pos == string::npos) return ".";
    return path.substr(0, pos);
}

string filename(const string& path) {
    auto pos = path.rfind('/');
    if (pos == string::npos) return path;
    return path.substr(pos + 1);
}

string stem(const string& path) {
    string name = filename(path);
    auto pos = name.rfind('.');
    if (pos == string::npos) return name;
    return name.substr(0, pos);
}

string extension(const string& path) {
    string name = filename(path);
    auto pos = name.rfind('.');
    if (pos == string::npos) return "";
    return name.substr(pos + 1);
}

string change_extension(const string& path, const string& ext) {
    string name = filename(path);
    string dir = parent_dir(path);
    auto pos = name.rfind('.');
    if (pos != string::npos) name = name.substr(0, pos);
    name += "." + ext;
    if (dir == ".") return name;
    return dir + "/" + name;
}

} // namespace convertor::fs
