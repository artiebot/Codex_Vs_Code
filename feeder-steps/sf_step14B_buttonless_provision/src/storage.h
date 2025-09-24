#pragma once
#include <Arduino.h>

namespace Storage {
struct WifiConfig {
  char ssid[33];
  char password[65];
  bool valid=false;
};

struct MqttConfig {
  char host[65];
  uint16_t port=0;
  bool tls=false;
  char user[33];
  char pass[33];
  bool hostSet=false;
  bool credsSet=false;
};

void begin();

bool loadWifi(WifiConfig& out);
bool saveWifi(const WifiConfig& in);

bool loadMqtt(MqttConfig& out);
bool saveMqtt(const MqttConfig& in);

bool loadDeviceId(char* out, size_t len);
bool saveDeviceId(const char* id);

void clearWifi();
void clearMqttCreds();

struct BootCounter {
  uint32_t count=0;
  uint64_t lastUs=0;
};
void loadBootCounter(BootCounter& out);
void saveBootCounter(const BootCounter& info);
void resetBootCounter();
}
