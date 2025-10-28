# A1.4 Soak Test - Issue Analysis & Handoff to Codex

**Date:** 2025-10-21
**Analyst:** Claude (troubleshooting session)
**Status:** 🔴 **BLOCKING** - Upload implementation missing

---

## Executive Summary

The 24-hour soak test revealed **0% upload success** (0 of 24+ photos uploaded to MinIO). Root cause: AMB-Mini firmware has a TODO stub for HTTP uploads that always returns `false`. Device is otherwise stable.

**Fixed Issues:**
- ✅ ESP32 sleep timeout (15s → 90s) - Already committed
- ✅ PowerShell soak test script - Already working

**Remaining Work:**
- ❌ Implement HTTP upload in Mini firmware (~6-10 hours)

---

## Files for Codex

| File | Purpose |
|------|---------|
| **[INSTRUCTIONS_FOR_CODEX.md](INSTRUCTIONS_FOR_CODEX.md)** | 📋 **START HERE** - Complete implementation guide with code |
| [UPLOAD_NOT_IMPLEMENTED.md](UPLOAD_NOT_IMPLEMENTED.md) | Full technical analysis + architecture |
| [IMPLEMENTATION_DECISION_NEEDED.md](IMPLEMENTATION_DECISION_NEEDED.md) | Background context |

---

## Quick Reference: What Codex Needs to Do

### 1. Implement 3 Functions in `amb-mini/amb-mini.ino`

**Add before line 444:**
```cpp
static bool requestPresignedUrl(const char* kind, char* urlOut, size_t maxLen);
static bool putToSignedUrl(const char* url, const uint8_t* data, size_t len);
```

**Replace line 444-454 (the stub):**
```cpp
static bool performUploadAttempt(const UploadSlot& slot, unsigned long& elapsedMs) {
  // Current: return false (TODO stub)
  // New: Call requestPresignedUrl() → putToSignedUrl() → return success
}
```

**Full implementations provided in [INSTRUCTIONS_FOR_CODEX.md](INSTRUCTIONS_FOR_CODEX.md)**

### 2. Test Flow
```bash
# 1. Flash updated Mini firmware
# 2. Flash ESP32 (sleep timeout already fixed)
# 3. Send snapshot via WebSocket (production method):
#    wscat -c "ws://10.0.0.4:8081?deviceId=dev1" --execute '{"cmd":"snapshot"}'
#    OR via MQTT (dev/testing only):
#    mosquitto_pub -t "skyfeeder/dev1/cmd/camera" -m '{"op":"snapshot"}'
# 4. Verify: docker exec skyfeeder-minio mc ls local/photos/dev1/
# 5. Re-run 24-hour soak test
```

**Note:** MQTT commands work for local testing but WebSocket is the production path.

### 3. Success Criteria
- ✅ Single snapshot → photo in MinIO within 10 seconds
- ✅ 24-hour soak test → >= 85% upload success (20+ of 24 photos)

---

## Test Environment Status

| Component | Status | Notes |
|-----------|--------|-------|
| Presign API | ✅ Running | `http://10.0.0.4:8080` |
| MinIO | ✅ Running | `http://10.0.0.4:9200` |
| ESP32 | ✅ Online | FW v1.4.2, sleep timeout fixed |
| AMB-Mini | ✅ Capturing | Photos work, upload stub fails |
| Soak Test Script | ✅ Ready | PowerShell fixed, ready to run |

---

## Context: What Happened During 24-Hour Soak Test

**Timeline:**
- 10/20 20:52 - Started 24-hour soak test
- 10/20 21:02 - First snapshot sent via MQTT
- 10/21 18:28 - User reported 0 uploads after 21+ hours

**Investigation:**
1. ❌ Initial suspicion: ESP32 boot loop → FALSE ALARM (device stable)
2. ✅ Found: ESP32 sleep timeout too short (15s) → FIXED (now 90s)
3. ✅ Found: Mini upload function is TODO stub → NEEDS IMPLEMENTATION

**Evidence:**
- Serial logs show `[upload] TODO: implement HTTPS upload`
- MQTT shows Mini reporting upload "retry" status
- MinIO shows last upload: 10/20 02:31 (before test started)
- Presign API logs show 400 errors (malformed JSON from Mini)

---

## Why Upload Failed (Technical Detail)

```
┌─────────────┐  Capture   ┌──────────────┐
│  AMB82-Mini │───────────>│ Upload Queue │
│   Camera    │  26KB JPG  │ (in memory)  │
└─────────────┘            └──────────────┘
                                   │
                                   │ performUploadAttempt()
                                   ▼
                           return false;  ← STUB!
```

**Expected flow (not implemented):**
```
1. POST /v1/presign/put → get signed URL
2. PUT <photo-data> to signed URL
3. MinIO stores file
4. Return true
```

**Actual flow:**
```
1. TODO stub always returns false
2. Mini schedules retry in 60s
3. ESP32 sends sleep_deep (now after 90s, was 15s)
4. Loop repeats forever → 0 uploads
```

---

## Changes Already Made (No Action Needed)

### ✅ Fixed: ESP32 Sleep Timeout
**File:** `skyfeeder/command_handler.cpp:122`
```cpp
// Before:
constexpr unsigned long kMiniIdleSleepMs = 15000;  // 15s - TOO SHORT!

// After:
constexpr unsigned long kMiniIdleSleepMs = 90000;  // 90s - allows retries
```

**Why:** Mini's upload retry backoff is 60 seconds. ESP32 was sending `sleep_deep` after only 15 seconds, interrupting uploads mid-flight.

### ✅ Fixed: Soak Test PowerShell Script
**File:** `tools/soak-test-24h.ps1`
**Issue:** PowerShell parsing pipe characters in markdown tables
**Fix:** Use `[char]124` + `Add-Content` to avoid pipe operators
**Status:** Tested, working, ready to re-run

---

## Next Steps (Codex)

1. 📖 **Read:** [INSTRUCTIONS_FOR_CODEX.md](INSTRUCTIONS_FOR_CODEX.md)
2. ✏️ **Implement:** 3 functions in `amb-mini/amb-mini.ino`
3. 🧪 **Test:** Manual snapshot → verify photo in MinIO
4. ⏱️ **Re-run:** 24-hour soak test → target >= 85% success
5. ✅ **Validate:** Mark A1.4 upload success as complete

---

## Questions for Codex

- **Q: Should Mini cache discovery response?**
  A: Optional optimization - can fetch on every upload for now

- **Q: Error handling for network failures?**
  A: Return false → retry queue handles backoff automatically

- **Q: Use HTTPS?**
  A: Not yet - presign API returns `http://` for local stack

- **Q: Memory concerns?**
  A: Watch heap, ensure `client.stop()` in all paths

---

## After Upload Implementation

**Remaining A1.4 Validation:**
- ⏳ 24-hour soak test (re-run with working upload)
- ⏳ Power measurements (INA260 sensor hookup)

**Remaining B1 Validation:**
- ⏳ Triple power-cycle test (manual)
- ⏳ LED transition verification (manual)
- ⏳ Provisioning demo video (manual)

**Remaining A1.3 Validation:**
- ⏳ iOS gallery testing (iOS device needed)

---

**All details, code samples, and testing instructions in [INSTRUCTIONS_FOR_CODEX.md](INSTRUCTIONS_FOR_CODEX.md)**
