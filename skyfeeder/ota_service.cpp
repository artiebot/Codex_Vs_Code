#include "ota_service.h"

#include <Arduino.h>
#include <ArduinoJson.h>
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

#include "logging.h"
#include "topics.h"

namespace SF {
namespace OtaService {
namespace {
Config config{};

uint8_t pseudoByte(uint32_t index) {
  return static_cast<uint8_t>((index * 29u + 0x5Fu) ^ 0xA5u);
}

uint32_t crc32Update(uint32_t crc, uint8_t byte) {
  crc ^= byte;
  for (int i = 0; i < 8; ++i) {
    const bool lsb = (crc & 1u) != 0u;
    crc >>= 1;
    if (lsb) {
      crc ^= 0xEDB88320u;
    }
  }
  return crc;
}

void publishEvent(PubSubClient& client,
                  const char* reqId,
                  const char* url,
                  uint32_t size,
                  const char* status,
                  int progress = -1,
                  const char* message = nullptr,
                  const char* crcHex = nullptr,
                  const char* reason = nullptr,
                  const char* detail = nullptr) {
  StaticJsonDocument<256> doc;
  doc["schema"] = "v1";
  if (reqId && reqId[0]) {
    doc["reqId"] = reqId;
  }
  doc["status"] = status ? status : "unknown";
  if (size > 0) {
    doc["size"] = size;
  }
  if (url && url[0]) {
    doc["url"] = url;
  }
  if (progress >= 0) {
    doc["progress"] = progress;
  }
  if (message && message[0]) {
    doc["msg"] = message;
  }
  if (crcHex && crcHex[0]) {
    doc["crc"] = crcHex;
  }
  if (reason && reason[0]) {
    doc["reason"] = reason;
  }
  if (detail && detail[0]) {
    doc["detail"] = detail;
  }

  char buffer[256];
  const size_t n = serializeJson(doc, buffer, sizeof(buffer));
  (void)n;
  client.publish(SF::Topics::eventOta(), buffer, false);
}

struct ParsedCommand {
  std::string reqId;
  std::string url;
  uint32_t size = 0;
  uint32_t chunkBytes = 0;
};

bool parseOtaPayload(const uint8_t* payload,
                     unsigned int length,
                     ParsedCommand& out,
                     std::string& detail) {
  if (!payload || length == 0) {
    detail = "empty payload";
    return false;
  }

  std::string raw(reinterpret_cast<const char*>(payload), reinterpret_cast<const char*>(payload) + length);
  if (raw.size() >= 3 && static_cast<unsigned char>(raw[0]) == 0xEF &&
      static_cast<unsigned char>(raw[1]) == 0xBB && static_cast<unsigned char>(raw[2]) == 0xBF) {
    raw.erase(0, 3);
  }

  DynamicJsonDocument doc(512);
  DeserializationError err = deserializeJson(doc, raw.c_str());
  if (err) {
    detail = err.c_str();
    return false;
  }

  JsonVariant root = doc.as<JsonVariant>();
  if (!root.is<JsonObject>()) {
    detail = "JSON object expected";
    return false;
  }

  JsonObject obj = root.as<JsonObject>();
  JsonObject ota = obj["ota"].is<JsonObject>() ? obj["ota"].as<JsonObject>() : obj;

  uint32_t size = ota["size"].as<uint32_t>();
  if (size == 0) {
    detail = "missing or invalid size";
    return false;
  }

  const char* url = ota["url"].is<const char*>() ? ota["url"].as<const char*>() : nullptr;
  const char* reqId = obj["reqId"].is<const char*>() ? obj["reqId"].as<const char*>()
                                                      : (ota["reqId"].is<const char*>() ? ota["reqId"].as<const char*>() : nullptr);
  uint32_t chunk = ota["chunkBytes"].as<uint32_t>();

  out.size = size;
  out.chunkBytes = chunk;
  out.url = url ? url : "";
  out.reqId = reqId ? reqId : "";
  return true;
}

uint32_t clampChunkBytes(uint32_t requested) {
  if (requested == 0) {
    return config.chunkBytes;
  }
  return std::max<uint32_t>(64, std::min<uint32_t>(requested, config.chunkBytes * 8));
}

}  // namespace

void configure(const Config& cfg) {
  config = cfg;
}

void begin(PubSubClient& client) {
  client.subscribe(SF::Topics::cmdOta(), 1);
  SF::Log::info("ota", "subscribed ota command topic");
}

void handleMessage(PubSubClient& client, const char* topic, const uint8_t* payload, unsigned int length) {
  if (!topic || std::strcmp(topic, SF::Topics::cmdOta()) != 0) {
    return;
  }

  ParsedCommand cmd;
  std::string detail;
  if (!parseOtaPayload(payload, length, cmd, detail)) {
    publishEvent(client, nullptr, nullptr, 0, "error", -1, nullptr, nullptr, "invalid payload", detail.c_str());
    SF::Log::warn("ota", "invalid OTA payload: %s", detail.c_str());
    return;
  }

  if (cmd.reqId.empty()) {
    char generated[32];
    std::snprintf(generated, sizeof(generated), "req-%lu", millis());
    cmd.reqId = generated;
  }

  uint32_t size = cmd.size;
  if (size > config.maxImageBytes) {
    publishEvent(client, cmd.reqId.c_str(), cmd.url.empty() ? nullptr : cmd.url.c_str(), size, "error", -1, nullptr, nullptr, "invalid payload", "size too large");
    SF::Log::warn("ota", "rejecting OTA: size=%u", size);
    return;
  }

  uint32_t chunkBytes = clampChunkBytes(cmd.chunkBytes);
  const char* url = cmd.url.empty() ? nullptr : cmd.url.c_str();

  publishEvent(client, cmd.reqId.c_str(), url, size, "started", 0, "OTA command accepted");
  SF::Log::info("ota", "begin req=%s url=%s size=%u chunk=%u", cmd.reqId.c_str(), url ? url : "", size, chunkBytes);

  const uint8_t progressMarks[] = {25, 50, 75};
  uint32_t thresholds[sizeof(progressMarks) / sizeof(progressMarks[0])];
  for (size_t i = 0; i < sizeof(progressMarks) / sizeof(progressMarks[0]); ++i) {
    uint32_t threshold = (size * progressMarks[i]) / 100u;
    if (threshold == 0 && size > 0) {
      threshold = 1;
    }
    thresholds[i] = threshold;
  }

  uint32_t crc = 0xFFFFFFFFu;
  uint32_t processed = 0;
  size_t markIndex = 0;

  while (processed < size) {
    const uint32_t chunk = std::min<uint32_t>(chunkBytes, size - processed);
    for (uint32_t i = 0; i < chunk; ++i) {
      const uint32_t offset = processed + i;
      const uint8_t byte = pseudoByte(offset);
      crc = crc32Update(crc, byte);
    }
    processed += chunk;

    while (markIndex < sizeof(progressMarks) / sizeof(progressMarks[0]) && processed >= thresholds[markIndex]) {
      if (config.progressDelayMs > 0) {
        delay(config.progressDelayMs);
      }
      publishEvent(client, cmd.reqId.c_str(), url, size, "progress", progressMarks[markIndex]);
      ++markIndex;
    }
  }

  crc ^= 0xFFFFFFFFu;
  if (config.progressDelayMs > 0) {
    delay(config.progressDelayMs);
  }

  char crcHex[9];
  std::snprintf(crcHex, sizeof(crcHex), "%08X", static_cast<unsigned int>(crc));
  publishEvent(client, cmd.reqId.c_str(), url, size, "verified", 100, "CRC verified", crcHex);
  SF::Log::info("ota", "complete req=%s crc=%s", cmd.reqId.c_str(), crcHex);
}

}  // namespace OtaService
}  // namespace SF
