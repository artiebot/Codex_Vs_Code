#include "led_ux.h"
#include <ctype.h>
#include <string.h>
#include "config.h"
#include "power_manager.h"
namespace {
uint32_t makeColor(uint8_t r,uint8_t g,uint8_t b){ return ((uint32_t)g<<16)|((uint32_t)r<<8)|((uint32_t)b); }
void writeError(char* err,size_t len,const char* msg){ if(!err||len==0) return; strncpy(err,msg,len); err[len-1]='\0'; }
}
namespace SF {
LedUx ledUx;
void LedUx::begin(){ active_name_[0]='o'; active_name_[1]='f'; active_name_[2]='f'; active_name_[3]='\0'; last_pattern_=WsPattern::OFF; last_color_=0; last_brightness_=0; override_active_=false; }
bool LedUx::overrideActive(unsigned long now){ if(!override_active_) return false; long diff=(long)(override_until_ms_-now); if(diff<=0){ override_active_=false; return false; } return true; }
uint8_t LedUx::clampBrightness(int value) const{ if(value<0) value=0; if(value>255) value=255; uint8_t limit=SF::power.brightnessLimit(); if(value>limit) value=limit; return (uint8_t)value; }
uint32_t LedUx::rgb(uint8_t r,uint8_t g,uint8_t b){ return makeColor(r,g,b); }
bool LedUx::parsePatternName(const char* name, WsPattern& outPattern, uint32_t& outColor, uint8_t& outBrightness) const{
  if(!name) return false;
  char lower[16]; size_t i=0; for(; i<sizeof(lower)-1 && name[i]; ++i) lower[i]=tolower((unsigned char)name[i]); lower[i]='\0';
  if(strcmp(lower,"off")==0){ outPattern=WsPattern::OFF; outColor=0; outBrightness=0; return true; }
  if(strcmp(lower,"solid")==0||strcmp(lower,"white")==0){ outPattern=WsPattern::SOLID; outColor=makeColor(255,255,255); outBrightness=LED_IDLE_BRIGHTNESS; return true; }
  if(strcmp(lower,"heartbeat")==0||strcmp(lower,"idle")==0){ outPattern=WsPattern::HEARTBEAT; outColor=makeColor(64,150,255); outBrightness=LED_IDLE_BRIGHTNESS; return true; }
  if(strcmp(lower,"amber")==0||strcmp(lower,"warn")==0){ outPattern=WsPattern::AMBER_WARN; outColor=makeColor(255,140,0); outBrightness=LED_WARN_BRIGHTNESS; return true; }
  if(strcmp(lower,"alert")==0||strcmp(lower,"red")==0){ outPattern=WsPattern::RED_ALERT; outColor=makeColor(255,32,0); outBrightness=LED_CRIT_BRIGHTNESS; return true; }
  return false;
}
uint32_t LedUx::parseColor(JsonVariantConst value, bool& ok) const{
  ok=false;
  if(value.is<const char*>()){
    const char* s=value.as<const char*>(); if(!s) return 0;
    if(s[0]=='#') ++s; size_t len=strlen(s); if(len!=6) return 0;
    uint32_t accum=0;
    for(size_t i=0;i<6;++i){ char c=tolower((unsigned char)s[i]); int v;
      if(c>='0'&&c<='9') v=c-'0';
      else if(c>='a'&&c<='f') v=10+(c-'a');
      else return 0;
      accum=(accum<<4)|v;
    }
    ok=true;
    uint8_t r=(accum>>16)&0xFF; uint8_t g=(accum>>8)&0xFF; uint8_t b=accum&0xFF;
    return makeColor(r,g,b);
  }
  if(value.is<uint32_t>()){
    ok=true; uint32_t raw=value.as<uint32_t>(); uint8_t r=(raw>>16)&0xFF; uint8_t g=(raw>>8)&0xFF; uint8_t b=raw&0xFF; return makeColor(r,g,b);
  }
  return 0;
}
const char* LedUx::patternToName(WsPattern pattern) const{
  switch(pattern){
    case WsPattern::OFF: return "off";
    case WsPattern::SOLID: return "solid";
    case WsPattern::HEARTBEAT: return "heartbeat";
    case WsPattern::AMBER_WARN: return "amber";
    case WsPattern::RED_ALERT: return "alert";
    default: return "unknown";
  }
}
void LedUx::applyDesired(WsPattern pattern,uint32_t color,uint8_t brightness){ brightness=clampBrightness(brightness); if(pattern==WsPattern::OFF) brightness=0; if(last_pattern_==pattern && last_color_==color && last_brightness_==brightness) return; SF::ws2812.setPattern(pattern,color,brightness); last_pattern_=pattern; last_color_=color; last_brightness_=brightness; const char* name=patternToName(pattern); strncpy(active_name_,name,sizeof(active_name_)); active_name_[sizeof(active_name_)-1]='\0'; }
void LedUx::activateOverride(WsPattern pattern,uint32_t color,uint8_t brightness,unsigned long hold_ms){ override_active_=true; override_pattern_=pattern; override_color_=color; override_brightness_=brightness; override_until_ms_=millis()+hold_ms; applyDesired(pattern,color,brightness); }
bool LedUx::applyCommand(JsonVariantConst cmd,const char*& appliedName,char* err,size_t errLen){ appliedName=nullptr; if(err&&errLen>0) err[0]='\0';
  WsPattern pattern=WsPattern::OFF; uint32_t color=0; uint8_t brightness=LED_IDLE_BRIGHTNESS; bool have=false;
  if(cmd.containsKey("pattern")){
    const char* requested=cmd["pattern"].as<const char*>(); if(!requested){ writeError(err,errLen,"pattern_not_string"); return false; }
    if(!parsePatternName(requested,pattern,color,brightness)){ writeError(err,errLen,"pattern_unknown"); return false; }
    have=true;
    if(cmd.containsKey("brightness")) brightness=clampBrightness(cmd["brightness"].as<int>());
    if(cmd.containsKey("color")) { bool ok=false; uint32_t parsed=parseColor(cmd["color"],ok); if(!ok){ writeError(err,errLen,"color_invalid"); return false; } color=parsed; }
  } else if(cmd.containsKey("on")){
    bool on=cmd["on"].as<bool>(); int req=cmd.containsKey("brightness")?cmd["brightness"].as<int>():64; brightness=clampBrightness(req); pattern=on?WsPattern::SOLID:WsPattern::OFF; color=on?makeColor(255,255,255):0; have=true;
  }
  if(!have){ writeError(err,errLen,"no_pattern"); return false; }
  unsigned long hold=cmd["hold_ms"].as<unsigned long>(); if(hold==0) hold=cmd["duration_ms"].as<unsigned long>(); if(hold==0) hold=LED_OVERRIDE_MS; activateOverride(pattern,color,brightness,hold);
  appliedName=patternToName(pattern);
  return true;
}
void LedUx::loop(){ unsigned long now=millis(); bool active=overrideActive(now); WsPattern pattern; uint32_t color; uint8_t brightness; if(active){ pattern=override_pattern_; color=override_color_; brightness=override_brightness_; }
  else {
    if(SF::power.valid()){
      switch(SF::power.state()){
        case PowerState::CRIT: pattern=WsPattern::RED_ALERT; color=makeColor(255,32,0); brightness=LED_CRIT_BRIGHTNESS; break;
        case PowerState::WARN: pattern=WsPattern::AMBER_WARN; color=makeColor(255,140,0); brightness=LED_WARN_BRIGHTNESS; break;
        default: pattern=WsPattern::HEARTBEAT; color=makeColor(64,150,255); brightness=LED_IDLE_BRIGHTNESS; break;
      }
    } else {
      pattern=WsPattern::HEARTBEAT; color=makeColor(64,150,255); brightness=LED_IDLE_BRIGHTNESS; }
  }
  applyDesired(pattern,color,brightness);
}
} // namespace SF