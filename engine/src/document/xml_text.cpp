#include "xml_text.hpp"

#include <cctype>
#include <cstdlib>
#include <sstream>

using namespace std;

namespace convertor::xml_text {

void append_utf8(string& out, unsigned long cp) {
    if (cp < 0x80) {
        out += static_cast<char>(cp);
    } else if (cp < 0x800) {
        out += static_cast<char>(0xC0 | (cp >> 6));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
        out += static_cast<char>(0xE0 | (cp >> 12));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else {
        out += static_cast<char>(0xF0 | (cp >> 18));
        out += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    }
}

unsigned long next_code_point(const string& text, size_t& index) {
    if (index >= text.size()) return 0;

    const unsigned char c = static_cast<unsigned char>(text[index]);
    const auto continuation = [&](size_t offset) -> unsigned long {
        return static_cast<unsigned char>(text[index + offset]) & 0x3FUL;
    };

    if (c < 0x80) { index += 1; return c; }
    if ((c & 0xE0) == 0xC0 && index + 1 < text.size()) {
        const unsigned long cp = ((c & 0x1FUL) << 6) | continuation(1);
        index += 2;
        return cp;
    }
    if ((c & 0xF0) == 0xE0 && index + 2 < text.size()) {
        const unsigned long cp =
            ((c & 0x0FUL) << 12) | (continuation(1) << 6) | continuation(2);
        index += 3;
        return cp;
    }
    if ((c & 0xF8) == 0xF0 && index + 3 < text.size()) {
        const unsigned long cp = ((c & 0x07UL) << 18) | (continuation(1) << 12) |
                                 (continuation(2) << 6) | continuation(3);
        index += 4;
        return cp;
    }

    index += 1;
    return '?';
}

string decode_entities(const string& in) {
    string out;
    out.reserve(in.size());

    for (size_t i = 0; i < in.size(); ++i) {
        if (in[i] != '&') { out += in[i]; continue; }

        const size_t end = in.find(';', i);
        if (end == string::npos || end - i > 12) { out += in[i]; continue; }

        const string entity = in.substr(i + 1, end - i - 1);
        if (entity == "amp")        out += '&';
        else if (entity == "lt")    out += '<';
        else if (entity == "gt")    out += '>';
        else if (entity == "quot")  out += '"';
        else if (entity == "apos")  out += '\'';
        else if (entity == "nbsp")  out += ' ';
        else if (entity == "mdash") out += "-";
        else if (entity == "ndash") out += "-";
        else if (entity.size() > 1 && entity[0] == '#') {
            const bool hex = entity[1] == 'x' || entity[1] == 'X';
            const unsigned long cp =
                strtoul(entity.c_str() + (hex ? 2 : 1), nullptr, hex ? 16 : 10);
            if (cp) append_utf8(out, cp); else out += '?';
        } else {
            out += in.substr(i, end - i + 1);   // leave unknown entities alone
            i = end;
            continue;
        }
        i = end;
    }
    return out;
}

string attribute(const string& tag, const string& name) {
    size_t search = 0;
    while (true) {
        const size_t pos = tag.find(name, search);
        if (pos == string::npos) return {};

        // Must be a whole attribute name, not a suffix of a longer one.
        const bool boundary_before =
            pos == 0 || isspace(static_cast<unsigned char>(tag[pos - 1]));
        size_t after = pos + name.size();
        while (after < tag.size() && isspace(static_cast<unsigned char>(tag[after]))) {
            ++after;
        }

        if (boundary_before && after < tag.size() && tag[after] == '=') {
            ++after;
            while (after < tag.size() && isspace(static_cast<unsigned char>(tag[after]))) {
                ++after;
            }
            if (after < tag.size() && (tag[after] == '"' || tag[after] == '\'')) {
                const char quote = tag[after];
                const size_t start = after + 1;
                const size_t end = tag.find(quote, start);
                if (end == string::npos) return {};
                return decode_entities(tag.substr(start, end - start));
            }
        }
        search = pos + name.size();
    }
}

void walk(const string& markup, const function<void(const Event&)>& on_event) {
    size_t i = 0;
    while (i < markup.size()) {
        const size_t lt = markup.find('<', i);

        if (lt == string::npos) {
            if (i < markup.size()) {
                Event text_event;
                text_event.is_text = true;
                text_event.text = decode_entities(markup.substr(i));
                on_event(text_event);
            }
            return;
        }

        if (lt > i) {
            Event text_event;
            text_event.is_text = true;
            text_event.text = decode_entities(markup.substr(i, lt - i));
            on_event(text_event);
        }

        // Comments, CDATA and declarations carry no markup we care about.
        if (markup.compare(lt, 4, "<!--") == 0) {
            const size_t end = markup.find("-->", lt);
            i = end == string::npos ? markup.size() : end + 3;
            continue;
        }
        if (markup.compare(lt, 9, "<![CDATA[") == 0) {
            const size_t end = markup.find("]]>", lt);
            const size_t start = lt + 9;
            Event text_event;
            text_event.is_text = true;
            text_event.text = markup.substr(
                start, (end == string::npos ? markup.size() : end) - start);
            on_event(text_event);
            i = end == string::npos ? markup.size() : end + 3;
            continue;
        }

        const size_t gt = markup.find('>', lt);
        if (gt == string::npos) return;

        Event event;
        event.tag = markup.substr(lt, gt - lt + 1);
        event.closing = gt > lt + 1 && markup[lt + 1] == '/';
        event.self_closing = gt > lt + 1 && markup[gt - 1] == '/';

        size_t n = lt + 1;
        if (event.closing || markup[n] == '?' || markup[n] == '!') ++n;
        while (n <= gt && !isspace(static_cast<unsigned char>(markup[n])) &&
               markup[n] != '>' && markup[n] != '/') {
            event.name += markup[n++];
        }

        on_event(event);
        i = gt + 1;
    }
}

string strip_markup(const string& markup) {
    string out;
    bool skipping = false;   // inside <script> or <style>

    walk(markup, [&](const Event& event) {
        if (event.is_text) {
            if (!skipping) out += event.text;
            return;
        }

        string lowered;
        for (char c : event.name) {
            lowered += static_cast<char>(tolower(static_cast<unsigned char>(c)));
        }

        // Script, style and document metadata are markup, not readable text.
        if (lowered == "script" || lowered == "style" || lowered == "head" ||
            lowered == "title") {
            skipping = !event.closing;
            return;
        }
        if (skipping) return;

        const bool breaks_line =
            lowered == "br" || lowered == "p" || lowered == "div" ||
            lowered == "tr" || lowered == "li" || lowered == "h1" ||
            lowered == "h2" || lowered == "h3" || lowered == "h4" ||
            lowered == "h5" || lowered == "h6" || lowered == "blockquote" ||
            lowered == "section" || lowered == "article";

        if (breaks_line) out += '\n';
        else if (lowered == "td" || lowered == "th") out += '\t';
    });

    // Collapse the blank-line runs that tag stripping leaves behind.
    istringstream stream(out);
    string line, result;
    int blank_run = 0;
    bool seen_content = false;
    while (getline(stream, line)) {
        while (!line.empty() &&
               isspace(static_cast<unsigned char>(line.back()))) {
            line.pop_back();
        }
        if (line.empty()) {
            if (!seen_content) continue;   // nothing rendered yet
            if (++blank_run > 1) continue;
        } else {
            blank_run = 0;
            seen_content = true;
        }
        result += line;
        result += '\n';
    }
    return result;
}

} // namespace convertor::xml_text
