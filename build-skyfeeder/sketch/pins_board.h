#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\pins_board.h"
#pragma once

#include <Arduino.h>

// Board-level pin assignments for SkyFeeder ESP32 controller.
// Adjust these constants to match your wiring harness.

#ifndef MINI_UART_TX_PIN
#define MINI_UART_TX_PIN 23  // ESP32 GPIO23 -> AMB82 Mini PE2 (Mini RX)
#endif

#ifndef MINI_UART_RX_PIN
#define MINI_UART_RX_PIN 34  // ESP32 GPIO34 <- AMB82 Mini PE1 (Mini TX)
#endif

#ifndef MINI_WAKE_PIN
#define MINI_WAKE_PIN 16
#endif

#ifndef MINI_WAKE_ACTIVE_HIGH
#define MINI_WAKE_ACTIVE_HIGH 1
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
constexpr bool MiniWakeActiveHigh = MINI_WAKE_ACTIVE_HIGH != 0;

inline HardwareSerial& miniSerial() {
  return Serial2;
}
}  // namespace Pins
}  // namespace SF
