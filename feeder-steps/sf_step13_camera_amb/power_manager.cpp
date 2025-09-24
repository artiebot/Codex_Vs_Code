#include "power_manager.h"
#include "config.h"
#include "led_ux.h"
#include "ws2812_service.h"
namespace {
const unsigned long SAMPLE_INTERVAL_MS = 60000; // 1 minute between packs when idle
bool ledsBusy(){
  if(!SF::ws2812.isInitialized()) return false;
  if(SF::ledUx.overrideActive()) return true;
  return SF::ws2812.pattern()==SF::WsPattern::SOLID && SF::ws2812.brightness()>32;
}
}
namespace SF {
PowerManager power;
static uint8_t clamp_brightness(uint8_t req){ return req>BRIGHTNESS_MAX_SAFE?BRIGHTNESS_MAX_SAFE:req; }
void PowerManager::begin(){
  power_begin_alert(INA260_ALERT_PIN);
  power_init();
  last_poll_=0; state_=PowerState::NORMAL;
  brightness_limit_=clamp_brightness(BRIGHTNESS_MAX_SAFE);
}
void PowerManager::loop(){
  const unsigned long now=millis();
  if(now-last_poll_<SAMPLE_INTERVAL_MS) return;
  if(ledsBusy()) return;
  if(!power_read(last_)){ return; }
  last_poll_=now;
  last_cell_v_ = (CELL_COUNT>0)? (last_.bus_v/float(CELL_COUNT)) : last_.bus_v;
  if (last_cell_v_<CELL_CRIT_V){ state_=PowerState::CRIT; brightness_limit_=BRIGHTNESS_CRIT_LIMIT; }
  else if (last_cell_v_<CELL_WARN_V){ state_=PowerState::WARN; brightness_limit_=BRIGHTNESS_WARN_LIMIT; }
  else { state_=PowerState::NORMAL; brightness_limit_=BRIGHTNESS_MAX_SAFE; }
  brightness_limit_=clamp_brightness(brightness_limit_);
}
} // namespace SF
