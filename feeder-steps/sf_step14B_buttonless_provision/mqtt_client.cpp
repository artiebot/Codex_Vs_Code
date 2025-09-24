#include "mqtt_client.h"
#include "command_handler.h"
#include "provisioning.h"
#include "topics.h"
namespace SF {
Mqtt mqtt;
void Mqtt::ensureWiFi() {
  if (!SF::provisioning.isReady()) return;
  if (WiFi.status() == WL_CONNECTED) {
    SF::provisioning.notifyWifiConnected();
    return;
  }
  const auto& cfg = SF::provisioning.config();
  WiFi.mode(WIFI_STA);
  SF::provisioning.notifyWifiAttempt();
  WiFi.begin(cfg.wifi_ssid, cfg.wifi_pass);
  unsigned long t0 = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t0 < 20000) { delay(200); }
  if (WiFi.status() == WL_CONNECTED) {
    SF::provisioning.notifyWifiConnected();
  } else {
    SF::provisioning.notifyWifiConnectTimeout();
  }
}
bool Mqtt::ensureMqtt() {
  if (!SF::provisioning.isReady()) return false;
  if (client.connected()) return true;
  const auto& cfg = SF::provisioning.config();
  client.setServer(cfg.mqtt_host, cfg.mqtt_port);
  client.setKeepAlive(10);
  String clientId = String("sf-") + SF::Topics::device() + "-" + String((uint32_t)ESP.getEfuseMac(), HEX);
  bool ok = client.connect(clientId.c_str(), cfg.mqtt_user, cfg.mqtt_pass, SF::Topics::status(), 1, true, "offline");
  if (ok) {
    publishStatusOnline();
    client.setCallback(SF_onMqttMessage);
    SF_registerCommandSubscriptions(client);
    SF::provisioning.onMqttConnected(client);
  }
  return ok;
}
void Mqtt::publishStatusOnline(){ if(!SF::provisioning.isReady()) return; client.publish(SF::Topics::status(), "online", true); }
void Mqtt::begin(){ ensureWiFi(); ensureMqtt(); }
void Mqtt::loop(){ ensureWiFi(); ensureMqtt(); if(client.connected()) client.loop(); }
} // namespace SF

