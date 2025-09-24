#pragma once
// --- WIFI & MQTT ---
#define WIFI_SSID  "wififordays"
#define WIFI_PASS  "wififordayspassword1236"

#define MQTT_HOST  "10.0.0.4"
#define MQTT_PORT  1883

#define MQTT_USER  "dev1"
#define MQTT_PASS  "dev1pass"

// Device identity used in topics: skyfeeder/<DEVICE_ID>/...
#define DEVICE_ID  "dev1"

// --- HARDWARE PINS ---
#define LED_PIN 2

// WS2812B (NeoPixel) settings
#define NEOPIXEL_PIN   5
#define NEOPIXEL_COUNT 64

// LED UX tuning
#define LED_OVERRIDE_MS         15000
#define LED_IDLE_BRIGHTNESS     96
#define LED_WARN_BRIGHTNESS     64
#define LED_CRIT_BRIGHTNESS     96

// ESP32-CAM (AI Thinker defaults)
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

// I2C pins for ESP32
#define I2C_SDA 25
#define I2C_SCL 26

// INA260 ALERT
#define INA260_ALERT_PIN 17

// HX711 load cell amplifier pins
#define HX711_DOUT_PIN 32
#define HX711_SCK_PIN  33

// PIR motion sensor
#define PIR_MOTION_PIN 27
#define MOTION_DEBUG_BLINK 0

// Visit fusion tuning
#define VISIT_WEIGHT_THRESHOLD_G 25.0f
#define VISIT_MOTION_WINDOW_MS   2000
#define VISIT_IDLE_TIMEOUT_MS    5000

// --- POWER POLICY ---
#define CELL_COUNT 1
#define CELL_WARN_V 3.35f
#define CELL_CRIT_V 3.15f
#define BRIGHTNESS_MAX_SAFE   128
#define BRIGHTNESS_WARN_LIMIT 48
#define BRIGHTNESS_CRIT_LIMIT 0
