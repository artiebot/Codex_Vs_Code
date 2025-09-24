#pragma once
#include <PubSubClient.h>

namespace SF {
namespace LogService {
void begin(PubSubClient& client);
void handleMessage(PubSubClient& client, const char* topic, const uint8_t* payload, unsigned int length);
}
} // namespace SF
