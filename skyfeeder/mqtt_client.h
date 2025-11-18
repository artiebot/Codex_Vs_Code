#pragma once
#include <WiFi.h>
#include <PubSubClient.h>
#include "config.h"
#include "topics.h"

namespace SF {

// Wi-Fi connection state machine for the ESP control plane.
// This replaces the old blocking ensureWiFi() logic with a non-blocking model
// that supports background retries and failure tracking.
enum class WifiState {
  Idle,
  Provisioning,
  Connecting,
  Online,
  OfflineRetry,
};

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

  WifiState wifiState_ = WifiState::Idle;
  unsigned long wifiConnectStartMs_ = 0;
  unsigned long wifiNextRetryMs_ = 0;
};
extern Mqtt mqtt;
} // namespace SF
