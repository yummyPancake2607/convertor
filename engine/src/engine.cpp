#include <convertor/engine.hpp>
#include <convertor/format_catalog.hpp>
#include <convertor/logging.hpp>

#include "../jobs/job_manager.hpp"
#include "../document/converter_registry.hpp"
#include "../document/media_prober.hpp"
#include "../document/remuxer.hpp"
#include "../document/video_converter.hpp"
#include "../document/audio_converter.hpp"
#include "../document/audio_extractor.hpp"
#include "../document/image_converter.hpp"
#include "../document/document_converter.hpp"

using namespace std;

namespace convertor {

Engine::Engine() = default;
Engine::~Engine() { shutdown(); }

void Engine::initialize() {
    if (initialized_) return;

#ifdef __ANDROID__
    // Native stdout is discarded on Android; logcat is where it can be read.
    Logger::instance().add_sink(make_shared<AndroidLogSink>());
#else
    Logger::instance().add_sink(make_shared<StdoutLogSink>());
#endif
    Logger::instance().info("Engine initializing...");

    FormatCatalog::instance().load_defaults();

    // Order matters: the first converter that accepts a request wins, so the
    // narrow, specific handlers are registered ahead of the general ones.
    auto& registry = ConverterRegistry::instance();
    registry.register_converter(make_unique<DocumentConverter>());
    registry.register_converter(make_unique<ImageConverter>());
    registry.register_converter(make_unique<AudioExtractor>());
    registry.register_converter(make_unique<AudioConverter>());
    registry.register_converter(make_unique<Remuxer>());
    registry.register_converter(make_unique<VideoConverter>());

    job_manager_ = make_unique<JobManager>();
    job_manager_->start();

    initialized_ = true;
    Logger::instance().info("Engine initialized");
}

void Engine::shutdown() {
    if (!initialized_) return;
    Logger::instance().info("Engine shutting down...");
    job_manager_->stop();
    job_manager_.reset();
    initialized_ = false;
}

MediaInfo Engine::probe(const string& path, Error& err) {
    return MediaProber::probe(path, err);
}

JobId Engine::convert(ConversionRequest request, JobCallback callback) {
    return job_manager_->submit(move(request), move(callback));
}

ConversionResult Engine::convert_sync(const ConversionRequest& request, Error& err) {
    MediaInfo input_info;
    Error probe_err;
    input_info = MediaProber::probe(request.input_path(), probe_err);
    if (!probe_err.ok()) { err = probe_err; return ConversionResult(); }

    auto& registry = ConverterRegistry::instance();
    auto converters = registry.find_converters(request, input_info);
    if (converters.empty()) {
        err = Error(ErrorCode::kUnsupportedFormat, "No converter found");
        return ConversionResult();
    }

    auto start = chrono::steady_clock::now();
    for (auto* converter : converters) {
        err = converter->convert(request, input_info);
        if (err.ok()) break;
    }
    auto elapsed = chrono::steady_clock::now() - start;
    double seconds = chrono::duration<double>(elapsed).count();

    if (!err.ok()) return ConversionResult();
    return ConversionResult(request.output_path(), 0, seconds);
}

bool Engine::cancel_job(JobId id) {
    return job_manager_ ? job_manager_->cancel_job(id) : false;
}

shared_ptr<Job> Engine::get_job(JobId id) const {
    return job_manager_ ? job_manager_->get_job(id) : nullptr;
}

size_t Engine::pending_jobs() const {
    return job_manager_ ? job_manager_->pending_jobs() : 0;
}

} // namespace convertor
