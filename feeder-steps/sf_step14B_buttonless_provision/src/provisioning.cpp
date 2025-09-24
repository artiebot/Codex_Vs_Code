#include "provisioning.h"
#include "storage.h"
#include "led.h"
#include "src/config.h"
#include "factory_api.h"
#include <DNSServer.h>
#include <WebServer.h>
#include <WiFi.h>

namespace {
bool portalActive=false;
DNSServer dnsServer;
WebServer portal(80);

void handleRoot() {
  String html = "<!DOCTYPE html><html><head><meta charset='utf-8'><title>SkyFeeder Setup</title><style>body{font-family:Arial;background:#0b1d2a;color:#fff;}form{max-width:360px;margin:40px auto;padding:20px;background:#123;box-shadow:0 0 12px rgba(0,0,0,.4);}label{display:block;margin-top:12px;}input{width:100%;padding:8px;border:1px solid #456;border-radius:4px;background:#0e2233;color:#fff;}button{margin-top:18px;width:100%;padding:10px;background:#29a19c;border:0;border-radius:4px;color:#fff;font-size:16px;}h1{text-align:center;font-weight:600;}</style></head><body><form method='POST' action='/submit'><h1>SkyFeeder Setup</h1>";
  html += "<label>Wi-Fi SSID<input name='ssid' required></label>";
  html += "<label>Password<input name='pass' type='password'></label>";
  html += "<label>Device Name (optional)<input name='device'></label>";
  html += "<button type='submit'>Save &amp; Reboot</button></form></body></html>";
  portal.send(200, "text/html", html);
}

void handleSubmit() {
  if (!portal.hasArg("ssid")) {
    portal.send(400, "text/plain", "Missing SSID");
    return;
  }
  Storage::WifiConfig wifi{};
  strncpy(wifi.ssid, portal.arg("ssid").c_str(), sizeof(wifi.ssid)-1);
  strncpy(wifi.password, portal.arg("pass").c_str(), sizeof(wifi.password)-1);
  wifi.valid = true;
  Storage::saveWifi(wifi);
  String device = portal.arg("device");
  if (!device.isEmpty()) {
    char idBuf[33];
    strncpy(idBuf, device.c_str(), sizeof(idBuf)-1);
    idBuf[sizeof(idBuf)-1]='\0';
    Storage::saveDeviceId(idBuf);
  }
  String reply = "<html><body><h1>Saved! Rebooting...</h1></body></html>";
  portal.send(200, "text/html", reply);
  delay(1200);
  ESP.restart();
}
}

namespace Provisioning {

void start() {
  if (portalActive) return;
  portalActive = true;
  Led::setState(Led::State::PROVISIONING);
  WiFi.mode(WIFI_AP);
  WiFi.softAP("SkyFeeder-Setup");
  dnsServer.start(53, "*", WiFi.softAPIP());
  portal.on("/", HTTP_GET, handleRoot);
  portal.on("/submit", HTTP_POST, handleSubmit);
  portal.onNotFound(handleRoot);
  FactoryAPI::attach(portal);
  portal.begin();
}

void loop() {
  if (!portalActive) return;
  dnsServer.processNextRequest();
  portal.handleClient();
  FactoryAPI::loop();
}

bool active() { return portalActive; }

} // namespace Provisioning
