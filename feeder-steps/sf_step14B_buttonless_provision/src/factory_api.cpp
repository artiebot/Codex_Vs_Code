#include "factory_api.h"
#include "provisioning.h"
#include "storage.h"
#include "src/config.h"
#include <ArduinoJson.h>
#include <WiFi.h>

namespace {
WebServer* serverPtr = nullptr;
String serialBuffer;

bool checkToken(const String& token) {
  return token == AppConfig::factoryToken();
}

void handleFactoryMqtt() {
  if (!serverPtr) return;
  if (!Provisioning::active()) {
    serverPtr->send(403, "application/json", "{\"error\":\"not_in_ap_mode\"}");
    return;
  }
  String headerToken = serverPtr->header("X-Factory-Token");
  if (!checkToken(headerToken)) {
    serverPtr->send(403, "application/json", "{\"error\":\"unauthorized\"}");
    return;
  }
  String body = serverPtr->arg("plain");
  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, body);
  if (err) {
    serverPtr->send(400, "application/json", "{\"error\":\"bad_json\"}");
    return;
  }
  Storage::MqttConfig mqtt{};
  if (doc.containsKey("host")) {
    strncpy(mqtt.host, doc["host"].as<const char*>(), sizeof(mqtt.host)-1);
    mqtt.hostSet = true;
  }
  if (doc.containsKey("port")) mqtt.port = doc["port"].as<uint16_t>();
  if (doc.containsKey("tls")) mqtt.tls = doc["tls"].as<bool>();
  if (doc.containsKey("user")) {
    strncpy(mqtt.user, doc["user"].as<const char*>(), sizeof(mqtt.user)-1);
    mqtt.credsSet = true;
  }
  if (doc.containsKey("pass")) {
    strncpy(mqtt.pass, doc["pass"].as<const char*>(), sizeof(mqtt.pass)-1);
    mqtt.credsSet = true;
  }
  Storage::saveMqtt(mqtt);
  if (doc.containsKey("deviceId")) {
    const char* id = doc["deviceId"].as<const char*>();
    Storage::saveDeviceId(id);
  }
  serverPtr->send(200, "application/json", "{\"ok\":true}");
}

void printConfig() {
  Storage::WifiConfig wifi{};
  Storage::MqttConfig mqtt{};
  Storage::loadWifi(wifi);
  Storage::loadMqtt(mqtt);
  char idBuf[33];
  bool hasId = Storage::loadDeviceId(idBuf, sizeof(idBuf));
  Serial.println(F("=== Current Config ==="));
  Serial.print(F("WiFi SSID: ")); Serial.println(wifi.valid ? wifi.ssid : "<none>");
  Serial.print(F("MQTT host: ")); Serial.println(mqtt.hostSet ? mqtt.host : AppConfig::MQTT_HOST_DEFAULT);
  Serial.print(F("MQTT user: ")); Serial.println(mqtt.credsSet ? mqtt.user : AppConfig::MQTT_USER_DEFAULT);
  Serial.print(F("Device ID: ")); 
  if (hasId) Serial.println(idBuf); else Serial.println("<default>");
}

}

namespace FactoryAPI {

void attach(WebServer& server) {
  serverPtr = &server;
  server.on("/factory/mqtt", HTTP_POST, handleFactoryMqtt);
}

void loop() {
  if (!Provisioning::active()) return;
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      if (serialBuffer.length() == 0) continue;
      String line = serialBuffer;
      serialBuffer = "";
      line.trim();
      if (line.length() == 0) continue;
      int firstSpace = line.indexOf(' ');
      String cmd = firstSpace>0 ? line.substring(0, firstSpace) : line;
      String rest = firstSpace>0 ? line.substring(firstSpace+1) : "";
      if (cmd == "show_cfg") {
        printConfig();
      } else if (cmd == "set_id") {
        int space = rest.indexOf(' ');
        String token = space>0 ? rest.substring(0, space) : rest;
        String value = space>0 ? rest.substring(space+1) : "";
        if (!checkToken(token)) {
          Serial.println(F("auth_fail"));
          continue;
        }
        if (value.length() == 0) {
          Serial.println(F("missing_id"));
          continue;
        }
        Storage::saveDeviceId(value.c_str());
        Serial.println(F("ok"));
      } else if (cmd == "set_mqtt") {
        // Expected: set_mqtt <token> <host> <port> <user> <pass> <tls>
        int idx = rest.indexOf(' ');
        if (idx < 0) { Serial.println(F("usage_error")); continue; }
        String token = rest.substring(0, idx);
        if (!checkToken(token)) { Serial.println(F("auth_fail")); continue; }
        rest = rest.substring(idx+1);
        int parts=0; String items[5];
        for (; parts<5 && rest.length()>0; ++parts) {
          int sp = rest.indexOf(' ');
          if (sp<0) { items[parts]=rest; rest=""; }
          else { items[parts]=rest.substring(0,sp); rest=rest.substring(sp+1); }
        }
        if (parts<5 || rest.length()==0) { Serial.println(F("usage_error")); continue; }
        Storage::MqttConfig mqtt{};
        strncpy(mqtt.host, items[0].c_str(), sizeof(mqtt.host)-1);
        mqtt.port = items[1].toInt();
        strncpy(mqtt.user, items[2].c_str(), sizeof(mqtt.user)-1);
        strncpy(mqtt.pass, items[3].c_str(), sizeof(mqtt.pass)-1);
        mqtt.tls = rest.toInt() != 0;
        mqtt.hostSet = true;
        mqtt.credsSet = true;
        Storage::saveMqtt(mqtt);
        Serial.println(F("ok"));
      } else {
        Serial.println(F("unknown"));
      }
    } else {
      serialBuffer += c;
    }
  }
}

} // namespace FactoryAPI
