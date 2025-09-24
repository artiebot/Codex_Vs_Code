#include "wifi_manager.h"
#include "storage.h"
#include "provisioning.h"
#include "led.h"
#include "src/config.h"
#include <WiFi.h>

namespace WifiManager {
namespace {
struct WifiState {
  bool haveConfig=false;
  Storage::WifiConfig cfg;
  unsigned long connectStart=0;
  uint8_t attempt=0;
  bool forcedPortal=false;
  bool apMode=false;
} state;

void startPortal() {
  state.apMode = true;
  Led::setState(Led::State::PROVISIONING);
  Provisioning::start();
}

void beginConnect() {
  state.apMode = false;
  state.connectStart = millis();
  state.attempt = 1;
  Led::setState(Led::State::CONNECTING_WIFI);
  WiFi.mode(WIFI_STA);
  WiFi.begin(state.cfg.ssid, state.cfg.password);
}
}

void begin() {
  Storage::begin();
  Storage::BootCounter boot;
  Storage::loadBootCounter(boot);
  uint64_t nowUs = esp_timer_get_time();
  if (nowUs - boot.lastUs < 60ULL * 1000000ULL) {
    boot.count++;
  } else {
    boot.count = 1;
  }
  boot.lastUs = nowUs;
  Storage::saveBootCounter(boot);
  if (boot.count >= 3) {
    state.forcedPortal = true;
    Storage::resetBootCounter();
  }

  state.haveConfig = Storage::loadWifi(state.cfg);

  if (!state.haveConfig || state.forcedPortal) {
    startPortal();
    return;
  }
  beginConnect();
}

void loop() {
  if (state.apMode) {
    Provisioning::loop();
    return;
  }

  if (WiFi.status() == WL_CONNECTED) {
    static bool wasConnected=false;
    if (!wasConnected) {
      wasConnected = true;
      state.attempt = 0;
      Storage::resetBootCounter();
      Led::setState(Led::State::ONLINE);
    }
    return;
  }

  static unsigned long disconnectTs = 0;
  if (state.haveConfig && !state.apMode) {
    unsigned long now = millis();
    if (state.attempt == 0) {
      // connection dropped after being online
      state.attempt = 1;
      state.connectStart = now;
      WiFi.disconnect();
      WiFi.begin(state.cfg.ssid, state.cfg.password);
      Led::setState(Led::State::CONNECTING_WIFI);
    } else if (now - state.connectStart > 10000UL) {
      state.attempt++;
      if (state.attempt > 3) {
        startPortal();
        return;
      }
      state.connectStart = now;
      WiFi.disconnect();
      delay(50);
      WiFi.begin(state.cfg.ssid, state.cfg.password);
    }
  }
}

bool connected() { return WiFi.status() == WL_CONNECTED; }
bool apMode() { return state.apMode; }

}
