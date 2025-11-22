#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\topics.h"
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
const char* eventSys();
const char* eventOta();
const char* eventAck();
const char* ack();
const char* cmdRoot();
const char* cmdAny();
const char* cmdLed();
const char* cmdCalibrate();
const char* cmdCamera();
const char* cmdCam();
const char* cmdLogs();
const char* cmdOta();
}
} // namespace SF

