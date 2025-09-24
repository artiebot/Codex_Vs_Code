#pragma once
#include <Arduino.h>
namespace SF {
struct PowerSample { float bus_v; float current; float power; bool ok; };
bool  power_init();
bool  power_read(PowerSample& s);
void  power_begin_alert(uint8_t alertPin);
} // namespace SF
