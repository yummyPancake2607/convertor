#pragma once

#include <string>
#include <convertor/error.hpp>

namespace convertor::ffmpeg {

Error ffmpeg_error(int av_error);
Error ffmpeg_open_error(const std::string& path);
Error ffmpeg_decode_error();
Error ffmpeg_encode_error();
Error ffmpeg_mux_error();

} // namespace convertor::ffmpeg
