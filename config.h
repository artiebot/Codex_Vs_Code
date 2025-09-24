#pragma once

// Hardware pin map remains shared across modules
#define LED_PIN 2
#define NEOPIXEL_PIN   5
#define NEOPIXEL_COUNT 64
#define I2C_SDA 25
#define I2C_SCL 26
#define HX711_DOUT_PIN 32
#define HX711_SCK_PIN  33
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
#define PROVISION_BUTTON_PIN 0
#define PROVISION_HOLD_MS    4000
#define INA260_ALERT_PIN 17

#include "src/config.h"

// Logging configuration (Step 15A)
#ifndef LOG_RING_CAPACITY
#define LOG_RING_CAPACITY 64 // Max entries retained in memory
#endif
#ifndef LOG_ENTRY_MAX_LEN
#define LOG_ENTRY_MAX_LEN 96 // Max message length per log entry
#endif

