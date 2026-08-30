#include "file_system.hpp"
#include "path_utils.hpp"

#include <sys/stat.h>
#include <unistd.h>

using namespace std;

namespace convertor::fs {

bool exists(const string& path) {
    struct stat st;
    return stat(path.c_str(), &st) == 0;
}

int64_t file_size(const string& path) {
    struct stat st;
    if (stat(path.c_str(), &st) != 0) return -1;
    return st.st_size;
}

bool is_writable(const string& path) {
    return access(path.c_str(), W_OK) == 0;
}

bool is_readable(const string& path) {
    return access(path.c_str(), R_OK) == 0;
}

string unique_output_path(const string& path) {
    if (!exists(path)) return path;
    string dir = parent_dir(path);
    string stem_name = stem(path);
    string ext = extension(path);
    for (int i = 1; i < 1000; ++i) {
        string candidate = dir + "/" + stem_name + "_" + to_string(i) + "." + ext;
        if (!exists(candidate)) return candidate;
    }
    return path + "_final";
}

} // namespace convertor::fs
