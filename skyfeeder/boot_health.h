#pragma once

#include <cstddef>
#include <cstdint>

namespace SF {
namespace BootHealth {

struct ResetRecord {
  uint8_t reason;
  uint32_t ts;
};

void begin();
void prepareForPending(const char* version, bool staged);
void markHealthy();
void markFailed(const char* reason);
bool awaitingHealth();
const char* pendingVersion();

// Returns up to max recent reset records (oldest first) into out. The return
// value is the number of records written.
std::size_t resetHistory(ResetRecord* out, std::size_t max);

}  // namespace BootHealth
}  // namespace SF
