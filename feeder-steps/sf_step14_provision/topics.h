#pragma once
#include <Arduino.h>
namespace SF { namespace Topics {
void init(const char* deviceId);
const char* device();
const char* status();
const char* ack();
const char* telemetry();
const char* cmdAny();
const char* cmdLed();
const char* cmdCalibrate();
const char* cmdCamera();
const char* eventVisit();
const char* eventCameraSnapshot();
const char* discovery();
}} // namespace SF::Topics
