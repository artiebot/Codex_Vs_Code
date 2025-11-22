#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\log_service.cpp"
#include "log_service.h"

#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include <cstring>

#include "logging.h"
#include "topics.h"

namespace SF {
namespace LogService {
namespace {
void publishDump(PubSubClient& client) {
  std::string payload = SF::Log::dumpJson();
  client.publish(SF::Topics::eventLog(), payload.c_str(), false);
}
}

void begin(PubSubClient& client) {
  client.subscribe(SF::Topics::cmdLogs(), 0);
  SF::Log::info("log", "subscribed log command topic");
}

void handleMessage(PubSubClient& client, const char* topic, const uint8_t* payload, unsigned int length) {
  if (!topic || std::strcmp(topic, SF::Topics::cmdLogs()) != 0) {
    return;
  }

  bool clear = false;
  if (payload && length > 0) {
    StaticJsonDocument<128> doc;
    auto err = deserializeJson(doc, payload, length);
    if (!err) {
      clear = doc["clear"].as<bool>();
    }
  }

  if (clear) {
    SF::Log::info("log", "clear requested via MQTT");
    SF::Log::clear();
  }

  publishDump(client);
}

} // namespace LogService
} // namespace SF
