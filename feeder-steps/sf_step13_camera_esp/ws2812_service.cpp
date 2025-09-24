#include "ws2812_service.h"
#include <Adafruit_NeoPixel.h>
namespace {
Adafruit_NeoPixel* strip=nullptr;
const unsigned long FRAME_MIN_MS=30;
uint8_t ramp(uint8_t from,uint8_t to,unsigned long progress,unsigned long span){ if(span==0) return to; long diff=(long)to - (long)from; long val=(long)from + (diff * (long)progress)/ (long)span; if(val<0) val=0; if(val>255) val=255; return (uint8_t)val; }
}
namespace SF {
Ws2812Service ws2812;
void Ws2812Service::begin(uint8_t pin,uint16_t count){
  pin_=pin; count_=count;
  if(strip){ delete strip; strip=nullptr; }
  strip=new Adafruit_NeoPixel(count_,pin_,NEO_GRB+NEO_KHZ800);
  strip->begin(); strip->clear(); strip->show();
  strip->setBrightness(0);
  initialized_=true;
  current_pattern_=WsPattern::OFF;
  target_color_=0; current_color_=0;
  target_brightness_=0; current_level_=0;
  pattern_start_ms_=millis(); last_frame_ms_=0;
}
void Ws2812Service::set(bool on,uint8_t brightness){ if(!initialized_) return; if(on) setPattern(WsPattern::SOLID, strip->Color(255,255,255), brightness); else setPattern(WsPattern::OFF,0,0); }
void Ws2812Service::color(uint32_t rgb){ if(!initialized_) return; uint8_t b=(target_brightness_>0)?target_brightness_:64; setPattern(WsPattern::SOLID,rgb,b); }
void Ws2812Service::off(){ if(!initialized_) return; setPattern(WsPattern::OFF,0,0); }
void Ws2812Service::setPattern(WsPattern pattern,uint32_t color,uint8_t brightness){ if(!initialized_) return; current_pattern_=pattern; target_color_=color; target_brightness_=brightness; pattern_start_ms_=millis(); last_frame_ms_=0; current_level_=255; current_color_=0xFFFFFFFF; update(); }
void Ws2812Service::applyLevel(uint8_t level,uint32_t color){ if(!initialized_) return; if(level>255) level=255; if(level==0){ if(current_level_==0) return; strip->clear(); strip->show(); current_level_=0; current_color_=0; return; }
  if(current_level_==level && current_color_==color) return;
  strip->setBrightness(level);
  for(uint16_t i=0;i<count_;++i) strip->setPixelColor(i,color);
  strip->show();
  current_level_=level; current_color_=color;
}
void Ws2812Service::update(){ if(!initialized_) return; unsigned long now=millis(); switch(current_pattern_){
  case WsPattern::OFF: applyLevel(0,0); break;
  case WsPattern::SOLID: applyLevel(target_brightness_, target_color_); break;
  case WsPattern::HEARTBEAT:{ if(now-last_frame_ms_<FRAME_MIN_MS) return; last_frame_ms_=now; unsigned long phase=(now-pattern_start_ms_)%2000UL; uint8_t lvl=0; uint8_t maxB=target_brightness_; if(maxB==0) maxB=32;
      if(phase<150) lvl=ramp(10,maxB,phase,150);
      else if(phase<300) lvl=ramp(maxB,30,phase-150,150);
      else if(phase<450) lvl=ramp(30,maxB,phase-300,150);
      else if(phase<650) lvl=ramp(maxB,20,phase-450,200);
      else lvl=10;
      applyLevel(lvl,target_color_==0?strip->Color(255,255,255):target_color_);
    } break;
  case WsPattern::AMBER_WARN:{ if(now-last_frame_ms_<FRAME_MIN_MS) return; last_frame_ms_=now; unsigned long phase=(now-pattern_start_ms_)%2600UL; uint8_t base=8; uint8_t maxB=target_brightness_; if(maxB==0) maxB=48; uint8_t lvl=(phase<1300)?ramp(base,maxB,phase,1300):ramp(maxB,base,phase-1300,1300); applyLevel(lvl,target_color_); } break;
  case WsPattern::RED_ALERT:{ if(now-last_frame_ms_<FRAME_MIN_MS) return; last_frame_ms_=now; unsigned long phase=(now-pattern_start_ms_)%1200UL; uint8_t maxB=target_brightness_; if(maxB==0) maxB=96; uint8_t lvl; if(phase<150) lvl=ramp(0,maxB,phase,150); else if(phase<300) lvl=ramp(maxB,0,phase-150,150); else if(phase<600) lvl=0; else if(phase<750) lvl=ramp(0,maxB,phase-600,150); else if(phase<900) lvl=ramp(maxB,0,phase-750,150); else lvl=0; applyLevel(lvl,target_color_); } break;
  }
}
} // namespace SF