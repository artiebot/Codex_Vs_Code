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
  bool candidate_=false;
  unsigned long candidate_deadline_=0;
  unsigned long candidate_start_ms_=0;
  float candidate_baseline_=0.0f;
  bool visit_active_=false;
  unsigned long visit_start_ms_=0;
  unsigned long last_active_ms_=0;
  float visit_baseline_=0.0f;
  float peak_weight_=0.0f;
};
extern VisitService visit;
} // namespace SF