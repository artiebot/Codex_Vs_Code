#include "storage.h"
#include <Preferences.h>
#include <cstring>

namespace {
constexpr const char* NS_WIFI = "wifi";
constexpr const char* NS_MQTT = "mqtt";
constexpr const char* NS_DEVICE = "device";
constexpr const char* NS_BOOT = "boot";

inline void strCopy(char* dst, size_t len, const char* src) {
  if (len == 0) return;
  if (!src) { dst[0] = '\0'; return; }
  strncpy(dst, src, len - 1);
  dst[len-1] = '\0';
}
}

namespace Storage {

void begin() {
  // Preferences uses NVS under the hood. Nothing else needed.
}

bool loadWifi(WifiConfig& out) {
  Preferences prefs;
  if (!prefs.begin(NS_WIFI, true)) return false;
  String ssid = prefs.getString("ssid", "");
  String pass = prefs.getString("pass", "");
  prefs.end();
  if (ssid.isEmpty()) return false;
  strCopy(out.ssid, sizeof(out.ssid), ssid.c_str());
  strCopy(out.password, sizeof(out.password), pass.c_str());
  out.valid = true;
  return true;
}

bool saveWifi(const WifiConfig& in) {
  Preferences prefs;
  if (!prefs.begin(NS_WIFI, false)) return false;
  prefs.putString("ssid", in.ssid);
  prefs.putString("pass", in.password);
  prefs.end();
  return true;
}

void clearWifi() {
  Preferences prefs;
  if (prefs.begin(NS_WIFI, false)) {
    prefs.clear();
    prefs.end();
  }
}

bool loadMqtt(MqttConfig& out) {
  Preferences prefs;
  if (!prefs.begin(NS_MQTT, true)) return false;
  String host = prefs.getString("host", "");
  out.hostSet = !host.isEmpty();
  if (out.hostSet) strCopy(out.host, sizeof(out.host), host.c_str());
  out.port = prefs.getUShort("port", 0);
  out.tls = prefs.getBool("tls", false);
  String user = prefs.getString("user", "");
  String pass = prefs.getString("pass", "");
  out.credsSet = !user.isEmpty();
  if (out.credsSet) {
    strCopy(out.user, sizeof(out.user), user.c_str());
    strCopy(out.pass, sizeof(out.pass), pass.c_str());
  }
  prefs.end();
  return out.hostSet || out.credsSet;
}

bool saveMqtt(const MqttConfig& in) {
  Preferences prefs;
  if (!prefs.begin(NS_MQTT, false)) return false;
  if (in.host[0]) prefs.putString("host", in.host);
  if (in.port) prefs.putUShort("port", in.port);
  prefs.putBool("tls", in.tls);
  if (in.user[0]) prefs.putString("user", in.user);
  if (in.pass[0]) prefs.putString("pass", in.pass);
  prefs.end();
  return true;
}

void clearMqttCreds() {
  Preferences prefs;
  if (prefs.begin(NS_MQTT, false)) {
    prefs.remove("user");
    prefs.remove("pass");
    prefs.end();
  }
}

bool loadDeviceId(char* out, size_t len) {
  Preferences prefs;
  if (!prefs.begin(NS_DEVICE, true)) return false;
  String id = prefs.getString("id", "");
  prefs.end();
  if (id.isEmpty()) return false;
  strCopy(out, len, id.c_str());
  return true;
}

bool saveDeviceId(const char* id) {
  Preferences prefs;
  if (!prefs.begin(NS_DEVICE, false)) return false;
  prefs.putString("id", id);
  prefs.end();
  return true;
}

void loadBootCounter(BootCounter& out) {
  Preferences prefs;
  if (prefs.begin(NS_BOOT, true)) {
    out.count = prefs.getUInt("count", 0);
    out.lastUs = prefs.getULong64("last", 0ULL);
    prefs.end();
  }
}

void saveBootCounter(const BootCounter& info) {
  Preferences prefs;
  if (prefs.begin(NS_BOOT, false)) {
    prefs.putUInt("count", info.count);
    prefs.putULong64("last", info.lastUs);
    prefs.end();
  }
}

void resetBootCounter() {
  Preferences prefs;
  if (prefs.begin(NS_BOOT, false)) {
    prefs.clear();
    prefs.end();
  }
}

} // namespace Storage
