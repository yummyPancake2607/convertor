#pragma once

#include <functional>
#include <string>

namespace convertor::xml_text {

/// One item from a scan: either a tag or the text between two tags.
struct Event {
    bool is_text = false;

    std::string text;          ///< decoded character data (is_text only)

    std::string name;          ///< tag name, e.g. "w:t"
    std::string tag;           ///< the whole tag as written, for attributes
    bool closing = false;      ///< </foo>
    bool self_closing = false; ///< <foo/>
};

/// Walks XML or HTML, reporting each tag and each run of text.
///
/// A real parser is overkill here: the office formats are machine-generated
/// and only ever need their text runs and a handful of attributes. Comments,
/// declarations and CDATA are handled so markup cannot leak into the output.
void walk(const std::string& markup, const std::function<void(const Event&)>& on_event);

/// Reads one attribute out of a start tag, or "" when it is absent.
std::string attribute(const std::string& tag, const std::string& name);

/// Decodes XML/HTML entities, including numeric ones.
std::string decode_entities(const std::string& text);

/// Strips tags from HTML or XHTML, keeping paragraph and row breaks.
std::string strip_markup(const std::string& markup);

/// Appends one Unicode code point to a UTF-8 string.
void append_utf8(std::string& out, unsigned long code_point);

/// Decodes the UTF-8 sequence at `index`, advancing it past the character.
/// Malformed bytes yield '?' and advance by one, so decoding always finishes.
unsigned long next_code_point(const std::string& text, size_t& index);

} // namespace convertor::xml_text
