#include "ws2812_service.h"
#include <Adafruit_NeoPixel.h>
namespace SF {
static Adafruit_NeoPixel* strip=nullptr;
Ws2812Service ws2812;
void Ws2812Service::begin(uint8_t pin,uint16_t count){
  pin_=pin; count_=count; if(strip){ delete strip; strip=nullptr; }
  strip=new Adafruit_NeoPixel(count_,pin_,NEO_GRB+NEO_KHZ800);
  strip->begin(); strip->setBrightness(brightness_); strip->clear(); strip->show();
  on_=false; initialized_=true;
}
void Ws2812Service::set(bool on,uint8_t brightness){
  if(!initialized_||!strip) return; on_=on; brightness_=brightness; strip->setBrightness(brightness_);
  if(on_) { for(uint16_t i=0;i<count_;++i) strip->setPixelColor(i, strip->Color(255,255,255)); }
  else { strip->clear(); } strip->show();
}
void Ws2812Service::color(uint32_t rgb){ if(!initialized_||!strip) return; for(uint16_t i=0;i<count_;++i) strip->setPixelColor(i,rgb); strip->show(); }
void Ws2812Service::off(){ if(!initialized_||!strip) return; on_=false; strip->clear(); strip->show(); }
} // namespace SF
