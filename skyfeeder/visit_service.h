#pragma once
#include <Arduino.h>
namespace SF {
class VisitService{
public:
  void begin();
  void loop();
private:
  void startVisit(float baseline, unsigned long start_ms);
  void finishVisit(unsigned long now);
  void evaluateSmallMotion(unsigned long now, float currentWeight);
  bool candidate_=false;
  unsigned long candidate_deadline_=0;
  unsigned long candidate_start_ms_=0;
  float candidate_baseline_=0.0f;
  bool visit_active_=false;
  unsigned long visit_start_ms_=0;
  unsigned long last_active_ms_=0;
  float visit_baseline_=0.0f;
  float peak_weight_=0.0f;
  bool small_event_candidate_=false;
  float small_event_baseline_=0.0f;
  unsigned long small_event_eval_ms_=0;
  unsigned long last_small_event_ms_=0;
};
extern VisitService visit;
} // namespace SF
