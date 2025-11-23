#pragma once

#define FW_VERSION  "1.4.0"

// --- Provisioning defaults (tweak per deployment) ---
#define WIFI_DEFAULT_SSID  "wififordays"
#define WIFI_DEFAULT_PASS  "wififordayspassword1236"
#define MQTT_DEFAULT_HOST  "10.0.0.4"
#define MQTT_DEFAULT_PORT  1883
#define MQTT_DEFAULT_USER  "dev1"
#define MQTT_DEFAULT_PASS  "dev1pass"
#define DEVICE_ID_DEFAULT  "dev1"

#ifndef API_BASE_URL
#define API_BASE_URL  "http://10.0.0.4:8080"
#endif
#ifndef TELEMETRY_PUSH_INTERVAL_MS
#define TELEMETRY_PUSH_INTERVAL_MS (30UL * 1000UL)
#endif

// --- Wi-Fi retry / provisioning behaviour ---
// Maximum failed connection attempts within the window before the device
// automatically escalates back into provisioning (setup AP) mode.
#define WIFI_MAX_FAILS_BEFORE_PROVISIONING 3
// Time window for counting failures (milliseconds). Default: 30 minutes.
#define WIFI_FAIL_WINDOW_MS (30UL * 60UL * 1000UL)
// Timeout for a single Wi-Fi connect attempt (milliseconds).
#define WIFI_CONNECT_TIMEOUT_MS 15000UL
// Background retry interval when offline but provisioned (milliseconds).
// The device will keep retrying Wi-Fi in the background without dropping
// immediately into provisioning mode.
#define WIFI_OFFLINE_RETRY_MS (5UL * 60UL * 1000UL)

// --- Watchdog / maintenance reboot ---
// Task watchdog timeout in seconds. Set to 0 to disable the watchdog for
// debugging, but production builds should keep this enabled.
#define WATCHDOG_TIMEOUT_SEC 30
// Periodic maintenance reboot interval in seconds. Set to 0 to disable
// maintenance reboots (useful during long-running debugging sessions).
#define MAINTENANCE_REBOOT_INTERVAL_SEC (6UL * 60UL * 60UL)

// --- Lighting & UX ---
#define LED_PIN 2
#define NEOPIXEL_PIN   5
#define NEOPIXEL_COUNT 64
#define LED_OVERRIDE_MS         3000
#define LED_IDLE_BRIGHTNESS     96
#define LED_WARN_BRIGHTNESS     64
#define LED_CRIT_BRIGHTNESS     96

// --- Sensor pins ---
#define I2C_SDA 25
#define I2C_SCL 26
#define HX711_DOUT_PIN 32
#define HX711_SCK_PIN  33
#define INA260_ALERT_PIN 17
#define PIR_MOTION_PIN 27

// --- Camera (AI-Thinker ESP32-CAM) ---
#define CAM_PIN_PWDN   32
#define CAM_PIN_RESET  -1
#define CAM_PIN_XCLK    0
#define CAM_PIN_SIOD   26
#define CAM_PIN_SIOC   27
#define CAM_PIN_D7     35
#define CAM_PIN_D6     34
#define CAM_PIN_D5     39
#define CAM_PIN_D4     36
#define CAM_PIN_D3     21
#define CAM_PIN_D2     19
#define CAM_PIN_D1     18
#define CAM_PIN_D0      5
#define CAM_PIN_VSYNC  25
#define CAM_PIN_HREF   23
#define CAM_PIN_PCLK   22
#define CAM_PIN_FLASH   4
#define CAM_XCLK_FREQ 20000000
#define CAM_FRAME_SIZE FRAMESIZE_QVGA
#define CAM_JPEG_QUALITY 12
#define CAM_FB_COUNT 1

// --- Provisioning button ---
#define PROVISION_BUTTON_PIN 0
#define PROVISION_HOLD_MS    4000

// --- Visit detection ---
#define VISIT_EMA_ALPHA                0.15f
#define VISIT_BASELINE_ALPHA           0.001f
#define VISIT_BASELINE_EPS_G           2.0f
#define VISIT_BASELINE_STABLE_MS       3000
#define VISIT_STABLE_WINDOW_MS         150
#define VISIT_STABLE_SPREAD_G          1.0f
#define VISIT_ENTER_DELTA_G            12.0f
#define VISIT_ENTER_DURATION_MS        200
#define VISIT_EXIT_DELTA_G             6.0f
#define VISIT_EXIT_DURATION_MS         500
#define VISIT_MAX_DURATION_MS          30000

#define PIR_EVENT_MIN_WEIGHT_G         80.0f
#define PIR_EVENT_EVAL_DELAY_MS        500
#define PIR_EVENT_COOLDOWN_MS          10000
#define PIR_EVENT_SNAPSHOT_COUNT       10
#define PIR_EVENT_VIDEO_SECONDS        5

#define MINI_BOOT_TIMEOUT_MS           3000
#define MINI_READY_TIMEOUT_MS          12000
#define MINI_READY_SETTLE_MS           1000

// Legacy aliases (temporary)
#define VISIT_WEIGHT_THRESHOLD_G VISIT_ENTER_DELTA_G
#define VISIT_MOTION_WINDOW_MS   VISIT_ENTER_DURATION_MS
#define VISIT_IDLE_TIMEOUT_MS    VISIT_MAX_DURATION_MS

// --- Power model ---
#define SERIES_CELLS 1
#define R_SYSTEM_OHMS 0.02f
#define HX711_CAL_DEFAULT 0.02536f  // grams per count baseline
#define CELL_WARN_V 3.35f
#define CELL_CRIT_V 3.15f
#define BRIGHTNESS_MAX_SAFE   128
#define BRIGHTNESS_WARN_LIMIT 48
#define BRIGHTNESS_CRIT_LIMIT 0

// Logging configuration (Step 15A)
#ifndef LOG_RING_CAPACITY
#define LOG_RING_CAPACITY 64
#endif
#ifndef LOG_ENTRY_MAX_LEN
#define LOG_ENTRY_MAX_LEN 96
#endif
#ifndef CELL_COUNT
#define CELL_COUNT SERIES_CELLS
#endif




