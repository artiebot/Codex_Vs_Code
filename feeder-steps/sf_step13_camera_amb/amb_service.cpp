#include "amb_service.h"
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <string.h>
#include "topics.h"
#include "mqtt_client.h"
#include "config.h"
namespace {
const unsigned long SNAP_TIMEOUT_MS = 10000;
const uint8_t SNAP_HTTP_MAX_RETRY = 3;
const unsigned long SNAP_HTTP_RETRY_DELAY_MS = 150;
void writeErr(char* err, size_t len, const char* msg) {
  if (!err || len == 0) return;
  strncpy(err, msg, len);
  err[len-1] = '\0';
}
}
namespace SF {
AmbService amb;
void AmbService::begin(){ setStatus("idle"); snap_pending_=false; snap_deadline_=0; }
void AmbService::loop(){ if(snap_pending_){ unsigned long now=millis(); if((long)(snap_deadline_-now)<=0){ snap_pending_=false; setStatus("snap_timeout"); } } }
bool AmbService::triggerSnapHttp(char* err,size_t errLen){
  HTTPClient http;
  String url = String(AMB_HTTP_BASE_URL) + AMB_HTTP_PATH_SNAP;
  int code = -1;
  for(uint8_t attempt=0; attempt<SNAP_HTTP_MAX_RETRY; ++attempt){
    http.begin(url);
    code = http.GET();
    http.end();
    if(code>=200 && code<300) return true;
    delay(SNAP_HTTP_RETRY_DELAY_MS);
  }
  char buf[48];
  snprintf(buf,sizeof(buf),"http_%d",code);
  writeErr(err,errLen,buf);
  return false;
}
bool AmbService::handleCommand(JsonVariantConst cmd,char* err,size_t errLen){ if(err&&errLen>0) err[0]='\0'; const char* action=nullptr;
  if(cmd.is<const char*>()) action=cmd.as<const char*>();
  else if(cmd.containsKey("action")) action=cmd["action"].as<const char*>();
  else if(cmd.containsKey("mode")) action=cmd["mode"].as<const char*>();
  else if(cmd.containsKey("snap") && cmd["snap"].as<bool>()) action="snap";
  else if(cmd.containsKey("sleep") && cmd["sleep"].as<bool>()) action="sleep";
  else if(cmd.containsKey("wake") && cmd["wake"].as<bool>()) action="wake";
  if(!action){ writeErr(err,errLen,"no_action"); return false; }
  if(strcmp(action,"snap")==0){
    if(triggerSnapHttp(err,errLen)){
      snap_pending_=true; snap_deadline_=millis()+SNAP_TIMEOUT_MS; setStatus("snap_pending"); return true;
    }
    setStatus("http_error"); snap_pending_=false; return false;
  }
  if(strcmp(action,"sleep")==0 || strcmp(action,"wake")==0 || strcmp(action,"power_on")==0){
    writeErr(err,errLen,"http_only_snap");
    return false;
  }
  writeErr(err,errLen,"action_unknown"); return false;
}
void AmbService::publishSnapshot(const char* url,const char* remote_ts){ if(!url) return; StaticJsonDocument<192> d; d["url"]=url; if(remote_ts&&remote_ts[0]) d["ts"]=remote_ts; else d["ts"]=millis(); char buf[192]; size_t n=serializeJson(d,buf,sizeof(buf)); (void)n; SF::mqtt.raw().publish(TOPIC_EVENT_CAMERA_SNAPSHOT, buf, false); }
void AmbService::onCameraEvent(const char* topic,const uint8_t* payload,unsigned int len){ if(!topic) return; if(strcmp(topic,TOPIC_CAMERA_AMB_EVENT_SNAP)==0){ StaticJsonDocument<256> doc; auto err=deserializeJson(doc,payload,len); if(err) return; const char* url=doc["url"].as<const char*>(); const char* ts=doc["ts"].as<const char*>(); publishSnapshot(url,ts); snap_pending_=false; setStatus("idle"); }
}
void AmbService::setStatus(const char* status){ if(!status) status="unknown"; strncpy(status_,status,sizeof(status_)); status_[sizeof(status_)-1]='\0'; }
} // namespace SF
