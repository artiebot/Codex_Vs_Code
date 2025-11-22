#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\health_service.h"
#pragma once

#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include <cstdint>

namespace SF {
namespace HealthService {
void begin();
void recordTelemetryPublish(uint32_t publishedAtMs, int16_t rssi);
void recordMqttRetry();
void appendHealth(JsonObject node, uint32_t nowMs);
}
}  // namespace SF
