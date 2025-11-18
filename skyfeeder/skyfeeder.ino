#include "config.h"
#include "logging.h"
#include <WiFi.h>
#include <esp_task_wdt.h>
#include <esp_system.h>
#include "mqtt_client.h"  // Now acts as Wi-Fi manager; MQTT is disabled.
#include "command_handler.h"
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

namespace {
// Maintenance reboot interval derived from config; 0 disables the feature.
constexpr unsigned long kMaintenanceIntervalMs =
    (MAINTENANCE_REBOOT_INTERVAL_SEC > 0)
        ? (MAINTENANCE_REBOOT_INTERVAL_SEC * 1000UL)
        : 0UL;
unsigned long gBootMillis = 0;
}  // namespace

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

#if WATCHDOG_TIMEOUT_SEC > 0
  Serial.println("Configuring task watchdog...");
  esp_task_wdt_init(WATCHDOG_TIMEOUT_SEC, true);
  esp_task_wdt_add(nullptr);
  Serial.println("Task watchdog configured!");
#else
  Serial.println("Task watchdog disabled via config.");
#endif

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
  SF::Mini_begin();
  delay(200);
  SF::Mini_requestStatus();
  Serial.println("Requested initial Mini status");
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
    Serial.println("Provisioning ready - ensuring Wi-Fi (HTTP/WS mode)...");
    SF::mqtt.begin();  // Wi-Fi only; MQTT itself is disabled.
  } else {
    Serial.println("Provisioning not ready - waiting for setup AP");
  }

  gBootMillis = millis();
  Serial.println("=== SETUP COMPLETE ===");
}

void loop() {
  static unsigned long lastDebug = 0;
  static bool debugPrinted = false;
  static unsigned long lastMaintenanceCheck = 0;

#if WATCHDOG_TIMEOUT_SEC > 0
  esp_task_wdt_reset();
#endif

  SF::provisioning.loop();
  SF::power.loop();
  SF::weight.loop();
  SF::motion.loop();
  SF::visit.loop();
  SF::cameraEsp.loop();
  SF::Mini_loop();
  SF_commandHandlerLoop();
  SF::ledUx.loop();
  SF::ws2812.update();

  if (!SF::provisioning.isReady()) {
    if (!debugPrinted) {
      Serial.println("DEBUG: Provisioning not ready, waiting...");
      debugPrinted = true;
    }
    delay(20);
    return;
  }

  // Debug output every 10 seconds
  if (millis() - lastDebug > 10000) {
    lastDebug = millis();
    Serial.println("DEBUG: Loop running");
    Serial.print("WiFi connected: ");
    Serial.println(WiFi.status() == WL_CONNECTED ? "YES" : "NO");
  }

  // Periodic maintenance reboot as a safety net. This is intentionally
  // conservative: it only considers uptime and avoids triggering during
  // provisioning or while OTA health is pending.
  if (kMaintenanceIntervalMs > 0 && SF::provisioning.isReady() && !SF::BootHealth::awaitingHealth()) {
    unsigned long now = millis();
    if (now - lastMaintenanceCheck > 60000UL) {  // check roughly once a minute
      lastMaintenanceCheck = now;
      if (now - gBootMillis >= kMaintenanceIntervalMs) {
        Serial.println("Maintenance reboot interval reached; rebooting...");
        SF::Log::warn("boot", "maintenance_reboot interval=%lus", static_cast<unsigned long>(MAINTENANCE_REBOOT_INTERVAL_SEC));
        delay(100);
        esp_restart();
      }
    }
  }

  SF::mqtt.loop();  // Maintains Wi-Fi only; MQTT is a no-op.
  delay(10);
}



