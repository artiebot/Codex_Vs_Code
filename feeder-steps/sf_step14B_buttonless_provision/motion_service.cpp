#include "motion_service.h"
#include "led_service.h"
namespace {
const unsigned long DEBOUNCE_MS=200;
const unsigned long COOLDOWN_MS=2000;
}
namespace SF {
MotionService motion;
void MotionService::begin(uint8_t pin){
  pin_=pin;
  pinMode(pin_, INPUT);
  last_level_=digitalRead(pin_);
  last_change_ms_=millis();
  last_trigger_ms_=0;
  pending_=false;
#if MOTION_DEBUG_BLINK
  blink_until_ms_=0;
  blink_restore_state_=false;
  blink_restore_needed_=false;
#endif
}
void MotionService::loop(){
  if(pin_==255) return;
  const unsigned long now=millis();
  int level=digitalRead(pin_);
  if(level!=last_level_){ last_level_=level; last_change_ms_=now; }
#if MOTION_DEBUG_BLINK
  if(blink_restore_needed_ && now>blink_until_ms_){ SF::led.set(blink_restore_state_); blink_restore_needed_=false; blink_until_ms_=0; }
#endif
  if(level==HIGH){
    if(now-last_change_ms_<DEBOUNCE_MS) return;
    if(now-last_trigger_ms_<COOLDOWN_MS) return;
    pending_=true;
    pending_ts_=now;
    last_trigger_ms_=now;
#if MOTION_DEBUG_BLINK
    if(!blink_restore_needed_){ blink_restore_state_=SF::led.isOn(); blink_restore_needed_=true; }
    SF::led.set(true);
    blink_until_ms_=now+120;
#endif
  }
}
bool MotionService::takeTrigger(unsigned long& ts){
  if(!pending_) return false;
  pending_=false;
  ts=pending_ts_;
  return true;
}
} // namespace SF