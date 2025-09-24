#include "topics.h"
#include <Arduino.h>

namespace {
String id;
String topic_status;
String topic_discovery;
String topic_telemetry;
String topic_events;
String topic_event_visit;
String topic_event_snapshot;
String topic_cmd;
String topic_cmd_led;
String topic_cmd_calibrate;
String topic_cmd_camera;
String topic_ota;

String makeTopic(const char* suffix) {
  String t("skyfeeder/");
  t += id;
  t += "/";
  t += suffix;
  return t;
}
}

namespace Topics {

void init(const char* deviceId) {
  id = deviceId ? deviceId : "sf-0000";
  topic_status = makeTopic("status");
  topic_discovery = makeTopic("discovery");
  topic_telemetry = makeTopic("telemetry");
  topic_events = makeTopic("event");
  topic_event_visit = makeTopic("event/visit");
  topic_event_snapshot = makeTopic("event/camera/snapshot");
  topic_cmd = makeTopic("cmd");
  topic_cmd_led = makeTopic("cmd/led");
  topic_cmd_calibrate = makeTopic("cmd/calibrate");
  topic_cmd_camera = makeTopic("cmd/camera");
  topic_ota = makeTopic("cmd/ota");
}

const char* device() { return id.c_str(); }
const char* status() { return topic_status.c_str(); }
const char* discovery() { return topic_discovery.c_str(); }
const char* telemetry() { return topic_telemetry.c_str(); }
const char* eventsRoot() { return topic_events.c_str(); }
const char* eventVisit() { return topic_event_visit.c_str(); }
const char* eventSnapshot() { return topic_event_snapshot.c_str(); }
const char* cmdRoot() { return topic_cmd.c_str(); }
const char* cmdLed() { return topic_cmd_led.c_str(); }
const char* cmdCalibrate() { return topic_cmd_calibrate.c_str(); }
const char* cmdCamera() { return topic_cmd_camera.c_str(); }
const char* ota() { return topic_ota.c_str(); }

} // namespace Topics
