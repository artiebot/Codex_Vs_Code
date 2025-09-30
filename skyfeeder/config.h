#pragma once

#define FW_VERSION  "1.4.0"

// --- Provisioning defaults (tweak per deployment) ---
#define WIFI_DEFAULT_SSID  "wififordays"
#define WIFI_DEFAULT_PASS  "wififordayspassword1236"
#define MQTT_DEFAULT_HOST  "10.0.0.4"
#define MQTT_DEFAULT_PORT  1883
#define MQTT_DEFAULT_USER  "dev1"
#define MQTT_DEFAULT_PASS  "dev1pass"
#define DEVICE_ID_DEFAULT  "sf-mock01"

// --- Lighting & UX ---
#define LED_PIN 2
#define NEOPIXEL_PIN   5
#define NEOPIXEL_COUNT 64
#define LED_OVERRIDE_MS         15000
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
#define VISIT_WEIGHT_THRESHOLD_G 25.0f
#define VISIT_MOTION_WINDOW_MS   2000
#define VISIT_IDLE_TIMEOUT_MS    5000

// --- Power model ---
#define SERIES_CELLS 1
#define R_SYSTEM_OHMS 0.02f
#define HX711_CAL_DEFAULT 0.002536f  // grams per count baseline
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


