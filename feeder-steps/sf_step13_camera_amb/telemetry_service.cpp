#include "telemetry_service.h"
#include <ArduinoJson.h>
#include "mqtt_client.h"
#include "topics.h"
#include "power_manager.h"
#include "weight_service.h"
#include "led_ux.h"
#include "ws2812_service.h"
#include "amb_service.h"
namespace SF {
Telemetry telemetry;
void Telemetry::begin(unsigned long period_ms){ period_=period_ms; last_=0; }
void Telemetry::loop(){
  const unsigned long now=millis(); if(now-last_<period_) return; last_=now;
  if(!SF::mqtt.connected()) return;
  StaticJsonDocument<384> d;
  if (SF::power.valid()) {
    d["power"]["pack_v"]=SF::power.packV();
    d["power"]["cell_v"]=SF::power.cellV();
    d["power"]["amps"]=SF::power.amps();
    d["power"]["watts"]=SF::power.watts();
    d["power"]["state"]=(int)SF::power.state();
    d["power"]["bmax"]=SF::power.brightnessLimit();
  } else {
    d["power"]["ok"]=false;
  }
  if(SF::weight.valid()){
    d["weight_g"]=SF::weight.weightG();
    d["weight"]["raw"]=SF::weight.lastMedianRaw();
    d["weight"]["cal"]=SF::weight.calFactor();
  } else {
    d["weight"]["ok"]=false;
  }
  d["led"]["pattern"]=SF::ledUx.activePatternName();
  d["led"]["brightness"]=SF::ws2812.brightness();
  d["camera"]["status"]=SF::amb.status();
  float cv=SF::power.cellV();
  if(cv>0.1f){ int soc=(int)((cv-3.2f)*(100.0f/(4.1f-3.2f))); if(soc<0) soc=0; if(soc>100) soc=100; d["battery"]=soc; } else { d["battery"]=0; }
  char buf[416]; size_t n=serializeJson(d,buf,sizeof(buf)); (void)n;
  SF::mqtt.raw().publish(TOPIC_TELEMETRY, buf, false);
}
} // namespace SF