#define SF_LOG_ENABLE_TEST_API
#include "../../logging.h"
#include "../../topics.h"
#include <iostream>

int main() {
  SF::Topics::init("sf-dev01");
  SF::Log::initForTest("sf-dev01");
  SF::Log::bootMarkerTest("power_on");
  SF::Log::info("provision", "setup complete");
  SF::Log::warn("power", "low battery %d%%", 15);
  SF::Log::error("camera", "snap_failed");
  std::cout << SF::Log::dumpJson() << std::endl;
  return 0;
}
