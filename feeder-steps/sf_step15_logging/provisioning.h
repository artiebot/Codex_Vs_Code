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
  void onMqttConnected(PubSubClient& client);
  bool deriveAndSave(const ProvisionedConfig& incoming);
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
  void checkRuntimeButton();
  bool setup_mode_=false;
  bool ready_=false;
  bool discovery_published_=false;
  bool mdns_ready_=false;
  unsigned long runtime_press_start_=0;
  bool runtime_press_active_=false;
  bool runtime_triggered_=false;
  ProvisionedConfig cfg_{};
};
extern Provisioning provisioning;
} // namespace SF
