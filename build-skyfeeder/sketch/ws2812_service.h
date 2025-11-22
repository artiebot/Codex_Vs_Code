#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\ws2812_service.h"
#pragma once
#include <Arduino.h>
namespace SF {
enum class WsPattern: uint8_t { OFF=0, SOLID, HEARTBEAT, AMBER_WARN, RED_ALERT };
class Ws2812Service{
public:
  void begin(uint8_t pin, uint16_t count);
  void set(bool on, uint8_t brightness=64);
  void color(uint32_t rgb);
  void off();
  void setPattern(WsPattern pattern, uint32_t color, uint8_t brightness);
  void update();
  bool isInitialized() const {return initialized_;}
  bool isOn() const {return current_pattern_!=WsPattern::OFF;}
  uint8_t brightness() const {return target_brightness_;}
  WsPattern pattern() const {return current_pattern_;}
private:
  void applyLevel(uint8_t level, uint32_t color);
  uint8_t pin_=255;
  uint16_t count_=0;
  bool initialized_=false;
  WsPattern current_pattern_=WsPattern::OFF;
  uint32_t target_color_=0;
  uint32_t current_color_=0;
  uint8_t target_brightness_=0;
  uint8_t current_level_=0;
  unsigned long pattern_start_ms_=0;
  unsigned long last_frame_ms_=0;
};
extern Ws2812Service ws2812;
} // namespace SF
