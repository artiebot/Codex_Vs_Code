#include <WiFi.h>
#include <PubSubClient.h>

// Config
char TEST_WIFI_SSID[] = "wififordays";
char TEST_WIFI_PASS[] = "wififordayspassword1236";
const char* TEST_MQTT_HOST = "10.0.0.4";
const uint16_t TEST_MQTT_PORT = 1883;
const char* TEST_MQTT_USER = "dev1";
const char* TEST_MQTT_PASS = "dev1pass";
const char* TEST_DEVICE_ID = "dev1";

// Forward declaration
void messageReceived(char* topic, byte* payload, unsigned int length);

// MQTT
WiFiClient wifiClient;
PubSubClient mqtt(TEST_MQTT_HOST, TEST_MQTT_PORT, messageReceived, wifiClient);
String topicCmd;
unsigned long lastReconnect = 0;
unsigned long callbackCount = 0;

void messageReceived(char* topic, byte* payload, unsigned int length) {
  callbackCount++;
  Serial.println("");
  Serial.println("==========================================");
  Serial.print("=== CALLBACK FIRED #");
  Serial.print(callbackCount);
  Serial.println(" ===");
  Serial.println("==========================================");
  Serial.print("Topic: ");
  Serial.println(topic);
  Serial.print("Length: ");
  Serial.println(length);
  Serial.print("Payload: ");
  for (unsigned int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();
  Serial.println("==========================================");
}

bool reconnectMqtt() {
  if (mqtt.connected()) return true;

  unsigned long now = millis();
  if (lastReconnect != 0 && (now - lastReconnect) < 5000) {
    return false;
  }
  lastReconnect = now;

  Serial.println("[mqtt] attempting connection...");

  char clientId[32];
  snprintf(clientId, sizeof(clientId), "amb82-test-fixed");

  Serial.print("[mqtt] connecting as: ");
  Serial.println(clientId);

  if (!mqtt.connect(clientId, TEST_MQTT_USER, TEST_MQTT_PASS)) {
    Serial.print("[mqtt] FAILED, state: ");
    Serial.println(mqtt.state());
    return false;
  }

  Serial.println("[mqtt] CONNECTED!");
  Serial.print("[mqtt] subscribing to: ");
  Serial.println(topicCmd);

  if (!mqtt.subscribe(topicCmd.c_str(), 0)) {
    Serial.println("[mqtt] subscribe FAILED!");
    mqtt.disconnect();
    return false;
  }

  Serial.println("[mqtt] subscribed OK");
  Serial.println("[mqtt] *** CALLBACK READY - SEND TEST MESSAGE ***");
  return true;
}

void setup() {
  Serial.begin(115200);
  delay(2000);
  Serial.println("\n\n===========================================");
  Serial.println("MQTT CALLBACK TEST - WITH NON-BLOCKING FIX");
  Serial.println("===========================================\n");

  topicCmd = String("skyfeeder/") + TEST_DEVICE_ID + "/amb/camera/cmd";
  Serial.print("Command topic: ");
  Serial.println(topicCmd);

  Serial.print("\n[wifi] connecting to ");
  Serial.println(TEST_WIFI_SSID);
  WiFi.begin(TEST_WIFI_SSID, TEST_WIFI_PASS);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[wifi] CONNECTED!");
    Serial.print("[wifi] IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n[wifi] FAILED!");
    return;
  }

  // *** CRITICAL FIX: Set WiFiClient to non-blocking mode ***
  Serial.println("[wifi] setting non-blocking mode...");
  wifiClient.setNonBlockingMode();

  reconnectMqtt();
}

void loop() {
  static unsigned long lastStatus = 0;

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[ERROR] WiFi disconnected!");
    delay(1000);
    WiFi.begin(TEST_WIFI_SSID, TEST_WIFI_PASS);
    return;
  }

  if (!mqtt.connected()) {
    static unsigned long lastDisconnectMsg = 0;
    if (millis() - lastDisconnectMsg > 2000) {
      Serial.print("[loop] MQTT DISCONNECTED! State: ");
      Serial.println(mqtt.state());
      lastDisconnectMsg = millis();
    }
    reconnectMqtt();
  } else {
    mqtt.loop();

    if (millis() - lastStatus > 5000) {
      Serial.print("[status] MQTT OK, callbacks: ");
      Serial.print(callbackCount);
      Serial.print(", uptime: ");
      Serial.print(millis() / 1000);
      Serial.println("s");
      lastStatus = millis();
    }
  }

  delay(10);
}
