#include <convertor/logging.hpp>
#include <algorithm>
#include <iostream>

using namespace std;

namespace convertor {

const char* log_level_name(LogLevel level) {
    switch (level) {
        case LogLevel::kTrace: return "TRACE";
        case LogLevel::kDebug: return "DEBUG";
        case LogLevel::kInfo:  return "INFO";
        case LogLevel::kWarn:  return "WARN";
        case LogLevel::kError: return "ERROR";
        case LogLevel::kFatal: return "FATAL";
    }
    return "UNKNOWN";
}

Logger& Logger::instance() {
    static Logger s_instance;
    return s_instance;
}

void Logger::set_level(LogLevel level) { level_ = level; }
LogLevel Logger::level() const { return level_; }

void Logger::add_sink(shared_ptr<LogSink> sink) {
    sinks_.push_back(move(sink));
}

void Logger::remove_sink(LogSink* sink) {
    sinks_.erase(
        remove_if(sinks_.begin(), sinks_.end(),
                  [sink](const auto& ptr) { return ptr.get() == sink; }),
        sinks_.end());
}

void Logger::log(LogLevel level, const string& message) {
    if (level < level_) return;
    for (auto& sink : sinks_) {
        sink->write(level, message);
    }
}

void Logger::trace(const string& m) { log(LogLevel::kTrace, m); }
void Logger::debug(const string& m) { log(LogLevel::kDebug, m); }
void Logger::info(const string& m)  { log(LogLevel::kInfo, m); }
void Logger::warn(const string& m)  { log(LogLevel::kWarn, m); }
void Logger::error(const string& m) { log(LogLevel::kError, m); }
void Logger::fatal(const string& m) { log(LogLevel::kFatal, m); }

void StdoutLogSink::write(LogLevel level, const string& message) {
    cout << "[" << log_level_name(level) << "] " << message << "\n";
}

} // namespace convertor

#ifdef __ANDROID__
#include <android/log.h>

namespace convertor {

void AndroidLogSink::write(LogLevel level, const string& message) {
    int priority = ANDROID_LOG_INFO;
    switch (level) {
        case LogLevel::kTrace:
        case LogLevel::kDebug: priority = ANDROID_LOG_DEBUG; break;
        case LogLevel::kInfo:  priority = ANDROID_LOG_INFO;  break;
        case LogLevel::kWarn:  priority = ANDROID_LOG_WARN;  break;
        case LogLevel::kError: priority = ANDROID_LOG_ERROR; break;
        case LogLevel::kFatal: priority = ANDROID_LOG_FATAL; break;
    }
    __android_log_print(priority, "ConvertorEngine", "%s", message.c_str());
}

} // namespace convertor
#endif
