#include "topics.h"
#include "config.h"
namespace {
String device_id;
String topic_status;
String topic_ack;
String topic_telemetry;
String topic_cmd_any;
String topic_cmd_led;
String topic_cmd_calibrate;
String topic_cmd_camera;
String topic_event_visit;
String topic_event_camera;
String topic_discovery;
String makeTopic(const char* id, const char* suffix){ String t("skyfeeder/"); t += id; t += "/"; t += suffix; return t; }
void ensureInit(){ if(device_id.length()==0){ SF::Topics::init(DEVICE_ID_DEFAULT); } }
}
namespace SF { namespace Topics {
void init(const char* id){ if(!id||!id[0]) id=DEVICE_ID_DEFAULT; device_id=id; topic_status=makeTopic(device_id.c_str(), "status"); topic_ack=makeTopic(device_id.c_str(), "ack"); topic_telemetry=makeTopic(device_id.c_str(), "telemetry"); topic_cmd_any=makeTopic(device_id.c_str(), "cmd/#"); topic_cmd_led=makeTopic(device_id.c_str(), "cmd/led"); topic_cmd_calibrate=makeTopic(device_id.c_str(), "cmd/calibrate"); topic_cmd_camera=makeTopic(device_id.c_str(), "cmd/camera"); topic_event_visit=makeTopic(device_id.c_str(), "event/visit"); topic_event_camera=makeTopic(device_id.c_str(), "event/camera/snapshot"); topic_discovery=makeTopic(device_id.c_str(), "discovery"); }
const char* device(){ ensureInit(); return device_id.c_str(); }
const char* status(){ ensureInit(); return topic_status.c_str(); }
const char* ack(){ ensureInit(); return topic_ack.c_str(); }
const char* telemetry(){ ensureInit(); return topic_telemetry.c_str(); }
const char* cmdAny(){ ensureInit(); return topic_cmd_any.c_str(); }
const char* cmdLed(){ ensureInit(); return topic_cmd_led.c_str(); }
const char* cmdCalibrate(){ ensureInit(); return topic_cmd_calibrate.c_str(); }
const char* cmdCamera(){ ensureInit(); return topic_cmd_camera.c_str(); }
const char* eventVisit(){ ensureInit(); return topic_event_visit.c_str(); }
const char* eventCameraSnapshot(){ ensureInit(); return topic_event_camera.c_str(); }
const char* discovery(){ ensureInit(); return topic_discovery.c_str(); }
}} // namespace SF::Topics
