#pragma once
#include <Arduino.h>
namespace SF {
class Telemetry{ public: void begin(unsigned long period_ms=2000); void loop();
private: unsigned long period_=2000; unsigned long last_=0; };
extern Telemetry telemetry;
} // namespace SF
