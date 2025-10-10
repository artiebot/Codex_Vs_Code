#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include "VideoStream.h"
#include "StreamIO.h"
#include "RTSP.h"
#if defined(__has_include)
#  if __has_include("freertos/FreeRTOS.h")
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#  else
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#  endif
#else
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#endif

// ---------- WIFI / MQTT CONFIG ----------
char WIFI_SSID[] = "wififordays";
char WIFI_PASS[] = "wififordayspassword1236";
static const char* MQTT_HOST = "10.0.0.4";
static const uint16_t MQTT_PORT = 1883;
static const char* MQTT_USER = "dev1";
static const char* MQTT_PASS = "dev1pass";
static const char* DEVICE_ID = "sf-mock01";
// ----------------------------------------

// MQTT topics derived from device id
String topicCmdCamera;
String topicEvtSnapshot;
String topicStatus;

// Camera configuration
#define CAM_CHANNEL 0
VideoSetting camCfg(VIDEO_VGA, CAM_FPS, VIDEO_H264_JPEG, 1);
bool camActive = false;

// HTTP server
WiFiServer httpServer(80);

// MQTT client
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

unsigned long lastReconnect = 0;

// MJPEG stream session state
WiFiClient streamClient;
bool streamActive = false;
uint32_t streamFrameCount = 0;
unsigned long lastStreamFrameTs = 0;
const uint32_t STREAM_FRAME_LIMIT = 0;  // 0 disables session auto-termination

// Snapshot buffer & counters
uint8_t* lastFrame = nullptr;
size_t   lastFrameLen = 0;
unsigned long lastSnapTs = 0;
uint32_t snapCount = 0;

// Message processing buffer
byte msgBuffer[256];
volatile unsigned int msgLen = 0;
volatile bool msgReceived = false;
volatile bool processingMessage = false;
TaskHandle_t mqttTaskHandle = nullptr;
SemaphoreHandle_t frameMutex = nullptr;
SemaphoreHandle_t streamMutex = nullptr;
SemaphoreHandle_t messageMutex = nullptr;
StreamIO* rtspStream = nullptr;
RTSP rtsp;
bool rtspStreaming = false;
uint16_t rtspPort = 0;

void mqttLoopTask(void* param);
void initSynchronization();
bool lockFrameBuffer(TickType_t wait);
void unlockFrameBuffer();
bool lockStreamState(TickType_t wait);
void unlockStreamState();
bool lockMessageBuffer(TickType_t wait);
void unlockMessageBuffer();
bool isStreamActive();
void startRtsp();
void stopRtsp();

void processMessage();
bool reconnectMqtt();

void pumpMqtt() {
  if (!mqtt.connected()) {
    reconnectMqtt();
    return;
  }
  mqtt.loop();
  processMessage();
}

void initSynchronization() {
  if (!frameMutex) {
    frameMutex = xSemaphoreCreateMutex();
    if (!frameMutex) {
      Serial.println("[sync] ERROR: frame mutex alloc failed");
    }
  }
  if (!messageMutex) {
    messageMutex = xSemaphoreCreateMutex();
    if (!messageMutex) {
      Serial.println("[sync] ERROR: message mutex alloc failed");
    }
  }
  if (!streamMutex) {
    streamMutex = xSemaphoreCreateMutex();
    if (!streamMutex) {
      Serial.println("[sync] ERROR: stream mutex alloc failed");
    }
  }
}

bool lockFrameBuffer(TickType_t wait) {
  if (!frameMutex) return false;
  return xSemaphoreTake(frameMutex, wait) == pdTRUE;
}

void unlockFrameBuffer() {
  if (!frameMutex) return;
  xSemaphoreGive(frameMutex);
}

bool lockStreamState(TickType_t wait) {
  if (!streamMutex) return false;
  return xSemaphoreTake(streamMutex, wait) == pdTRUE;
}

void unlockStreamState() {
  if (!streamMutex) return;
  xSemaphoreGive(streamMutex);
}

bool lockMessageBuffer(TickType_t wait) {
  if (!messageMutex) return false;
  return xSemaphoreTake(messageMutex, wait) == pdTRUE;
}

void unlockMessageBuffer() {
  if (!messageMutex) return;
  xSemaphoreGive(messageMutex);
}

bool isStreamActive() {
  if (!streamMutex) {
    return streamActive;
  }
  if (xSemaphoreTake(streamMutex, 0) == pdTRUE) {
    bool active = streamActive;
    xSemaphoreGive(streamMutex);
    return active;
  }
  return true;
}

void startRtsp() {
  if (rtspStreaming) return;
  if (!rtspStream) {
    rtspStream = new StreamIO(1, 1);
  }

  rtsp.configVideo(camCfg);
  rtsp.begin();
  rtspStream->registerInput(Camera.getStream(CAM_CHANNEL));
  rtspStream->registerOutput(rtsp);
  if (rtspStream->begin() != 0) {
    Serial.println("[rtsp] ERROR: StreamIO begin failed");
    rtsp.end();
    return;
  }

  rtspPort = rtsp.getPort();
  rtspStreaming = true;
  Serial.print("[rtsp] streaming ready on rtsp://");
  Serial.print(ipToString(WiFi.localIP()));
  Serial.print(":");
  Serial.print(rtspPort);
  Serial.println("/live");
}

void stopRtsp() {
  if (!rtspStreaming) return;
  if (rtspStream) {
    rtspStream->end();
  }
  rtsp.end();
  rtspStreaming = false;
  rtspPort = 0;
  Serial.println("[rtsp] stopped");
}

void mqttLoopTask(void* param) {
  (void)param;
  Serial.println("[mqtt] worker task started");
  for (;;) {
    pumpMqtt();
    vTaskDelay(pdMS_TO_TICKS(5));
  }
}

String ipToString(const IPAddress& ip) {
  char buf[24];
  snprintf(buf, sizeof(buf), "%u.%u.%u.%u", ip[0], ip[1], ip[2], ip[3]);
  return String(buf);
}

void ensureCamera() {
  if (camActive) return;
  camCfg.setBitrate(2 * 1024 * 1024);  // 2 Mbps for RTSP + JPEG snapshots
  Camera.configVideoChannel(CAM_CHANNEL, camCfg);
  Camera.videoInit();
  startRtsp();
  Camera.channelBegin(CAM_CHANNEL);
  camActive = true;
  Serial.println("[cam] started");
}

void stopCamera() {
  if (!camActive) return;
  stopRtsp();
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
  if (!lockFrameBuffer(pdMS_TO_TICKS(500))) {
    Serial.println("[snap] ERROR: frame mutex timeout");
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
    unlockFrameBuffer();
    return false;
  }
  memcpy(lastFrame, (void*)addr, len);
  lastFrameLen = len;
  lastSnapTs = millis();
  unlockFrameBuffer();
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
  if (!lockFrameBuffer(pdMS_TO_TICKS(200))) {
    Serial.println("[mqtt] publish snapshot -> skipped (frame mutex timeout)");
    return;
  }
  bool hasFrame = lastFrame != nullptr;
  size_t frameLen = lastFrameLen;
  unsigned long snapTs = lastSnapTs;
  unlockFrameBuffer();

  if (!hasFrame) {
    Serial.println("[mqtt] publish snapshot -> skipped (no frame)");
    return;
  }

  Serial.print("[mqtt] connection state before publish: ");
  Serial.println(mqtt.connected() ? "CONNECTED" : "DISCONNECTED");

  if (!ensureMqttConnected()) {
    Serial.println("[mqtt] publish snapshot -> skipped (MQTT reconnect failed)");
    Serial.print("[mqtt] client state: ");
    Serial.println(mqtt.state());
    return;
  }

  StaticJsonDocument<256> doc;
  doc["url"] = String("http://") + ipToString(WiFi.localIP()) + "/snapshot.jpg";
  doc["ts"] = snapTs;
  doc["size"] = frameLen;
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
  Serial.println("");
  Serial.println("==========================================");
  Serial.println("=== MQTT CALLBACK FIRED ===");
  Serial.println("==========================================");
  Serial.print("Topic: ");
  Serial.println(topic);
  Serial.print("Length: ");
  Serial.println(length);
  Serial.print("Payload: ");
  for (unsigned int i = 0; i < length && i < 128; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();
  Serial.println("==========================================");

  if (length < sizeof(msgBuffer)) {
    if (lockMessageBuffer(pdMS_TO_TICKS(200))) {
      memcpy(msgBuffer, payload, length);
      msgLen = length;
      msgReceived = true;
      unlockMessageBuffer();
    } else {
      Serial.println("[callback] ERROR: message mutex busy");
    }
  } else {
    Serial.println("[callback] ERROR: payload too large!");
  }
}

void processMessage() {
  if (processingMessage) return;
  if (!lockMessageBuffer(0)) return;
  if (!msgReceived) {
    unlockMessageBuffer();
    return;
  }

  processingMessage = true;
  byte localBuffer[sizeof(msgBuffer)];
  unsigned int localLen = msgLen;
  if (localLen > sizeof(localBuffer)) {
    localLen = sizeof(localBuffer);
  }
  memcpy(localBuffer, msgBuffer, localLen);
  msgReceived = false;
  unlockMessageBuffer();

  Serial.print("[process] message (");
  Serial.print(localLen);
  Serial.print(" bytes): ");
  for (unsigned int i = 0; i < localLen; i++) {
    Serial.print((char)localBuffer[i]);
  }
  Serial.println();

  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, localBuffer, localLen);
  String actionStr;

  if (!err) {
    if (const char* action = doc["action"]) {
      actionStr = action;
    }
  } else {
    Serial.print("[process] JSON error: ");
    Serial.println(err.c_str());
  }

  if (actionStr.length() == 0) {
    String payload;
    payload.reserve(localLen);
    for (unsigned int i = 0; i < localLen; i++) {
      payload += (char)localBuffer[i];
    }
    String normalized = payload;
    normalized.trim();
    normalized.toLowerCase();
    normalized.replace("\"", "");
    normalized.replace("'", "");

    if (normalized.indexOf("snap") >= 0) {
      actionStr = "snap";
    } else if (normalized.indexOf("wake") >= 0) {
      actionStr = "wake";
    } else if (normalized.indexOf("sleep") >= 0) {
      actionStr = "sleep";
    }

    if (actionStr.length() > 0) {
      Serial.print("[process] fallback parsed action: ");
      Serial.println(actionStr);
    }
  }

  if (actionStr.length() == 0) {
    Serial.println("[process] no action");
    processingMessage = false;
    return;
  }

  Serial.print("[process] action: ");
  Serial.println(actionStr);
  if (actionStr.equalsIgnoreCase("snap")) {
    if (captureStill()) {
      publishSnapshot();
    }
  } else if (actionStr.equalsIgnoreCase("sleep")) {
    stopCamera();
  } else if (actionStr.equalsIgnoreCase("wake")) {
    ensureCamera();
  }

  processingMessage = false;
}

bool reconnectMqtt() {
  if (mqtt.connected()) return true;

  unsigned long now = millis();
  if (lastReconnect != 0 && (now - lastReconnect) < 2000) {
    Serial.print("[mqtt] throttled (last ");
    Serial.print((now - lastReconnect) / 1000.0, 1);
    Serial.println("s ago)");
    return false;
  }
  lastReconnect = now;

  Serial.println("[mqtt] attempting connection...");
  Serial.print("[mqtt] server: ");
  Serial.print(MQTT_HOST);
  Serial.print(":");
  Serial.println(MQTT_PORT);

  mqtt.disconnect();
  delay(100);

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(messageReceived);
  mqtt.setBufferSize(512);
  mqtt.setKeepAlive(30);

  Serial.print("[mqtt] callback: 0x");
  Serial.println((unsigned long)messageReceived, HEX);

  char clientId[32];
  snprintf(clientId, sizeof(clientId), "amb82-%s-%lu", DEVICE_ID, millis());

  Serial.print("[mqtt] client ID: ");
  Serial.println(clientId);

  if (!mqtt.connect(clientId, MQTT_USER, MQTT_PASS)) {
    Serial.print("[mqtt] connect FAILED, state: ");
    Serial.println(mqtt.state());
    return false;
  }

  Serial.println("[mqtt] CONNECTED!");
  Serial.print("[mqtt] subscribing to: ");
  Serial.println(topicCmdCamera);

  if (!mqtt.subscribe(topicCmdCamera.c_str(), 0)) {
    Serial.println("[mqtt] subscribe FAILED!");
    mqtt.disconnect();
    return false;
  }

  Serial.print("[mqtt] subscribed to: ");
  Serial.println(topicCmdCamera);
  Serial.println("[mqtt] setup complete, callback ready");

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
  doc["rtsp_active"] = rtspStreaming;
  doc["rtsp_port"] = (uint16_t)rtspPort;
  if (rtspStreaming) {
    doc["rtsp_url"] = String("rtsp://") + ipToString(WiFi.localIP()) + ":" + String(rtspPort) + "/live";
  }

  char json[384];
  serializeJson(doc, json, sizeof(json));

  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: application/json");
  client.println("Connection: close");
  client.println();
  client.print(json);
}

void handleHttpSnapshot(WiFiClient& client) {
  if (!lockFrameBuffer(pdMS_TO_TICKS(1000))) {
    client.println("HTTP/1.1 503 Service Unavailable");
    client.println("Connection: close");
    client.println();
    client.println("Snapshot busy, try again");
    return;
  }

  if (!lastFrame) {
    unlockFrameBuffer();
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
  unlockFrameBuffer();
}

static void stopStreamSessionLocked(const char* reason) {
  if (!streamActive) return;
  Serial.print("[stream] ending (");
  Serial.print(reason);
  Serial.println(")");
  streamClient.stop();
  streamActive = false;
  streamFrameCount = 0;
}

void stopStreamSession(const char* reason) {
  if (!lockStreamState(pdMS_TO_TICKS(200))) return;
  stopStreamSessionLocked(reason);
  unlockStreamState();
}

void serviceStream() {
  if (!streamMutex) return;
  if (xSemaphoreTake(streamMutex, 0) != pdTRUE) return;
  if (!streamActive) {
    unlockStreamState();
    return;
  }
  if (!streamClient.connected()) {
    stopStreamSessionLocked("client disconnected");
    unlockStreamState();
    return;
  }

  // Limit frame rate ~30 fps
  if (millis() - lastStreamFrameTs < 33) {
    unlockStreamState();
    return;
  }

  ensureCamera();
  if (!camActive) {
    stopStreamSessionLocked("camera inactive");
    unlockStreamState();
    return;
  }

  uint32_t addr = 0;
  uint32_t len = 0;
  Camera.getImage(CAM_CHANNEL, &addr, &len);
  if (addr == 0 || len == 0) {
    unlockStreamState();
    return;
  }

  Stream& out = streamClient;
  out.print("--frame\r\n");
  out.print("Content-Type: image/jpeg\r\n");
  out.print("Content-Length: ");
  out.print(len);
  out.print("\r\n\r\n");
  size_t written = out.write((uint8_t*)addr, len);
  out.print("\r\n");

  if (written != len) {
    stopStreamSessionLocked("write failed");
    unlockStreamState();
    return;
  }

  streamFrameCount++;
  lastStreamFrameTs = millis();
  if (STREAM_FRAME_LIMIT > 0 && streamFrameCount >= STREAM_FRAME_LIMIT) {
    stopStreamSessionLocked("frame limit");
  }
  unlockStreamState();
}

bool handleHttpStream(WiFiClient& client) {
  ensureCamera();
  if (!camActive) {
    client.println("HTTP/1.1 503 Service Unavailable");
    client.println("Connection: close");
    client.println();
    return false;
  }

  if (!lockStreamState(pdMS_TO_TICKS(500))) {
    client.println("HTTP/1.1 503 Service Unavailable");
    client.println("Connection: close");
    client.println();
    client.println("Stream handler busy");
    return false;
  }

  if (streamActive && streamClient.connected()) {
    client.println("HTTP/1.1 409 Conflict");
    client.println("Connection: close");
    client.println();
    client.println("Stream already in progress");
    unlockStreamState();
    return false;
  }

  Serial.println("[stream] client connected");

  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: multipart/x-mixed-replace; boundary=frame");
  client.println();

  streamClient = client;
  streamActive = true;
  streamFrameCount = 0;
  lastStreamFrameTs = 0;
  unlockStreamState();
  return true;
}

void handleHttpTestSnap(WiFiClient& client) {
  Serial.println("[http] test-snap triggered");
  const char* testCmd = "{\"action\":\"snap\"}";
  size_t testLen = strlen(testCmd);
  if (testLen >= sizeof(msgBuffer)) {
    client.println("HTTP/1.1 500 Internal Server Error");
    client.println("Connection: close");
    client.println();
    client.println("Command buffer overflow");
    return;
  }

  if (!lockMessageBuffer(pdMS_TO_TICKS(200))) {
    client.println("HTTP/1.1 503 Service Unavailable");
    client.println("Connection: close");
    client.println();
    client.println("Message handler busy");
    return;
  }

  memcpy(msgBuffer, testCmd, testLen);
  msgLen = testLen;
  msgReceived = true;
  unlockMessageBuffer();

  unsigned long start = millis();
  uint32_t initialSnaps = snapCount;
  bool completed = false;
  while (millis() - start < 5000) {
    if (!msgReceived && !processingMessage && snapCount > initialSnaps) {
      completed = true;
      break;
    }
    delay(10);
  }

  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/plain");
  client.println("Connection: close");
  client.println();
  if (completed) {
    client.println("snap triggered");
  } else {
    client.println("snap queued");
  }
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
  client.println("<p><a href='/stream'>MJPEG Stream</a></p>");
  client.println("<p><a href='/test-snap'>Trigger Snap</a></p>");
  client.println("<p><a href='/snapshot.jpg'>Latest Snapshot</a></p>");
  client.print("<p>RTSP: ");
  if (rtspStreaming) {
    client.print("rtsp://");
    client.print(ipToString(WiFi.localIP()));
    client.print(":");
    client.print(rtspPort);
    client.println("/live</p>");
  } else {
    client.println("inactive</p>");
  }
  client.println("</body></html>");
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n[boot] AMB82 MQTT Camera Bridge");
  initSynchronization();

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

  // *** CRITICAL FIX: Set WiFiClient to non-blocking mode for AMB82 platform ***
  // Required for PubSubClient to work correctly on Realtek RTL8735B
  // Without this, MQTT will disconnect every few seconds (state -3)
  Serial.println("[wifi] setting non-blocking mode...");
  wifiClient.setNonBlockingMode();

  ensureCamera();
  httpServer.begin();
  Serial.println("[http] server listening on 80");
  reconnectMqtt();
  if (xTaskCreate(mqttLoopTask, "mqttLoop", 4096, nullptr, 2, &mqttTaskHandle) != pdPASS) {
    Serial.println("[mqtt] ERROR: worker task start failed");
    mqttTaskHandle = nullptr;
  }
}

void loop() {
  serviceStream();

  if (isStreamActive()) {
    delay(1);
    return;
  }

  if (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    return;
  }

  WiFiClient client = httpServer.available();
  if (client) {
    bool keepAlive = false;
    String request;
    unsigned long timeout = millis() + 1000;
    while (client.connected() && millis() < timeout) {
      if (client.available()) {
        char c = client.read();
        request += c;
        if (request.endsWith("\r\n\r\n")) break;
      }
      delay(1);
    }

    if (request.indexOf("/status") >= 0) {
      handleHttpStatus(client);
    } else if (request.indexOf("/stream") >= 0) {
      keepAlive = handleHttpStream(client);
    } else if (request.indexOf("/snapshot.jpg") >= 0) {
      handleHttpSnapshot(client);
    } else if (request.indexOf("/test-snap") >= 0) {
      handleHttpTestSnap(client);
    } else {
      handleHttpDefault(client);
    }
    if (!keepAlive) {
      client.stop();
    }
  }

  delay(1);
}











