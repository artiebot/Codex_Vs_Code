# A1.4 Validation - Implementation Decision Needed

**Status:** ⏸️ **DECISION POINT**
**Date:** 2025-10-21

## What I Found

### ✅ Issues Diagnosed
1. **ESP32 Sleep Timeout Bug** - FIXED
   - Was: 15 seconds (too short for uploads)
   - Now: 90 seconds (allows retry backoff)
   - File: [skyfeeder/command_handler.cpp:122](skyfeeder/command_handler.cpp#L122)

2. **HTTP Upload Not Implemented** - DOCUMENTED
   - Mini firmware has TODO stub that always fails
   - File: [amb-mini/amb-mini.ino:444-454](amb-mini/amb-mini.ino#L444-L454)
   - Details: [UPLOAD_NOT_IMPLEMENTED.md](UPLOAD_NOT_IMPLEMENTED.md)

3. **False Alarm: Boot Loop** - CORRECTED
   - Device actually boots fine and runs stably
   - Previous crash report was incorrect
   - File: [CRITICAL_WATCHDOG_CRASH_BOOTLOOP.md](CRITICAL_WATCHDOG_CRASH_BOOTLOOP.md) - RETRACTED

### 📊 Soak Test Results
- **Duration:** 21+ hours (of 24h target)
- **Upload Success:** 0% (target: >= 85%)
- **Root Cause:** Upload function not implemented
- **Photos Captured:** 24+ (camera works)
- **Photos Uploaded:** 0 (upload stub always fails)

## Decision: How to Proceed?

### Option A: I Implement HTTP Upload Now (6-10 hours)
**What it involves:**
- Add HTTP client code to Mini firmware
- Implement presign API flow (GET discovery, POST presign, PUT data)
- Test and debug
- Flash firmware
- Re-run soak test

**Pros:**
- Unblocks A1.4 validation immediately
- Completes the missing feature

**Cons:**
- Complex (6-10 hours of work)
- Risk of introducing new bugs
- I might not match Codex's architecture vision

### Option B: Wait for Codex to Implement (Recommended)
**What it involves:**
- Share detailed implementation plan with Codex
- Codex implements upload properly
- Test when ready

**Pros:**
- Codex knows the architecture best
- Lower risk of architectural mismatch
- Proper error handling and edge cases

**Cons:**
- Blocks A1.4 validation until Codex is available
- Delays field deployment timeline

### Option C: Hybrid - Minimal Proof-of-Concept
**What it involves:**
- I implement bare-minimum upload (no retry, minimal error handling)
- Just enough to prove it works
- Codex refines it later

**Pros:**
- Quick validation that upload path works
- Unblocks immediate testing

**Cons:**
- Will need rework later
- Might not handle edge cases

## My Recommendation

**Wait for Codex (Option B)** because:

1. The upload implementation is complex and touches critical camera firmware
2. I've already fixed the sleep timeout bug (quick win)
3. The detailed implementation docs I created give Codex everything needed
4. Risk of me introducing subtle bugs in memory management or HTTP parsing

## What's Ready for Codex

✅ **Complete diagnostics:**
- [UPLOAD_NOT_IMPLEMENTED.md](UPLOAD_NOT_IMPLEMENTED.md) - Full analysis + code samples
- ESP32 sleep timeout already fixed

✅ **Implementation guide includes:**
- HTTP client code examples (POST, PUT)
- JSON parsing snippets
- URL parsing logic
- Error handling patterns
- Testing plan

## If You Want Me to Implement (Option A or C)

Just say "go ahead and implement the upload" and I'll:
1. Add HTTP helper functions to Mini firmware
2. Implement presign flow (discovery → presign → upload)
3. Test with manual snapshot
4. Re-run soak test
5. Debug any issues

**Estimated time:** Rest of today + testing tomorrow

## Current State

| Component | Status | Notes |
|-----------|--------|-------|
| ESP32 Firmware | ✅ FIXED | Sleep timeout 15s → 90s |
| Mini Firmware | ❌ NEEDS WORK | Upload stub must be implemented |
| Presign API | ✅ WORKING | Tested, returns signed URLs |
| MinIO | ✅ WORKING | Ready to receive uploads |
| Soak Test Script | ✅ WORKING | PowerShell fixed, ready to re-run |

## Next Steps (Pending Your Decision)

1. **If Option A/C:** I implement upload now
2. **If Option B:** Share docs with Codex, wait for implementation
3. **Then:** Re-run 24-hour soak test
4. **Then:** Continue with B1 provisioning validation
5. **Then:** A1.4 power measurements

---

**Your call:** Should I implement the HTTP upload myself, or wait for Codex?
