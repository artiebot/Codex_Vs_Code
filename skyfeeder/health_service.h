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
