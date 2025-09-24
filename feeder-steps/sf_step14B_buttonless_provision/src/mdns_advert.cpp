#include "mdns_advert.h"
#include "src/config.h"
#include "src/topics.h"
#include <ESPmDNS.h>

namespace MdnsAdvert {
namespace {
bool started = false;
bool onlineState = false;
}

void begin(const char* deviceId) {
  if (MDNS.begin(deviceId)) {
    started = true;
    MDNS.addService("skyfeeder", "tcp", 80);
    MDNS.addServiceTxt("skyfeeder", "tcp", "id", deviceId);
    MDNS.addServiceTxt("skyfeeder", "tcp", "fw", AppConfig::FW_VERSION);
    MDNS.addServiceTxt("skyfeeder", "tcp", "cap", "camera,hx711,ina260,led,mdns");
  }
}

void setOnline(bool online) {
  onlineState = online;
  if (started) {
    MDNS.addServiceTxt("skyfeeder", "tcp", "state", online ? "online" : "offline");
  }
}

void loop() {
  // MDNS.update() is not needed in newer ESP32 Arduino core versions
}

}
