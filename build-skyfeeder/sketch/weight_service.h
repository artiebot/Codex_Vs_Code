#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\weight_service.h"
#pragma once
#include <Arduino.h>
namespace SF {
class WeightService{
public:
  void begin();
  void loop();
  bool tare();
  bool calibrateKnownMass(float known_mass_g);
  float weightG() const { return filtered_weight_g_; }
  bool valid() const { return sensor_ok_; }
  float calFactor() const { return cal_factor_; }
  long tareOffset() const { return tare_offset_; }
  long lastMedianRaw() const { return last_median_; }
private:
  void loadCalibration();
  void persistTare();
  void persistCal();
  void pushSample(long raw);
  long currentMedian() const;
  float toGrams(long raw) const;
  long window_[5]={0,0,0,0,0};
  uint8_t window_size_=0;
  uint8_t window_pos_=0;
  long last_median_=0;
  float filtered_weight_g_=0.0f;
  float ema_=0.0f;
  bool ema_init_=false;
  long tare_offset_=0;
  float cal_factor_=0.001f;
  unsigned long last_sample_ms_=0;
  bool sensor_ok_=false;
};
extern WeightService weight;
} // namespace SF
