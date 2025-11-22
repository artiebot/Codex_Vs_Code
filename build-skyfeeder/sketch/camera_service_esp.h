#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\camera_service_esp.h"
#pragma once
#include <Arduino.h>
#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
namespace SF {
class CameraServiceEsp{
public:
  void begin();
  void loop();
  bool handleCommand(JsonVariantConst cmd, char* err, size_t errLen);
  const char* status() const { return status_; }
private:
  bool initCamera();
  void shutdownCamera();
  bool ensureAwake();
  bool captureAndPublish();
  void setStatus(const char* s);
  bool sleeping_=false;
  bool camera_ready_=false;
  bool snap_pending_=false;
  unsigned long snap_deadline_=0;
  char status_[16];
};
extern CameraServiceEsp cameraEsp;
} // namespace SF
