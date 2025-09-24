#pragma once
#include <WiFi.h>
#include <PubSubClient.h>
#include "config.h"
#include "topics.h"

namespace SF {
class Mqtt {
public:
  void begin();
  void loop();
  bool connected() { return client.connected(); }
  void publishStatusOnline();
  PubSubClient& raw() { return client; }
private:
  WiFiClient wifi;
  PubSubClient client{wifi};
  void ensureWiFi();
  bool ensureMqtt();
};
extern Mqtt mqtt;
} // namespace SF
