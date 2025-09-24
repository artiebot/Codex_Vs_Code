#include "led.h"

namespace Led {
namespace {
uint8_t ledPin = 255;
State current = State::CONNECTING_WIFI;
unsigned long lastToggle = 0;
bool ledOn = false;
}

void begin(uint8_t pin) {
  ledPin = pin;
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, LOW);
  lastToggle = millis();
}

void setState(State s) {
  current = s;
  lastToggle = millis();
}

void loop() {
  if (ledPin == 255) return;
  unsigned long now = millis();
  unsigned long interval = 500;
  switch (current) {
    case State::PROVISIONING: interval = 900; break; // slow heartbeat
    case State::CONNECTING_WIFI: interval = 200; break; // fast blink
    case State::ONLINE: interval = 1500; break; // gentle pulse (long on, short off)
  }

  if (current == State::ONLINE) {
    if (now - lastToggle > interval) {
      ledOn = !ledOn;
      digitalWrite(ledPin, ledOn ? HIGH : LOW);
      lastToggle = now;
    }
  } else {
    if (now - lastToggle > interval) {
      ledOn = !ledOn;
      digitalWrite(ledPin, ledOn ? HIGH : LOW);
      lastToggle = now;
    }
  }
}

} // namespace Led
