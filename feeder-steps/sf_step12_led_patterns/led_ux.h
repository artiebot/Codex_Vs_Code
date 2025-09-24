#pragma once
#include <Arduino.h>
#include <ArduinoJson.h>
#include "ws2812_service.h"
namespace SF {
class LedUx{
public:
  void begin();
  void loop();
  bool applyCommand(JsonVariantConst cmd, const char*& appliedName, char* err, size_t errLen);
  const char* activePatternName() const { return active_name_; }
private:
  bool overrideActive(unsigned long now);
  void applyDesired(WsPattern pattern, uint32_t color, uint8_t brightness);
  bool parsePatternName(const char* name, WsPattern& outPattern, uint32_t& outColor, uint8_t& outBrightness) const;
  uint32_t parseColor(JsonVariantConst value, bool& ok) const;
  uint8_t clampBrightness(int value) const;
  void activateOverride(WsPattern pattern, uint32_t color, uint8_t brightness, unsigned long hold_ms);
  const char* patternToName(WsPattern pattern) const;
  static uint32_t rgb(uint8_t r, uint8_t g, uint8_t b);
  WsPattern last_pattern_=WsPattern::OFF;
  uint32_t last_color_=0;
  uint8_t last_brightness_=0;
  bool override_active_=false;
  unsigned long override_until_ms_=0;
  WsPattern override_pattern_=WsPattern::SOLID;
  uint32_t override_color_=0;
  uint8_t override_brightness_=0;
  char active_name_[16];
};
extern LedUx ledUx;
} // namespace SF