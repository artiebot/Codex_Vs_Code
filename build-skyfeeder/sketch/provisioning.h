#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\provisioning.h"
#pragma once
#include <Arduino.h>
class PubSubClient;
namespace SF {
struct ProvisionedConfig{
  char wifi_ssid[33];
  char wifi_pass[65];
  char mqtt_host[65];
  uint16_t mqtt_port;
  char mqtt_user[33];
  char mqtt_pass[33];
  char device_id[33];
};
class Provisioning{
public:
  void begin();
  void loop();
  bool provisioningMode() const { return setup_mode_; }
  bool isReady() const { return ready_; }
  const ProvisionedConfig& config() const { return cfg_; }
  const char* deviceId() const;
  // Legacy MQTT hook - kept as no-op for compatibility.
  void onMqttConnected(PubSubClient& /*client*/) {}
  bool deriveAndSave(const ProvisionedConfig& incoming);
  // Wi-Fi connection lifecycle notifications used by the non-blocking
  // Wi-Fi state machine. These allow provisioning to track failure windows
  // and decide when to escalate back into setup AP mode.
  void notifyWifiAttempt();
  void notifyWifiConnected();
  void notifyWifiConnectTimeout();
private:
  void load();
  void save(const ProvisionedConfig& incoming);
  bool cfgValid(const ProvisionedConfig& incoming) const;
  bool buttonRequestedSetup();
  void startSetupAp();
  void stopSetupAp();
  void handleHttp();
  void ensureMdns();
  void publishDiscovery(PubSubClient& client);
  void enterProvisioningMode();
  void runtimeButtonCheck();
  void monitorStability();
  uint8_t recordBootCycle();
  void clearPowerCycleCounter();
  void loadPowerCycleState();
  void savePowerCycleState();
  void loadWifiFailureState();
  void saveWifiFailureState();
  bool setup_mode_=false;
  bool ready_=false;
  bool discovery_published_=false;
  bool mdns_ready_=false;
  unsigned long runtime_press_start_=0;
  bool runtime_press_active_=false;
  bool runtime_triggered_=false;
  ProvisionedConfig cfg_{};
  struct PowerCycleState {
    uint8_t count;
    bool armed;
  } power_cycle_state_{0, false};
  bool power_cycle_loaded_ = false;
  bool power_cycle_cleared_ = false;
  unsigned long stable_connected_since_ms_ = 0;
  bool applied_stable_auto_ = false;
  bool wifi_failure_state_loaded_ = false;
  bool wifi_connected_ = false;
  uint8_t wifi_fail_count_ = 0;
  unsigned long wifi_fail_window_start_ms_ = 0;
};
extern Provisioning provisioning;
} // namespace SF
