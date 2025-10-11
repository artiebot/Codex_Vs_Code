#include "mini_link.h"

#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include <cstring>

#include "logging.h"
#include "pins_board.h"

namespace {
constexpr size_t kRxBuf = 256;
constexpr size_t kLogCapacity = 24;

HardwareSerial* miniSerial = nullptr;
char rxBuffer[kRxBuf];
size_t rxLen = 0;

struct LogEntry {
  unsigned long ts;
  char dir;
  String line;
};
LogEntry logRing[kLogCapacity];
size_t logCount = 0;
size_t logHead = 0;

SF::MiniStatusCallback statusCb = nullptr;
SF::MiniSnapshotCallback snapshotCb = nullptr;
SF::MiniWifiCallback wifiCb = nullptr;

void pushLog(char dir, const char* line) {
  if (!line) line = "";
  logRing[logHead] = {millis(), dir, String(line)};
  logHead = (logHead + 1) % kLogCapacity;
  if (logCount < kLogCapacity) ++logCount;
}

bool writeLine(const JsonDocument& doc) {
  if (!miniSerial) return false;
  String out;
  serializeJson(doc, out);
  pushLog('>', out.c_str());
  Serial.print("[mini] >> ");
  Serial.println(out);
  miniSerial->println(out);
  return true;
}

void handleStatus(const JsonDocument& doc) {
  const char* state = doc["state"] | "";
  const char* ip = doc["ip"] | "";
  const char* rtsp = doc["rtsp"] | "";
  if (statusCb) statusCb(state, ip, rtsp);
}

void handleSnapshot(const JsonDocument& doc) {
  bool ok = doc["ok"].as<bool>();
  uint32_t bytes = doc["bytes"].as<uint32_t>();
  const char* sha = doc["sha256"] | "";
  const char* path = doc["path"] | "";
  const char* trigger = doc["trigger"] | "";
  if (snapshotCb) snapshotCb(ok, bytes, sha, path, trigger);
}

void handleWifiTest(const JsonDocument& doc) {
  bool ok = doc["ok"].as<bool>();
  const char* reason = doc["reason"] | "";
  const char* op = doc["op"] | "";
  const char* token = doc["token"] | "";
  if (wifiCb) wifiCb(ok, reason, op, token);
}

void processLine(const char* line) {
  if (!line || !line[0]) return;
  pushLog('<', line);
  Serial.print("[mini] << ");
  Serial.println(line);
  StaticJsonDocument<256> doc;
  auto err = deserializeJson(doc, line);
  if (err) {
    SF::Log::warn("mini", "bad json: %s", err.c_str());
    return;
  }
  const char* type = doc["mini"] | "";
  if (strcmp(type, "status") == 0) {
    handleStatus(doc);
  } else if (strcmp(type, "snapshot") == 0) {
    handleSnapshot(doc);
  } else if (strcmp(type, "wifi_test") == 0) {
    handleWifiTest(doc);
  } else if (strcmp(type, "error") == 0) {
    const char* msg = doc["msg"] | "";
    SF::Log::warn("mini", "error: %s", msg);
  } else {
    SF::Log::info("mini", "unhandled frame: %s", type);
  }
}

bool queueOp(const char* op) {
  if (!miniSerial || !op) return false;
  StaticJsonDocument<96> doc;
  doc["op"] = op;
  return writeLine(doc);
}

bool queueWifiOp(const char* op, const char* ssid = nullptr, const char* psk = nullptr, const char* token = nullptr) {
  if (!miniSerial || !op) return false;
  StaticJsonDocument<192> doc;
  doc["op"] = op;
  if (ssid && ssid[0]) doc["ssid"] = ssid;
  if (psk && psk[0]) doc["psk"] = psk;
  if (token && token[0]) doc["token"] = token;
  return writeLine(doc);
}

}  // namespace

namespace SF {

void Mini_begin(unsigned long baud) {
  miniSerial = &Pins::miniSerial();
  miniSerial->begin(baud, SERIAL_8N1, Pins::MiniUartRx, Pins::MiniUartTx);
  rxLen = 0;
  logCount = 0;
  logHead = 0;
  pushLog('=', "open");
  if (Pins::MiniPowerEnable >= 0) {
    pinMode(Pins::MiniPowerEnable, OUTPUT);
    digitalWrite(Pins::MiniPowerEnable, HIGH);
  }
  if (Pins::MiniWake >= 0) {
    pinMode(Pins::MiniWake, OUTPUT);
    digitalWrite(Pins::MiniWake, HIGH);
  }
}

void Mini_loop() {
  if (!miniSerial) return;
  while (miniSerial->available()) {
    char c = static_cast<char>(miniSerial->read());
    if (c == '\r') continue;
    if (c == '\n') {
      if (rxLen > 0) {
        rxBuffer[rxLen] = '\0';
        processLine(rxBuffer);
        rxLen = 0;
      }
    } else {
      if (rxLen + 1 < kRxBuf) {
        rxBuffer[rxLen++] = c;
      } else {
        rxLen = 0;
      }
    }
  }
}

bool Mini_sendWake() {
  if (Pins::MiniWake >= 0) {
    digitalWrite(Pins::MiniWake, HIGH);
  }
  return queueOp("wake");
}

bool Mini_sendSleep() {
  bool ok = queueOp("sleep");
  if (Pins::MiniWake >= 0) {
    digitalWrite(Pins::MiniWake, LOW);
  }
  return ok;
}

bool Mini_requestStatus() {
  return queueOp("status");
}

bool Mini_requestSnapshot() {
  return queueOp("snapshot");
}

bool Mini_stageWifi(const char* ssid, const char* psk, const char* token) {
  return queueWifiOp("stage_wifi", ssid, psk, token);
}

bool Mini_commitWifi(const char* token) {
  return queueWifiOp("commit_wifi", nullptr, nullptr, token);
}

bool Mini_abortWifi(const char* token) {
  return queueWifiOp("abort_wifi", nullptr, nullptr, token);
}

void Mini_setStatusCallback(MiniStatusCallback cb) { statusCb = cb; }
void Mini_setSnapshotCallback(MiniSnapshotCallback cb) { snapshotCb = cb; }
void Mini_setWifiCallback(MiniWifiCallback cb) { wifiCb = cb; }

void Mini_logTo(Stream& out) {
  out.println(F("-- mini link log --"));
  size_t idx = logCount < kLogCapacity ? 0 : logHead;
  for (size_t i = 0; i < logCount; ++i) {
    size_t slot = (idx + i) % kLogCapacity;
    const auto& entry = logRing[slot];
    out.print('[');
    out.print(entry.ts);
    out.print("] ");
    out.print(entry.dir);
    out.print(' ');
    out.println(entry.line);
  }
}

}  // namespace SF

