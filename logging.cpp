#include "logging.h"

#include <array>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <string>
#include <algorithm>

#ifdef ARDUINO
#include <Arduino.h>
#include <esp_system.h>
#include "freertos/FreeRTOS.h"
#include "freertos/portmacro.h"
#else
#include <chrono>
#include <mutex>
#endif

#include "topics.h"

#ifndef LOG_RING_CAPACITY
#define LOG_RING_CAPACITY 64
#endif

#ifndef LOG_ENTRY_MAX_LEN
#define LOG_ENTRY_MAX_LEN 96
#endif

namespace SF {
namespace Log {
namespace {
struct Entry {
  uint32_t ts_ms{0};
  Level level{Level::kInfo};
  char tag[16] = {0};
  char message[LOG_ENTRY_MAX_LEN] = {0};
};

static std::array<Entry, LOG_RING_CAPACITY> ring{};
static size_t head = 0;  // points to next write position
static size_t used = 0;  // number of valid entries
static bool initialised = false;
static std::string deviceId = "sf-unknown";

#ifdef ARDUINO
static portMUX_TYPE logMux = portMUX_INITIALIZER_UNLOCKED;
struct CriticalGuard {
  CriticalGuard() { taskENTER_CRITICAL(&logMux); }
  ~CriticalGuard() { taskEXIT_CRITICAL(&logMux); }
};
#else
static std::mutex logMutex;
struct CriticalGuard {
  CriticalGuard() { logMutex.lock(); }
  ~CriticalGuard() { logMutex.unlock(); }
};
static uint64_t startTickMs() {
  using namespace std::chrono;
  static const auto start = steady_clock::now();
  return duration_cast<milliseconds>(steady_clock::now() - start).count();
}
#endif

uint32_t timestampMs() {
#ifdef ARDUINO
  return millis();
#else
  return static_cast<uint32_t>(startTickMs());
#endif
}

const char* levelToString(Level level) {
  switch (level) {
    case Level::kInfo: return "info";
    case Level::kWarn: return "warn";
    case Level::kError: return "error";
    case Level::kBoot: return "boot";
    case Level::kCrash: return "crash";
    default: return "info";
  }
}

std::string escape(const char* text) {
  if (!text) return "";
  std::string out;
  out.reserve(std::strlen(text) + 8);
  for (const char* p = text; *p; ++p) {
    char c = *p;
    switch (c) {
      case '\\': out += "\\\\"; break;
      case '"': out += "\\\""; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (static_cast<unsigned char>(c) < 0x20) {
          char buf[7];
          std::snprintf(buf, sizeof(buf), "\\u%04x", static_cast<unsigned char>(c));
          out += buf;
        } else {
          out += c;
        }
        break;
    }
  }
  return out;
}

void append(Level level, const char* tag, const char* message) {
  CriticalGuard guard;
  Entry& e = ring[head];
  e.ts_ms = timestampMs();
  e.level = level;
  if (tag && tag[0]) {
    std::strncpy(e.tag, tag, sizeof(e.tag) - 1);
    e.tag[sizeof(e.tag) - 1] = '\0';
  } else {
    std::strcpy(e.tag, "log");
  }
  if (message && message[0]) {
    std::strncpy(e.message, message, sizeof(e.message) - 1);
    e.message[sizeof(e.message) - 1] = '\0';
  } else {
    e.message[0] = '\0';
  }
  head = (head + 1) % LOG_RING_CAPACITY;
  if (used < LOG_RING_CAPACITY) {
    ++used;
  }
}

std::string fmtMessage(const char* fmt, va_list args) {
  if (!fmt) return "";
  char buffer[LOG_ENTRY_MAX_LEN];
  vsnprintf(buffer, sizeof(buffer), fmt, args);
  return buffer;
}

#ifdef ARDUINO
const char* resetReasonString(esp_reset_reason_t reason) {
  switch (reason) {
    case ESP_RST_POWERON: return "power_on";
    case ESP_RST_EXT: return "ext";
    case ESP_RST_SW: return "sw";
    case ESP_RST_PANIC: return "panic";
    case ESP_RST_INT_WDT: return "int_wdt";
    case ESP_RST_TASK_WDT: return "task_wdt";
    case ESP_RST_BROWNOUT: return "brownout";
    case ESP_RST_SDIO: return "sdio";
    case ESP_RST_DEEPSLEEP: return "deep_sleep";
    case ESP_RST_WDT: return "wdt";
    default: return "unknown";
  }
}
#endif

} // namespace

void init() {
  if (initialised) {
    return;
  }
  {
    CriticalGuard guard;
    head = 0;
    used = 0;
  }
  bootMarker();
  initialised = true;
}

void setDeviceId(const char* id) {
  if (!id || !id[0]) {
    return;
  }
  deviceId = id;
}

void record(Level level, const char* tag, const char* message) {
  append(level, tag, message);
}

template <typename Formatter>
void recordFormatted(Level level, const char* tag, const char* fmt, Formatter formatter) {
  std::string msg = formatter(fmt);
  append(level, tag, msg.c_str());
}

void info(const char* tag, const char* fmt, ...) {
  va_list args;
  va_start(args, fmt);
  std::string msg = fmtMessage(fmt, args);
  va_end(args);
  record(Level::kInfo, tag, msg.c_str());
}

void warn(const char* tag, const char* fmt, ...) {
  va_list args;
  va_start(args, fmt);
  std::string msg = fmtMessage(fmt, args);
  va_end(args);
  record(Level::kWarn, tag, msg.c_str());
}

void error(const char* tag, const char* fmt, ...) {
  va_list args;
  va_start(args, fmt);
  std::string msg = fmtMessage(fmt, args);
  va_end(args);
  record(Level::kError, tag, msg.c_str());
}

void bootMarker() {
#ifdef ARDUINO
  esp_reset_reason_t reason = esp_reset_reason();
  const char* reasonStr = resetReasonString(reason);
  char buf[80];
  std::snprintf(buf, sizeof(buf), "boot_reason=%s(%d)", reasonStr, static_cast<int>(reason));
  record(Level::kBoot, "boot", buf);
#else
  record(Level::kBoot, "boot", "boot_reason=test");
#endif
}

void crashMarker(const char* detail) {
  if (detail && detail[0]) {
    record(Level::kCrash, "crash", detail);
  } else {
    record(Level::kCrash, "crash", "detail=unknown");
  }
}

void clear() {
  CriticalGuard guard;
  head = 0;
  used = 0;
}

size_t size() {
  CriticalGuard guard;
  return used;
}

std::string dumpJson() {
  CriticalGuard guard;
  std::string out;
  out.reserve(256 + used * 96);
  out += "{\"device\":\"";
  out += escape(deviceId.c_str());
  out += "\",\"count\":";
  out += std::to_string(used);
  out += ",\"entries\":[";
  for (size_t i = 0; i < used; ++i) {
    if (i > 0) out += ",";
    size_t idx = (head + LOG_RING_CAPACITY - used + i) % LOG_RING_CAPACITY;
    const Entry& e = ring[idx];
    out += "{\"ts_ms\":";
    out += std::to_string(e.ts_ms);
    out += ",\"level\":\"";
    out += levelToString(e.level);
    out += "\",\"tag\":\"";
    out += escape(e.tag);
    out += "\",\"msg\":\"";
    out += escape(e.message);
    out += "\"}";
  }
  out += "]}";
  return out;
}

#ifdef SF_LOG_ENABLE_TEST_API
void initForTest(const char* id) {
  initialised = false;
  setDeviceId(id ? id : "sf-test");
  clear();
}

void bootMarkerTest(const char* reason) {
  std::string msg = "boot_reason=";
  msg += reason ? reason : "test";
  record(Level::kBoot, "boot", msg.c_str());
}
#endif

} // namespace Log
} // namespace SF
