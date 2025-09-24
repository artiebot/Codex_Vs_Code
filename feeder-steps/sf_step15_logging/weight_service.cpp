#include "weight_service.h"
#include "hx711_hal.h"
#include "storage_nvs.h"
#include "config.h"
#include <math.h>
namespace {
const unsigned long SAMPLE_INTERVAL_MS=50;
const float EMA_ALPHA=0.18f;
const char* NS="weight";
const char* KEY_TARE="tare";
const char* KEY_CAL="cal";
}
namespace SF {
WeightService weight;
void WeightService::begin(){
  Storage::begin();
  hx711_begin(HX711_DOUT_PIN, HX711_SCK_PIN);
  loadCalibration();
  ema_init_=false; sensor_ok_=false; window_size_=0; window_pos_=0;
}
void WeightService::pushSample(long raw){
  window_[window_pos_]=raw;
  if(window_size_<5) ++window_size_;
  window_pos_=(window_pos_+1)%5;
}
long WeightService::currentMedian() const{
  if(window_size_==0) return last_median_;
  long tmp[5];
  for(uint8_t i=0;i<window_size_;++i) tmp[i]=window_[i];
  for(uint8_t i=1;i<window_size_;++i){ long v=tmp[i]; int j=i-1; while(j>=0 && tmp[j]>v){ tmp[j+1]=tmp[j]; --j; } tmp[j+1]=v; }
  return tmp[window_size_/2];
}
float WeightService::toGrams(long raw) const{
  float delta=float(raw - tare_offset_);
  if(fabsf(cal_factor_)<1e-6f) return 0.0f;
  return delta*cal_factor_;
}
void WeightService::loop(){
  if(!hx711_ready()) return;
  const unsigned long now=millis();
  if(now-last_sample_ms_<SAMPLE_INTERVAL_MS) return;
  last_sample_ms_=now;
  long raw=0;
  if(!hx711_read(raw)) { sensor_ok_=false; return; }
  sensor_ok_=true;
  pushSample(raw);
  long median=currentMedian();
  last_median_=median;
  float grams=toGrams(median);
  if(!ema_init_) { ema_=grams; ema_init_=true; }
  else { ema_ += EMA_ALPHA*(grams-ema_); }
  if(!isfinite(ema_)) ema_=0.0f;
  filtered_weight_g_=ema_;
}
void WeightService::loadCalibration(){
  int32_t storedTare=0;
  if(Storage::getInt32(NS, KEY_TARE, storedTare)) tare_offset_=storedTare;
  float storedCal=0.0f;
  if(Storage::getFloat(NS, KEY_CAL, storedCal) && fabsf(storedCal)>1e-6f) cal_factor_=storedCal;
}
void WeightService::persistTare(){ Storage::setInt32(NS, KEY_TARE, (int32_t)tare_offset_); }
void WeightService::persistCal(){ Storage::setFloat(NS, KEY_CAL, cal_factor_); }
bool WeightService::tare(){ if(window_size_==0) return false; tare_offset_=last_median_; persistTare(); return true; }
bool WeightService::calibrateKnownMass(float known_mass_g){ if(known_mass_g<=0.0f) return false; long delta=last_median_-tare_offset_; if(delta==0) return false; float factor=known_mass_g/float(delta); if(!isfinite(factor) || fabsf(factor)<1e-7f) return false; cal_factor_=factor; persistCal(); return true; }
} // namespace SF