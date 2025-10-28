#include "visit_service.h"
#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include <math.h>
#include "motion_service.h"
#include "weight_service.h"
#include "mqtt_client.h"
#include "topics.h"
#include "config.h"
#include "command_handler.h"
namespace {
const float THRESH_G = VISIT_WEIGHT_THRESHOLD_G;
const unsigned long WINDOW_MS = VISIT_MOTION_WINDOW_MS;
const unsigned long IDLE_MS = VISIT_IDLE_TIMEOUT_MS;
const float SMALL_EVENT_MAX_DELTA_G = PIR_EVENT_MAX_WEIGHT_DELTA_G;
const unsigned long SMALL_EVENT_EVAL_DELAY_MS = PIR_EVENT_EVAL_DELAY_MS;
const unsigned long SMALL_EVENT_COOLDOWN_MS = PIR_EVENT_COOLDOWN_MS;
const uint8_t SMALL_EVENT_SNAPSHOT_COUNT = PIR_EVENT_SNAPSHOT_COUNT;
const uint16_t SMALL_EVENT_VIDEO_SECONDS = PIR_EVENT_VIDEO_SECONDS;
}
namespace SF {
VisitService visit;
void VisitService::begin(){
  candidate_=false;
  visit_active_=false;
  small_event_candidate_=false;
  last_small_event_ms_=0;
}
void VisitService::loop(){
  unsigned long now=millis();
  unsigned long trig_ts=0;
  if(SF::motion.takeTrigger(trig_ts)){
    if(visit_active_) last_active_ms_=now;
    if(!SF::weight.valid()) {
      candidate_=false;
      small_event_candidate_=false;
    } else {
      candidate_=true;
      candidate_deadline_=trig_ts+WINDOW_MS;
      candidate_start_ms_=trig_ts;
      candidate_baseline_=SF::weight.weightG();
      small_event_candidate_=true;
      small_event_baseline_=candidate_baseline_;
      small_event_eval_ms_=trig_ts+SMALL_EVENT_EVAL_DELAY_MS;
    }
  }
  if(!SF::weight.valid()){
    small_event_candidate_=false;
    return;
  }
  float current=SF::weight.weightG();
  evaluateSmallMotion(now, current);
  if(candidate_){
    if(now>candidate_deadline_) candidate_=false;
    else if((current-candidate_baseline_)>=THRESH_G){ startVisit(candidate_baseline_, candidate_start_ms_); candidate_=false; }
  }
  if(!visit_active_) return;
  if(current>peak_weight_) peak_weight_=current;
  float delta=current-visit_baseline_;
  if(delta<0) delta=0;
  if(delta>=THRESH_G) last_active_ms_=now;
  if(now-last_active_ms_>=IDLE_MS) finishVisit(now);
}
void VisitService::evaluateSmallMotion(unsigned long now, float currentWeight){
  if(!small_event_candidate_) return;
  if(now<small_event_eval_ms_) return;
  small_event_candidate_=false;
  float delta=fabsf(currentWeight-small_event_baseline_);
  if(delta>=SMALL_EVENT_MAX_DELTA_G){
    Serial.print("[visit] PIR ignored, weight delta=");
    Serial.println(delta);
    return;
  }
  if(now-last_small_event_ms_<SMALL_EVENT_COOLDOWN_MS){
    Serial.println("[visit] PIR capture suppressed (cooldown)");
    return;
  }
  Serial.print("[visit] PIR capture delta=");
  Serial.println(delta);
  const char* trigger = "pir";
  if(SF_captureEvent(SMALL_EVENT_SNAPSHOT_COUNT, SMALL_EVENT_VIDEO_SECONDS, trigger)){
    last_small_event_ms_=now;
  } else {
    Serial.println("[visit] PIR capture failed to schedule");
  }
}
void VisitService::startVisit(float baseline,unsigned long start_ms){
  SF_armForMotion();
  visit_active_=true;
  visit_baseline_=baseline;
  visit_start_ms_=start_ms;
  last_active_ms_=millis();
  peak_weight_=SF::weight.weightG();
  float delta = peak_weight_-visit_baseline_;
  if(delta<0) delta=0;
  SF_visitStart(delta);
}
void VisitService::finishVisit(unsigned long now){
  visit_active_=false;
  float peak=peak_weight_-visit_baseline_;
  if(peak<0) peak=0;
  SF_visitEnd(now-visit_start_ms_, peak);
  if(!SF::mqtt.connected()) return;
  StaticJsonDocument<192> doc;
  doc["start_ts"]=visit_start_ms_;
  doc["duration_ms"]=now-visit_start_ms_;
  doc["peak_weight_g"]=peak;
  char buf[192]; size_t n=serializeJson(doc,buf,sizeof(buf)); (void)n;
  SF::mqtt.raw().publish(SF::Topics::eventVisit(), buf, false);
}
} // namespace SF
