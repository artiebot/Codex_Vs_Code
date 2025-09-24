#include "ina260_hal.h"
#include <Wire.h>
#include <Adafruit_INA260.h>
#include "config.h"
namespace SF {
static Adafruit_INA260 ina;
static bool inited=false;
static bool ina_try_begin(uint8_t addr){
  return ina.begin(addr);
}
bool power_init(){
  Wire.begin(I2C_SDA,I2C_SCL);
  Wire.setClock(400000);
  delay(5);
  const uint8_t candidates[]={0x40,0x41,0x44,0x45};
  for(uint8_t a: candidates){ if(ina_try_begin(a)){ inited=true; return true; } }
  inited=false; return false;
}
bool power_read(PowerSample& s){
  if(!inited){ power_init(); if(!inited){ s={0,0,0,false}; return false; } }
  float v=ina.readBusVoltage()/1000.0f;
  float i=ina.readCurrent()/1000.0f;
  float p=ina.readPower()/1000.0f;
  if(!(v>0.01f)){ s={0,0,0,false}; return false; }
  s.bus_v=v; s.current=i; s.power=p; s.ok=true; return true;
}
void power_begin_alert(uint8_t alertPin){ pinMode(alertPin, INPUT_PULLUP); }
} // namespace SF

