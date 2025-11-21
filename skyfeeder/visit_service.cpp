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
const float SMALL_EVENT_MIN_WEIGHT_G = PIR_EVENT_MIN_WEIGHT_G;
const unsigned long SMALL_EVENT_EVAL_DELAY_MS = PIR_EVENT_EVAL_DELAY_MS;
const unsigned long SMALL_EVENT_COOLDOWN_MS = PIR_EVENT_COOLDOWN_MS;
const uint8_t SMALL_EVENT_SNAPSHOT_COUNT = PIR_EVENT_SNAPSHOT_COUNT;
const uint16_t SMALL_EVENT_VIDEO_SECONDS = PIR_EVENT_VIDEO_SECONDS;
const unsigned long CAPTURE_PHOTO_INTERVAL_MS = 15000UL;
const unsigned long CAPTURE_MAX_DURATION_MS = 150000UL;
const unsigned long CAPTURE_VIDEO_DELAY_MS = 5000UL;
const float CAPTURE_DEPARTURE_RATIO = 0.5f;
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
  bool weightValid = SF::weight.valid();
  if(!weightValid){
    small_event_candidate_=false;
    if(capture_session_active_){
      updateCaptureSession(now, capture_baseline_g_, false);
    }
    return;
  }
  float current=SF::weight.weightG();
  evaluateSmallMotion(now, current);
  if(capture_session_active_){
    updateCaptureSession(now, current, true);
  }
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
  if(delta<SMALL_EVENT_MIN_WEIGHT_G){
    Serial.print("[visit] PIR ignored, weight delta=");
    Serial.print(delta);
    Serial.println("g (too light)");
    return;
  }
  if(now-last_small_event_ms_<SMALL_EVENT_COOLDOWN_MS){
    Serial.println("[visit] PIR capture suppressed (cooldown)");
    return;
  }
  Serial.print("[visit] PIR capture triggered, weight delta=");
  Serial.print(delta);
  Serial.println("g");
  if(capture_session_active_){
    Serial.println("[visit] PIR capture ignored (session already active)");
    return;
  }
  capture_session_active_ = true;
  capture_baseline_g_ = small_event_baseline_;
  bird_weight_g_ = delta;
  capture_start_ms_ = now;
  last_photo_ms_ = now;
  photo_count_ = 1;
  const char* trigger = "pir";
  if(SF_captureStart(trigger, bird_weight_g_)){
    last_small_event_ms_=now;
    Serial.printf("[visit] capture session started (%.1fg)\n", bird_weight_g_);
  } else {
    Serial.println("[visit] capture_start failed");
    capture_session_active_ = false;
  }
}
void VisitService::updateCaptureSession(unsigned long now, float currentWeight, bool weightValid){
  if(!capture_session_active_) return;
  const bool pirLow = !SF::motion.sensorHigh();
  float remaining = currentWeight - capture_baseline_g_;
  if(remaining < 0.0f) remaining = 0.0f;
  bool shouldStop = false;
  bool departure = false;
  if(weightValid && bird_weight_g_ > 0.0f){
    departure = pirLow && (remaining < (bird_weight_g_ * CAPTURE_DEPARTURE_RATIO));
  } else if(!weightValid){
    departure = false;
  } else {
    departure = pirLow;
  }
  const bool maxPhotos = photo_count_ >= SMALL_EVENT_SNAPSHOT_COUNT;
  const bool timedOut = now - capture_start_ms_ >= CAPTURE_MAX_DURATION_MS;
  if(departure){
    Serial.println("[visit] capture: bird departure detected");
    shouldStop = true;
  }
  if(!shouldStop && !maxPhotos){
    if(now - last_photo_ms_ >= CAPTURE_PHOTO_INTERVAL_MS){
      uint8_t nextIndex = photo_count_ + 1;
      if(nextIndex > SMALL_EVENT_SNAPSHOT_COUNT){
        shouldStop = true;
      } else if(SF_capturePhoto(nextIndex)){
        photo_count_ = nextIndex;
        last_photo_ms_ = now;
        Serial.printf("[visit] capture: photo %u requested\n", nextIndex);
      } else {
        Serial.println("[visit] capture_photo failed; stopping session");
        shouldStop = true;
      }
    }
  }
  if(!shouldStop && (timedOut || maxPhotos)){
    Serial.println("[visit] capture: max duration or photo limit reached");
    shouldStop = true;
  }
  if(shouldStop){
    SF_captureStop(photo_count_);
    capture_session_active_ = false;
    bird_weight_g_ = 0.0f;
    Serial.println("[visit] capture session stopped");
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
