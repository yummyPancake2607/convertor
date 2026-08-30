#pragma once

#include <string>

#include <convertor/error.hpp>

#include "document_content.hpp"

namespace convertor::readers {

/// Reads any document the engine understands, chosen by `extension`.
///
/// Every source ends up as a [DocumentContent], so the converter never needs a
/// branch per source/target pair.
Error read_document(const std::string& path, const std::string& extension,
                    DocumentContent& out);

/// True when this extension can be read at all. Legacy binary Office formats
/// (.doc, .xls, .ppt) are deliberately absent: they need a full compound-file
/// parser that is not linked in.
bool can_read(const std::string& extension);

} // namespace convertor::readers
