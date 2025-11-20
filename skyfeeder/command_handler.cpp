#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include <cstring>
#include <esp_task_wdt.h>

#include "topics.h"
#include "mqtt_client.h"
#include "led_service.h"
#include "ws2812_service.h"
#include "power_manager.h"
#include "weight_service.h"
#include "led_ux.h"
#include "camera_service_esp.h"
#include "mini_link.h"
#include "config.h"
#include "log_service.h"
#include "logging.h"
#include "ota_service.h"
#include "visit_service.h"
#include <ctime>

namespace {
enum class MiniArmState {
  Idle,
  ArmedWaking,
  ArmedWaitBoot,
  ArmedWaitReady,
  ArmedSettling,
  ArmedReady,
  VisitCapturing,
  Disarming
};

void publishAck(const char* cmd, bool ok, const char* msg = nullptr) {
  StaticJsonDocument<160> doc;
  doc["cmd"] = cmd;
  doc["ok"] = ok;
  if (msg) {
    doc["msg"] = msg;
  }
  char buf[160];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  (void)n;
  SF::mqtt.raw().publish(SF::Topics::ack(), buf, false);
}

uint32_t unixNow() {
  time_t now = time(nullptr);
  if (now <= 0) {
    return static_cast<uint32_t>(millis() / 1000);
  }
  return static_cast<uint32_t>(now);
}

void publishCamAck(bool ok, const char* code, const char* msg, const char* op, const char* token = nullptr) {
  StaticJsonDocument<192> doc;
  doc["ok"] = ok;
  doc["code"] = code ? code : "";
  doc["cmd"] = "cam";
  doc["op"] = op ? op : "";
  if (msg && msg[0]) {
    doc["msg"] = msg;
  }
  if (token && token[0]) {
    doc["token"] = token;
  }
  doc["ts"] = unixNow();

  char buf[192];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  (void)n;
  SF::mqtt.raw().publish(SF::Topics::eventAck(), buf, false);
}

void publishSnapshotEvent(bool ok, uint32_t bytes, const char* sha, const char* path, const char* trigger) {
  StaticJsonDocument<224> doc;
  doc["ok"] = ok;
  doc["bytes"] = bytes;
  doc["sha256"] = sha ? sha : "";
  doc["url"] = "";
  doc["source"] = "mini";
  doc["trigger"] = (trigger && trigger[0]) ? trigger : "cmd";
  doc["ts"] = unixNow();

  char buf[224];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  (void)n;
  SF::mqtt.raw().publish(SF::Topics::eventCameraSnapshot(), buf, false);
}

void copyString(char* dst, size_t len, const char* src) {
  if (!dst || len == 0) return;
  if (!src) src = "";
  std::strncpy(dst, src, len);
  dst[len - 1] = '\0';
}

char gMiniState[16] = "";
char gMiniIp[32] = "";
char gMiniRtsp[96] = "";
bool gMiniActive = false;
bool gMiniSettled = false;
bool gSleepInFlight = false;
bool gSnapshotPending = false;
bool gVisitActive = false;
bool gVisitMediaCaptured = false;
bool gVisitMetadataOnly = false;
unsigned long gMiniLastStatusMs = 0;
unsigned long gMiniLastActivityMs = 0;

struct SnapshotRecord {
  bool ready = false;
  bool ok = false;
  uint32_t bytes = 0;
};

SnapshotRecord gSnapshotResult;
bool gEventCapturePending = false;
unsigned long gEventCaptureStartMs = 0;

constexpr unsigned long kMiniIdleSleepMs = 90000;  // 90s to allow upload retries
constexpr unsigned long kMiniWakeTimeoutMs = 15000;
constexpr unsigned long kMiniSettleTimeoutMs = 1500;
constexpr unsigned long kMiniSnapshotTimeoutMs = 5000;
constexpr unsigned long kMiniEventTimeoutMs = 15000;
constexpr unsigned long kMiniWakePulseIntervalMs = 2000;
constexpr unsigned long kMiniBootTimeoutMs = 8000;
constexpr unsigned long kMiniReadyTimeoutMs = 8000;
constexpr uint8_t kMiniWakeMaxRetries = 3;
constexpr unsigned long kMiniErrorWindowMs = 60UL * 60UL * 1000UL;  // 1 hour
constexpr uint8_t kMiniErrorThreshold = 5;

MiniArmState gArmState = MiniArmState::Idle;
bool gMiniBootSeen = false;
bool gMiniReadySeen = false;
bool gMiniDegraded = false;

bool miniLikelyPresent() {
  if (gMiniDegraded) return false;
  if (gMiniLastStatusMs != 0) return true;
  if (gMiniActive) return true;
  if (gMiniReadySeen) return true;
  if (gMiniBootSeen) return true;
  return false;
}

unsigned long gWakePulseMs = 0;
unsigned long gBootSeenMs = 0;
unsigned long gReadySeenMs = 0;
unsigned long gSettleDueMs = 0;
uint8_t gWakeRetryCount = 0;
bool gCaptureQueued = false;
const char* gCaptureReason = nullptr;
unsigned long gVisitStartMs = 0;
float gVisitPeakDelta = 0.0f;
unsigned long gVisitEndMs = 0;

const char* reasonArmedReady = "armed_ready";
const char* reasonLateReady = "late_ready";
const char* reasonNoCapture = "no_capture_ready";

unsigned long gMiniErrorWindowStartMs = 0;
uint8_t gMiniErrorCount = 0;

void markMiniActivity() { gMiniLastActivityMs = millis(); }

void publishSysState(const char* state) {
  StaticJsonDocument<160> doc;
  doc["ts"] = unixNow();
  doc["state"] = state;
  char buf[160];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  (void)n;
  SF::mqtt.raw().publish(SF::Topics::eventSys(), buf, false);
  Serial.print("[sys] ");
  Serial.println(buf);
}

void publishVisitEvent(const char* type, float delta = 0.0f, unsigned long durationMs = 0, const char* reason = nullptr) {
  StaticJsonDocument<192> doc;
  doc["ts"] = unixNow();
  doc["type"] = type;
  if (std::strcmp(type, "start") == 0) {
    doc["delta"] = delta;
  } else if (std::strcmp(type, "capture") == 0) {
    if (reason && reason[0]) doc["reason"] = reason;
  } else if (std::strcmp(type, "end") == 0) {
    doc["dur_ms"] = durationMs;
    doc["delta"] = delta;
    if (reason && reason[0]) doc["reason"] = reason;
  }
  char buf[192];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  (void)n;
  SF::mqtt.raw().publish(SF::Topics::eventVisit(), buf, false);
  Serial.print("[visit] ");
  Serial.println(buf);
}

void recordMiniSuccess() {
  gMiniErrorWindowStartMs = 0;
  gMiniErrorCount = 0;
  if (gMiniDegraded) {
    gMiniDegraded = false;
    publishSysState("mini_recovered");
  }
}

void recordMiniError(const char* code) {
  unsigned long now = millis();
  bool windowExpired = false;
  if (gMiniErrorWindowStartMs == 0 || now < gMiniErrorWindowStartMs) {
    windowExpired = true;
  } else if ((now - gMiniErrorWindowStartMs) > kMiniErrorWindowMs) {
    windowExpired = true;
  }

  if (windowExpired) {
    gMiniErrorWindowStartMs = now;
    gMiniErrorCount = 1;
  } else if (gMiniErrorCount < 255) {
    ++gMiniErrorCount;
  }

  SF::Log::warn("mini", "error code=%s count=%u", code ? code : "unknown", gMiniErrorCount);

  if (!gMiniDegraded && gMiniErrorCount >= kMiniErrorThreshold) {
    bool powerCycled = SF::Mini_powerCycle();
    gMiniDegraded = true;
    publishSysState(powerCycled ? "mini_degraded_power_cycle" : "mini_degraded");
  }
}

void onMiniStatus(const char* state, const char* ip, const char* rtsp, bool settled) {
  copyString(gMiniState, sizeof(gMiniState), state);
  copyString(gMiniIp, sizeof(gMiniIp), ip);
  copyString(gMiniRtsp, sizeof(gMiniRtsp), rtsp);
  gMiniSettled = settled;
  gMiniLastStatusMs = millis();

  if (std::strcmp(gMiniState, "active") == 0) {
    gMiniActive = true;
    gSleepInFlight = false;
    if (settled) {
      markMiniActivity();
    }
  } else if (std::strcmp(gMiniState, "sleep_deep") == 0) {
    gMiniActive = false;
    gMiniSettled = false;
    gSleepInFlight = false;
  }

  SF::Log::info("mini", "state=%s settled=%s ip=%s", gMiniState, settled ? "true" : "false", gMiniIp);
  Serial.print("[mini] state="); Serial.print(gMiniState);
  Serial.print(" settled="); Serial.print(settled ? "true" : "false");
  Serial.print(" ip="); Serial.print(gMiniIp);
  Serial.print(" rtsp=");
  Serial.println(gMiniRtsp[0] ? gMiniRtsp : "(none)");
}

void onMiniSnapshot(bool ok, uint32_t bytes, const char* sha, const char* path, const char* trigger) {
  publishSnapshotEvent(ok, bytes, sha, path, trigger);
  Serial.print("[mini] snapshot ok="); Serial.print(ok ? "true" : "false");
  Serial.print(" bytes="); Serial.println(bytes);
  gSnapshotResult.ready = true;
  gSnapshotResult.ok = ok;
  gSnapshotResult.bytes = bytes;
  markMiniActivity();
  gSnapshotPending = false;
}

void onMiniWifi(bool ok, const char* reason, const char* op, const char* token) {
  const char* code = (reason && reason[0]) ? reason : (ok ? "ok" : "fail");
  const char* ackOp = (op && op[0]) ? op : "wifi_test";
  publishCamAck(ok, code, nullptr, ackOp, (token && token[0]) ? token : nullptr);
  if (ok) {
    SF::Log::info("mini", "wifi test ok (op=%s)", ackOp);
    Serial.print("[mini] wifi test ok");
  } else {
    SF::Log::warn("mini", "wifi test fail: %s (op=%s)", reason ? reason : "", ackOp);
    Serial.print("[mini] wifi test fail: ");
  }
  if (token && token[0]) {
    Serial.print(" token=");
    Serial.print(token);
  }
  if (reason && reason[0]) {
    Serial.print(" reason=");
    Serial.print(reason);
  }
  Serial.println();
}

void onMiniEvent(const char* phase, const char* trigger, uint8_t index, uint8_t total, uint16_t seconds, bool ok) {
  SF::Log::info("mini", "event phase=%s trigger=%s idx=%u/%u sec=%u ok=%s",
                phase ? phase : "(null)",
                trigger ? trigger : "",
                static_cast<unsigned>(index),
                static_cast<unsigned>(total),
                static_cast<unsigned>(seconds),
                ok ? "true" : "false");
  Serial.print("[mini] event phase=");
  Serial.print(phase ? phase : "(null)");
  if (trigger && trigger[0]) {
    Serial.print(" trigger=");
    Serial.print(trigger);
  }
  if (total > 0) {
    Serial.print(" total=");
    Serial.print(total);
  }
  if (index > 0) {
    Serial.print(" index=");
    Serial.print(index);
  }
  if (seconds > 0) {
    Serial.print(" seconds=");
    Serial.print(seconds);
  }
  Serial.print(" ok=");
  Serial.println(ok ? "true" : "false");

  if (phase && std::strcmp(phase, "done") == 0) {
    gEventCapturePending = false;
    gVisitMediaCaptured = ok;
    publishVisitEvent("capture_done", 0.0f, 0, ok ? "ok" : "error");
    gCaptureQueued = false;
    gArmState = MiniArmState::Disarming;
  }
  markMiniActivity();
}

void onMiniLifecycle(const char* kind, uint32_t ts, const char* fw, bool camera, bool rtsp) {
  if (!kind) return;
  if (std::strcmp(kind, "boot") == 0) {
    gMiniBootSeen = true;
    gBootSeenMs = millis();
    publishSysState("mini_boot_seen");
    if (gArmState == MiniArmState::ArmedWaking || gArmState == MiniArmState::ArmedWaitBoot) {
      gArmState = MiniArmState::ArmedWaitReady;
    }
  } else if (std::strcmp(kind, "ready") == 0) {
    gMiniReadySeen = true;
    gReadySeenMs = millis();
    gSettleDueMs = gReadySeenMs + MINI_READY_SETTLE_MS;
    publishSysState("mini_ready_seen");
    if (gArmState == MiniArmState::ArmedWaitReady || gArmState == MiniArmState::ArmedSettling) {
      gArmState = MiniArmState::ArmedSettling;
    }
  } else if (std::strcmp(kind, "sleep_deep") == 0) {
    publishSysState("mini_sleep_deep");
    gArmState = MiniArmState::Idle;
    gMiniBootSeen = false;
    gMiniReadySeen = false;
    gCaptureQueued = false;
    gCaptureReason = nullptr;
    gEventCapturePending = false;
    gVisitActive = false;
    gVisitMediaCaptured = false;
    gVisitMetadataOnly = false;
  }
}

struct MiniCallbackRegistrar {
  MiniCallbackRegistrar() {
    SF::Mini_setStatusCallback(onMiniStatus);
    SF::Mini_setSnapshotCallback(onMiniSnapshot);
    SF::Mini_setWifiCallback(onMiniWifi);
    SF::Mini_setEventCallback(onMiniEvent);
    SF::Mini_setLifecycleCallback(onMiniLifecycle);
  }
} miniCallbackRegistrar;

void pumpMiniWhileWaiting() {
  SF::Mini_loop();
  #if WATCHDOG_TIMEOUT_SEC > 0
    esp_task_wdt_reset();  // Prevent watchdog timeout during long AMB82 wake waits
  #endif
  delay(10);
}

bool waitForMiniState(const char* desired, unsigned long timeoutMs) {
  unsigned long start = millis();
  while (millis() - start < timeoutMs) {
    if (std::strcmp(gMiniState, desired) == 0) {
      return true;
    }
    pumpMiniWhileWaiting();
  }
  return std::strcmp(gMiniState, desired) == 0;
}

bool waitForMiniSettled(unsigned long timeoutMs) {
  unsigned long start = millis();
  while (millis() - start < timeoutMs) {
    if (gMiniSettled) {
      return true;
    }
    pumpMiniWhileWaiting();
  }
  return gMiniSettled;
}

bool waitForSnapshotResult(unsigned long timeoutMs, SnapshotRecord& out) {
  unsigned long start = millis();
  while (millis() - start < timeoutMs) {
    if (gSnapshotResult.ready) {
      out = gSnapshotResult;
      gSnapshotResult.ready = false;
      return true;
    }
    pumpMiniWhileWaiting();
  }
  if (gSnapshotResult.ready) {
    out = gSnapshotResult;
    gSnapshotResult.ready = false;
    return true;
  }
  return false;
}

bool ensureMiniReady(const char*& codeOut) {
  if (!miniLikelyPresent()) {
    codeOut = "NO_MINI";
    Serial.println("[cmd/cam] Mini unavailable before wake");
    recordMiniError(codeOut);
    return false;
  }
  markMiniActivity();
  if (!SF::Mini_wakePulse()) {
    codeOut = "WAKE_PIN";
    SF::Log::warn("cmd/cam", "wake pulse skipped (pin < 0)");
    recordMiniError(codeOut);
    return false;
  }

  if (!waitForMiniState("active", kMiniWakeTimeoutMs)) {
    codeOut = "WAKE_TIMEOUT";
    Serial.println("[cmd/cam] Mini wake timeout");
    recordMiniError(codeOut);
    return false;
  }

  if (!waitForMiniSettled(kMiniSettleTimeoutMs)) {
    codeOut = "SETTLE_TIMEOUT";
    Serial.println("[cmd/cam] Mini settle timeout");
    recordMiniError(codeOut);
    return false;
  }

  recordMiniSuccess();
  return true;
}

bool runSnapshotSequence(const char*& codeOut) {
  if (!miniLikelyPresent()) {
    codeOut = "NO_MINI";
    Serial.println("[cmd/cam] Mini not detected; aborting snapshot");
     recordMiniError(codeOut);
    return false;
  }
  Serial.println("[cmd/cam] Snapshot sequence start");
  if (!ensureMiniReady(codeOut)) {
    return false;
  }
  gSnapshotPending = true;
  gSnapshotResult.ready = false;
  if (!SF::Mini_requestSnapshot()) {
    gSnapshotPending = false;
    codeOut = "UART_WRITE";
    Serial.println("[cmd/cam] Snapshot UART write failed");
    recordMiniError(codeOut);
    return false;
  }

  SnapshotRecord result;
  if (!waitForSnapshotResult(kMiniSnapshotTimeoutMs, result)) {
    gSnapshotPending = false;
    codeOut = "SNAP_TIMEOUT";
    Serial.println("[cmd/cam] Snapshot result timeout");
    recordMiniError(codeOut);
    return false;
  }

  gSnapshotPending = false;
  if (!result.ok) {
    codeOut = "SNAP_FAIL";
    Serial.println("[cmd/cam] Snapshot reported failure");
    recordMiniError(codeOut);
    return false;
  }

  codeOut = "OK";
  markMiniActivity();
  Serial.println("[cmd/cam] Snapshot sequence success");
  return true;
}

bool runEventCapture(uint8_t snapshotCount, uint16_t videoSeconds, const char* trigger, float weightG, const char*& codeOut) {
  if (!miniLikelyPresent()) {
    codeOut = "NO_MINI";
    Serial.println("[event] Mini not detected; aborting capture");
    recordMiniError(codeOut);
    return false;
  }
  Serial.println("[event] Capture sequence start");
  if (!gMiniSettled) {
    if (!ensureMiniReady(codeOut)) {
      return false;
    }
  }
  if (!SF::Mini_requestEventCapture(snapshotCount, videoSeconds, trigger, weightG)) {
    codeOut = "UART_WRITE";
    Serial.println("[event] capture_event UART write failed");
    recordMiniError(codeOut);
    return false;
  }
  markMiniActivity();
  gEventCapturePending = true;
  gEventCaptureStartMs = millis();
  gCaptureQueued = true;
  gVisitMetadataOnly = false;
  gCaptureReason = (trigger && trigger[0]) ? trigger : reasonArmedReady;
  gArmState = MiniArmState::VisitCapturing;
  publishVisitEvent("capture", 0.0f, 0, gCaptureReason);
  Serial.println("[event] capture_event command sent");
  codeOut = "OK";
  return true;
}

void handleLed(byte* payload, unsigned int len) {
  StaticJsonDocument<256> doc;
  auto err = deserializeJson(doc, payload, len);
  if (err) {
    publishAck("led", false, "bad_json");
    return;
  }

  const char* applied = nullptr;
  char errmsg[32];
  bool ok = SF::ledUx.applyCommand(doc.as<JsonVariantConst>(), applied, errmsg, sizeof(errmsg));

  StaticJsonDocument<192> ack;
  ack["cmd"] = "led";
  ack["ok"] = ok;
  if (ok) {
    ack["pattern"] = applied ? applied : SF::ledUx.activePatternName();
    ack["brightness"] = SF::ws2812.brightness();
  } else {
    ack["msg"] = errmsg[0] ? errmsg : "apply_failed";
  }

  char buf[192];
  size_t n = serializeJson(ack, buf, sizeof(buf));
  (void)n;
  SF::mqtt.raw().publish(SF::Topics::ack(), buf, false);
}

void handleCalibrate(byte* payload, unsigned int len) {
  StaticJsonDocument<192> doc;
  auto err = deserializeJson(doc, payload, len);
  if (err) {
    publishAck("calibrate", false, "bad_json");
    return;
  }

  if (doc["tare"].as<bool>()) {
    bool ok = SF::weight.tare();
    publishAck("calibrate", ok, ok ? nullptr : "tare_wait");
    return;
  }

  if (doc.containsKey("known_mass_g")) {
    float mass = doc["known_mass_g"].as<float>();
    if (mass <= 0) {
      publishAck("calibrate", false, "mass_le_zero");
      return;
    }
    bool ok = SF::weight.calibrateKnownMass(mass);
    publishAck("calibrate", ok, ok ? nullptr : "cal_failed");
    return;
  }

  publishAck("calibrate", false, "missing_args");
}

void handleCamera(byte* payload, unsigned int len) {
  StaticJsonDocument<192> doc;
  auto err = deserializeJson(doc, payload, len);
  if (err) {
    publishAck("camera", false, "bad_json");
    return;
  }

  char errmsg[32];
  bool ok = SF::cameraEsp.handleCommand(doc.as<JsonVariantConst>(), errmsg, sizeof(errmsg));

  StaticJsonDocument<160> ack;
  ack["cmd"] = "camera";
  ack["ok"] = ok;
  ack["status"] = SF::cameraEsp.status();
  if (!ok) {
    ack["msg"] = errmsg[0] ? errmsg : "camera_fail";
  }

  char buf[160];
  size_t n = serializeJson(ack, buf, sizeof(buf));
  (void)n;
  SF::mqtt.raw().publish(SF::Topics::ack(), buf, false);
}

void handleMiniCam(byte* payload, unsigned int len) {
  StaticJsonDocument<256> doc;
  auto err = deserializeJson(doc, payload, len);
  if (err) {
    SF::Log::warn("cmd/cam", "json parse error: %s", err.c_str());
    publishCamAck(false, "BAD_PAYLOAD", err.c_str(), "");
    return;
  }

  const char* op = doc["op"] | "";
  if (!op || !op[0]) {
    SF::Log::warn("cmd/cam", "missing op field");
    publishCamAck(false, "BAD_PAYLOAD", "missing op", "");
    return;
  }

  SF::Log::info("cmd/cam", "op=%s len=%u", op, static_cast<unsigned>(len));
  Serial.print("[cmd/cam] op="); Serial.println(op);

  const char* tokenField = doc["token"] | "";
  const char* token = (tokenField && tokenField[0]) ? tokenField : nullptr;

  if (std::strcmp(op, "snapshot") == 0) {
    if (!miniLikelyPresent()) {
      publishCamAck(false, "NO_MINI", "mini_unavailable", op, token);
      return;
    }
    const char* code = "OK";
    bool ok = runSnapshotSequence(code);
    const char* msg = ok ? nullptr : code;
    publishCamAck(ok, code, msg, op, token);
    return;
  }

  if (std::strcmp(op, "sleep_deep") == 0 || std::strcmp(op, "sleep") == 0) {
    if (!miniLikelyPresent()) {
      publishCamAck(false, "NO_MINI", "mini_unavailable", "sleep_deep", token);
      return;
    }
    bool ok = SF::Mini_sendSleepDeep();
    if (ok) {
      gSleepInFlight = true;
      gMiniSettled = false;
      markMiniActivity();
    }
    publishCamAck(ok, ok ? "OK" : "UART_WRITE", ok ? nullptr : "sleep_deep_failed", "sleep_deep", token);
    return;
  }
  if (std::strcmp(op, "wake") == 0) {
    if (!miniLikelyPresent()) {
      publishCamAck(false, "NO_MINI", "mini_unavailable", op, token);
      return;
    }
    bool ok = SF::Mini_wakePulse();
    publishCamAck(ok, ok ? "OK" : "WAKE_PIN", ok ? nullptr : "wake_pulse_failed", op, token);
    return;
  }

  bool queued = false;
  const char* ackToken = nullptr;
  if (std::strcmp(op, "status") == 0) {
    if (!miniLikelyPresent()) {
      publishCamAck(false, "NO_MINI", "mini_unavailable", op, token);
      return;
    }
    queued = SF::Mini_requestStatus();
  } else if (std::strcmp(op, "stage_wifi") == 0) {
    if (!miniLikelyPresent()) {
      publishCamAck(false, "NO_MINI", "mini_unavailable", op, token);
      return;
    }
    const char* ssid = doc["ssid"] | "";
    const char* psk = doc["psk"] | "";
    if (!ssid || !ssid[0]) {
      publishCamAck(false, "BAD_PAYLOAD", "missing ssid", op, token);
      return;
    }
    ackToken = token;
    queued = SF::Mini_stageWifi(ssid, psk ? psk : "", token);
  } else if (std::strcmp(op, "commit_wifi") == 0) {
    if (!miniLikelyPresent()) {
      publishCamAck(false, "NO_MINI", "mini_unavailable", op, token);
      return;
    }
    ackToken = token;
    queued = SF::Mini_commitWifi(token);
  } else if (std::strcmp(op, "abort_wifi") == 0) {
    if (!miniLikelyPresent()) {
      publishCamAck(false, "NO_MINI", "mini_unavailable", op, token);
      return;
    }
    ackToken = token;
    queued = SF::Mini_abortWifi(token);
  } else {
    publishCamAck(false, "BAD_PAYLOAD", "unsupported op", op, token);
    return;
  }

  if (!queued) {
    publishCamAck(false, "UART_WRITE", "", op, ackToken);
    return;
  }

  publishCamAck(true, "SENT", nullptr, op, ackToken);
}
}  // namespace

void SF_registerCommandSubscriptions(PubSubClient& client) {
  client.subscribe(SF::Topics::cmdLed(), 1);
  client.subscribe(SF::Topics::cmdCalibrate(), 1);
  client.subscribe(SF::Topics::cmdCamera(), 1);
  client.subscribe(SF::Topics::cmdCam(), 1);
}

void SF_onMqttMessage(char* topic, byte* payload, unsigned int len) {
  SF::LogService::handleMessage(SF::mqtt.raw(), topic, payload, len);
  SF::OtaService::handleMessage(SF::mqtt.raw(), topic, payload, len);

  if (std::strcmp(topic, SF::Topics::cmdLed()) == 0) {
    handleLed(payload, len);
  } else if (std::strcmp(topic, SF::Topics::cmdCalibrate()) == 0) {
    handleCalibrate(payload, len);
  } else if (std::strcmp(topic, SF::Topics::cmdCamera()) == 0) {
    handleCamera(payload, len);
  } else if (std::strcmp(topic, SF::Topics::cmdCam()) == 0) {
    handleMiniCam(payload, len);
  }
}

bool SF_captureEvent(uint8_t snapshotCount, uint16_t videoSeconds, const char* trigger, float weightG) {
  const unsigned long now = millis();
  if (gSnapshotPending) {
    Serial.println("[event] capture blocked (snapshot pending)");
    return false;
  }
  if (gSleepInFlight) {
    Serial.println("[event] capture blocked (sleep in progress)");
    return false;
  }
  if (gEventCapturePending) {
    if (now - gEventCaptureStartMs < kMiniEventTimeoutMs) {
      Serial.println("[event] capture blocked (event pending)");
      return false;
    }
    gEventCapturePending = false;
  }
  const char* code = "OK";
  if (!runEventCapture(snapshotCount, videoSeconds, trigger, weightG, code)) {
    SF::Log::warn("event", "capture_event failed (%s)", code ? code : "err");
    return false;
  }
  SF::Log::info("event", "capture_event queued (snap=%u video=%u weight=%.1fg)", snapshotCount, videoSeconds, weightG);
  return true;
}

void SF_armForMotion() {
  if (gArmState == MiniArmState::VisitCapturing ||
      gArmState == MiniArmState::ArmedWaitBoot ||
      gArmState == MiniArmState::ArmedWaitReady ||
      gArmState == MiniArmState::ArmedSettling ||
      gArmState == MiniArmState::ArmedReady) {
    return;
  }

  gMiniBootSeen = false;
  gMiniReadySeen = false;
  gWakeRetryCount = 0;
  gWakePulseMs = 0;
  gCaptureQueued = false;
  gCaptureReason = nullptr;
  gVisitMetadataOnly = false;
  gVisitMediaCaptured = false;
  gSettleDueMs = 0;

  publishVisitEvent("arm", 0.0f, 0, "wake");
  if (SF::Mini_sendWake()) {
    gWakePulseMs = millis();
    gWakeRetryCount = 1;
    markMiniActivity();
    publishSysState("mini_wake_pulse");
    gArmState = MiniArmState::ArmedWaitBoot;
  } else {
    publishSysState("mini_wake_failed");
    gArmState = MiniArmState::Idle;
  }
}

void SF_visitStart(float delta) {
  gVisitActive = true;
  gVisitStartMs = millis();
  gVisitPeakDelta = delta;
  publishVisitEvent("start", delta);
}

void SF_visitEnd(unsigned long durationMs, float peakDelta) {
  gVisitActive = false;
  gVisitEndMs = millis();
  gVisitPeakDelta = peakDelta;

  const char* reason = gCaptureReason;
  if (!gVisitMediaCaptured) {
    if (!reason) {
      reason = gVisitMetadataOnly ? reasonNoCapture : reasonLateReady;
    }
  } else if (!reason) {
    reason = reasonArmedReady;
  }

  publishVisitEvent("end", peakDelta, durationMs, reason);
  gCaptureReason = nullptr;
  gVisitMetadataOnly = false;
  gVisitMediaCaptured = false;
  gCaptureQueued = false;
  gArmState = MiniArmState::Disarming;
}

void SF_commandHandlerLoop() {
  const unsigned long now = millis();
  if (gEventCapturePending && now - gEventCaptureStartMs > kMiniEventTimeoutMs) {
    gEventCapturePending = false;
  }
  switch (gArmState) {
    case MiniArmState::ArmedWaking:
      if (gWakeRetryCount == 0 || now - gWakePulseMs >= kMiniWakePulseIntervalMs) {
        if (SF::Mini_sendWake()) {
          gWakePulseMs = now;
          ++gWakeRetryCount;
          markMiniActivity();
          publishSysState("mini_wake_retry");
          gArmState = MiniArmState::ArmedWaitBoot;
        }
      }
      break;
    case MiniArmState::ArmedWaitBoot:
      if (gMiniBootSeen) {
        publishSysState("mini_boot_confirmed");
        gArmState = MiniArmState::ArmedWaitReady;
      } else if (now - gWakePulseMs > kMiniBootTimeoutMs) {
        if (gWakeRetryCount < kMiniWakeMaxRetries) {
          gArmState = MiniArmState::ArmedWaking;
        } else {
          gVisitMetadataOnly = true;
          gCaptureReason = reasonNoCapture;
          publishVisitEvent("capture", 0.0f, 0, reasonNoCapture);
          gArmState = MiniArmState::Idle;
        }
      }
      break;
    case MiniArmState::ArmedWaitReady:
      if (gMiniReadySeen) {
        publishSysState("mini_ready_detected");
        gArmState = MiniArmState::ArmedSettling;
        SF::Mini_requestStatus();
      } else if (now - gBootSeenMs > kMiniReadyTimeoutMs) {
        gVisitMetadataOnly = true;
        gCaptureReason = reasonLateReady;
        publishVisitEvent("capture", 0.0f, 0, reasonLateReady);
        gArmState = MiniArmState::Idle;
      }
      break;
    case MiniArmState::ArmedSettling:
      if (gMiniSettled && now >= gSettleDueMs) {
        gCaptureReason = reasonArmedReady;
        publishVisitEvent("capture_ready", 0.0f, 0, reasonArmedReady);
        gArmState = MiniArmState::ArmedReady;
      } else if (now - gReadySeenMs > kMiniSettleTimeoutMs) {
        gVisitMetadataOnly = true;
        gCaptureReason = reasonLateReady;
        publishVisitEvent("capture", 0.0f, 0, reasonLateReady);
        gArmState = MiniArmState::ArmedReady;
      }
      break;
    case MiniArmState::ArmedReady:
      if (!gVisitActive && !gCaptureQueued && now - gReadySeenMs > kMiniIdleSleepMs) {
        gArmState = MiniArmState::Disarming;
      }
      break;
    case MiniArmState::Disarming:
      if (!gEventCapturePending && !gSleepInFlight && gMiniActive) {
        if (SF::Mini_sendSleepDeep()) {
          gSleepInFlight = true;
          gMiniSettled = false;
          markMiniActivity();
          publishSysState("mini_disarm_sleep");
        }
      }
      break;
    default:
      break;
  }

  if (gMiniActive && gMiniSettled && !gSnapshotPending && !gSleepInFlight && gArmState == MiniArmState::Idle) {
    if (now - gMiniLastActivityMs > kMiniIdleSleepMs) {
      if (SF::Mini_sendSleepDeep()) {
        gSleepInFlight = true;
        gMiniSettled = false;
        markMiniActivity();
        SF::Log::info("mini", "idle -> sleep_deep");
      }
    }
  }
}

const char* SF_miniState() {
  return gMiniState;
}

bool SF_miniSettled() {
  return gMiniSettled;
}

