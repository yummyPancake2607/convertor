#pragma once

#include <string>
#include <vector>

#include <convertor/error.hpp>

namespace convertor {

struct TableCell {
    int row;
    int col;
    std::string value;
};

class OOXMLReader {
public:
    explicit OOXMLReader(const std::string& path);

    bool is_open() const;

    std::string extract_text();
    std::vector<TableCell> extract_cells();

    /// Renders extracted cells as CSV, quoting values that need it.
    static std::string cells_to_csv(const std::vector<TableCell>& cells);

private:
    std::string path_;
    bool open_;
};

} // namespace convertor
