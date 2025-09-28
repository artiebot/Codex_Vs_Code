#pragma once
#include <cstddef>
#include <cstdint>
#include <string>

namespace SF {
namespace Log {

enum class Level : uint8_t {
  kInfo = 0,
  kWarn = 1,
  kError = 2,
  kBoot = 3,
  kCrash = 4,
};

// Initialize the logging ring buffer and capture boot markers.
void init();

// Provide the device identifier used when publishing dumps.
void setDeviceId(const char* deviceId);

// Append log entries with printf-style formatting.
void info(const char* tag, const char* fmt, ...);
void warn(const char* tag, const char* fmt, ...);
void error(const char* tag, const char* fmt, ...);
void record(Level level, const char* tag, const char* message);

// Capture boot/crash markers (crash detail optional).
void bootMarker();
void crashMarker(const char* detail);

// Clear ring buffer.
void clear();

// Number of entries currently buffered.
size_t size();

// Render buffered entries as JSON (NDJSON friendly single payload).
std::string dumpJson();

#ifdef SF_LOG_ENABLE_TEST_API
void initForTest(const char* deviceId);
void bootMarkerTest(const char* reason);
#endif

} // namespace Log
} // namespace SF
