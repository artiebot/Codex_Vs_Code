#pragma once
#include <Arduino.h>
#include <WiFi.h>
#include <esp_system.h>

namespace AppConfig {
constexpr const char* FW_VERSION = "14.1.0";
constexpr const char* HW_REVISION = "ESP32-Feeder-A";
constexpr const char* FACTORY_TOKEN = "skyfactorytoken";

#ifdef PROD
constexpr const char* MQTT_HOST_DEFAULT = "prod-broker.example";
constexpr uint16_t MQTT_PORT_DEFAULT = 8883;
constexpr bool MQTT_TLS_DEFAULT = true;
constexpr const char* MQTT_USER_DEFAULT = "";
constexpr const char* MQTT_PASS_DEFAULT = "";
#else
constexpr const char* MQTT_HOST_DEFAULT = "10.0.0.4";
constexpr uint16_t MQTT_PORT_DEFAULT = 1883;
constexpr bool MQTT_TLS_DEFAULT = false;
constexpr const char* MQTT_USER_DEFAULT = "dev1";
constexpr const char* MQTT_PASS_DEFAULT = "dev1pass";
#endif

inline bool isProd() {
#ifdef PROD
  return true;
#else
  return false;
#endif
}

inline const char* factoryToken() { return FACTORY_TOKEN; }

inline void macSuffix(char* out, size_t len) {
  uint8_t mac[6];
  if (WiFi.macAddress(mac) == 0) {
    strncpy(out, "0000", len);
    if (len) out[len-1]='\0';
    return;
  }
  snprintf(out, len, "%02X%02X", mac[4], mac[5]);
}

inline void defaultDeviceId(char* out, size_t len) {
  char suffix[5]{0};
  macSuffix(suffix, sizeof(suffix));
  snprintf(out, len, "sf-%s", suffix);
}

inline void buildClientId(const char* deviceId, char* out, size_t len) {
  char suffix[5]{0};
  macSuffix(suffix, sizeof(suffix));
  snprintf(out, len, "%s-%s", deviceId, suffix);
}

inline String ipToString(const IPAddress& ip) {
  return String(ip[0]) + "." + ip[1] + "." + ip[2] + "." + ip[3];
}
}
