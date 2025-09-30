#include "ota_service.h"

#include <ArduinoJson.h>
#include <cstring>
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
  if (raw.size() >= 3 &&
      static_cast<unsigned char>(raw[0]) == 0xEF &&
      static_cast<unsigned char>(raw[1]) == 0xBB &&
      static_cast<unsigned char>(raw[2]) == 0xBF) {
    raw.erase(0, 3);
  }

  DeserializationError err = deserializeJson(doc, raw);
  if (err) {
    std::snprintf(error, errorLen, "json:%s", err.c_str());
    return false;
  }

  if (!doc.is<JsonObject>()) {
    std::snprintf(error, errorLen, "object_expected");
    return false;
  }

  return true;
}

}  // namespace

void configure(const Config& cfg) {
  gConfig = cfg;
  (void)gConfig;
}

void begin(PubSubClient& client) {
  client.subscribe(SF::Topics::cmdOta(), 1);
  SF::Log::info("ota", "subscribed ota command topic");
}

void handleMessage(PubSubClient& client, const char* topic, const uint8_t* payload, unsigned int length) {
  if (!topic || std::strcmp(topic, SF::Topics::cmdOta()) != 0) {
    return;
  }

  DynamicJsonDocument doc(1024);
  char error[64] = {0};
  if (!parsePayload(payload, length, doc, error, sizeof(error))) {
    SF::Log::warn("ota", "parse error: %s", error);
    SF::OtaManager::publishError(client, "parse", error);
    return;
  }

  if (!SF::OtaManager::processCommand(client, doc.as<JsonObjectConst>(), error, sizeof(error))) {
    SF::Log::warn("ota", "command rejected: %s", error);
    SF::OtaManager::publishError(client, "command", error);
  }
}

}  // namespace OtaService
}  // namespace SF
