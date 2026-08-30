#pragma once

#include <string>
#include <vector>

#include <convertor/error.hpp>

namespace convertor {

class TextDocument {
public:
    TextDocument() = default;
    explicit TextDocument(const std::string& path);

    Error load(const std::string& path);
    Error save(const std::string& path);

    const std::string& content() const;
    void set_content(const std::string& text);

    std::vector<std::string> lines() const;

private:
    std::string content_;
};

} // namespace convertor
