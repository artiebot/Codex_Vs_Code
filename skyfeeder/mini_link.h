#pragma once

#include <Arduino.h>

namespace SF {

using MiniStatusCallback = void (*)(const char* state, const char* ip, const char* rtsp);
using MiniSnapshotCallback = void (*)(bool ok, uint32_t bytes, const char* sha256, const char* path, const char* trigger);
using MiniWifiCallback = void (*)(bool ok, const char* reason, const char* op, const char* token);

void Mini_begin(unsigned long baud = 115200);
void Mini_loop();

bool Mini_sendWake();
bool Mini_sendSleep();
bool Mini_requestStatus();
bool Mini_requestSnapshot();
bool Mini_stageWifi(const char* ssid, const char* psk, const char* token);
bool Mini_commitWifi(const char* token = nullptr);
bool Mini_abortWifi(const char* token = nullptr);

void Mini_setStatusCallback(MiniStatusCallback cb);
void Mini_setSnapshotCallback(MiniSnapshotCallback cb);
void Mini_setWifiCallback(MiniWifiCallback cb);

void Mini_logTo(Stream& out);

}  // namespace SF
