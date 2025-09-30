#pragma once

#include <cstdint>
#include <cstddef>

class PubSubClient;
class JsonObjectConst;

namespace SF {
namespace OtaManager {

void begin();
const char* runningVersion();
const char* lastGoodVersion();
const char* pendingVersion();
bool hasPending();
bool awaitingHealth();

bool processCommand(PubSubClient& client, JsonObjectConst cmd, char* error, size_t errorLen);

void publishError(PubSubClient& client, const char* reason, const char* detail = nullptr);
void onMqttConnected(PubSubClient& client);

void markApplySuccess();
void queueRollbackEvent(const char* fromVersion, const char* toVersion, const char* reason, bool immediateReboot, const char* channel = nullptr);
void queueAppliedEvent(const char* version, const char* channel = nullptr);

void clearPending();

}  // namespace OtaManager
}  // namespace SF

