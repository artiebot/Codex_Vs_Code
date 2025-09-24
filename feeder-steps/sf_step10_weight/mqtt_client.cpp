#include "mqtt_client.h"
#include "command_handler.h"
namespace SF {
Mqtt mqtt;
void Mqtt::ensureWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  unsigned long t0 = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t0 < 20000) { delay(200); }
}
bool Mqtt::ensureMqtt() {
  if (client.connected()) return true;
  client.setServer(MQTT_HOST, MQTT_PORT);
  client.setKeepAlive(10);
  String clientId = String("sf-") + DEVICE_ID + "-" + String((uint32_t)ESP.getEfuseMac(), HEX);
  bool ok = client.connect(clientId.c_str(), MQTT_USER, MQTT_PASS, TOPIC_STATUS, 1, true, "offline");
  if (ok) { publishStatusOnline(); client.setCallback(SF_onMqttMessage); SF_registerCommandSubscriptions(client); }
  return ok;
}
void Mqtt::publishStatusOnline(){ client.publish(TOPIC_STATUS, "online", true); }
void Mqtt::begin(){ ensureWiFi(); ensureMqtt(); }
void Mqtt::loop(){ ensureWiFi(); ensureMqtt(); client.loop(); }
} // namespace SF
