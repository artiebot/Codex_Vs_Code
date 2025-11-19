#include "provisioning.h"
#include "config.h"
#ifndef ARDUINOJSON_DEPRECATED
#define ARDUINOJSON_DEPRECATED(msg)
#endif
#include <ArduinoJson.h>
#include <WiFi.h>
#include <DNSServer.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <ESP.h>
#include <string.h>
#include "led_ux.h"
#include "storage_nvs.h"
#include "logging.h"

namespace {
constexpr uint32_t kMagic = 0x53465014;
constexpr uint32_t kPowerCycleMagic = 0x53504331;  // "SPC1"
const unsigned long HOLD_MS = PROVISION_HOLD_MS;
constexpr unsigned long kStableConnectedMs = 120000;
// Wi-Fi failure tracking configuration. Failures are counted within the
// configured time window; once WIFI_MAX_FAILS_BEFORE_PROVISIONING is reached
// the device escalates back into provisioning mode.
constexpr uint8_t kWifiFailureLimit = WIFI_MAX_FAILS_BEFORE_PROVISIONING;
constexpr unsigned long kWifiFailureWindowMs = WIFI_FAIL_WINDOW_MS;
DNSServer dnsServer;
WebServer portalServer(80);
bool portalActive = false;
SF::Provisioning* gProvisioning = nullptr;

void copySafe(char* dst, size_t len, const char* src) {
  if (len == 0) return;
  if (!src) { dst[0] = '\0'; return; }
  strncpy(dst, src, len - 1);
  dst[len - 1] = '\0';
}
String htmlEscape(const char* in) {
  String s(in ? in : "");
  s.replace("&", "&amp;");
  s.replace("<", "&lt;");
  s.replace(">", "&gt;");
  s.replace("\"", "&quot;");
  return s;
}

void sendPortalPage(bool saved=false) {
  auto& prov=*gProvisioning; const auto& cfg=prov.config(); String html;
  html.reserve(2048);
  html += "<!DOCTYPE html><html><head><meta charset='utf-8'><title>SkyFeeder Setup</title><style>body{font-family:Arial;background:#0b1d2a;color:#fff;}form{max-width:420px;margin:40px auto;padding:20px;background:#123;box-shadow:0 0 12px rgba(0,0,0,.4);}label{display:block;margin-top:12px;}input{width:100%;padding:8px;border:1px solid #456;border-radius:4px;background:#0e2233;color:#fff;}button{margin-top:18px;width:100%;padding:10px;background:#29a19c;border:0;border-radius:4px;color:#fff;font-size:16px;}h1{text-align:center;font-weight:600;}</style></head><body><form method='POST' action='/submit'><h1>SkyFeeder Setup</h1>";
  if(saved) html += "<p>Configuration saved! Device will reboot...</p>";
  html += "<label>Wi-Fi SSID<input name='ssid' value='" + htmlEscape(cfg.wifi_ssid) + "' required></label>";
  html += "<label>Wi-Fi Password<input name='wifi_pass' value='" + htmlEscape(cfg.wifi_pass) + "'></label>";
  html += "<label>Device ID<input name='device_id' value='" + htmlEscape(cfg.device_id) + "' required></label>";
  html += "<button type='submit'>Save &amp; Reboot</button></form></body></html>";
  portalServer.send(200,"text/html",html);
}

void handleRoot(){ sendPortalPage(); }

void handleSubmit(){
  if(!gProvisioning) return;
  auto& prov=*gProvisioning;
  SF::ProvisionedConfig incoming{};
  auto copyField=[&](const char* key,char* dest,size_t len,const char* fallback){ String v=portalServer.hasArg(key)?portalServer.arg(key):String(); if(v.length()==0 && fallback) v=fallback; copySafe(dest,len,v.c_str()); };
  copyField("ssid", incoming.wifi_ssid, sizeof(incoming.wifi_ssid), WIFI_DEFAULT_SSID);
  copyField("wifi_pass", incoming.wifi_pass, sizeof(incoming.wifi_pass), WIFI_DEFAULT_PASS);
  // MQTT fields are legacy; keep using defaults internally but do not collect from the portal.
  copySafe(incoming.mqtt_host, sizeof(incoming.mqtt_host), MQTT_DEFAULT_HOST);
  incoming.mqtt_port = MQTT_DEFAULT_PORT;
  copySafe(incoming.mqtt_user, sizeof(incoming.mqtt_user), MQTT_DEFAULT_USER);
  copySafe(incoming.mqtt_pass, sizeof(incoming.mqtt_pass), MQTT_DEFAULT_PASS);
  copyField("device_id", incoming.device_id, sizeof(incoming.device_id), DEVICE_ID_DEFAULT);
  if(!prov.deriveAndSave(incoming)){ portalServer.send(400,"text/plain","Invalid configuration (ssid, host, device required)"); return; }
  sendPortalPage(true);
  delay(1000);
  ESP.restart();
}

void handleNotFound(){ sendPortalPage(); }
} // namespace

namespace SF {
Provisioning provisioning;

void Provisioning::loadPowerCycleState() {
  if (power_cycle_loaded_) return;
  struct Stored {
    uint32_t magic;
    uint8_t count;
    uint8_t armed;
  } stored{};
  if (SF::Storage::getBytes("prov", "cycle", &stored, sizeof(stored)) && stored.magic == kPowerCycleMagic) {
    power_cycle_state_.count = stored.count;
    power_cycle_state_.armed = stored.armed != 0;
  } else {
    power_cycle_state_.count = 0;
    power_cycle_state_.armed = false;
  }
  power_cycle_loaded_ = true;
}

void Provisioning::savePowerCycleState() {
  struct Stored {
    uint32_t magic;
    uint8_t count;
    uint8_t armed;
  } stored{};
  stored.magic = kPowerCycleMagic;
  stored.count = power_cycle_state_.count;
  stored.armed = power_cycle_state_.armed ? 1 : 0;
  SF::Storage::setBytes("prov", "cycle", &stored, sizeof(stored));
}

uint8_t Provisioning::recordBootCycle() {
  loadPowerCycleState();
  const esp_reset_reason_t reason = esp_reset_reason();
  if (reason == ESP_RST_BROWNOUT) {
    power_cycle_state_.count = 0;
    power_cycle_state_.armed = false;
    savePowerCycleState();
    SF::Log::warn("prov", "brownout reset detected - triple-boot counter held");
    Serial.println("[prov] brownout reset - ignoring triple-boot counter");
    return 0;
  }
  if (!power_cycle_state_.armed) {
    power_cycle_state_.count = 1;
    power_cycle_state_.armed = true;
  } else if (power_cycle_state_.count < 255) {
    power_cycle_state_.count += 1;
  }
  savePowerCycleState();
  return power_cycle_state_.count;
}

void Provisioning::clearPowerCycleCounter() {
  loadPowerCycleState();
  if (!power_cycle_state_.armed && power_cycle_state_.count == 0) {
    power_cycle_cleared_ = true;
    return;
  }
  power_cycle_state_.count = 0;
  power_cycle_state_.armed = false;
  savePowerCycleState();
  power_cycle_cleared_ = true;
}

const char* Provisioning::deviceId() const { return cfg_.device_id[0] ? cfg_.device_id : DEVICE_ID_DEFAULT; }

bool Provisioning::deriveAndSave(const ProvisionedConfig& incoming){ if(!cfgValid(incoming)) return false; save(incoming); return true; }

bool Provisioning::cfgValid(const ProvisionedConfig& incoming) const {
  // Wi-Fi-only configuration is considered valid when SSID and device_id are present.
  // MQTT fields are legacy and no longer required for normal operation.
  return incoming.wifi_ssid[0] && incoming.device_id[0];
}

void Provisioning::begin(){
  SF::Log::init();
  gProvisioning=this;
  pinMode(PROVISION_BUTTON_PIN, INPUT_PULLUP);
  Storage::begin();
  uint8_t bootCycles = recordBootCycle();
  load();
  loadWifiFailureState();
  bool tripleTriggered = bootCycles >= 3;
  if (tripleTriggered) {
    SF::Log::warn("prov", "power-cycle setup triggered count=%u", bootCycles);
  }
  if(buttonRequestedSetup() || !ready_ || tripleTriggered){
    enterProvisioningMode();
  } else {
    ready_=true;
    Topics::init(deviceId());
    SF::Log::info("boot", "provisioning ready");
    ensureMdns();
    SF::ledUx.setMode(LedUx::Mode::CONNECTING_WIFI);
    stable_connected_since_ms_ = 0;
    applied_stable_auto_ = false;
    power_cycle_cleared_ = power_cycle_state_.count == 0 && !power_cycle_state_.armed;
  }
}

void Provisioning::load(){ ProvisionedConfig defaults{}; copySafe(defaults.wifi_ssid,sizeof(defaults.wifi_ssid),WIFI_DEFAULT_SSID); copySafe(defaults.wifi_pass,sizeof(defaults.wifi_pass),WIFI_DEFAULT_PASS); copySafe(defaults.mqtt_host,sizeof(defaults.mqtt_host),MQTT_DEFAULT_HOST); defaults.mqtt_port=MQTT_DEFAULT_PORT; copySafe(defaults.mqtt_user,sizeof(defaults.mqtt_user),MQTT_DEFAULT_USER); copySafe(defaults.mqtt_pass,sizeof(defaults.mqtt_pass),MQTT_DEFAULT_PASS); copySafe(defaults.device_id,sizeof(defaults.device_id),DEVICE_ID_DEFAULT);
  struct Persisted { uint32_t magic; ProvisionedConfig cfg; } stored{};
  if(Storage::getBytes("prov","cfg", &stored, sizeof(stored)) && stored.magic==kMagic){ cfg_=stored.cfg; ready_=cfgValid(cfg_); } else { cfg_=defaults; ready_=false; }
  if(!ready_) cfg_=defaults;
}

void Provisioning::save(const ProvisionedConfig& incoming){
  struct Persisted { uint32_t magic; ProvisionedConfig cfg; } stored{};
  stored.magic=kMagic;
  stored.cfg=incoming;
  cfg_=incoming;
  Storage::setBytes("prov","cfg", &stored, sizeof(stored));
  Topics::init(deviceId());
  discovery_published_=false;
  ready_=true;
  setup_mode_=false;
  mdns_ready_=false;
  stopSetupAp();
  clearPowerCycleCounter();
  stable_connected_since_ms_ = 0;
  applied_stable_auto_ = false;
  SF::ledUx.setMode(LedUx::Mode::CONNECTING_WIFI);
  // Reset Wi-Fi failure tracking when a fresh configuration is saved.
  wifi_connected_ = false;
  wifi_fail_count_ = 0;
  wifi_fail_window_start_ms_ = 0;
  wifi_failure_state_loaded_ = true;
  saveWifiFailureState();
}

bool Provisioning::buttonRequestedSetup(){ if(digitalRead(PROVISION_BUTTON_PIN)==LOW){ unsigned long start=millis(); while(digitalRead(PROVISION_BUTTON_PIN)==LOW){ if(millis()-start >= HOLD_MS) return true; delay(10); } } return false; }

void Provisioning::startSetupAp(){ WiFi.mode(WIFI_AP); WiFi.softAP("SkyFeeder-Setup"); dnsServer.start(53,"*",WiFi.softAPIP()); portalServer.on("/", HTTP_GET, handleRoot); portalServer.on("/submit", HTTP_POST, handleSubmit); portalServer.onNotFound(handleNotFound); portalServer.begin(); portalActive=true; SF::ledUx.setMode(LedUx::Mode::PROVISIONING); }

void Provisioning::stopSetupAp(){ if(portalActive){ portalServer.stop(); dnsServer.stop(); portalActive=false; } WiFi.softAPdisconnect(true); WiFi.mode(WIFI_STA); }

void Provisioning::handleHttp(){ if(!portalActive) return; dnsServer.processNextRequest(); portalServer.handleClient(); }

void Provisioning::enterProvisioningMode(){
  setup_mode_=true;
  ready_=false;
  Topics::init(deviceId());
  SF::Log::warn("prov", "entering setup AP mode");
  startSetupAp();
  runtime_press_active_=true;
  stable_connected_since_ms_ = 0;
  power_cycle_cleared_ = false;
  applied_stable_auto_ = false;
  // Reset Wi-Fi failure tracking when explicitly entering provisioning.
  wifi_connected_ = false;
  wifi_fail_count_ = 0;
  wifi_fail_window_start_ms_ = 0;
  wifi_failure_state_loaded_ = true;
  saveWifiFailureState();
}

void Provisioning::runtimeButtonCheck(){ int level=digitalRead(PROVISION_BUTTON_PIN); unsigned long now=millis(); if(level==LOW){ if(!runtime_press_active_){ runtime_press_active_=true; runtime_press_start_=now; } else if((now-runtime_press_start_)>=HOLD_MS && !setup_mode_){ enterProvisioningMode(); } } else { runtime_press_active_=false; runtime_press_start_=0; } }

void Provisioning::monitorStability() {
  if (setup_mode_ || !ready_) {
    stable_connected_since_ms_ = 0;
    applied_stable_auto_ = false;
    return;
  }
  if (WiFi.status() == WL_CONNECTED) {
    unsigned long now = millis();
    if (stable_connected_since_ms_ == 0) {
      stable_connected_since_ms_ = now;
    }
    unsigned long elapsed = now - stable_connected_since_ms_;
    if (!power_cycle_cleared_ && elapsed >= kStableConnectedMs) {
      clearPowerCycleCounter();
    }
    if (!applied_stable_auto_ && elapsed >= kStableConnectedMs) {
      SF::ledUx.setMode(LedUx::Mode::AUTO);
      applied_stable_auto_ = true;
    }
  } else {
    stable_connected_since_ms_ = 0;
    applied_stable_auto_ = false;
  }
}

void Provisioning::loadWifiFailureState() {
  if (wifi_failure_state_loaded_) return;
  int32_t count = 0;
  int32_t windowMs = 0;
  if (SF::Storage::getInt32("prov", "wifi_fail_count", count) && count > 0) {
    if (count > 255) count = 255;
    wifi_fail_count_ = static_cast<uint8_t>(count);
  } else {
    wifi_fail_count_ = 0;
  }
  if (SF::Storage::getInt32("prov", "wifi_fail_window_ms", windowMs) && windowMs > 0) {
    wifi_fail_window_start_ms_ = static_cast<unsigned long>(windowMs);
  } else {
    wifi_fail_window_start_ms_ = 0;
  }
  wifi_failure_state_loaded_ = true;
}

void Provisioning::saveWifiFailureState() {
  if (!wifi_failure_state_loaded_) return;
  SF::Storage::setInt32("prov", "wifi_fail_count", static_cast<int32_t>(wifi_fail_count_));
  SF::Storage::setInt32("prov", "wifi_fail_window_ms", static_cast<int32_t>(wifi_fail_window_start_ms_));
}

void Provisioning::notifyWifiAttempt() {
  if (!ready_ || setup_mode_) return;
  loadWifiFailureState();
  wifi_connected_ = false;
}

void Provisioning::notifyWifiConnected() {
  if (!ready_ || setup_mode_) return;
  loadWifiFailureState();
  if (!wifi_connected_) {
    wifi_connected_ = true;
    wifi_fail_count_ = 0;
    wifi_fail_window_start_ms_ = 0;
    saveWifiFailureState();
    // Once Wi-Fi is stable, clear the boot power-cycle counter so a future
    // triple power-cycle can intentionally re-enter provisioning.
    clearPowerCycleCounter();
  }
}

void Provisioning::notifyWifiConnectTimeout() {
  if (!ready_ || setup_mode_) return;
  loadWifiFailureState();
  wifi_connected_ = false;
  unsigned long now = millis();
  bool windowExpired = false;
  if (wifi_fail_window_start_ms_ == 0 || now < wifi_fail_window_start_ms_) {
    windowExpired = true;
  } else if ((now - wifi_fail_window_start_ms_) > kWifiFailureWindowMs) {
    windowExpired = true;
  }
  if (wifi_fail_count_ == 0 || windowExpired) {
    wifi_fail_count_ = 1;
    wifi_fail_window_start_ms_ = now;
  } else if (wifi_fail_count_ < 255) {
    ++wifi_fail_count_;
  }
  saveWifiFailureState();
  if (wifi_fail_count_ >= kWifiFailureLimit) {
    SF::Log::warn("wifi", "failure threshold exceeded (fails=%u), entering provisioning", wifi_fail_count_);
    enterProvisioningMode();
  }
}

void Provisioning::loop(){
  if(setup_mode_){
    handleHttp();
    return;
  }
  runtimeButtonCheck();
  ensureMdns();
  monitorStability();
}

void Provisioning::ensureMdns(){
  if(!ready_||mdns_ready_) return;
  if(!MDNS.begin(deviceId())) return;
  MDNS.addService("skyfeeder","tcp",80);
  MDNS.addServiceTxt("skyfeeder","tcp","step","sf_step15D_ota_safe_staging");
  mdns_ready_=true;
}

// MQTT discovery is now legacy and intentionally disabled; HTTP/WS clients
// should use mDNS + HTTP APIs for discovery instead.
void Provisioning::publishDiscovery(PubSubClient&){
  SF::Log::info("prov", "MQTT discovery is disabled in HTTP/WS-only mode");
}

} // namespace SF






