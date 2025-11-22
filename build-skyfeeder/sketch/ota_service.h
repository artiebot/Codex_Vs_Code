#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\ota_service.h"
#pragma once

#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include <PubSubClient.h>
#include <cstdint>

namespace SF {
namespace OtaService {

struct Config {
  uint32_t chunkBytes = 4 * 1024;
  uint32_t progressDelayMs = 120;
  uint32_t maxImageBytes = 4 * 1024 * 1024;
};

void configure(const Config& cfg);
void begin(PubSubClient& client);
void handleMessage(PubSubClient& client, const char* topic, const uint8_t* payload, unsigned int length);

} // namespace OtaService
} // namespace SF

