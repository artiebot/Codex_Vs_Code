#pragma once

#include <Arduino.h>
#include <ArduinoJson.h>

namespace SF {

class MiniLink {
 public:
  void begin(unsigned long baud = 115200);
  void loop();

  bool handleCommand(JsonVariantConst cmd, char* err, size_t errLen);
  bool sendWake();
  bool sendSleep();
  bool requestStatus();

  const char* state() const { return state_; }
  const char* lastReason() const { return lastReason_; }
  unsigned long lastStatusMs() const { return lastStatusMs_; }
  const char* lastStatusRaw() const { return lastStatusRaw_; }
  bool hasRecentStatus(unsigned long maxAgeMs = 5000) const;

 private:
  bool sendOp(const char* op);
  void processLine(const char* line);
  void writeErr(char* err, size_t errLen, const char* msg);
  void updateState(const char* state, const char* reason);

  HardwareSerial* serial_ = nullptr;
  char rxBuf_[256];
  size_t rxLen_ = 0;
  unsigned long lastStatusMs_ = 0;
  unsigned long lastTxMs_ = 0;
  bool awaitingStatus_ = false;
  char state_[16] = "unknown";
  char lastReason_[16] = "";
  char lastStatusRaw_[192] = "";
};

extern MiniLink miniLink;

}  // namespace SF

