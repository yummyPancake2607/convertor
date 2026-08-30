#pragma once

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>

using namespace std;

namespace convertor {

enum class LogLevel : uint32_t {
    kTrace = 0,
    kDebug,
    kInfo,
    kWarn,
    kError,
    kFatal,
};

const char* log_level_name(LogLevel level);

class LogSink {
public:
    virtual ~LogSink() = default;
    virtual void write(LogLevel level, const string& message) = 0;
};

class Logger {
public:
    static Logger& instance();

    void set_level(LogLevel level);
    LogLevel level() const;

    void add_sink(shared_ptr<LogSink> sink);
    void remove_sink(LogSink* sink);

    void log(LogLevel level, const string& message);
    void trace(const string& message);
    void debug(const string& message);
    void info(const string& message);
    void warn(const string& message);
    void error(const string& message);
    void fatal(const string& message);

private:
    Logger() = default;
    LogLevel level_ = LogLevel::kInfo;
    vector<shared_ptr<LogSink>> sinks_;
};

class StdoutLogSink : public LogSink {
public:
    void write(LogLevel level, const string& message) override;
};

#ifdef __ANDROID__
/// Writes to logcat, where stdout from a native library does not appear.
/// Filter the app's output with `adb logcat -s ConvertorEngine`.
class AndroidLogSink : public LogSink {
public:
    void write(LogLevel level, const string& message) override;
};
#endif

} // namespace convertor
