#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include <cstring>

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
#include <ctime>

namespace {
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

void onMiniStatus(const char* state, const char* ip, const char* rtsp) {
  copyString(gMiniState, sizeof(gMiniState), state);
  copyString(gMiniIp, sizeof(gMiniIp), ip);
  copyString(gMiniRtsp, sizeof(gMiniRtsp), rtsp);
  SF::Log::info("mini", "state=%s ip=%s", gMiniState, gMiniIp);
  Serial.print("[mini] state="); Serial.print(gMiniState);
  Serial.print(" ip="); Serial.print(gMiniIp);
  Serial.print(" rtsp=");
  Serial.println(gMiniRtsp[0] ? gMiniRtsp : "(none)");
}

void onMiniSnapshot(bool ok, uint32_t bytes, const char* sha, const char* path, const char* trigger) {
  publishSnapshotEvent(ok, bytes, sha, path, trigger);
  Serial.print("[mini] snapshot ok="); Serial.print(ok ? "true" : "false");
  Serial.print(" bytes="); Serial.println(bytes);
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

struct MiniCallbackRegistrar {
  MiniCallbackRegistrar() {
    SF::Mini_setStatusCallback(onMiniStatus);
    SF::Mini_setSnapshotCallback(onMiniSnapshot);
    SF::Mini_setWifiCallback(onMiniWifi);
  }
} miniCallbackRegistrar;

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
  // DEBUG: Log raw MQTT payload
  Serial.print("[cmd/cam] Raw payload (");
  Serial.print(len);
  Serial.print(" bytes): '");
  for (unsigned int i = 0; i < len; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println("'");
  Serial.print("[cmd/cam] Hex dump: ");
  for (unsigned int i = 0; i < len; i++) {
    Serial.printf("%02X ", payload[i]);
  }
  Serial.println();

  StaticJsonDocument<256> doc;
  auto err = deserializeJson(doc, payload, len);
  if (err) {
    Serial.print("[cmd/cam] JSON parse error: ");
    Serial.println(err.c_str());
    publishCamAck(false, "BAD_PAYLOAD", err.c_str(), "");
    return;
  }

  const char* op = doc["op"] | "";
  Serial.print("[cmd/cam] Parsed op field: '");
  Serial.print(op ? op : "(null)");
  Serial.println("'");

  if (!op || !op[0]) {
    Serial.println("[cmd/cam] ERROR: op field is empty or missing!");
    publishCamAck(false, "BAD_PAYLOAD", "missing op", "");
    return;
  }

  const char* tokenField = doc["token"] | "";
  const char* token = (tokenField && tokenField[0]) ? tokenField : nullptr;

  bool queued = false;
  const char* ackToken = nullptr;
  if (std::strcmp(op, "wake") == 0) {
    queued = SF::Mini_sendWake();
  } else if (std::strcmp(op, "sleep") == 0) {
    queued = SF::Mini_sendSleep();
  } else if (std::strcmp(op, "snapshot") == 0) {
    queued = SF::Mini_requestSnapshot();
  } else if (std::strcmp(op, "status") == 0) {
    queued = SF::Mini_requestStatus();
  } else if (std::strcmp(op, "stage_wifi") == 0) {
    const char* ssid = doc["ssid"] | "";
    const char* psk = doc["psk"] | "";
    if (!ssid || !ssid[0]) {
      publishCamAck(false, "BAD_PAYLOAD", "missing ssid", op, token);
      return;
    }
    ackToken = token;
    queued = SF::Mini_stageWifi(ssid, psk ? psk : "", token);
  } else if (std::strcmp(op, "commit_wifi") == 0) {
    ackToken = token;
    queued = SF::Mini_commitWifi(token);
  } else if (std::strcmp(op, "abort_wifi") == 0) {
    ackToken = token;
    queued = SF::Mini_abortWifi(token);
  } else {
    publishCamAck(false, "BAD_PAYLOAD", "unsupported op", op);
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
