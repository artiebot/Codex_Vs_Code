#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\power_manager.h"
#pragma once
#include <Arduino.h>
#include "ina260_hal.h"
namespace SF {
enum class PowerState: uint8_t { NORMAL=0, WARN=1, CRIT=2 };
class PowerManager{
public:
  void begin();
  void loop();
  float packV() const { return last_.bus_v; }
  float cellV() const { return last_cell_v_; }
  float amps()  const { return last_.current; }
  float watts() const { return last_.power; }
  bool  valid() const { return last_.ok; }
  PowerState state() const { return state_; }
  uint8_t brightnessLimit() const { return brightness_limit_; }
private:
  unsigned long last_poll_=0;
  PowerSample last_{0,0,0,false};
  float last_cell_v_=0.0f;
  PowerState state_=PowerState::NORMAL;
  uint8_t brightness_limit_=128;
};
extern PowerManager power;
} // namespace SF
