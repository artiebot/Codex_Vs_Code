#include "boot_health.h"

#include <Arduino.h>
#include <cstring>
#include <ctime>
#include <cstddef>
#include <esp_system.h>

#include "logging.h"
#include "ota_manager.h"
#include "storage_nvs.h"

namespace SF {
namespace BootHealth {
namespace {
constexpr uint32_t kMagic = 0x53464248;       // "SFBH"
constexpr uint32_t kResetMagic = 0x5346524c;  // "SFRL"
constexpr size_t kVersionLen = 16;
constexpr uint8_t kMaxBootFailures = 2;
constexpr std::size_t kResetHistoryMax = 10;

struct State {
  uint32_t magic;
  char pendingVersion[kVersionLen];
  uint8_t consecutiveFails;
  bool awaitingHealth;
  bool stagedApply;
};

struct ResetEntry {
  uint8_t reason;
  uint32_t ts;
};

struct ResetLog {
  uint32_t magic;
  uint8_t count;
  ResetEntry entries[kResetHistoryMax];
};

State gState{};
bool gLoaded = false;
ResetLog gResetLog{};
bool gResetLoaded = false;

void copyStr(char* dst, size_t len, const char* src) {
  if (!dst || len == 0) return;
  if (!src) {
    dst[0] = '\0';
    return;
  }
  std::strncpy(dst, src, len - 1);
  dst[len - 1] = '\0';
}

void saveState() {
  gState.magic = kMagic;
  SF::Storage::setBytes("boot", "state", &gState, sizeof(gState));
}

void ensureLoaded() {
  if (gLoaded) return;
  State stored{};
  if (SF::Storage::getBytes("boot", "state", &stored, sizeof(stored)) && stored.magic == kMagic) {
    gState = stored;
  } else {
    std::memset(&gState, 0, sizeof(gState));
  }
  gLoaded = true;
  saveState();
}

void resetPending() {
  gState.pendingVersion[0] = '\0';
  gState.consecutiveFails = 0;
  gState.awaitingHealth = false;
  gState.stagedApply = true;
  saveState();
}

void loadResetLog() {
  if (gResetLoaded) return;
  ResetLog stored{};
  if (SF::Storage::getBytes("boot", "reset_log", &stored, sizeof(stored)) && stored.magic == kResetMagic) {
    gResetLog = stored;
    if (gResetLog.count > kResetHistoryMax) {
      gResetLog.count = kResetHistoryMax;
    }
  } else {
    std::memset(&gResetLog, 0, sizeof(gResetLog));
    gResetLog.magic = kResetMagic;
  }
  gResetLoaded = true;
}

void saveResetLog() {
  if (!gResetLoaded) return;
  gResetLog.magic = kResetMagic;
  SF::Storage::setBytes("boot", "reset_log", &gResetLog, sizeof(gResetLog));
}

uint32_t nowSeconds() {
  time_t now = time(nullptr);
  if (now <= 0) {
    return static_cast<uint32_t>(millis() / 1000);
  }
  return static_cast<uint32_t>(now);
}

void appendReset(uint8_t reason, uint32_t ts) {
  loadResetLog();
  if (gResetLog.count < kResetHistoryMax) {
    gResetLog.entries[gResetLog.count++] = {reason, ts};
  } else {
    // Shift left and append at the end (oldest dropped, newest appended).
    for (std::size_t i = 1; i < kResetHistoryMax; ++i) {
      gResetLog.entries[i - 1] = gResetLog.entries[i];
    }
    gResetLog.entries[kResetHistoryMax - 1] = {reason, ts};
  }
  saveResetLog();
}

}  // namespace

void begin() {
  ensureLoaded();

  // Log the reset reason for this boot into a small rolling history.
  esp_reset_reason_t reason = esp_reset_reason();
  uint8_t reasonCode = static_cast<uint8_t>(reason);
  uint32_t ts = nowSeconds();
  appendReset(reasonCode, ts);
  SF::Log::info("boot", "reset_reason=%u", static_cast<unsigned>(reasonCode));

  if (!gState.awaitingHealth) {
    return;
  }

  const char* running = SF::OtaManager::runningVersion();
  const char* pending = gState.pendingVersion;
  const char* lastGood = SF::OtaManager::lastGoodVersion();

  if (!pending[0]) {
    resetPending();
    return;
  }

  if (std::strcmp(running, pending) == 0) {
    gState.consecutiveFails++;
    saveState();
    if (gState.consecutiveFails >= kMaxBootFailures) {
      SF::Log::warn("boot", "health rollback version=%s", pending);
      SF::OtaManager::queueRollbackEvent(pending, lastGood, "boot_failures", true);
    }
    return;
  }

  if (std::strcmp(running, lastGood) == 0) {
    SF::Log::warn("boot", "bootloader reverted to %s", lastGood);
    SF::OtaManager::queueRollbackEvent(pending, lastGood, "bootloader_revert", false);
    resetPending();
    return;
  }

  // Unknown version; leave awaiting flag but do not count as failure.
  gState.consecutiveFails = 0;
  saveState();
}

void prepareForPending(const char* version, bool staged) {
  ensureLoaded();
  copyStr(gState.pendingVersion, sizeof(gState.pendingVersion), version);
  gState.awaitingHealth = true;
  gState.consecutiveFails = 0;
  gState.stagedApply = staged;
  saveState();
}

void markHealthy() {
  ensureLoaded();
  if (!gState.awaitingHealth) return;
  const char* pending = gState.pendingVersion;
  if (pending[0] && std::strcmp(pending, SF::OtaManager::runningVersion()) != 0) {
    return;
  }
  SF::OtaManager::markApplySuccess();
  resetPending();
}

void markFailed(const char* reason) {
  ensureLoaded();
  if (!gState.awaitingHealth) return;
  const char* pending = gState.pendingVersion;
  const char* lastGood = SF::OtaManager::lastGoodVersion();
  SF::Log::warn("boot", "health failure triggers rollback %s", reason ? reason : "unknown");
  SF::OtaManager::queueRollbackEvent(pending, lastGood, reason ? reason : "health_failure", true);
  resetPending();
}

bool awaitingHealth() {
  ensureLoaded();
  return gState.awaitingHealth;
}

const char* pendingVersion() {
  ensureLoaded();
  return gState.pendingVersion;
}

std::size_t resetHistory(ResetRecord* out, std::size_t max) {
  if (!out || max == 0) return 0;
  loadResetLog();
  std::size_t n = gResetLog.count;
  if (n > max) n = max;
  for (std::size_t i = 0; i < n; ++i) {
    out[i].reason = gResetLog.entries[i].reason;
    out[i].ts = gResetLog.entries[i].ts;
  }
  return n;
}

}  // namespace BootHealth
}  // namespace SF
