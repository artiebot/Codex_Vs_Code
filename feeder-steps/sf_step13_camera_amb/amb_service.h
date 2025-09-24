#pragma once
#include <Arduino.h>
#include <ArduinoJson.h>
namespace SF {
class AmbService {
public:
  void begin();
  void loop();
  bool handleCommand(JsonVariantConst cmd, char* err, size_t errLen);
  void onCameraEvent(const char* topic, const uint8_t* payload, unsigned int len);
  const char* status() const { return status_; }
private:
  bool triggerSnapHttp(char* err, size_t errLen);
  void publishSnapshot(const char* url, const char* remote_ts);
  void setStatus(const char* status);
  char status_[16];
  bool snap_pending_=false;
  unsigned long snap_deadline_=0;
};
extern AmbService amb;
} // namespace SF
