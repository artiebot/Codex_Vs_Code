#include "config.h"
#include "logging.h"
#include <WiFi.h>
#include "mqtt_client.h"
#include "telemetry_service.h"
#include "power_manager.h"
#include "weight_service.h"
#include "motion_service.h"
#include "visit_service.h"
#include "led_service.h"
#include "ws2812_service.h"
#include "led_ux.h"
#include "camera_service_esp.h"
#include "mini_link.h"
#include "provisioning.h"
#include "ota_service.h"
#include "ota_manager.h"
#include "boot_health.h"

static bool s_mqttStarted = false;

void setup() {
  Serial.begin(115200);
  delay(150);

  Serial.println();
  Serial.println("=== SKYFEEDER BOOT DEBUG ===");
  Serial.println("setup() reached!");
  Serial.print("Free heap: ");
  Serial.println(ESP.getFreeHeap());
  Serial.print("CPU Freq: ");
  Serial.println(ESP.getCpuFreqMHz());

  Serial.println("Initializing logging...");
  SF::Log::init();
  SF::Log::bootMarker();
  Serial.println("Logging initialized!");

  Serial.println("Initializing OTA Manager...");
  SF::OtaManager::begin();
  Serial.println("OTA Manager initialized!");

  Serial.println("Initializing Boot Health...");
  SF::BootHealth::begin();
  Serial.println("Boot Health initialized!");

  Serial.println("Initializing LED services...");
  SF::led.begin(LED_PIN);
  SF::ws2812.begin(NEOPIXEL_PIN, NEOPIXEL_COUNT);
  SF::ledUx.begin();
  Serial.println("LED services initialized!");

  Serial.println("Initializing power manager...");
  SF::power.begin();
  Serial.println("Power manager initialized!");

  Serial.println("Initializing weight service...");
  SF::weight.begin();
  Serial.println("Weight service initialized!");

  Serial.println("Initializing motion service...");
  SF::motion.begin(PIR_MOTION_PIN);
  Serial.println("Motion service initialized!");

  Serial.println("Initializing visit service...");
  SF::visit.begin();
  Serial.println("Visit service initialized!");

  Serial.println("Initializing AMB mini link...");
  SF::miniLink.begin();
  SF::miniLink.requestStatus();
  Serial.println("AMB mini link initialized!");

  Serial.println("Initializing camera service...");
  SF::cameraEsp.begin();
  Serial.println("Camera service initialized!");

  Serial.println("Configuring OTA service...");
  SF::OtaService::Config otaCfg;
  SF::OtaService::configure(otaCfg);
  Serial.println("OTA service configured!");

  Serial.println("Initializing provisioning...");
  SF::provisioning.begin();
  Serial.println("Provisioning initialized!");

  if (SF::provisioning.isReady()) {
    Serial.println("Provisioning ready - starting MQTT...");
    SF::mqtt.begin();
    Serial.println("MQTT initialized!");

    Serial.println("Starting telemetry...");
    SF::telemetry.begin(2000);
    Serial.println("Telemetry started!");

    s_mqttStarted = true;
    Serial.println("MQTT services started!");
  } else {
    Serial.println("Provisioning not ready - skipping MQTT");
  }

  Serial.println("=== SETUP COMPLETE ===");
}

void loop() {
  static unsigned long lastDebug = 0;
  static bool debugPrinted = false;

  SF::provisioning.loop();
  SF::power.loop();
  SF::weight.loop();
  SF::motion.loop();
  SF::visit.loop();
  SF::cameraEsp.loop();
  SF::miniLink.loop();
  SF::ledUx.loop();
  SF::ws2812.update();

  if (!SF::provisioning.isReady()) {
    if (!debugPrinted) {
      Serial.println("DEBUG: Provisioning not ready, waiting...");
      debugPrinted = true;
    }
    s_mqttStarted = false;
    delay(20);
    return;
  }

  if (!s_mqttStarted) {
    Serial.println("DEBUG: Starting MQTT services in loop...");
    SF::mqtt.begin();
    SF::telemetry.begin(2000);
    s_mqttStarted = true;
    Serial.println("DEBUG: MQTT services started in loop!");
  }

  // Debug output every 10 seconds
  if (millis() - lastDebug > 10000) {
    lastDebug = millis();
    Serial.println("DEBUG: Loop running, MQTT active");
    Serial.print("WiFi connected: ");
    Serial.println(WiFi.status() == WL_CONNECTED ? "YES" : "NO");
    Serial.print("MQTT connected: ");
    Serial.println(SF::mqtt.raw().connected() ? "YES" : "NO");
  }

  SF::mqtt.loop();
  SF::telemetry.loop();
  delay(10);
}



