#include <ArduinoJson.h>
#include <string.h>
#include "topics.h"
#include "mqtt_client.h"
#include "led_service.h"
#include "ws2812_service.h"
#include "power_manager.h"
#include "weight_service.h"
#include "led_ux.h"
#include "camera_service_esp.h"
#include "config.h"
static void publishAck(const char* cmd, bool ok, const char* msg=nullptr){
  StaticJsonDocument<160> doc; doc["cmd"]=cmd; doc["ok"]=ok; if(msg) doc["msg"]=msg;
  char buf[160]; size_t n=serializeJson(doc,buf,sizeof(buf)); (void)n;
  SF::mqtt.raw().publish(SF::Topics::ack(), buf, false);
}
static void handleLed(byte* payload,unsigned int len){
  StaticJsonDocument<256> doc; auto err=deserializeJson(doc,payload,len);
  if(err){ publishAck("led",false,"bad_json"); return; }
  const char* applied=nullptr; char errmsg[32];
  bool ok=SF::ledUx.applyCommand(doc.as<JsonVariantConst>(), applied, errmsg, sizeof(errmsg));
  StaticJsonDocument<192> ack;
  ack["cmd"]="led";
  ack["ok"]=ok;
  if(ok){ ack["pattern"]=applied?applied:SF::ledUx.activePatternName(); ack["brightness"]=SF::ws2812.brightness(); }
  else{ ack["msg"]=errmsg[0]?errmsg:"apply_failed"; }
  char buf[192]; size_t n=serializeJson(ack,buf,sizeof(buf)); (void)n;
  SF::mqtt.raw().publish(SF::Topics::ack(), buf, false);
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
static void handleCamera(byte* payload,unsigned int len){
  StaticJsonDocument<192> doc; auto err=deserializeJson(doc,payload,len);
  if(err){ publishAck("camera",false,"bad_json"); return; }
  char errmsg[32];
  bool ok=SF::cameraEsp.handleCommand(doc.as<JsonVariantConst>(), errmsg, sizeof(errmsg));
  StaticJsonDocument<160> ack;
  ack["cmd"]="camera";
  ack["ok"]=ok;
  ack["status"]=SF::cameraEsp.status();
  if(!ok) ack["msg"]=errmsg[0]?errmsg:"camera_fail";
  char buf[160]; size_t n=serializeJson(ack,buf,sizeof(buf)); (void)n;
  SF::mqtt.raw().publish(SF::Topics::ack(), buf, false);
}
void SF_registerCommandSubscriptions(PubSubClient& client){ client.subscribe(SF::Topics::cmdLed(),1); client.subscribe(SF::Topics::cmdCalibrate(),1); client.subscribe(SF::Topics::cmdCamera(),1); }
void SF_onMqttMessage(char* topic, byte* payload, unsigned int len){
  if(strcmp(topic,SF::Topics::cmdLed())==0) handleLed(payload,len);
  else if(strcmp(topic,SF::Topics::cmdCalibrate())==0) handleCalibrate(payload,len);
  else if(strcmp(topic,SF::Topics::cmdCamera())==0) handleCamera(payload,len);
}
