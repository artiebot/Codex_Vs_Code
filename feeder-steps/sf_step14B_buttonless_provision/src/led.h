#pragma once
#include <Arduino.h>

namespace Led {
enum class State : uint8_t { PROVISIONING, CONNECTING_WIFI, ONLINE };

void begin(uint8_t pin);
void setState(State s);
void loop();
}
