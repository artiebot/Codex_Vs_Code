#pragma once
#include <Arduino.h>

namespace Topics {
void init(const char* deviceId);
const char* device();
const char* status();
const char* discovery();
const char* telemetry();
const char* eventsRoot();
const char* eventVisit();
const char* eventSnapshot();
const char* cmdRoot();
const char* cmdLed();
const char* cmdCalibrate();
const char* cmdCamera();
const char* ota();
}
