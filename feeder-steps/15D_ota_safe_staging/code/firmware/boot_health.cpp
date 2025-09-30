#include "boot_health.h"

#include <Arduino.h>
#include <cstring>

#include "logging.h"
#include "ota_manager.h"
#include "storage_nvs.h"

namespace SF {
namespace BootHealth {
namespace {
constexpr uint32_t kMagic = 0x53464248;  // "SFBH"
constexpr size_t kVersionLen = 16;
constexpr uint8_t kMaxBootFailures = 2;

struct State {
  uint32_t magic;
  char pendingVersion[kVersionLen];
  uint8_t consecutiveFails;
  bool awaitingHealth;
  bool stagedApply;
};

State gState{};
bool gLoaded = false;

void copyStr(char* dst, size_t len, const char* src) {
  if (!dst || len == 0) return;
  if (!src) {
    dst[0] = '\0';
    return;
  }
  std::strncpy(dst, src, len - 1);
  dst[len - 1] = '\0';
}

void save() {
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
  save();
}

void resetPending() {
  gState.pendingVersion[0] = '\0';
  gState.consecutiveFails = 0;
  gState.awaitingHealth = false;
  gState.stagedApply = true;
  save();
}

}  // namespace

void begin() {
  ensureLoaded();
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
    save();
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
  save();
}

void prepareForPending(const char* version, bool staged) {
  ensureLoaded();
  copyStr(gState.pendingVersion, sizeof(gState.pendingVersion), version);
  gState.awaitingHealth = true;
  gState.consecutiveFails = 0;
  gState.stagedApply = staged;
  save();
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

}  // namespace BootHealth
}  // namespace SF
