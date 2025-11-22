#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\health_service.cpp"
#include "health_service.h"

#include <Arduino.h>
#include <WiFi.h>
#include <climits>

namespace SF {
namespace HealthService {
namespace {
uint32_t bootMs = 0;
uint32_t lastPublishMs = 0;
uint32_t publishCount = 0;
uint32_t mqttRetryCount = 0;
int16_t lastRssi = INT16_MIN;
}

void begin() {
  bootMs = millis();
  lastPublishMs = 0;
  publishCount = 0;
  mqttRetryCount = 0;
  lastRssi = INT16_MIN;
}

void recordTelemetryPublish(uint32_t publishedAtMs, int16_t rssi) {
  lastPublishMs = publishedAtMs;
  ++publishCount;
  if (rssi != INT16_MIN) {
    lastRssi = rssi;
  }
}

void recordMqttRetry() {
  ++mqttRetryCount;
}

void appendHealth(JsonObject node, uint32_t nowMs) {
  const uint32_t uptime = nowMs - bootMs;
  node["uptime_ms"] = uptime;
  node["last_seen_ms"] = lastPublishMs;
  node["telemetry_count"] = publishCount;
  node["mqtt_retries"] = mqttRetryCount;
  if (lastPublishMs > 0 && nowMs >= lastPublishMs) {
    node["since_last_ms"] = nowMs - lastPublishMs;
  }
  int16_t rssi = lastRssi;
  if (rssi == INT16_MIN && WiFi.status() == WL_CONNECTED) {
    rssi = WiFi.RSSI();
  }
  if (rssi != INT16_MIN) {
    node["rssi"] = rssi;
  }
}

}  // namespace HealthService
}  // namespace SF
