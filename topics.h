#pragma once
#include <cstddef>

namespace SF {
namespace Topics {
void init(const char* deviceId);
const char* device();
const char* status();
const char* discovery();
const char* telemetry();
const char* eventsRoot();
const char* eventVisit();
const char* eventCameraSnapshot();
const char* eventLog();
const char* eventOta();
const char* ack();
const char* cmdRoot();
const char* cmdAny();
const char* cmdLed();
const char* cmdCamera();
const char* cmdLogs();
const char* cmdOta();
}
} // namespace SF

