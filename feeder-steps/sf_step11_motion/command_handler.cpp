#include <ArduinoJson.h>
#include "topics.h"
#include "mqtt_client.h"
#include "led_service.h"
#include "ws2812_service.h"
#include "power_manager.h"
#include "weight_service.h"
#include "config.h"
static void publishAck(const char* cmd, bool ok, const char* msg=nullptr){
  StaticJsonDocument<160> doc; doc["cmd"]=cmd; doc["ok"]=ok; if(msg) doc["msg"]=msg;
  char buf[160]; size_t n=serializeJson(doc,buf,sizeof(buf)); (void)n;
  SF::mqtt.raw().publish(TOPIC_ACK, buf, false);
}
static void handleLed(byte* payload,unsigned int len){
  StaticJsonDocument<192> doc; auto err=deserializeJson(doc,payload,len);
  if(err){ publishAck("led",false,"bad_json"); return; }
  if(!doc.containsKey("on")){ publishAck("led",false,"missing_field:on"); return; }
  bool on=doc["on"].as<bool>(); int brightness=doc["brightness"]|64;
  if(brightness<0) brightness=0; if(brightness>BRIGHTNESS_MAX_SAFE) brightness=BRIGHTNESS_MAX_SAFE;
  uint8_t policyCap=SF::power.brightnessLimit(); if(brightness>policyCap) brightness=policyCap;
  if(SF::ws2812.isInitialized()) SF::ws2812.set(on,(uint8_t)brightness); else SF::led.set(on);
  publishAck("led",true);
}
static void handleCalibrate(byte* payload,unsigned int len){
  StaticJsonDocument<192> doc; auto err=deserializeJson(doc,payload,len);
  if(err){ publishAck("calibrate",false,"bad_json"); return; }
  bool doTare=doc["tare"].as<bool>();
  if(doTare){ bool ok=SF::weight.tare(); publishAck("calibrate",ok, ok?nullptr:"tare_wait"); return; }
  if(doc.containsKey("known_mass_g")){
    float mass=doc["known_mass_g"].as<float>();
    if(mass<=0){ publishAck("calibrate",false,"mass_le_zero"); return; }
    bool ok=SF::weight.calibrateKnownMass(mass);
    publishAck("calibrate",ok, ok?nullptr:"cal_failed");
    return;
  }
  publishAck("calibrate",false,"missing_args");
}
void SF_registerCommandSubscriptions(PubSubClient& client){ client.subscribe(TOPIC_CMD_LED,1); client.subscribe(TOPIC_CMD_CALIBRATE,1); }
void SF_onMqttMessage(char* topic, byte* payload, unsigned int len){
  if(strcmp(topic,TOPIC_CMD_LED)==0) handleLed(payload,len);
  else if(strcmp(topic,TOPIC_CMD_CALIBRATE)==0) handleCalibrate(payload,len);
}