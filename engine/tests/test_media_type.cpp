#include <convertor/media_type.hpp>
#include <cassert>
#include <iostream>

using namespace convertor;
using namespace std;

void test_media_type() {
    assert(media_type_from_extension("mp4") == MediaType::kVideo);
    assert(media_type_from_extension("mkv") == MediaType::kVideo);
    assert(media_type_from_extension("mp3") == MediaType::kAudio);
    assert(media_type_from_extension("wav") == MediaType::kAudio);
    assert(media_type_from_extension("jpg") == MediaType::kImage);
    assert(media_type_from_extension("png") == MediaType::kImage);
    assert(media_type_from_extension("pdf") == MediaType::kDocument);
    assert(media_type_from_extension("txt") == MediaType::kDocument);
    assert(media_type_from_extension("xyz") == MediaType::kUnknown);

    assert(media_type_from_mime("video/mp4") == MediaType::kVideo);
    assert(media_type_from_mime("audio/mpeg") == MediaType::kAudio);
    assert(media_type_from_mime("image/png") == MediaType::kImage);
}
