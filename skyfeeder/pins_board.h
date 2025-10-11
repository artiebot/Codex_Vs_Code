#pragma once

#include <Arduino.h>

// Board-level pin assignments for SkyFeeder ESP32 controller.
// Adjust these constants to match your wiring harness.

#ifndef MINI_UART_RX_PIN
#define MINI_UART_RX_PIN 12
#endif

#ifndef MINI_UART_TX_PIN
#define MINI_UART_TX_PIN 13
#endif

#ifndef MINI_WAKE_PIN
#define MINI_WAKE_PIN 14
#endif

#ifndef MINI_PWR_PIN
#define MINI_PWR_PIN (-1)
#endif

namespace SF {
namespace Pins {
constexpr int MiniUartRx = MINI_UART_RX_PIN;
constexpr int MiniUartTx = MINI_UART_TX_PIN;
constexpr int MiniWake = MINI_WAKE_PIN;
constexpr int MiniPowerEnable = MINI_PWR_PIN;

inline HardwareSerial& miniSerial() {
  return Serial2;
}
}  // namespace Pins
}  // namespace SF

