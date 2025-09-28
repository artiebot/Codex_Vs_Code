#include "topics.h"

#include <string>

#include "logging.h"

namespace SF {
namespace Topics {
namespace {
std::string deviceId = "sf-0000";
std::string topicStatus;
std::string topicDiscovery;
std::string topicTelemetry;
std::string topicEvents;
std::string topicVisit;
std::string topicSnapshot;
std::string topicLogs;
std::string topicAck;
std::string topicEventOta;
std::string topicCmdRoot;
std::string topicCmdAny;
std::string topicCmdLed;
std::string topicCmdCalibrate;
std::string topicCmdCamera;
std::string topicCmdLogs;
std::string topicCmdOta;

std::string makeTopic(const char* suffix) {
  std::string t("skyfeeder/");
  t += deviceId;
  t += "/";
  t += suffix;
  return t;
}
}  // namespace

void init(const char* id) {
  deviceId = (id && id[0]) ? id : "sf-0000";
  SF::Log::setDeviceId(deviceId.c_str());

  topicStatus = makeTopic("status");
  topicDiscovery = makeTopic("discovery");
  topicTelemetry = makeTopic("telemetry");
  topicEvents = makeTopic("event");
  topicVisit = makeTopic("event/visit");
  topicSnapshot = makeTopic("event/camera/snapshot");
  topicLogs = makeTopic("event/log");
  topicEventOta = makeTopic("event/ota");
  topicAck = makeTopic("ack");
  topicCmdRoot = makeTopic("cmd");
  topicCmdAny = makeTopic("cmd/#");
  topicCmdLed = makeTopic("cmd/led");
  topicCmdCalibrate = makeTopic("cmd/calibrate");
  topicCmdCamera = makeTopic("cmd/camera");
  topicCmdLogs = makeTopic("cmd/logs");
  topicCmdOta = makeTopic("cmd/ota");
}

const char* device() { return deviceId.c_str(); }
const char* status() { return topicStatus.c_str(); }
const char* discovery() { return topicDiscovery.c_str(); }
const char* telemetry() { return topicTelemetry.c_str(); }
const char* eventsRoot() { return topicEvents.c_str(); }
const char* eventVisit() { return topicVisit.c_str(); }
const char* eventCameraSnapshot() { return topicSnapshot.c_str(); }
const char* eventLog() { return topicLogs.c_str(); }
const char* eventOta() { return topicEventOta.c_str(); }
const char* ack() { return topicAck.c_str(); }
const char* cmdRoot() { return topicCmdRoot.c_str(); }
const char* cmdAny() { return topicCmdAny.c_str(); }
const char* cmdLed() { return topicCmdLed.c_str(); }
const char* cmdCalibrate() { return topicCmdCalibrate.c_str(); }
const char* cmdCamera() { return topicCmdCamera.c_str(); }
const char* cmdLogs() { return topicCmdLogs.c_str(); }
const char* cmdOta() { return topicCmdOta.c_str(); }

}  // namespace Topics
}  // namespace SF
