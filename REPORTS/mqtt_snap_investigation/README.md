# MQTT Snapshot Event Investigation

**Issue:** MQTT snap commands don't produce `event/snapshot` messages
**Date:** 2025-10-04
**Status:** Fix Applied - Awaiting User Validation

## Summary

MQTT commands successfully trigger image capture, but snapshot events are not published to the broker.

**Root Cause:** The `pumpMqtt()` function (called during image capture) did not attempt reconnection if the MQTT client became disconnected. By the time `publishSnapshot()` was called, `mqtt.connected()` returned false, causing the publish to be skipped.

**Fix:** Enhanced `pumpMqtt()` to attempt reconnection if disconnected, and added connection state logging for diagnostics.

## Investigation Files

1. **01_skip_path.txt** - Code analysis identifying skip conditions
2. **02_root_cause.txt** - Timing analysis and reconnection logic fix
3. **03_fix_validation.txt** - Complete test procedure for user
4. **04_test_results.txt** - (User to create) Test results after flashing

## Key Findings

✅ Code already publishes **metadata-only** (production design)
✅ Payload size (~100 bytes) well under limits
✅ `mqtt.loop()` was being called during capture
❌ Reconnection logic missing in `pumpMqtt()`

## Changes Made

### amb-mini/amb-mini.ino

**Line 50-57:** Enhanced `pumpMqtt()`
```cpp
void pumpMqtt() {
  if (!mqtt.connected()) {
    reconnectMqtt();  // NEW: Attempt reconnect
  } else {
    mqtt.loop();
    processMessage();  // NEW: Process pending messages
  }
}
```

**Line 131-132:** Added connection state logging
```cpp
Serial.print("[mqtt] connection state before publish: ");
Serial.println(mqtt.connected() ? "CONNECTED" : "DISCONNECTED");
```

**Line 127, 135:** Improved error messages for debugging

## Next Steps

1. User flashes updated `amb-mini.ino`
2. User runs test procedure in `03_fix_validation.txt`
3. User saves test results to `04_test_results.txt`
4. If successful → A0.1 complete, proceed to A0.2
5. If failed → Further debugging required

## Production Design Confirmed

The firmware correctly implements the recommended production pattern:

**Event Payload (MQTT):**
```json
{
  "url": "http://{device-ip}/snapshot.jpg",
  "ts": 123456,
  "size": 11506
}
```

**Image Delivery:** HTTP endpoint `/snapshot.jpg`
**No binary data over MQTT** ✓

## References

- Original issue: Serial log showing "publish snapshot → skipped (MQTT)"
- Codex analysis: Systematic investigation plan
- Related fix: mqtt.loop() in streaming handler (validation_A0.1_SOLVED.txt)
