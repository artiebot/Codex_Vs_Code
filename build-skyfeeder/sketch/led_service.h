#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\led_service.h"
#pragma once
#include <Arduino.h>
namespace SF {
class LedService{ public: void begin(uint8_t pin); void set(bool on); bool isOn() const {return state_;}
private: uint8_t pin_=255; bool state_=false; };
extern LedService led;
} // namespace SF
