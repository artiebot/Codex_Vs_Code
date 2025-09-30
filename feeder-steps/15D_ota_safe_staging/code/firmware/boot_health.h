#pragma once

#include <cstddef>

namespace SF {
namespace BootHealth {

void begin();
void prepareForPending(const char* version, bool staged);
void markHealthy();
void markFailed(const char* reason);
bool awaitingHealth();
const char* pendingVersion();

}  // namespace BootHealth
}  // namespace SF
