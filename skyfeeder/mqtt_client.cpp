// Legacy MQTT client stub.
// In the current HTTP/WS-only architecture, MQTT is no longer used as an
// active control plane. This file is kept to avoid large-scale churn. The MQTT
// client itself is effectively a no-op; the only active responsibility here is
// managing Wi-Fi connectivity via a non-blocking state machine.

#include "mqtt_client.h"

#include <Arduino.h>

#include "provisioning.h"
#include "led_ux.h"
#include "logging.h"

namespace {
constexpr unsigned long kConnectTimeoutMs = WIFI_CONNECT_TIMEOUT_MS;
constexpr unsigned long kOfflineRetryMs = WIFI_OFFLINE_RETRY_MS;
}  // namespace

namespace SF {
Mqtt mqtt;

void Mqtt::ensureWiFi() {
  // If provisioning is not ready, Wi-Fi credentials are not yet available.
  // Stay idle here and let the provisioning system run its captive portal.
  if (!SF::provisioning.isReady()) {
    wifiState_ = WifiState::Provisioning;
    return;
  }

  const unsigned long now = millis();
  wl_status_t status = WiFi.status();

  switch (wifiState_) {
    case WifiState::Idle:
    case WifiState::OfflineRetry: {
      if (status == WL_CONNECTED) {
        wifiState_ = WifiState::Online;
        SF::provisioning.notifyWifiConnected();
        SF::ledUx.setMode(SF::LedUx::Mode::ONLINE);
        break;
      }
      if (wifiState_ == WifiState::OfflineRetry && now < wifiNextRetryMs_) {
        // Waiting until the next scheduled retry window.
        break;
      }
      const auto& cfg = SF::provisioning.config();
      SF::Log::info("wifi", "starting connect attempt ssid=%s", cfg.wifi_ssid);
      SF::provisioning.notifyWifiAttempt();
      WiFi.mode(WIFI_STA);
      SF::ledUx.setMode(SF::LedUx::Mode::CONNECTING_WIFI);
      WiFi.begin(cfg.wifi_ssid, cfg.wifi_pass);
      wifiState_ = WifiState::Connecting;
      wifiConnectStartMs_ = now;
      break;
    }
    case WifiState::Connecting: {
      if (status == WL_CONNECTED) {
        wifiState_ = WifiState::Online;
        SF::provisioning.notifyWifiConnected();
        SF::ledUx.setMode(SF::LedUx::Mode::ONLINE);
        SF::Log::info("wifi", "connected");
      } else if (now - wifiConnectStartMs_ > kConnectTimeoutMs) {
        // Timed out waiting for this attempt; record the failure and move into
        // a background retry state.
        SF::Log::warn("wifi", "connect timeout after %lu ms", now - wifiConnectStartMs_);
        SF::provisioning.notifyWifiConnectTimeout();
        wifiState_ = WifiState::OfflineRetry;
        wifiNextRetryMs_ = now + kOfflineRetryMs;
        WiFi.disconnect();
        SF::ledUx.setMode(SF::LedUx::Mode::AUTO);
      }
      break;
    }
    case WifiState::Online: {
      if (status != WL_CONNECTED) {
        // Connection dropped; schedule a background retry without instantly
        // flipping into provisioning.
        SF::Log::warn("wifi", "link dropped, scheduling retry");
        SF::provisioning.notifyWifiConnectTimeout();
        wifiState_ = WifiState::OfflineRetry;
        wifiNextRetryMs_ = now;
        SF::ledUx.setMode(SF::LedUx::Mode::AUTO);
      }
      break;
    }
    case WifiState::Provisioning: {
      // Provisioning is active; Wi-Fi connect attempts are driven by the
      // captive portal flow, so there is nothing to do here.
      break;
    }
  }
}

bool Mqtt::ensureMqtt() {
  // MQTT is intentionally disabled; always report "not connected".
  return false;
}

void Mqtt::publishStatusOnline() {
  // Legacy stub – no-op in HTTP/WS-only mode.
}

void Mqtt::begin() {
  // Initialise Wi-Fi state; actual work is driven from loop() via ensureWiFi().
  wifiState_ = WifiState::Idle;
  wifiConnectStartMs_ = 0;
  wifiNextRetryMs_ = 0;
  ensureWiFi();
}

void Mqtt::loop() {
  // Maintain Wi-Fi, but skip MQTT entirely.
  ensureWiFi();
}

}  // namespace SF

