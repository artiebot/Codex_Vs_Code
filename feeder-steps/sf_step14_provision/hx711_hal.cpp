#include "hx711_hal.h"
#include <HX711.h>
static HX711 hx;
static bool initialized=false;
void hx711_begin(uint8_t dout_pin, uint8_t sck_pin){
  hx.begin(dout_pin, sck_pin);
  hx.set_gain(128);
  hx.power_up();
  initialized=true;
}
bool hx711_ready(){ return initialized && hx.is_ready(); }
bool hx711_read(long& raw){ if(!initialized||!hx.is_ready()) return false; raw=hx.read(); return true; }
void hx711_sleep(){ if(!initialized) return; hx.power_down(); }