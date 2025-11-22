#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\led_ux.cpp"
#include "led_ux.h"

#include <ctype.h>
#include <string.h>

#include "config.h"
#include "power_manager.h"

namespace SF {
struct BurstConfig {
  uint8_t pulseCount;
  uint16_t onMs;
  uint16_t offMsBetween;
  uint32_t burstPeriodMs;
  uint32_t color;
  uint8_t brightness;
  WsPattern pattern;
};
}  // namespace SF

/*
 * LED UX Spec v1
 *  - LED is OFF by default and only pulses to communicate status.
 *  - Color semantics:
 *      • Red / orange / yellow  = needs attention (faults, low battery, provisioning).
 *      • Blue / green           = in progress or success.
 *  - Patterns:
 *      • Heartbeat (dim → bright → dim) for in-progress states (provisioning, Wi-Fi connecting).
 *      • Short solid pulse for success (“dev OK” beacon).
 *      • Burst pulses for attention states (faults, battery warnings).
 *  - Priority order (highest first):
 *      FAULT > BATTERY_CRITICAL > BATTERY_LOW > PROVISIONING > CONNECTING_WIFI > DEV_OK beacon.
 *  - Temporary overrides sit above the priority stack and expire quickly.
 */

namespace {
using SF::BurstConfig;
constexpr uint32_t makeColor(uint8_t r, uint8_t g, uint8_t b) {
  return (static_cast<uint32_t>(g) << 16) | (static_cast<uint32_t>(r) << 8) | static_cast<uint32_t>(b);
}
constexpr uint32_t kProvisioningColor = makeColor(255, 140, 0);   // amber/orange
constexpr uint32_t kConnectingColor = makeColor(64, 150, 255);    // blue
constexpr uint32_t kOnlineColor = makeColor(64, 220, 96);         // green
constexpr uint32_t kBatteryLowColor = makeColor(255, 200, 0);     // yellow/orange
constexpr uint32_t kBatteryCriticalColor = makeColor(255, 32, 0); // bright red
constexpr uint32_t kFaultColor = makeColor(255, 0, 0);            // solid red

constexpr uint8_t kHeartbeatBrightness = 48;
constexpr unsigned long kDevOkBeaconIntervalMs = 30000UL;
constexpr bool kDevOkBeaconEnabled = true;

const BurstConfig kFaultBurstConfig{2, 300, 300, 5000UL, kFaultColor, LED_CRIT_BRIGHTNESS, SF::WsPattern::SOLID};
const BurstConfig kBatteryCriticalBurstConfig{3, 150, 150, 12000UL, kBatteryCriticalColor, LED_CRIT_BRIGHTNESS, SF::WsPattern::SOLID};
const BurstConfig kBatteryLowBurstConfig{3, 100, 150, 60000UL, kBatteryLowColor, LED_WARN_BRIGHTNESS, SF::WsPattern::SOLID};
const BurstConfig kDevOkBurstConfig{1, 80, 0, kDevOkBeaconIntervalMs, kOnlineColor, LED_IDLE_BRIGHTNESS, SF::WsPattern::SOLID};
}  // namespace

namespace SF {
LedUx ledUx;

void LedUx::begin() {
  active_name_[0] = 'o';
  active_name_[1] = 'f';
  active_name_[2] = 'f';
  active_name_[3] = '\0';
  last_pattern_ = WsPattern::OFF;
  last_color_ = 0;
  last_brightness_ = 0;
  override_active_ = false;
  override_until_ms_ = 0;
  fault_active_ = false;
  resetBurst(faultBurst_);
  resetBurst(batteryLowBurst_);
  resetBurst(batteryCriticalBurst_);
  resetBurst(devOkBurst_);
}

void LedUx::setMode(Mode mode) {
  if (mode_ == mode) return;
  mode_ = mode;
}

void LedUx::setFault(bool faultActive) {
  if (fault_active_ == faultActive) return;
  fault_active_ = faultActive;
  if (!fault_active_) {
    resetBurst(faultBurst_);
  }
}

bool LedUx::overrideActive(unsigned long now) {
  if (!override_active_) return false;
  long diff = (long)(override_until_ms_ - now);
  if (diff <= 0) {
    override_active_ = false;
    return false;
  }
  return true;
}

uint8_t LedUx::clampBrightness(int value) const {
  if (value < 0) value = 0;
  if (value > 255) value = 255;
  uint8_t limit = SF::power.brightnessLimit();
  if (value > limit) value = limit;
  return (uint8_t)value;
}

uint32_t LedUx::rgb(uint8_t r, uint8_t g, uint8_t b) { return makeColor(r, g, b); }

bool LedUx::parsePatternName(const char* name, WsPattern& outPattern, uint32_t& outColor, uint8_t& outBrightness) const {
  if (!name) return false;
  char lower[16];
  size_t i = 0;
  for (; i < sizeof(lower) - 1 && name[i]; ++i) lower[i] = tolower((unsigned char)name[i]);
  lower[i] = '\0';
  if (strcmp(lower, "off") == 0) {
    outPattern = WsPattern::OFF;
    outColor = 0;
    outBrightness = 0;
    return true;
  }
  if (strcmp(lower, "solid") == 0 || strcmp(lower, "white") == 0) {
    outPattern = WsPattern::SOLID;
    outColor = makeColor(255, 255, 255);
    outBrightness = LED_IDLE_BRIGHTNESS;
    return true;
  }
  if (strcmp(lower, "heartbeat") == 0 || strcmp(lower, "idle") == 0) {
    outPattern = WsPattern::HEARTBEAT;
    outColor = makeColor(64, 150, 255);
    outBrightness = LED_IDLE_BRIGHTNESS;
    return true;
  }
  if (strcmp(lower, "amber") == 0 || strcmp(lower, "warn") == 0) {
    outPattern = WsPattern::AMBER_WARN;
    outColor = makeColor(255, 140, 0);
    outBrightness = LED_WARN_BRIGHTNESS;
    return true;
  }
  if (strcmp(lower, "alert") == 0 || strcmp(lower, "red") == 0) {
    outPattern = WsPattern::RED_ALERT;
    outColor = makeColor(255, 32, 0);
    outBrightness = LED_CRIT_BRIGHTNESS;
    return true;
  }
  return false;
}

uint32_t LedUx::parseColor(JsonVariantConst value, bool& ok) const {
  ok = false;
  if (value.is<const char*>()) {
    const char* s = value.as<const char*>();
    if (!s) return 0;
    if (s[0] == '#') ++s;
    size_t len = strlen(s);
    if (len != 6) return 0;
    uint32_t accum = 0;
    for (size_t i = 0; i < 6; ++i) {
      char c = tolower((unsigned char)s[i]);
      int v;
      if (c >= '0' && c <= '9')
        v = c - '0';
      else if (c >= 'a' && c <= 'f')
        v = 10 + (c - 'a');
      else
        return 0;
      accum = (accum << 4) | v;
    }
    ok = true;
    uint8_t r = (accum >> 16) & 0xFF;
    uint8_t g = (accum >> 8) & 0xFF;
    uint8_t b = accum & 0xFF;
    return makeColor(r, g, b);
  }
  if (value.is<uint32_t>()) {
    ok = true;
    uint32_t raw = value.as<uint32_t>();
    uint8_t r = (raw >> 16) & 0xFF;
    uint8_t g = (raw >> 8) & 0xFF;
    uint8_t b = raw & 0xFF;
    return makeColor(r, g, b);
  }
  return 0;
}

const char* LedUx::patternToName(WsPattern pattern) const {
  switch (pattern) {
    case WsPattern::OFF:
      return "off";
    case WsPattern::SOLID:
      return "solid";
    case WsPattern::HEARTBEAT:
      return "heartbeat";
    case WsPattern::AMBER_WARN:
      return "amber";
    case WsPattern::RED_ALERT:
      return "alert";
    default:
      return "unknown";
  }
}

void LedUx::applyDesired(WsPattern pattern, uint32_t color, uint8_t brightness) {
  brightness = clampBrightness(brightness);
  if (pattern == WsPattern::OFF) brightness = 0;
  if (last_pattern_ == pattern && last_color_ == color && last_brightness_ == brightness) return;
  SF::ws2812.setPattern(pattern, color, brightness);
  last_pattern_ = pattern;
  last_color_ = color;
  last_brightness_ = brightness;
  const char* name = patternToName(pattern);
  strncpy(active_name_, name, sizeof(active_name_));
  active_name_[sizeof(active_name_) - 1] = '\0';
}

void LedUx::activateOverride(WsPattern pattern, uint32_t color, uint8_t brightness, unsigned long hold_ms) {
  override_active_ = true;
  override_pattern_ = pattern;
  override_color_ = color;
  override_brightness_ = brightness;
  override_until_ms_ = millis() + hold_ms;
  applyDesired(pattern, color, brightness);
}

bool LedUx::applyCommand(JsonVariantConst cmd, const char*& appliedName, char* err, size_t errLen) {
  appliedName = nullptr;
  if (err && errLen > 0) err[0] = '\0';
  WsPattern pattern = WsPattern::OFF;
  uint32_t color = 0;
  uint8_t brightness = LED_IDLE_BRIGHTNESS;
  bool have = false;
  if (cmd.containsKey("pattern")) {
    const char* requested = cmd["pattern"].as<const char*>();
    if (!requested) {
      if (err && errLen) strncpy(err, "pattern_not_string", errLen);
      return false;
    }
    if (!parsePatternName(requested, pattern, color, brightness)) {
      if (err && errLen) strncpy(err, "pattern_unknown", errLen);
      return false;
    }
    have = true;
    if (cmd.containsKey("brightness")) brightness = clampBrightness(cmd["brightness"].as<int>());
    if (cmd.containsKey("color")) {
      bool ok = false;
      uint32_t parsed = parseColor(cmd["color"], ok);
      if (!ok) {
        if (err && errLen) strncpy(err, "color_invalid", errLen);
        return false;
      }
      color = parsed;
    }
  } else if (cmd.containsKey("on")) {
    bool on = cmd["on"].as<bool>();
    int req = cmd.containsKey("brightness") ? cmd["brightness"].as<int>() : 64;
    brightness = clampBrightness(req);
    pattern = on ? WsPattern::SOLID : WsPattern::OFF;
    color = on ? makeColor(255, 255, 255) : 0;
    have = true;
  }
  if (!have) {
    if (err && errLen) strncpy(err, "no_pattern", errLen);
    return false;
  }
  unsigned long hold = cmd["hold_ms"].as<unsigned long>();
  if (hold == 0) hold = cmd["duration_ms"].as<unsigned long>();
  if (hold == 0) hold = LED_OVERRIDE_MS;
  activateOverride(pattern, color, brightness, hold);
  appliedName = patternToName(pattern);
  return true;
}

void LedUx::loop() {
  unsigned long now = millis();
  if (overrideActive(now)) {
    applyDesired(override_pattern_, override_color_, override_brightness_);
    return;
  }

  PowerState powerState = SF::power.valid() ? SF::power.state() : PowerState::NORMAL;
  PriorityState priority = resolvePriority(powerState);
  resetAllBurstsExcept(priority);

  switch (priority) {
    case PriorityState::Fault:
      runBurst(faultBurst_, kFaultBurstConfig, now);
      applyDesired(WsPattern::OFF, 0, 0);
      break;
    case PriorityState::BatteryCritical:
      runBurst(batteryCriticalBurst_, kBatteryCriticalBurstConfig, now);
      applyDesired(WsPattern::OFF, 0, 0);
      break;
    case PriorityState::BatteryLow:
      runBurst(batteryLowBurst_, kBatteryLowBurstConfig, now);
      applyDesired(WsPattern::OFF, 0, 0);
      break;
    case PriorityState::Provisioning:
      applyDesired(WsPattern::HEARTBEAT, kProvisioningColor, kHeartbeatBrightness);
      break;
    case PriorityState::Connecting:
      applyDesired(WsPattern::HEARTBEAT, kConnectingColor, kHeartbeatBrightness);
      break;
    case PriorityState::DevOk:
      if (kDevOkBeaconEnabled) {
        runBurst(devOkBurst_, kDevOkBurstConfig, now);
      }
      applyDesired(WsPattern::OFF, 0, 0);
      break;
    case PriorityState::Off:
    default:
      applyDesired(WsPattern::OFF, 0, 0);
      break;
  }
}

void LedUx::resetBurst(BurstState& state) {
  state.burstActive = false;
  state.pulsesRemaining = 0;
  state.nextPulseMs = 0;
  state.nextBurstMs = 0;
}

void LedUx::resetAllBurstsExcept(PriorityState active) {
  if (active != PriorityState::Fault) resetBurst(faultBurst_);
  if (active != PriorityState::BatteryCritical) resetBurst(batteryCriticalBurst_);
  if (active != PriorityState::BatteryLow) resetBurst(batteryLowBurst_);
  if (active != PriorityState::DevOk) resetBurst(devOkBurst_);
}

bool LedUx::runBurst(BurstState& state, const BurstConfig& cfg, unsigned long now) {
  if (!state.burstActive) {
    if (state.nextBurstMs == 0 || now >= state.nextBurstMs) {
      state.burstActive = true;
      state.pulsesRemaining = cfg.pulseCount;
      state.nextPulseMs = now;
    } else {
      return true;
    }
  }

  if (state.pulsesRemaining > 0 && now >= state.nextPulseMs) {
    activateOverride(cfg.pattern, cfg.color, cfg.brightness, cfg.onMs);
    state.pulsesRemaining--;
    state.nextPulseMs = now + cfg.onMs + cfg.offMsBetween;
  }

  if (state.burstActive && state.pulsesRemaining == 0 && now >= state.nextPulseMs) {
    state.burstActive = false;
    state.nextBurstMs = now + cfg.burstPeriodMs;
  }
  return true;
}

LedUx::PriorityState LedUx::resolvePriority(PowerState powerState) const {
  if (fault_active_) return PriorityState::Fault;
  if (powerState == PowerState::CRIT) return PriorityState::BatteryCritical;
  if (powerState == PowerState::WARN) return PriorityState::BatteryLow;
  if (mode_ == Mode::PROVISIONING) return PriorityState::Provisioning;
  if (mode_ == Mode::CONNECTING_WIFI) return PriorityState::Connecting;
  if (isHealthyOnline(powerState)) return PriorityState::DevOk;
  return PriorityState::Off;
}

bool LedUx::isHealthyOnline(PowerState powerState) const {
  if (powerState != PowerState::NORMAL) return false;
  return (mode_ == Mode::ONLINE || mode_ == Mode::AUTO);
}
}  // namespace SF
