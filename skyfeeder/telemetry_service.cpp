#include "telemetry_service.h"

#include <ArduinoJson.h>
#include <WiFi.h>
#include <climits>

#include "health_service.h"
#include "mqtt_client.h"
#include "topics.h"
#include "power_manager.h"
#include "weight_service.h"
#include "led_ux.h"
#include "ws2812_service.h"
#include "camera_service_esp.h"
#include "provisioning.h"

namespace SF {
Telemetry telemetry;

void Telemetry::begin(unsigned long period_ms) {
  period_ = period_ms;
  last_ = 0;
  SF::HealthService::begin();
}

void Telemetry::loop() {
  if (!SF::provisioning.isReady()) return;
  const unsigned long now = millis();
  if (last_ != 0 && (now - last_) < period_) return;
  if (!SF::mqtt.connected()) return;

  last_ = now;

  StaticJsonDocument<512> doc;
  doc["schema"] = "v1";
  doc["ts_ms"] = now;

  if (SF::power.valid()) {
    doc["power"]["pack_v"] = SF::power.packV();
    doc["power"]["cell_v"] = SF::power.cellV();
    doc["power"]["amps"] = SF::power.amps();
    doc["power"]["watts"] = SF::power.watts();
    doc["power"]["state"] = static_cast<int>(SF::power.state());
    doc["power"]["bmax"] = SF::power.brightnessLimit();
  } else {
    doc["power"]["ok"] = false;
  }

  if (SF::weight.valid()) {
    doc["weight_g"] = SF::weight.weightG();
    doc["weight"]["raw"] = SF::weight.lastMedianRaw();
    doc["weight"]["cal"] = SF::weight.calFactor();
  } else {
    doc["weight"]["ok"] = false;
  }

  doc["led"]["pattern"] = SF::ledUx.activePatternName();
  doc["led"]["brightness"] = SF::ws2812.brightness();
  doc["camera"]["status"] = SF::cameraEsp.status();

  const float cellV = SF::power.cellV();
  if (cellV > 0.1f) {
    int soc = static_cast<int>((cellV - 3.2f) * (100.0f / (4.1f - 3.2f)));
    if (soc < 0) soc = 0;
    if (soc > 100) soc = 100;
    doc["battery"] = soc;
  } else {
    doc["battery"] = 0;
  }

  JsonObject health = doc.createNestedObject("health");
  SF::HealthService::appendHealth(health, now);

  char buf[512];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  (void)n;
  SF::mqtt.raw().publish(SF::Topics::telemetry(), buf, false);

  const int16_t rssi = (WiFi.status() == WL_CONNECTED) ? WiFi.RSSI() : INT16_MIN;
  SF::HealthService::recordTelemetryPublish(now, rssi);
}

}  // namespace SF
