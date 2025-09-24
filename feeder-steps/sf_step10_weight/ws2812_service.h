#pragma once
#include <Arduino.h>
namespace SF {
class Ws2812Service{
public:
  void begin(uint8_t pin, uint16_t count);
  void set(bool on, uint8_t brightness=64);
  void color(uint32_t rgb);
  void off();
  bool isOn() const {return on_;}
  uint8_t brightness() const {return brightness_;}
  bool isInitialized() const {return initialized_;}
private:
  uint8_t pin_=255; uint16_t count_=0; bool on_=false; uint8_t brightness_=64; bool initialized_=false;
};
extern Ws2812Service ws2812;
} // namespace SF
