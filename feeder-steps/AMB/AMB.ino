#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include "VideoStream.h"

// ---------- WIFI / MQTT CONFIG ----------
char WIFI_SSID[] = "wififordays";
char WIFI_PASS[] = "wififordayspassword1236";
static const char* MQTT_HOST = "10.0.0.4";
static const uint16_t MQTT_PORT = 1883;
static const char* MQTT_USER = "dev1";
static const char* MQTT_PASS = "dev1pass";
static const char* DEVICE_ID = "dev1";
// ----------------------------------------

// MQTT topics derived from device id
String topicCmdCamera;
String topicEvtSnapshot;
String topicStatus;

// Camera configuration
#define CAM_CHANNEL 0
VideoSetting camCfg(VIDEO_VGA, CAM_FPS, VIDEO_JPEG, 1);
bool camActive = false;

// HTTP server
WiFiServer httpServer(80);

// MQTT client
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

unsigned long lastReconnect = 0;
unsigned long lastPoll = 0;

// Snapshot buffer & counters
uint8_t* lastFrame = nullptr;
size_t   lastFrameLen = 0;
unsigned long lastSnapTs = 0;
uint32_t snapCount = 0;

// Message processing buffer
byte msgBuffer[256];
unsigned int msgLen = 0;
bool msgReceived = false;

String ipToString(const IPAddress& ip) {
  char buf[24];
  snprintf(buf, sizeof(buf), "%u.%u.%u.%u", ip[0], ip[1], ip[2], ip[3]);
  return String(buf);
}

void ensureCamera() {
  if (camActive) return;
  camCfg.setBitrate(750 * 1024);
  Camera.configVideoChannel(CAM_CHANNEL, camCfg);
  Camera.videoInit();
  Camera.channelBegin(CAM_CHANNEL);
  camActive = true;
  Serial.println("[cam] started");
}

void stopCamera() {
  if (!camActive) return;
  Camera.channelEnd(CAM_CHANNEL);
  Camera.videoDeinit();
  camActive = false;
  Serial.println("[cam] stopped");
}

bool captureStill() {
  ensureCamera();
  if (!camActive) return false;

  uint32_t addr = 0;
  uint32_t len = 0;
  Serial.println("[snap] attempting capture...");
  for (int attempt = 0; attempt < 40; ++attempt) {
    Camera.getImage(CAM_CHANNEL, &addr, &len);
    if (addr != 0 && len != 0) break;
    delay(25);
  }
  if (addr == 0 || len == 0) {
    Serial.println("[snap] frame not ready");
    return false;
  }
  if (lastFrame) {
    free(lastFrame);
    lastFrame = nullptr;
    lastFrameLen = 0;
  }
  lastFrame = (uint8_t*)malloc(len);
  if (!lastFrame) {
    Serial.println("[snap] malloc failed");
    return false;
  }
  memcpy(lastFrame, (void*)addr, len);
  lastFrameLen = len;
  lastSnapTs = millis();
  Serial.print("[snap] captured ");
  Serial.print(len);
  Serial.println(" bytes");
  return true;
}

bool reconnectMqtt();
bool ensureMqttConnected() {
  if (mqtt.connected()) return true;
  return reconnectMqtt();
}

void publishSnapshot() {
  if (!lastFrame) return;
  if (!ensureMqttConnected()) {
    Serial.println("[mqtt] publish snapshot -> skipped (no MQTT)");
    return;
  }

  StaticJsonDocument<256> doc;
  doc["url"] = String("http://") + ipToString(WiFi.localIP()) + "/snapshot.jpg";
  doc["ts"] = lastSnapTs;
  doc["size"] = lastFrameLen;
  char payload[256];
  serializeJson(doc, payload, sizeof(payload));

  bool ok = mqtt.publish(topicEvtSnapshot.c_str(), payload, false);
  Serial.print("[mqtt] publish snapshot event -> ");
  Serial.println(ok ? "OK" : "FAIL");
  if (!ok) {
    mqtt.disconnect();
    if (ensureMqttConnected()) {
      ok = mqtt.publish(topicEvtSnapshot.c_str(), payload, false);
      Serial.print("[mqtt] retry publish -> ");
      Serial.println(ok ? "OK" : "FAIL");
    }
  }
  if (ok) {
    snapCount++;
  }
}

void messageReceived(char* topic, byte* payload, unsigned int length) {
  Serial.println("=== CALLBACK FIRED ===");
  Serial.print("Topic: ");
  Serial.println(topic);
  Serial.print("Length: ");
  Serial.println(length);
  if (length < sizeof(msgBuffer)) {
    memcpy(msgBuffer, payload, length);
    msgLen = length;
    msgReceived = true;
  }
}

void processMessage() {
  if (!msgReceived) return;
  msgReceived = false;

  Serial.print("[process] message (");
  Serial.print(msgLen);
  Serial.print(" bytes): ");
  for (unsigned int i = 0; i < msgLen; i++) {
    Serial.print((char)msgBuffer[i]);
  }
  Serial.println();

  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, msgBuffer, msgLen);
  if (err) {
    Serial.print("[process] JSON error: ");
    Serial.println(err.c_str());
    return;
  }

  const char* action = doc["action"];
  if (!action) {
    Serial.println("[process] no action");
    return;
  }

  Serial.print("[process] action: ");
  Serial.println(action);

  if (strcmp(action, "snap") == 0) {
    if (captureStill()) {
      publishSnapshot();
    }
  } else if (strcmp(action, "sleep") == 0) {
    stopCamera();
  } else if (strcmp(action, "wake") == 0) {
    ensureCamera();
  }
}

bool reconnectMqtt() {
  if (mqtt.connected()) return true;
  unsigned long now = millis();
  if (now - lastReconnect < 2000) return false;
  lastReconnect = now;

  Serial.println("[mqtt] attempting connection...");
  mqtt.disconnect();
  delay(100);

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(messageReceived);
  mqtt.setBufferSize(512);
  mqtt.setKeepAlive(30);

  char clientId[32];
  snprintf(clientId, sizeof(clientId), "amb82-%s-%lu", DEVICE_ID, millis());

  if (!mqtt.connect(clientId, MQTT_USER, MQTT_PASS)) {
    Serial.print("[mqtt] connect failed, state: ");
    Serial.println(mqtt.state());
    return false;
  }

  Serial.println("[mqtt] connected!");
  if (!mqtt.subscribe(topicCmdCamera.c_str(), 0)) {
    Serial.println("[mqtt] subscribe failed!");
    mqtt.disconnect();
    return false;
  }
  Serial.print("[mqtt] subscribed to: ");
  Serial.println(topicCmdCamera);

  mqtt.publish(topicStatus.c_str(), "online", false);
  return true;
}

void handleHttpStatus(WiFiClient& client) {
  StaticJsonDocument<384> doc;
  doc["online"] = true;
  doc["mqtt_connected"] = mqtt.connected();
  doc["camera_active"] = camActive;
  doc["uptime_ms"] = (uint32_t)millis();
  doc["snap_count"] = snapCount;
  doc["last_snap_size"] = (uint32_t)lastFrameLen;
  doc["last_snap_ts"] = (uint32_t)lastSnapTs;

  char json[384];
  serializeJson(doc, json, sizeof(json));

  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: application/json");
  client.println("Connection: close");
  client.println();
  client.print(json);
}

void handleHttpSnapshot(WiFiClient& client) {
  if (!lastFrame) {
    client.println("HTTP/1.1 404 Not Found");
    client.println("Connection: close");
    client.println();
    client.println("No snapshot captured yet.");
    return;
  }
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: image/jpeg");
  client.print("Content-Length: ");
  client.println((unsigned)lastFrameLen);
  client.println("Connection: close");
  client.println();
  client.write(lastFrame, lastFrameLen);
}

void handleHttpTestSnap(WiFiClient& client) {
  Serial.println("[http] test-snap triggered");
  const char* testCmd = "{\"action\":\"snap\"}";
  memcpy(msgBuffer, testCmd, strlen(testCmd));
  msgLen = strlen(testCmd);
  msgReceived = true;
  processMessage();
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/plain");
  client.println("Connection: close");
  client.println();
  client.println("snap triggered");
}

void handleHttpDefault(WiFiClient& client) {
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/html");
  client.println("Connection: close");
  client.println();
  client.println("<html><head><title>AMB82 Camera</title></head><body>");
  client.println("<h1>AMB82 Camera Bridge</h1>");
  client.print("<p>Device: ");
  client.print(DEVICE_ID);
  client.println("</p>");
  client.print("<p>WiFi: ");
  client.print(ipToString(WiFi.localIP()));
  client.println("</p>");
  client.print("<p>MQTT: ");
  client.print(mqtt.connected() ? "connected" : "disconnected");
  client.print(" (" ); client.print(MQTT_HOST); client.print(":"); client.print(MQTT_PORT); client.println(")</p>");
  client.println("<hr>");
  client.println("<p><a href='/status'>JSON Status</a></p>");
  client.println("<p><a href='/test-snap'>Trigger Snap</a></p>");
  client.println("<p><a href='/snapshot.jpg'>Latest Snapshot</a></p>");
  client.println("</body></html>");
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n[boot] AMB82 MQTT Camera Bridge");

  topicCmdCamera = String("skyfeeder/") + DEVICE_ID + "/amb/camera/cmd";
  topicEvtSnapshot = String("skyfeeder/") + DEVICE_ID + "/amb/camera/event/snapshot";
  topicStatus = String("skyfeeder/") + DEVICE_ID + "/amb/status";
  Serial.print("[mqtt] cmd topic: "); Serial.println(topicCmdCamera);
  Serial.print("[mqtt] evt topic: "); Serial.println(topicEvtSnapshot);

  Serial.print("[wifi] connecting to "); Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print('.');
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("\n[wifi] connected: ");
    Serial.println(ipToString(WiFi.localIP()));
  } else {
    Serial.println("\n[wifi] connection failed!");
  }

  ensureCamera();
  httpServer.begin();
  Serial.println("[http] server listening on 80");
  reconnectMqtt();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    return;
  }

  if (!mqtt.connected()) {
    reconnectMqtt();
  } else {
    mqtt.loop();
    processMessage();
    unsigned long now = millis();
    if (now - lastPoll > 100) {
      mqtt.loop();
      lastPoll = now;
    }
  }

  WiFiClient client = httpServer.available();
  if (client) {
    String request;
    unsigned long timeout = millis() + 1000;
    while (client.connected() && millis() < timeout) {
      if (client.available()) {
        char c = client.read();
        request += c;
        if (request.endsWith("\r\n\r\n")) break;
      }
    }
    if (request.indexOf("/status") >= 0) {
      handleHttpStatus(client);
    } else if (request.indexOf("/snapshot.jpg") >= 0) {
      handleHttpSnapshot(client);
    } else if (request.indexOf("/test-snap") >= 0) {
      handleHttpTestSnap(client);
    } else {
      handleHttpDefault(client);
    }
    client.stop();
  }
  delay(1);
}
