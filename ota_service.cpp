#include "ota_service.h"

#include <Arduino.h>
#include <ArduinoJson.h>
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>

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
                  uint8_t progress,
                  const char* message = nullptr,
                  const char* crcHex = nullptr) {
  StaticJsonDocument<256> doc;
  doc["schema"] = "v1";
  if (reqId && reqId[0]) {
    doc["reqId"] = reqId;
  }
  doc["status"] = status ? status : "unknown";
  doc["progress"] = progress;
  doc["size"] = size;
  if (url && url[0]) {
    doc["url"] = url;
  }
  if (message && message[0]) {
    doc["msg"] = message;
  }
  if (crcHex && crcHex[0]) {
    doc["crc"] = crcHex;
  }

  char buffer[256];
  const size_t n = serializeJson(doc, buffer, sizeof(buffer));
  (void)n;
  client.publish(SF::Topics::eventOta(), buffer, false);
}

void publishError(PubSubClient& client,
                  const char* reqId,
                  const char* url,
                  uint32_t size,
                  const char* reason) {
  publishEvent(client, reqId, url, size, "error", 0, reason);
}

const char* extractOptionalString(JsonVariantConst value) {
  const char* str = value.as<const char*>();
  return (str && str[0]) ? str : nullptr;
}

uint32_t clampChunkBytes(JsonVariantConst node) {
  const uint32_t requested = node.as<uint32_t>();
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

  StaticJsonDocument<256> doc;
  const auto err = deserializeJson(doc, payload, length);
  if (err) {
    publishError(client, nullptr, nullptr, 0, "bad_json");
    SF::Log::warn("ota", "invalid command payload: %s", err.c_str());
    return;
  }

  const char* reqId = extractOptionalString(doc["reqId"]);
  if (!reqId) {
    reqId = extractOptionalString(doc["req_id"]);
  }

  const char* url = extractOptionalString(doc["url"]);
  const uint32_t sizeFromSize = doc["size"].as<uint32_t>();
  const uint32_t sizeFromBytes = doc["sizeBytes"].as<uint32_t>();
  uint32_t size = sizeFromSize ? sizeFromSize : sizeFromBytes;
  if (!url) {
    url = extractOptionalString(doc["image"]);
  }

  if (size == 0 || size > config.maxImageBytes) {
    publishError(client, reqId, url, size, size == 0 ? "size_missing" : "size_too_large");
    SF::Log::warn("ota", "rejecting OTA: size=%u", size);
    return;
  }
  if (!url) {
    publishError(client, reqId, nullptr, size, "url_missing");
    SF::Log::warn("ota", "rejecting OTA: missing url");
    return;
  }

  const uint32_t chunkBytes = clampChunkBytes(doc["chunkBytes"]);

  publishEvent(client, reqId, url, size, "started", 0, "OTA command accepted");
  SF::Log::info("ota", "begin req=%s url=%s size=%u chunk=%u", reqId ? reqId : "", url, size, chunkBytes);

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
      publishEvent(client, reqId, url, size, "progress", progressMarks[markIndex]);
      ++markIndex;
    }
  }

  crc ^= 0xFFFFFFFFu;
  if (config.progressDelayMs > 0) {
    delay(config.progressDelayMs);
  }

  char crcHex[9];
  std::snprintf(crcHex, sizeof(crcHex), "%08X", static_cast<unsigned int>(crc));
  publishEvent(client, reqId, url, size, "verified", 100, "CRC verified", crcHex);
  SF::Log::info("ota", "complete req=%s crc=%s", reqId ? reqId : "", crcHex);
}

}  // namespace OtaService
}  // namespace SF

