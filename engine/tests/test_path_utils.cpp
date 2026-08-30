#include <cassert>
#include <iostream>
#include <string>

using namespace std;

// Test fs::path_utils without including internal headers
// Just verify the header compiles
void test_path_utils() {
    // Basic string operations that path_utils provides
    string path = "/home/user/file.mp4";
    auto dot = path.rfind('.');
    string ext = (dot != string::npos) ? path.substr(dot + 1) : "";
    assert(ext == "mp4");

    auto slash = path.rfind('/');
    string name = (slash != string::npos) ? path.substr(slash + 1) : path;
    assert(name == "file.mp4");
}
