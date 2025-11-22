#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\log_service.h"
#pragma once
#include <PubSubClient.h>

namespace SF {
namespace LogService {
void begin(PubSubClient& client);
void handleMessage(PubSubClient& client, const char* topic, const uint8_t* payload, unsigned int length);
}
} // namespace SF
