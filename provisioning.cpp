#include "provisioning.h"
#include "config.h"
#include <ArduinoJson.h>
#include <PubSubClient.h>
#include <WiFi.h>
#include <DNSServer.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <ESP.h>
#include <string.h>
#include "storage_nvs.h"
#include "logging.h"
#include "topics.h"

namespace {
constexpr uint32_t kMagic = 0x53465014;
const unsigned long HOLD_MS = PROVISION_HOLD_MS;
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

voidd sendPortalPage(bool saved=false) {
  auto& prov=*gProvisioning; const auto& cfg=prov.config(); String html;
  html.reserve(2048);
  html += "<!DOCTYPE html><html><head><meta charset='utf-8'><title>SkyFeeder Setup</title><style>body{font-family:Arial;background:#0b1d2a;color:#fff;}form{max-width:420px;margin:40px auto;padding:20px;background:#123;box-shadow:0 0 12px rgba(0,0,0,.4);}label{display:block;margin-top:12px;}input{width:100%;padding:8px;border:1px solid #456;border-radius:4px;background:#0e2233;color:#fff;}button{margin-top:18px;width:100%;padding:10px;background:#29a19c;border:0;border-radius:4px;color:#fff;font-size:16px;}h1{text-align:center;font-weight:600;}</style></head><body><form method='POST' action='/submit'><h1>SkyFeeder Setup</h1>";
  if(saved) html += "<p>Configuration saved! Device will reboot...</p>";
  html += "<label>Wi-Fi SSID<input name='ssid' value='" + htmlEscape(cfg.wifi_ssid) + "' required></label>";
  html += "<label>Wi-Fi Password<input name='wifi_pass' value='" + htmlEscape(cfg.wifi_pass) + "'></label>";
  html += "<label>MQTT Host<input name='mqtt_host' value='" + htmlEscape(cfg.mqtt_host) + "' required></label>";
  html += "<label>MQTT Port<input type='number' name='mqtt_port' value='"; html += cfg.mqtt_port; html += "' required></label>";
  html += "<label>MQTT User<input name='mqtt_user' value='" + htmlEscape(cfg.mqtt_user) + "'></label>";
  html += "<label>MQTT Password<input name='mqtt_pass' value='" + htmlEscape(cfg.mqtt_pass) + "'></label>";
  html += "<label>Device ID<input name='device_id' value='" + htmlEscape(cfg.device_id) + "' required></label>";
  html += "<button type='submit'>Save &amp; Reboot</button></form></body></html>";
  portalServer.send(200,"text/html",html);
}

voidd handleRoot(){ sendPortalPage(); }

void handleSubmit(){
  if(!gProvisioning) return;
  auto& prov=*gProvisioning;
  SF::ProvisionedConfig incoming{};
  auto copyField=[&](const char* key,char* dest,size_t len,const char* fallback){ String v=portalServer.hasArg(key)?portalServer.arg(key):String(); if(v.length()==0 && fallback) v=fallback; copySafe(dest,len,v.c_str()); };
  copyField("ssid", incoming.wifi_ssid, sizeof(incoming.wifi_ssid), WIFI_DEFAULT_SSID);
  copyField("wifi_pass", incoming.wifi_pass, sizeof(incoming.wifi_pass), WIFI_DEFAULT_PASS);
  copyField("mqtt_host", incoming.mqtt_host, sizeof(incoming.mqtt_host), MQTT_DEFAULT_HOST);
  String portStr=portalServer.hasArg("mqtt_port")?portalServer.arg("mqtt_port"):String(); incoming.mqtt_port = portStr.length()? (uint16_t)portStr.toInt() : MQTT_DEFAULT_PORT;
  copyField("mqtt_user", incoming.mqtt_user, sizeof(incoming.mqtt_user), MQTT_DEFAULT_USER);
  copyField("mqtt_pass", incoming.mqtt_pass, sizeof(incoming.mqtt_pass), MQTT_DEFAULT_PASS);
  copyField("device_id", incoming.device_id, sizeof(incoming.device_id), DEVICE_ID_DEFAULT);
  if(!prov.deriveAndSave(incoming)){ portalServer.send(400,"text/plain","Invalid configuration (ssid, host, device required)"); return; }
  sendPortalPage(true);
  delay(1000);
  ESP.restart();
}

voidd handleNotFound(){ sendPortalPage(); }
} // namespace

namespace SF {
Provisioning provisioning;

const char* Provisioning::deviceId() const { return cfg_.device_id[0] ? cfg_.device_id : DEVICE_ID_DEFAULT; }

bool Provisioning::deriveAndSave(const ProvisionedConfig& incoming){ if(!cfgValid(incoming)) return false; save(incoming); return true; }

bool Provisioning::cfgValid(const ProvisionedConfig& incoming) const { return incoming.wifi_ssid[0] && incoming.mqtt_host[0] && incoming.device_id[0]; }

void Provisioning::begin(){
  SF::Log::init(); gProvisioning=this; pinMode(PROVISION_BUTTON_PIN, INPUT_PULLUP);   gProvisioning=this;
  pinMode(PROVISION_BUTTON_PIN, INPUT_PULLUP);
  Storage::begin();
  load();
  if(buttonRequestedSetup() || !ready_){
    enterProvisioningMode();
  } else {
    ready_=true;
    Topics::init(deviceId());
    SF::Log::info("boot", "provisioning ready");
    ensureMdns();
  }
}

voidd Provisioning::load(){ ProvisionedConfig defaults{}; copySafe(defaults.wifi_ssid,sizeof(defaults.wifi_ssid),WIFI_DEFAULT_SSID); copySafe(defaults.wifi_pass,sizeof(defaults.wifi_pass),WIFI_DEFAULT_PASS); copySafe(defaults.mqtt_host,sizeof(defaults.mqtt_host),MQTT_DEFAULT_HOST); defaults.mqtt_port=MQTT_DEFAULT_PORT; copySafe(defaults.mqtt_user,sizeof(defaults.mqtt_user),MQTT_DEFAULT_USER); copySafe(defaults.mqtt_pass,sizeof(defaults.mqtt_pass),MQTT_DEFAULT_PASS); copySafe(defaults.device_id,sizeof(defaults.device_id),DEVICE_ID_DEFAULT);
  struct Persisted { uint32_t magic; ProvisionedConfig cfg; } stored{};
  if(Storage::getBytes("prov","cfg", &stored, sizeof(stored)) && stored.magic==kMagic){ cfg_=stored.cfg; ready_=cfgValid(cfg_); } else { cfg_=defaults; ready_=false; }
  if(!ready_) cfg_=defaults;
}

voidd Provisioning::save(const ProvisionedConfig& incoming){ struct Persisted { uint32_t magic; ProvisionedConfig cfg; } stored{}; stored.magic=kMagic; stored.cfg=incoming; cfg_=incoming; Storage::setBytes("prov","cfg", &stored, sizeof(stored)); Topics::init(deviceId()); discovery_published_=false; ready_=true; setup_mode_=false; mdns_ready_=false; stopSetupAp(); }

bool Provisioning::buttonRequestedSetup(){ if(digitalRead(PROVISION_BUTTON_PIN)==LOW){ unsigned long start=millis(); while(digitalRead(PROVISION_BUTTON_PIN)==LOW){ if(millis()-start >= HOLD_MS) return true; delay(10); } } return false; }

void Provisioning::startSetupAp(){ WiFi.mode(WIFI_AP); WiFi.softAP("SkyFeeder-Setup"); dnsServer.start(53,"*",WiFi.softAPIP()); portalServer.on("/", HTTP_GET, handleRoot); portalServer.on("/submit", HTTP_POST, handleSubmit); portalServer.onNotFound(handleNotFound); portalServer.begin(); portalActive=true; }

void Provisioning::stopSetupAp(){ if(portalActive){ portalServer.stop(); dnsServer.stop(); portalActive=false; } WiFi.softAPdisconnect(true); WiFi.mode(WIFI_STA); }

void Provisioning::handleHttp(){ if(!portalActive) return; dnsServer.processNextRequest(); portalServer.handleClient(); }

void Provisioning::enterProvisioningMode(){
  setup_mode_=true;
  ready_=false;
  Topics::init(deviceId());
  SF::Log::warn("prov", "entering setup AP mode");
  startSetupAp();
  runtime_press_active_=true;
}

voidd Provisioning::runtimeButtonCheck(){ int level=digitalRead(PROVISION_BUTTON_PIN); unsigned long now=millis(); if(level==LOW){ if(!runtime_press_active_){ runtime_press_active_=true; runtime_press_start_=now; } else if((now-runtime_press_start_)>=HOLD_MS && !setup_mode_){ enterProvisioningMode(); } } else { runtime_press_active_=false; runtime_press_start_=0; } }

void Provisioning::loop(){ if(setup_mode_){ handleHttp(); return; } runtimeButtonCheck(); ensureMdns(); }

void Provisioning::ensureMdns(){ if(!ready_||mdns_ready_) return; if(!MDNS.begin(deviceId())) return; MDNS.addService("skyfeeder","tcp",80); MDNS.addServiceTxt("skyfeeder","tcp","step","sf_step14_provision"); mdns_ready_=true; }

void Provisioning::publishDiscovery(PubSubClient& client){
  if(discovery_published_||!ready_) return;
  StaticJsonDocument<640> doc;
  doc["device_id"]=deviceId();
  doc["step"]="sf_step15B_ota_stub";
  doc["services"][0]="weight";
  doc["services"][1]="motion";
  doc["services"][2]="visit";
  doc["services"][3]="led";
  doc["services"][4]="camera";
  doc["services"][5]="logs";
  doc["services"][6]="ota";
  auto topics=doc["topics"].to<JsonObject>();
  topics["status"]=Topics::status();
  topics["ack"]=Topics::ack();
  topics["telemetry"]=Topics::telemetry();
  topics["cmd"] = Topics::cmdAny();
  topics["cmd_logs"] = Topics::cmdLogs();
  topics["cmd_ota"] = Topics::cmdOta();
  topics["event_visit"]=Topics::eventVisit();
  topics["event_snapshot"]=Topics::eventCameraSnapshot();
  topics["event_log"] = Topics::eventLog();
  topics["event_ota"] = Topics::eventOta();
  char payload[640];
  size_t n=serializeJson(doc,payload,sizeof(payload));
  (void)n;
  client.publish(Topics::discovery(), payload, true);
  discovery_published_=true;
  SF::Log::info("prov", "discovery published with log topics");
}

voidd Provisioning::onMqttConnected(PubSubClient& client){ publishDiscovery(client); }

} // namespace SF





