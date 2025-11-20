#pragma once

#include <Arduino.h>

namespace SF {

using MiniStatusCallback = void (*)(const char* state, const char* ip, const char* rtsp, bool settled);
using MiniSnapshotCallback = void (*)(bool ok, uint32_t bytes, const char* sha256, const char* path, const char* trigger);
using MiniWifiCallback = void (*)(bool ok, const char* reason, const char* op, const char* token);
using MiniEventCallback = void (*)(const char* phase, const char* trigger, uint8_t index, uint8_t total, uint16_t seconds, bool ok);
using MiniLifecycleCallback = void (*)(const char* kind, uint32_t ts, const char* fw, bool camera, bool rtsp);

void Mini_begin(unsigned long baud = 115200);
void Mini_loop();

bool Mini_sendWake();
bool Mini_sendSleep();
bool Mini_sendSleepDeep();
bool Mini_requestStatus();
bool Mini_requestSnapshot();
bool Mini_requestEventCapture(uint8_t snapshotCount, uint16_t videoSeconds, const char* trigger = nullptr, float weightG = 0.0f);
bool Mini_stageWifi(const char* ssid, const char* psk, const char* token);
bool Mini_commitWifi(const char* token = nullptr);
bool Mini_abortWifi(const char* token = nullptr);
bool Mini_wakePulse(uint16_t ms = 80);
bool Mini_powerCycle(uint16_t offMs = 500, uint16_t onDelayMs = 0);

void Mini_setStatusCallback(MiniStatusCallback cb);
void Mini_setSnapshotCallback(MiniSnapshotCallback cb);
void Mini_setWifiCallback(MiniWifiCallback cb);
void Mini_setEventCallback(MiniEventCallback cb);
void Mini_setLifecycleCallback(MiniLifecycleCallback cb);

void Mini_logTo(Stream& out);

}  // namespace SF


