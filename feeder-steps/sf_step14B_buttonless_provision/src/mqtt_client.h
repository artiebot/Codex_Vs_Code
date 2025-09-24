#pragma once
#include <Arduino.h>

namespace MqttClient {
void begin();
void setDeviceId(const char* id);
void loop();
bool connected();
void publishTelemetry(const char* topic, const char* payload, bool retain=false);
}
