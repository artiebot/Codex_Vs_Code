#pragma once
#include <Arduino.h>
#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include "ws2812_service.h"
namespace SF {
struct BurstConfig;
enum class PowerState : uint8_t;
class LedUx{
public:
  enum class Mode {
    AUTO,
    PROVISIONING,
    CONNECTING_WIFI,
    ONLINE
  };

  void begin();
  void loop();
  bool overrideActive() const { return override_active_; }
  bool applyCommand(JsonVariantConst cmd, const char*& appliedName, char* err, size_t errLen);
  const char* activePatternName() const { return active_name_; }
  void setMode(Mode mode);
  Mode mode() const { return mode_; }
  void setFault(bool faultActive);
  bool fault() const { return fault_active_; }
private:
  enum class PriorityState : uint8_t {
    Off,
    DevOk,
    Connecting,
    Provisioning,
    BatteryLow,
    BatteryCritical,
    Fault
  };
  struct BurstState {
    bool burstActive = false;
    uint8_t pulsesRemaining = 0;
    unsigned long nextPulseMs = 0;
    unsigned long nextBurstMs = 0;
  };
  bool overrideActive(unsigned long now);
  void applyDesired(WsPattern pattern, uint32_t color, uint8_t brightness);
  bool parsePatternName(const char* name, WsPattern& outPattern, uint32_t& outColor, uint8_t& outBrightness) const;
  uint32_t parseColor(JsonVariantConst value, bool& ok) const;
  uint8_t clampBrightness(int value) const;
  void activateOverride(WsPattern pattern, uint32_t color, uint8_t brightness, unsigned long hold_ms);
  const char* patternToName(WsPattern pattern) const;
  static uint32_t rgb(uint8_t r, uint8_t g, uint8_t b);
  void resetBurst(BurstState& state);
  void resetAllBurstsExcept(PriorityState active);
  bool runBurst(BurstState& state, const struct BurstConfig& cfg, unsigned long now);
  PriorityState resolvePriority(PowerState powerState) const;
  bool isHealthyOnline(PowerState powerState) const;
  WsPattern last_pattern_=WsPattern::OFF;
  uint32_t last_color_=0;
  uint8_t last_brightness_=0;
  bool override_active_=false;
  unsigned long override_until_ms_=0;
  WsPattern override_pattern_=WsPattern::SOLID;
  uint32_t override_color_=0;
  uint8_t override_brightness_=0;
  char active_name_[16];
  Mode mode_ = Mode::AUTO;
  bool fault_active_ = false;
  BurstState faultBurst_;
  BurstState batteryLowBurst_;
  BurstState batteryCriticalBurst_;
  BurstState devOkBurst_;
};
extern LedUx ledUx;
} // namespace SF
