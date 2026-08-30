cmake_minimum_required(VERSION 3.20)
project(convertor_engine LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_compile_definitions(__STDC_CONSTANT_MACROS)

# Dependencies.
#
# On the desktop these come from the system through pkg-config. On Android
# there is no system copy of any of them, so they are cross-compiled into
# android/prefix/<abi> and linked statically into one shared library - see
# android/scripts/. CONVERTOR_DEPS_PREFIX points at that tree.
if(ANDROID)
    if(NOT CONVERTOR_DEPS_PREFIX)
        message(FATAL_ERROR "Android builds need -DCONVERTOR_DEPS_PREFIX=<prefix/abi>")
    endif()

    set(DEPS ${CONVERTOR_DEPS_PREFIX})
    set(CONVERTOR_DEP_INCLUDES
        ${DEPS}/include
        ${DEPS}/include/poppler
        ${DEPS}/include/poppler/cpp
        ${DEPS}/include/freetype2
    )

    # Link order matters for static archives: dependents come before what
    # they depend on.
    set(CONVERTOR_DEP_LIBS
        ${DEPS}/lib/libpoppler-cpp.a
        ${DEPS}/lib/libpoppler.a
        ${DEPS}/lib/libfreetype.a
        ${DEPS}/lib/libiconv.a
        ${DEPS}/lib/libcharset.a
        ${DEPS}/lib/libzip.a
        ${DEPS}/lib/libavfilter.a
        ${DEPS}/lib/libavformat.a
        ${DEPS}/lib/libavcodec.a
        ${DEPS}/lib/libswresample.a
        ${DEPS}/lib/libswscale.a
        ${DEPS}/lib/libavutil.a
        ${DEPS}/lib/libx264.a
        ${DEPS}/lib/libmp3lame.a
        ${DEPS}/lib/libvpx.a
        ${DEPS}/lib/libwebp.a
        ${DEPS}/lib/libsharpyuv.a
        ${DEPS}/lib/libvorbisenc.a
        ${DEPS}/lib/libvorbis.a
        ${DEPS}/lib/libogg.a
        ${DEPS}/lib/libopus.a
        z m dl log
    )
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(AVFORMAT REQUIRED libavformat)
    pkg_check_modules(AVCODEC REQUIRED libavcodec)
    pkg_check_modules(AVUTIL REQUIRED libavutil)
    pkg_check_modules(SWRESAMPLE REQUIRED libswresample)
    pkg_check_modules(SWSCALE REQUIRED libswscale)
    pkg_check_modules(AVFILTER REQUIRED libavfilter)

    # Document backends: poppler-cpp reads PDF, libzip reads OOXML (docx/xlsx)
    pkg_check_modules(POPPLER REQUIRED poppler-cpp)
    pkg_check_modules(LIBZIP REQUIRED libzip)

    set(CONVERTOR_DEP_INCLUDES ${POPPLER_INCLUDE_DIRS} ${LIBZIP_INCLUDE_DIRS})
    set(CONVERTOR_DEP_LIBS
        ${POPPLER_LIBRARIES}
        ${LIBZIP_LIBRARIES}
        ${AVFORMAT_LIBRARIES}
        ${AVCODEC_LIBRARIES}
        ${AVUTIL_LIBRARIES}
        ${SWRESAMPLE_LIBRARIES}
        ${SWSCALE_LIBRARIES}
        ${AVFILTER_LIBRARIES}
    )
endif()

# Core sources
set(CORE_SOURCES
    src/core/error.cpp
    src/core/version.cpp
    src/core/media_type.cpp
    src/core/file_format.cpp
    src/core/format_catalog.cpp
    src/core/logging.cpp
    src/core/media_info.cpp
    src/core/conversion_result.cpp
    src/core/conversion_request.cpp
)

# FS sources
set(FS_SOURCES
    src/fs/path_utils.cpp
    src/fs/file_system.cpp
    src/fs/temp_file.cpp
)

# FFmpeg sources
set(FFMPEG_SOURCES
    src/ffmpeg/ffmpeg_error.cpp
    src/ffmpeg/ffmpeg_log.cpp
    src/ffmpeg/format_context.cpp
    src/ffmpeg/codec_context.cpp
    src/ffmpeg/frame.cpp
    src/ffmpeg/packet.cpp
    src/ffmpeg/resampler.cpp
    src/ffmpeg/rescaler.cpp
    src/ffmpeg/filter_graph.cpp
)

# Document/Converter sources
set(DOC_SOURCES
    src/document/remuxer.cpp
    src/document/video_converter.cpp
    src/document/audio_converter.cpp
    src/document/audio_transcoder.cpp
    src/document/audio_extractor.cpp
    src/document/image_converter.cpp
    src/document/document_converter.cpp
    src/document/converter_registry.cpp
    src/document/pdf_document.cpp
    src/document/text_document.cpp
    src/document/text_layout.cpp
    src/document/pdf_writer.cpp
    src/document/zip_reader.cpp
    src/document/zip_writer.cpp
    src/document/xml_text.cpp
    src/document/document_readers.cpp
    src/document/document_writers.cpp
    src/document/ooxml_reader.cpp
    src/document/format_detector.cpp
    src/document/media_prober.cpp
)

# Job sources
set(JOB_SOURCES
    src/jobs/cancellation_token.cpp
    src/jobs/progress_reporter.cpp
    src/jobs/job.cpp
    src/jobs/job_queue.cpp
    src/jobs/worker_pool.cpp
    src/jobs/job_manager.cpp
)

# FFI sources
set(FFI_SOURCES
    src/ffi/handle_table.cpp
    src/ffi/c_string.cpp
    src/ffi/engine_c_api.cpp
)

# Engine library
add_library(convertor_engine STATIC
    ${CORE_SOURCES}
    ${FS_SOURCES}
    ${FFMPEG_SOURCES}
    ${DOC_SOURCES}
    ${JOB_SOURCES}
    ${FFI_SOURCES}
    src/engine.cpp
)

target_include_directories(convertor_engine
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/core
        ${CMAKE_CURRENT_SOURCE_DIR}/src/ffmpeg
        ${CMAKE_CURRENT_SOURCE_DIR}/src/fs
        ${CMAKE_CURRENT_SOURCE_DIR}/src/document
        ${CMAKE_CURRENT_SOURCE_DIR}/src/jobs
        ${CMAKE_CURRENT_SOURCE_DIR}/src/ffi
)

target_include_directories(convertor_engine PRIVATE ${CONVERTOR_DEP_INCLUDES})

target_link_libraries(convertor_engine PUBLIC ${CONVERTOR_DEP_LIBS})

if(NOT ANDROID)
    target_link_directories(convertor_engine
        PUBLIC
            ${POPPLER_LIBRARY_DIRS}
            ${LIBZIP_LIBRARY_DIRS}
            ${AVFORMAT_LIBRARY_DIRS}
            ${AVCODEC_LIBRARY_DIRS}
            ${AVUTIL_LIBRARY_DIRS}
            ${SWRESAMPLE_LIBRARY_DIRS}
            ${SWSCALE_LIBRARY_DIRS}
            ${AVFILTER_LIBRARY_DIRS}
    )
endif()

# Shared library for FFI
add_library(convertor_shared SHARED
    ${CORE_SOURCES}
    ${FS_SOURCES}
    ${FFMPEG_SOURCES}
    ${DOC_SOURCES}
    ${JOB_SOURCES}
    ${FFI_SOURCES}
    src/engine.cpp
)

target_include_directories(convertor_shared
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/core
        ${CMAKE_CURRENT_SOURCE_DIR}/src/ffmpeg
        ${CMAKE_CURRENT_SOURCE_DIR}/src/fs
        ${CMAKE_CURRENT_SOURCE_DIR}/src/document
        ${CMAKE_CURRENT_SOURCE_DIR}/src/jobs
        ${CMAKE_CURRENT_SOURCE_DIR}/src/ffi
)

target_include_directories(convertor_shared PRIVATE ${CONVERTOR_DEP_INCLUDES})

target_link_libraries(convertor_shared PUBLIC ${CONVERTOR_DEP_LIBS})

if(NOT ANDROID)
    target_link_directories(convertor_shared
        PUBLIC
            ${POPPLER_LIBRARY_DIRS}
            ${LIBZIP_LIBRARY_DIRS}
            ${AVFORMAT_LIBRARY_DIRS}
            ${AVCODEC_LIBRARY_DIRS}
            ${AVUTIL_LIBRARY_DIRS}
            ${SWRESAMPLE_LIBRARY_DIRS}
            ${SWSCALE_LIBRARY_DIRS}
            ${AVFILTER_LIBRARY_DIRS}
    )
endif()

set_target_properties(convertor_shared PROPERTIES
    OUTPUT_NAME convertor
    VERSION 1.0.0
    SOVERSION 1
)

if(ANDROID)
    # Everything is folded into this one library, so nothing from the bundled
    # static archives needs to be exported. Making those symbols local also
    # lets the linker resolve FFmpeg's assembly references directly: while they
    # stay globally visible they count as preemptible, and the PC-relative
    # relocations its NEON/x86 code emits are rejected outright.
    target_link_options(convertor_shared PRIVATE
        "-Wl,--exclude-libs,ALL"
        "-Wl,-z,max-page-size=16384"
    )
    set_target_properties(convertor_shared PROPERTIES VERSION "" SOVERSION "")
endif()

# CLI executable and tests are desktop-only; Android just needs the .so.
if(NOT ANDROID)

# CLI executable
add_executable(convertor_cli
    tools/cli_main.cpp
    tools/cmd_convert.cpp
    tools/cmd_probe.cpp
    tools/cmd_formats.cpp
)

target_include_directories(convertor_cli
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${CMAKE_CURRENT_SOURCE_DIR}/tools
)

target_link_libraries(convertor_cli PRIVATE convertor_engine)

# Tests
enable_testing()
add_executable(convertor_tests
    tests/test_main.cpp
    tests/test_error.cpp
    tests/test_format_catalog.cpp
    tests/test_path_utils.cpp
    tests/test_media_type.cpp
    tests/test_settings.cpp
)

target_include_directories(convertor_tests
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/tests
)

target_link_libraries(convertor_tests PRIVATE convertor_engine)

add_test(NAME convertor_tests COMMAND convertor_tests)

endif()
