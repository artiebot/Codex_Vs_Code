#pragma once
#include <Arduino.h>

namespace MdnsAdvert {
void begin(const char* deviceId);
void setOnline(bool online);
void loop();
}
