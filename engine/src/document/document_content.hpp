#pragma once

#include <string>
#include <vector>

namespace convertor {

/// What a document carries, once the source format has been peeled away.
///
/// Every reader produces one of these and every writer consumes one, so the
/// converter does not need a special case per format pair - any source can be
/// written to any target.
struct DocumentContent {
    /// The document as a flow of lines. Always populated; a table source fills
    /// this with its rows rendered as text so text targets still work.
    std::vector<std::string> lines;

    /// Rows of cells, non-empty only when the source really was tabular.
    /// Spreadsheet targets use this to keep the grid instead of flattening it.
    std::vector<std::vector<std::string>> rows;

    bool is_table() const { return !rows.empty(); }
    bool empty() const { return lines.empty() && rows.empty(); }
};

} // namespace convertor
