#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\ota_service.cpp"
#include "ota_service.h"

#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include <cstring>
#include <cstdio>
#include <string>

#include "logging.h"
#include "ota_manager.h"
#include "topics.h"

namespace SF {
namespace OtaService {
namespace {
Config gConfig{};

bool parsePayload(const uint8_t* payload,
                  unsigned int length,
                  DynamicJsonDocument& doc,
                  char* error,
                  size_t errorLen) {
  if (!payload || length == 0) {
    std::snprintf(error, errorLen, "empty_payload");
    return false;
  }

  std::string raw(reinterpret_cast<const char*>(payload), reinterpret_cast<const char*>(payload) + length);

  // Debug: Print received payload
  Serial.print("DEBUG: Received OTA payload (");
  Serial.print(length);
  Serial.print(" bytes): ");
  Serial.println(raw.c_str());

  if (raw.size() >= 3 &&
      static_cast<unsigned char>(raw[0]) == 0xEF &&
      static_cast<unsigned char>(raw[1]) == 0xBB &&
      static_cast<unsigned char>(raw[2]) == 0xBF) {
    raw.erase(0, 3);
    Serial.println("DEBUG: Removed UTF-8 BOM");
  }

  DeserializationError err = deserializeJson(doc, raw);
  if (err) {
    Serial.print("DEBUG: JSON parse error: ");
    Serial.println(err.c_str());
    std::snprintf(error, errorLen, "json:%s", err.c_str());
    return false;
  }

  Serial.println("DEBUG: JSON parsed successfully");

  if (!doc.is<JsonObject>()) {
    std::snprintf(error, errorLen, "object_expected");
    return false;
  }
  return true;
}

}  // namespace

void configure(const Config& cfg) {
  gConfig = cfg;
  (void)gConfig;  // reserved for future throttling settings
}

void begin(PubSubClient& client) {
  const char* otaTopic = SF::Topics::cmdOta();
  Serial.print("DEBUG: OTA Service subscribing to: ");
  Serial.println(otaTopic);
  bool subOk = client.subscribe(otaTopic, 1);
  Serial.print("DEBUG: Subscription result: ");
  Serial.println(subOk ? "SUCCESS" : "FAILED");
  SF::Log::info("ota", "subscribed ota command topic: %s", otaTopic);
}

void handleMessage(PubSubClient& client, const char* topic, const uint8_t* payload, unsigned int length) {
  if (!topic || strcmp(topic, SF::Topics::cmdOta()) != 0) {
    return;
  }

  DynamicJsonDocument doc(1024);
  char error[64] = {0};
  if (!parsePayload(payload, length, doc, error, sizeof(error))) {
    SF::Log::warn("ota", "parse error: %s", error);
    SF::OtaManager::publishError(client, "parse", error);
    return;
  }

  Serial.println("DEBUG: Calling OtaManager::processCommand...");
  bool cmdResult = SF::OtaManager::processCommand(client, doc.as<ArduinoJson::JsonObjectConst>(), error, sizeof(error));
  Serial.print("DEBUG: processCommand result: ");
  Serial.println(cmdResult ? "SUCCESS" : "FAILED");
  if (!cmdResult) {
    Serial.print("DEBUG: Error string: '");
    Serial.print(error);
    Serial.println("'");
    if (error[0]) {
      SF::Log::warn("ota", "command rejected: %s", error);
      SF::OtaManager::publishError(client, "command", error);
    } else {
      Serial.println("DEBUG: No error string provided!");
    }
  } else {
    Serial.println("DEBUG: OTA command accepted!");
  }
}

}  // namespace OtaService
}  // namespace SF

