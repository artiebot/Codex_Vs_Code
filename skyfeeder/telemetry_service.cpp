#include "telemetry_service.h"

#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFi.h>

#include "boot_health.h"
#include "config.h"
#include "power_manager.h"
#include "provisioning.h"
#include "weight_service.h"

namespace {
constexpr unsigned long kDefaultIntervalMs = TELEMETRY_PUSH_INTERVAL_MS;
bool gTelemetryHealthyReported = false;
}  // namespace

namespace SF {

Telemetry telemetry;

void Telemetry::begin(unsigned long period_ms) {
  period_ = period_ms;
  last_ = 0;
}

void Telemetry::loop() {
  if (!SF::provisioning.isReady()) return;
  if (WiFi.status() != WL_CONNECTED) return;
  const unsigned long now = millis();
  const unsigned long interval = (period_ > 0) ? period_ : kDefaultIntervalMs;
  if (last_ != 0 && (now - last_) < interval) return;
  last_ = now;

  StaticJsonDocument<512> doc;
  doc["ts_ms"] = now;
  doc["uptime_ms"] = now;

  if (SF::power.valid()) {
    doc["packVoltage"] = SF::power.packV();
    doc["cellVoltage"] = SF::power.cellV();
    doc["watts"] = SF::power.watts();
    doc["amps"] = SF::power.amps();
    doc["powerState"] = static_cast<int>(SF::power.state());
  } else {
    doc["powerValid"] = false;
  }

  if (SF::weight.valid()) {
    doc["weightG"] = SF::weight.weightG();
  } else {
    doc["weightValid"] = false;
  }

  doc["signalStrengthDbm"] = WiFi.RSSI();

  const char* deviceId = SF::provisioning.deviceId();
  if (!deviceId || !deviceId[0]) {
    deviceId = DEVICE_ID_DEFAULT;
  }

  String json;
  serializeJson(doc, json);

  HTTPClient http;
  String url = String(API_BASE_URL) + "/api/telemetry/push?deviceId=" + deviceId;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(json);
  if (code >= 200 && code < 300) {
    Serial.println("[telem] push ok");
    if (!gTelemetryHealthyReported) {
      SF::BootHealth::markHealthy();
      gTelemetryHealthyReported = true;
    }
  } else {
    Serial.printf("[telem] push failed: %d\n", code);
  }
  http.end();
}

}  // namespace SF
