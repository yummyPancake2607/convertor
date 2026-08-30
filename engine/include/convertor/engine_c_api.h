#pragma once

#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

typedef int64_t convertor_error_code;
typedef uint64_t convertor_handle;

convertor_handle convertor_engine_create();
void convertor_engine_destroy(convertor_handle handle);

convertor_handle convertor_probe(convertor_handle engine,
                                 const char* file_path);

int32_t convertor_probe_has_video(convertor_handle probe);
int32_t convertor_probe_has_audio(convertor_handle probe);
int64_t convertor_probe_duration_us(convertor_handle probe);
int32_t convertor_probe_width(convertor_handle probe);
int32_t convertor_probe_height(convertor_handle probe);
double convertor_probe_frame_rate(convertor_handle probe);
int32_t convertor_probe_sample_rate(convertor_handle probe);
int32_t convertor_probe_channels(convertor_handle probe);
const char* convertor_probe_video_codec(convertor_handle probe);
const char* convertor_probe_audio_codec(convertor_handle probe);
const char* convertor_probe_format_name(convertor_handle probe);
const char* convertor_probe_media_type(convertor_handle probe);
void convertor_probe_dispose(convertor_handle probe);

convertor_handle convertor_convert(convertor_handle engine,
                                   const char* input_path,
                                   const char* output_path);

int32_t convertor_job_status(convertor_handle engine,
                             convertor_handle job);
float convertor_job_progress(convertor_handle engine,
                             convertor_handle job);
const char* convertor_job_stage(convertor_handle engine,
                                convertor_handle job);
const char* convertor_job_error(convertor_handle engine,
                                convertor_handle job);
void convertor_job_cancel(convertor_handle engine,
                          convertor_handle job);

const char* convertor_supported_outputs(convertor_handle engine,
                                        const char* format_id);

const char* convertor_engine_version();

const char* convertor_error_message(convertor_error_code code);
void convertor_string_free(char* str);

#ifdef __cplusplus
}
#endif
