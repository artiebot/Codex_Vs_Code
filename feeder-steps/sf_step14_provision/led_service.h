#pragma once
#include <Arduino.h>
namespace SF {
class LedService{ public: void begin(uint8_t pin); void set(bool on); bool isOn() const {return state_;}
private: uint8_t pin_=255; bool state_=false; };
extern LedService led;
} // namespace SF
