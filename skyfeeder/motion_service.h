#pragma once
#include <Arduino.h>
#include "config.h"
namespace SF {
class MotionService{
public:
  void begin(uint8_t pin);
  void loop();
  bool takeTrigger(unsigned long& ts);
  bool sensorHigh() const { return last_level_==HIGH; }
private:
  uint8_t pin_=255;
  int last_level_=LOW;
  unsigned long last_change_ms_=0;
  unsigned long last_trigger_ms_=0;
  bool pending_=false;
  unsigned long pending_ts_=0;
#if MOTION_DEBUG_BLINK
  unsigned long blink_until_ms_=0;
  bool blink_restore_state_=false;
  bool blink_restore_needed_=false;
#endif
};
extern MotionService motion;
} // namespace SF
