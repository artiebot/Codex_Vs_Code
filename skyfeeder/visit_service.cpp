#include "visit_service.h"
#include <ArduinoJson.h>
#include "motion_service.h"
#include "weight_service.h"
#include "mqtt_client.h"
#include "topics.h"
#include "config.h"
namespace {
const float THRESH_G = VISIT_WEIGHT_THRESHOLD_G;
const unsigned long WINDOW_MS = VISIT_MOTION_WINDOW_MS;
const unsigned long IDLE_MS = VISIT_IDLE_TIMEOUT_MS;
}
namespace SF {
VisitService visit;
void VisitService::begin(){ candidate_=false; visit_active_=false; }
void VisitService::loop(){
  unsigned long now=millis();
  unsigned long trig_ts=0;
  if(SF::motion.takeTrigger(trig_ts)){
    if(visit_active_) last_active_ms_=now;
    if(!SF::weight.valid()) { candidate_=false; }
    else {
      candidate_=true;
      candidate_deadline_=trig_ts+WINDOW_MS;
      candidate_start_ms_=trig_ts;
      candidate_baseline_=SF::weight.weightG();
    }
  }
  if(!SF::weight.valid()) return;
  float current=SF::weight.weightG();
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
void VisitService::startVisit(float baseline,unsigned long start_ms){
  visit_active_=true;
  visit_baseline_=baseline;
  visit_start_ms_=start_ms;
  last_active_ms_=millis();
  peak_weight_=SF::weight.weightG();
}
void VisitService::finishVisit(unsigned long now){
  visit_active_=false;
  float peak=peak_weight_-visit_baseline_;
  if(peak<0) peak=0;
  if(!SF::mqtt.connected()) return;
  StaticJsonDocument<192> doc;
  doc["start_ts"]=visit_start_ms_;
  doc["duration_ms"]=now-visit_start_ms_;
  doc["peak_weight_g"]=peak;
  char buf[192]; size_t n=serializeJson(doc,buf,sizeof(buf)); (void)n;
  SF::mqtt.raw().publish(SF::Topics::eventVisit(), buf, false);
}
} // namespace SF
