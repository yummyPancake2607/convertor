#include <convertor/engine_c_api.h>
#include <convertor/engine.hpp>
#include <convertor/format_catalog.hpp>

#include "handle_table.hpp"

#include <exception>
#include <string>
#include <thread>

using namespace convertor;

extern "C" {

convertor_handle convertor_engine_create() {
    try {
        auto* engine = new Engine();
        engine->initialize();
        return ffi::HandleTable::instance().insert(engine);
    } catch (...) {
        return 0;
    }
}

void convertor_engine_destroy(convertor_handle handle) {
    try {
        auto* engine = static_cast<Engine*>(ffi::HandleTable::instance().get(handle));
        if (engine) {
            engine->shutdown();
            delete engine;
        }
        ffi::HandleTable::instance().erase(handle);
    } catch (...) {}
}

convertor_handle convertor_probe(convertor_handle engine_handle,
                                 const char* file_path) {
    try {
        auto* engine = static_cast<Engine*>(ffi::HandleTable::instance().get(engine_handle));
        if (!engine) return 0;
        Error err;
        auto info = engine->probe(file_path, err);
        if (!err.ok()) return 0;
        auto* info_ptr = new MediaInfo(move(info));
        return ffi::HandleTable::instance().insert(info_ptr);
    } catch (...) {
        return 0;
    }
}

static MediaInfo* get_probe(convertor_handle probe) {
    return static_cast<MediaInfo*>(ffi::HandleTable::instance().get(probe));
}

int32_t convertor_probe_has_video(convertor_handle probe) {
    auto* info = get_probe(probe);
    return info && info->has_video() ? 1 : 0;
}

int32_t convertor_probe_has_audio(convertor_handle probe) {
    auto* info = get_probe(probe);
    return info && info->has_audio() ? 1 : 0;
}

int64_t convertor_probe_duration_us(convertor_handle probe) {
    auto* info = get_probe(probe);
    return info ? info->duration_us : 0;
}

int32_t convertor_probe_width(convertor_handle probe) {
    auto* info = get_probe(probe);
    if (!info) return 0;
    auto* vs = info->video_stream();
    return vs ? vs->width : 0;
}

int32_t convertor_probe_height(convertor_handle probe) {
    auto* info = get_probe(probe);
    if (!info) return 0;
    auto* vs = info->video_stream();
    return vs ? vs->height : 0;
}

double convertor_probe_frame_rate(convertor_handle probe) {
    auto* info = get_probe(probe);
    if (!info) return 0;
    auto* vs = info->video_stream();
    return vs ? vs->frame_rate : 0;
}

int32_t convertor_probe_sample_rate(convertor_handle probe) {
    auto* info = get_probe(probe);
    if (!info) return 0;
    auto* as = info->audio_stream();
    return as ? as->sample_rate : 0;
}

int32_t convertor_probe_channels(convertor_handle probe) {
    auto* info = get_probe(probe);
    if (!info) return 0;
    auto* as = info->audio_stream();
    return as ? as->channels : 0;
}

const char* convertor_probe_video_codec(convertor_handle probe) {
    auto* info = get_probe(probe);
    if (!info) return "";
    auto* vs = info->video_stream();
    return vs ? vs->codec_name.c_str() : "";
}

const char* convertor_probe_audio_codec(convertor_handle probe) {
    auto* info = get_probe(probe);
    if (!info) return "";
    auto* as = info->audio_stream();
    return as ? as->codec_name.c_str() : "";
}

const char* convertor_probe_format_name(convertor_handle probe) {
    auto* info = get_probe(probe);
    return info ? info->format_name.c_str() : "";
}

const char* convertor_probe_media_type(convertor_handle probe) {
    auto* info = get_probe(probe);
    if (!info) return "unknown";
    return media_type_name(info->media_type);
}

void convertor_probe_dispose(convertor_handle probe) {
    try {
        auto* info = get_probe(probe);
        delete info;
        ffi::HandleTable::instance().erase(probe);
    } catch (...) {}
}

convertor_handle convertor_convert(convertor_handle engine_handle,
                                   const char* input_path,
                                   const char* output_path) {
    try {
        auto* engine = static_cast<Engine*>(ffi::HandleTable::instance().get(engine_handle));
        if (!engine) return 0;
        ConversionRequest req(input_path, output_path);
        JobId id = engine->convert(move(req));
        return id;
    } catch (...) {
        return 0;
    }
}

int32_t convertor_job_status(convertor_handle engine_handle,
                             convertor_handle job_handle) {
    try {
        auto* engine = static_cast<Engine*>(ffi::HandleTable::instance().get(engine_handle));
        if (!engine) return -1;
        auto job = engine->get_job(job_handle);
        if (!job) return -1;
        return static_cast<int32_t>(job->status());
    } catch (...) {
        return -1;
    }
}

float convertor_job_progress(convertor_handle engine_handle,
                             convertor_handle job_handle) {
    try {
        auto* engine = static_cast<Engine*>(ffi::HandleTable::instance().get(engine_handle));
        if (!engine) return 0;
        auto job = engine->get_job(job_handle);
        return job ? job->progress() : 0;
    } catch (...) {
        return 0;
    }
}

const char* convertor_job_stage(convertor_handle engine_handle,
                                convertor_handle job_handle) {
    try {
        auto* engine = static_cast<Engine*>(ffi::HandleTable::instance().get(engine_handle));
        if (!engine) return "";
        auto job = engine->get_job(job_handle);
        if (!job) return "";
        static thread_local string cached_stage;
        cached_stage = job->stage();
        return cached_stage.c_str();
    } catch (...) {
        return "";
    }
}

const char* convertor_job_error(convertor_handle engine_handle,
                                convertor_handle job_handle) {
    try {
        auto* engine = static_cast<Engine*>(ffi::HandleTable::instance().get(engine_handle));
        if (!engine) return "";
        auto job = engine->get_job(job_handle);
        if (!job || job->error().ok()) return "";
        static thread_local string cached_error;
        cached_error = job->error().to_string();
        return cached_error.c_str();
    } catch (...) {
        return "";
    }
}

void convertor_job_cancel(convertor_handle engine_handle,
                          convertor_handle job_handle) {
    try {
        auto* engine = static_cast<Engine*>(ffi::HandleTable::instance().get(engine_handle));
        if (engine) engine->cancel_job(job_handle);
    } catch (...) {}
}

const char* convertor_supported_outputs(convertor_handle engine_handle,
                                        const char* format_id) {
    try {
        auto outputs = FormatCatalog::instance().outputs_for_id(format_id);
        static thread_local string result;
        result.clear();
        for (size_t i = 0; i < outputs.size(); i++) {
            if (i > 0) result += ",";
            result += outputs[i];
        }
        return result.c_str();
    } catch (...) {
        return "";
    }
}

const char* convertor_engine_version() {
    return "1.0.0";
}

const char* convertor_error_message(convertor_error_code code) {
    switch (static_cast<ErrorCode>(code)) {
        case ErrorCode::kOk: return "OK";
        case ErrorCode::kFileNotFound: return "File not found";
        case ErrorCode::kUnsupportedFormat: return "Unsupported format";
        case ErrorCode::kFFmpegError: return "FFmpeg error";
        default: return "Unknown error";
    }
}

void convertor_string_free(char* str) {
    delete[] str;
}

} // extern "C"
