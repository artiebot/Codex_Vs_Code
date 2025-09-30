#include "mqtt_client.h"

#include <Arduino.h>

#include "command_handler.h"
#include "health_service.h"
#include "log_service.h"
#include "ota_service.h"
#include "ota_manager.h"
#include "provisioning.h"
#include "telemetry_service.h"
#include "topics.h"

namespace {
void handleMqttMessage(char* topic, byte* payload, unsigned int length) {
  SF::LogService::handleMessage(SF::mqtt.raw(), topic, payload, length);
  SF::OtaService::handleMessage(SF::mqtt.raw(), topic, payload, length);
  SF_onMqttMessage(topic, payload, length);
}
}

namespace SF {
Mqtt mqtt;

void Mqtt::ensureWiFi() {
  if (!SF::provisioning.isReady()) return;
  if (WiFi.status() == WL_CONNECTED) return;
  const auto& cfg = SF::provisioning.config();
  WiFi.mode(WIFI_STA);
  WiFi.begin(cfg.wifi_ssid, cfg.wifi_pass);
  const unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(200);
  }
}

bool Mqtt::ensureMqtt() {
  if (!SF::provisioning.isReady()) return false;
  if (client.connected()) return true;

  const auto& cfg = SF::provisioning.config();
  client.setServer(cfg.mqtt_host, cfg.mqtt_port);
  client.setBufferSize(1024);  // Increase buffer for discovery payload
  client.setKeepAlive(10);
  client.setCallback(handleMqttMessage);

  String clientId = String("sf-") + SF::Topics::device() + "-" + String(static_cast<uint32_t>(ESP.getEfuseMac()), HEX);
  const bool ok = client.connect(clientId.c_str(), cfg.mqtt_user, cfg.mqtt_pass, SF::Topics::status(), 1, true, "offline");
  if (ok) {
    publishStatusOnline();
    SF_registerCommandSubscriptions(client);
    SF::LogService::begin(client);
    SF::OtaService::begin(client);
    SF::OtaManager::onMqttConnected(client);
    SF::provisioning.onMqttConnected(client);
  } else {
    SF::HealthService::recordMqttRetry();
  }
  return ok;
}

void Mqtt::publishStatusOnline() {
  if (!SF::provisioning.isReady()) return;
  client.publish(SF::Topics::status(), "online", true);
}

void Mqtt::begin() {
  ensureWiFi();
  ensureMqtt();
}

void Mqtt::loop() {
  ensureWiFi();
  if (ensureMqtt()) {
    client.loop();
  }
}

}  // namespace SF


