#include "ota_manager.h"

#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <Update.h>
#include <WiFiClient.h>
#include <Arduino.h>
#include <cstdio>
#include <cstring>
#include <esp_ota_ops.h>
#include <mbedtls/sha256.h>

#include "boot_health.h"
#include "config.h"
#include "logging.h"
#include "storage_nvs.h"
#include "topics.h"

namespace SF {
namespace OtaManager {
namespace {
constexpr uint32_t kStateMagic = 0x53464F54;  // "SFOT"
constexpr size_t kVersionLen = 16;
constexpr size_t kChannelLen = 16;
constexpr size_t kReasonLen = 64;

struct PersistedState {
  uint32_t magic;
  char lastGood[kVersionLen];
  char pending[kVersionLen];
  char pendingChannel[kChannelLen];
};

PersistedState gState{};
bool gStateLoaded = false;

struct PendingEvent {
  bool active = false;
  char state[24];
  char version[kVersionLen];
  char fromVersion[kVersionLen];
  char toVersion[kVersionLen];
  char reason[kReasonLen];
};

PendingEvent gEvent{};

constexpr const char* kFwVersion = FW_VERSION;

void copyStr(char* dst, size_t len, const char* src) {
  if (!dst || len == 0) return;
  if (!src) {
    dst[0] = '\0';
    return;
  }
  std::strncpy(dst, src, len - 1);
  dst[len - 1] = '\0';
}

uint8_t hexToNibble(char c) {
  if (c >= '0' && c <= '9') return static_cast<uint8_t>(c - '0');
  if (c >= 'a' && c <= 'f') return static_cast<uint8_t>(10 + (c - 'a'));
  if (c >= 'A' && c <= 'F') return static_cast<uint8_t>(10 + (c - 'A'));
  return 0;
}

bool parseSha(const char* hex, uint8_t out[32]) {
  if (!hex) return false;
  const size_t len = std::strlen(hex);
  if (len != 64) return false;
  for (size_t i = 0; i < 32; ++i) {
    uint8_t high = hexToNibble(hex[2 * i]);
    uint8_t low = hexToNibble(hex[2 * i + 1]);
    out[i] = static_cast<uint8_t>((high << 4) | low);
  }
  return true;
}

int compareSemver(const char* lhs, const char* rhs) {
  if (!lhs || !rhs) return 0;
  int lMaj = 0, lMin = 0, lPat = 0;
  int rMaj = 0, rMin = 0, rPat = 0;
  std::sscanf(lhs, "%d.%d.%d", &lMaj, &lMin, &lPat);
  std::sscanf(rhs, "%d.%d.%d", &rMaj, &rMin, &rPat);
  if (lMaj != rMaj) return (lMaj < rMaj) ? -1 : 1;
  if (lMin != rMin) return (lMin < rMin) ? -1 : 1;
  if (lPat != rPat) return (lPat < rPat) ? -1 : 1;
  return 0;
}

void saveState() {
  gState.magic = kStateMagic;
  SF::Storage::setBytes("ota", "state", &gState, sizeof(gState));
}

void ensureStateLoaded() {
  if (gStateLoaded) return;
  PersistedState stored{};
  if (SF::Storage::getBytes("ota", "state", &stored, sizeof(stored)) && stored.magic == kStateMagic) {
    gState = stored;
  } else {
    std::memset(&gState, 0, sizeof(gState));
    copyStr(gState.lastGood, sizeof(gState.lastGood), kFwVersion);
  }
  gStateLoaded = true;
  saveState();
}

void queueEvent(const char* state, const char* version, const char* fromVersion, const char* toVersion, const char* reason, const char* channel = nullptr) {
  gEvent.active = true;
  copyStr(gEvent.state, sizeof(gEvent.state), state);
  copyStr(gEvent.version, sizeof(gEvent.version), version);
  copyStr(gEvent.fromVersion, sizeof(gEvent.fromVersion), fromVersion);
  copyStr(gEvent.toVersion, sizeof(gEvent.toVersion), toVersion);
  copyStr(gEvent.reason, sizeof(gEvent.reason), reason);
  // Channel parameter is ignored for now since PendingEvent doesn't store it
}

void publishEvent(PubSubClient& client, const char* state, const char* version, const char* reason = nullptr, const char* fromVersion = nullptr, const char* toVersion = nullptr, const char* channel = nullptr) {
  StaticJsonDocument<256> doc;
  doc["schema"] = "v1";
  doc["state"] = state ? state : "unknown";
  if (version && version[0]) {
    doc["version"] = version;
  }
  if (channel && channel[0]) {
    doc["channel"] = channel;
  }
  if (reason && reason[0]) {
    doc["reason"] = reason;
  }
  if (fromVersion && fromVersion[0]) {
    doc["from"] = fromVersion;
  }
  if (toVersion && toVersion[0]) {
    doc["to"] = toVersion;
  }
  char payload[256];
  size_t n = serializeJson(doc, payload, sizeof(payload));
  (void)n;
  client.publish(SF::Topics::eventOta(), payload, false);
}

bool flushQueued(PubSubClient& client) {
  if (!gEvent.active) return false;
  publishEvent(client, gEvent.state, gEvent.version, gEvent.reason, gEvent.fromVersion, gEvent.toVersion, gState.pendingChannel);
  gEvent.active = false;
  return true;
}

struct ParsedCommand {
  char version[kVersionLen];
  char url[256];
  uint32_t size = 0;
  uint8_t sha256[32];
  char channel[kChannelLen];
  bool staged = true;
  bool force = false;
};

bool downloadAndStage(const ParsedCommand& cmd, PubSubClient& client, char* error, size_t errorLen) {
  WiFiClient wifiClient;
  HTTPClient http;
  if (!http.begin(wifiClient, cmd.url)) {
    std::snprintf(error, errorLen, "http_begin_failed");
    return false;
  }
  int resp = http.GET();
  if (resp != HTTP_CODE_OK) {
    std::snprintf(error, errorLen, "http_%d", resp);
    http.end();
    return false;
  }
  int contentLength = http.getSize();
  if (cmd.size > 0 && contentLength > 0 && static_cast<uint32_t>(contentLength) != cmd.size) {
    std::snprintf(error, errorLen, "size_mismatch");
    http.end();
    return false;
  }
  const size_t updateSize = cmd.size ? cmd.size : (contentLength > 0 ? static_cast<size_t>(contentLength) : static_cast<size_t>(UPDATE_SIZE_UNKNOWN));
  if (!Update.begin(updateSize)) {
    std::snprintf(error, errorLen, "update_begin");
    http.end();
    return false;
  }

  WiFiClient* stream = http.getStreamPtr();
  constexpr size_t kBufSize = 2048;
  uint8_t buffer[kBufSize];
  size_t total = 0;
  unsigned long lastProgress = 0;
  mbedtls_sha256_context shaCtx;
  mbedtls_sha256_init(&shaCtx);
  mbedtls_sha256_starts(&shaCtx, 0);

  while (http.connected()) {
    size_t available = stream->available();
    if (available == 0) {
      if (!http.connected()) break;
      delay(10);
      continue;
    }
    size_t toRead = available > kBufSize ? kBufSize : available;
    int read = stream->readBytes(reinterpret_cast<char*>(buffer), toRead);
    if (read <= 0) {
      delay(5);
      continue;
    }
    if (Update.write(buffer, read) != static_cast<size_t>(read)) {
      mbedtls_sha256_free(&shaCtx);
      Update.abort();
      std::snprintf(error, errorLen, "update_write");
      http.end();
      return false;
    }
    mbedtls_sha256_update(&shaCtx, buffer, read);
    total += static_cast<size_t>(read);

    // Publish progress every 2 seconds
    if (millis() - lastProgress > 2000 && updateSize > 0) {
      lastProgress = millis();
      int percent = (total * 100) / updateSize;
      StaticJsonDocument<128> progressDoc;
      progressDoc["status"] = "downloading";
      progressDoc["version"] = cmd.version;
      progressDoc["progress"] = percent;
      progressDoc["bytes"] = total;
      progressDoc["total"] = updateSize;
      char progressPayload[128];
      serializeJson(progressDoc, progressPayload, sizeof(progressPayload));
      client.publish(SF::Topics::eventOta(), progressPayload, false);
      Serial.print("OTA Download: ");
      Serial.print(percent);
      Serial.println("%");
    }
  }

  uint8_t digest[32];
  mbedtls_sha256_finish(&shaCtx, digest);
  mbedtls_sha256_free(&shaCtx);

  if (cmd.size && total != cmd.size) {
    Update.abort();
    http.end();
    std::snprintf(error, errorLen, "size_bytes");
    return false;
  }

  if (std::memcmp(digest, cmd.sha256, sizeof(digest)) != 0) {
    Update.abort();
    http.end();
    std::snprintf(error, errorLen, "sha256_mismatch");
    return false;
  }

  if (!Update.end(true)) {
    Update.abort();
    http.end();
    std::snprintf(error, errorLen, "update_end");
    return false;
  }

  if (!Update.isFinished()) {
    http.end();
    std::snprintf(error, errorLen, "update_incomplete");
    return false;
  }

  http.end();
  return true;
}

}  // namespace

void begin() {
  ensureStateLoaded();
}

const char* runningVersion() {
  return kFwVersion;
}

const char* lastGoodVersion() {
  ensureStateLoaded();
  return gState.lastGood;
}

const char* pendingVersion() {
  ensureStateLoaded();
  return gState.pending;
}

bool hasPending() {
  ensureStateLoaded();
  return gState.pending[0] != '\0';
}

bool awaitingHealth() {
  return SF::BootHealth::awaitingHealth();
}

bool processCommand(PubSubClient& client, ArduinoJson::JsonObjectConst cmd, char* error, size_t errorLen) {
  ensureStateLoaded();
  ParsedCommand parsed{};

  const char* version = cmd["version"].as<const char*>();
  const char* url = cmd["url"].as<const char*>();
  const char* channel = cmd["channel"].as<const char*>();
  const char* shaHex = cmd["sha256"].as<const char*>();
  bool stagedPresent = cmd.containsKey("staged");
  bool staged = cmd["staged"].as<bool>();
  bool force = cmd["force"].as<bool>();
  uint32_t size = cmd["size"].as<uint32_t>();

  if (!version || !url || !shaHex || !stagedPresent || size == 0) {
    std::snprintf(error, errorLen, "missing_fields");
    return false;
  }
  if (!parseSha(shaHex, parsed.sha256)) {
    std::snprintf(error, errorLen, "bad_sha256");
    return false;
  }
  copyStr(parsed.version, sizeof(parsed.version), version);
  copyStr(parsed.url, sizeof(parsed.url), url);
  copyStr(parsed.channel, sizeof(parsed.channel), channel);
  parsed.size = size;
  parsed.staged = staged;
  parsed.force = force;

  if (!force && compareSemver(parsed.version, runningVersion()) <= 0) {
    std::snprintf(error, errorLen, "version_not_newer");
    return false;
  }

  if (hasPending() && compareSemver(parsed.version, pendingVersion()) <= 0 && !force) {
    std::snprintf(error, errorLen, "pending_newer_or_equal");
    return false;
  }

  publishEvent(client, "download_started", parsed.version, nullptr, nullptr, nullptr, parsed.channel);
  SF::Log::info("ota", "download start %s", parsed.version);

  if (!downloadAndStage(parsed, client, error, errorLen)) {

    SF::Log::warn("ota", "download failed %s reason=%s", parsed.version, error);
    return false;
  }

  publishEvent(client, "download_ok", parsed.version, nullptr, nullptr, nullptr, parsed.channel);
  publishEvent(client, "verify_ok", parsed.version, nullptr, nullptr, nullptr, parsed.channel);

  copyStr(gState.pending, sizeof(gState.pending), parsed.version);
  copyStr(gState.pendingChannel, sizeof(gState.pendingChannel), parsed.channel);
  saveState();

  SF::BootHealth::prepareForPending(parsed.version, parsed.staged);

  publishEvent(client, "apply_pending", parsed.version, nullptr, nullptr, nullptr, parsed.channel);
  SF::Log::info("ota", "staged %s (staged=%s)", parsed.version, parsed.staged ? "true" : "false");
  if (!parsed.staged) {
    delay(100);
    ESP.restart();
  }
  return true;
}

void publishError(PubSubClient& client, const char* reason, const char* detail) {
  publishEvent(client, "error", nullptr, detail ? detail : reason);
}

void onMqttConnected(PubSubClient& client) {
  ensureStateLoaded();
  flushQueued(client);
}

void markApplySuccess() {
  ensureStateLoaded();
  char channelCopy[kChannelLen];
  copyStr(channelCopy, sizeof(channelCopy), gState.pendingChannel);
  copyStr(gState.lastGood, sizeof(gState.lastGood), runningVersion());
  gState.pending[0] = '\0';
  gState.pendingChannel[0] = '\0';
  saveState();
  esp_ota_mark_app_valid_cancel_rollback();
  queueAppliedEvent(runningVersion(), channelCopy);
  SF::Log::info("ota", "firmware marked valid %s", runningVersion());
}
void queueRollbackEvent(const char* fromVersion, const char* toVersion, const char* reason, bool immediateReboot, const char* channel) {
  ensureStateLoaded();
  char channelCopy[kChannelLen];
  copyStr(channelCopy, sizeof(channelCopy), channel ? channel : gState.pendingChannel);
  queueEvent("rollback", fromVersion, fromVersion, toVersion, reason, channelCopy);
  gState.pending[0] = '\0';
  gState.pendingChannel[0] = '\0';
  saveState();
  if (immediateReboot) {
    esp_ota_mark_app_invalid_rollback_and_reboot();
  }
}
void queueAppliedEvent(const char* version, const char* channel) {
  queueEvent("applied", version, nullptr, nullptr, nullptr, channel);
}
void clearPending() {
  ensureStateLoaded();
  gState.pending[0] = '\0';
  gState.pendingChannel[0] = '\0';
  saveState();
}

}  // namespace OtaManager
}  // namespace SF




