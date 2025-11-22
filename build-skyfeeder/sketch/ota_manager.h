#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\ota_manager.h"
#pragma once

#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include <PubSubClient.h>
#include <cstdint>
#include <cstddef>

namespace SF {
namespace OtaManager {

void begin();
const char* runningVersion();
const char* lastGoodVersion();
const char* pendingVersion();
const char* lastAppliedChannel();
bool hasPending();
bool awaitingHealth();

bool processCommand(PubSubClient& client, ArduinoJson::JsonObjectConst cmd, char* error, size_t errorLen);

void publishError(PubSubClient& client, const char* reason, const char* detail = nullptr);
void onMqttConnected(PubSubClient& client);

void markApplySuccess();
void queueRollbackEvent(const char* fromVersion, const char* toVersion, const char* reason, bool immediateReboot, const char* channel = nullptr);
void queueAppliedEvent(const char* version, const char* channel = nullptr);

void clearPending();

}  // namespace OtaManager
}  // namespace SF

