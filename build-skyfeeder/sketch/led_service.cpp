#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\led_service.cpp"
#include "led_service.h"
namespace SF {
LedService led;
void LedService::begin(uint8_t pin){ pin_=pin; pinMode(pin_,OUTPUT); digitalWrite(pin_,LOW); state_=false; }
void LedService::set(bool on){ if(pin_==255) return; state_=on; digitalWrite(pin_, on?HIGH:LOW); }
} // namespace SF
