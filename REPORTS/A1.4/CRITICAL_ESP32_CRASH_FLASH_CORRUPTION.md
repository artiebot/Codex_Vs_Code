# CRITICAL: ESP32 Crashes During MQTT Init - Flash Corruption - Complete Boot Failure

**Status:** 🔴 **P0 BLOCKING** - Device completely non-functional, infinite boot loop
**Discovered:** 2025-10-21 during serial console verification
**Severity:** CRITICAL - Requires immediate firmware reflash and flash erase

## Summary

The ESP32 firmware crashes with Guru Meditation errors during MQTT client initialization. The panic handler itself panics, causing a cascading failure that corrupts the flash partitions. After corruption, the device enters an infinite boot loop with "No bootable app partitions" errors.

## Root Cause

**Crash Location:** MQTT initialization in `provisioning.cpp` or `mqtt_client.cpp`

**Sequence of Failure:**
1. Device boots successfully through all initialization stages
2. Reaches "Provisioning ready - starting MQTT..."
3. Triggers **IllegalInstruction** exception (invalid opcode or memory corruption)
4. Triggers **LoadProhibited** exception (invalid memory access)
5. Panic handler enters infinite recursion ("Panic handler entered multiple times")
6. Watchdog forces reboot, but flash is now corrupted
7. Bootloader cannot find valid app partition
8. Infinite boot loop ensues

## Serial Console Evidence

### Initial Crash
```
=== SKYFEEDER BOOT DEBUG ===
setup() reached!
Free heap: 250936
CPU Freq: 240
Initializing logging...
Logging initialized!
Initializing OTA Manager...
OTA Manager initialized!
Initializing Boot Health...
Boot Health initialized!
Initializing LED services...
LED services initialized!
Initializing power manager...
Power manager initialized!
Initializing weight service...
Weight service initialized!
Initializing motion service...
Motion service initialized!
Initializing visit service...
Visit service initialized!
Initializing AMB mini link...
[mini] >> {"op":"status"}
Requested initial Mini status
AMB mini link initialized!
Initializing camera service...
Camera service initialized!
Configuring OTA service...
OTA service configured!
Initializing provisioning...
Provisioning initialized!
Provisioning ready - starting MQTT...
Guru Meditation Error: Core  0 panic'ed (IllegalInstruction). Exception was unhandled.
Memory dump at 0x40183b7c: 20aa20ff 00000000 02000000
Core  0 register dump:Guru Meditation Error: Core  0 panic'ed (LoadProhibited). Exception was unhandled.
Core  0 register dump:ler entered multiple times. Abort panic handling. Rebooting ...
```

### Flash Corruption
```
ets Jul 29 2019 12:21:46
rst:0xc (SW_CPU_RESET),boot:0x13 (SPI_FAST_FLASH_BOOT)
E (358) esp_image: Checksum failed. Calculated 0xc read 0x52
E (358) boot: OTA app partition slot 1 is not bootable
E (359) esp_image: image at 0x10000 has invalid magic byte (nothing flashed here?)
E (365) boot: OTA app partition slot 0 is not bootable
E (369) boot: No bootable app partitions in the partition table
```

### Infinite Boot Loop
The device then enters an endless cycle:
```
rst:0x3 (SW_RESET),boot:0x13 (SPI_FAST_FLASH_BOOT)
E (384) esp_image: Checksum failed. Calculated 0x63 read 0x52
E (384) boot: OTA app partition slot 1 is not bootable
E (384) esp_image: image at 0x10000 has invalid magic byte (nothing flashed here?)
E (390) boot: OTA app partition slot 0 is not bootable
E (395) boot: No bootable app partitions in the partition table
[repeats infinitely with different checksum values]
```

## Impact on A1.4/B1 Validation

| Validation Phase | Status | Blocker |
|-----------------|--------|---------|
| **A1.4 Soak Test** | ❌ FAIL | Device cannot run for 24 hours |
| **A1.4 Upload Success** | ❌ FAIL | Cannot test uploads (device offline) |
| **A1.4 Power Measurements** | ❌ BLOCKED | Cannot measure power (continuous reboot) |
| **B1 Provisioning** | ❌ BLOCKED | Cannot test LED states (never gets past boot) |
| **B1 Triple Power Cycle** | ❌ BLOCKED | Device already in boot loop |
| **Field Deployment** | 🚫 **BLOCKED** | Device unusable |

## Recovery Steps

### 1. Erase Flash Completely
```bash
# Using esptool.py (if available)
esptool.py --chip esp32 --port COM4 erase_flash
```

### 2. Reflash Bootloader + Partitions + Firmware
```
# Via Arduino IDE:
1. Open Arduino IDE
2. Select Tools > Board > ESP32 Dev Module
3. Select Tools > Erase All Flash Before Sketch Upload > Enabled
4. Open skyfeeder/skyfeeder.ino
5. Verify/Compile
6. Upload (this will erase NVS, flash, and reflash clean firmware)
```

### 3. Verify Clean Boot
```
# Monitor serial console - should see clean boot to "Provisioning ready"
# WITHOUT crash
```

## Root Cause Analysis - MQTT Init Bug

**Suspected Issue:** MQTT client initialization is calling a corrupted function pointer or accessing invalid memory.

**Files to Investigate:**
- [skyfeeder/mqtt_client.cpp](skyfeeder/mqtt_client.cpp) - MQTT initialization code
- [skyfeeder/provisioning.cpp](skyfeeder/provisioning.cpp) - Where MQTT start is triggered
- Memory corruption in PubSubClient library
- Stack overflow during MQTT.begin()

**Possible Causes:**
1. **Function pointer corruption** - MQTT callback or handler has invalid address
2. **Stack overflow** - Deep call stack during initialization exceeds available stack
3. **Heap corruption** - Prior memory leak/corruption affects MQTT client allocation
4. **Library incompatibility** - PubSubClient version incompatible with ESP32 core
5. **Concurrent access** - Race condition between WiFi and MQTT initialization

## Why Soak Test Appeared to Run

**Key Finding:** The soak test monitor detected 6 existing uploads at the start but saw NO new MQTT events during 22+ hours. This is because:

1. Device crashes immediately after boot
2. Never successfully connects to MQTT broker
3. Never publishes telemetry or receives commands
4. Soak test script was monitoring a dead device
5. No new uploads = 0% success rate

The soak test was actually monitoring a continuously crashing device, not a stable system.

## Immediate Actions Required

1. ✅ **Stop all soak test processes** - No point monitoring a crashed device
2. ⏳ **Erase flash + reflash firmware** - User must do this manually via Arduino IDE
3. ⏳ **Identify MQTT init bug** - Debug crash with exception decoder
4. ⏳ **Add watchdog feeding** - Prevent watchdog timeout during long init
5. ⏳ **Add crash dump logging** - Store crash reason in NVS for next boot
6. ⏳ **Test minimal boot** - Comment out MQTT to isolate crash

## Prevention Measures

1. **Add exception handler** - Catch and log exceptions before panic
2. **Add init timeout** - Fail gracefully if MQTT doesn't initialize in 30s
3. **Add boot counter** - Auto-enter safe mode after 3 consecutive crashes
4. **Add memory checks** - Verify heap integrity before critical operations
5. **Add stack size monitoring** - Alert if stack usage exceeds 80%

## Next Steps

1. ✅ Document crash in this report
2. ⏳ Stop soak test (device is offline anyway)
3. ⏳ **User must manually reflash firmware via Arduino IDE**
4. ⏳ Verify clean boot without crash
5. ⏳ Re-run minimal test (snapshot + upload) before 24-hour soak test
6. ⏳ Debug MQTT initialization crash

---

**This is a P0 CRITICAL BUG that blocks all A1.4 and B1 validation.**

The device CANNOT be used in its current state and requires immediate firmware reflash with flash erase.
