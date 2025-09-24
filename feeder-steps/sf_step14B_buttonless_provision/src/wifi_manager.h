#pragma once
#include <Arduino.h>

namespace WifiManager {
enum class Mode { WIFI, AP };

void begin();
void loop();
bool connected();
bool apMode();
}
