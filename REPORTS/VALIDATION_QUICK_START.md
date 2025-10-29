# Validation Quick Start Guide

**Full Instructions:** [MANUAL_VALIDATION_INSTRUCTIONS.md](MANUAL_VALIDATION_INSTRUCTIONS.md)

---

## B1 Provisioning Tests (15 min)

### Quick Overview

Test the triple power-cycle factory reset and provisioning flow.

**What You'll Need:**
- ESP32 device with USB power
- Phone/laptop with WiFi
- Visual access to LED strip

### Test Flow

1. **Triple Power-Cycle** (5 min)
   - Unplug/replug USB 3 times quickly (within 10 sec each cycle)
   - LED should turn **amber**
   - `SkyFeeder-Setup` WiFi appears

2. **Provision via Captive Portal** (7 min)
   - Connect to `SkyFeeder-Setup`
   - Fill form: WiFi + MQTT credentials
   - Watch LED: **Amber** → **Blue** → **Green**
   - Verify device online via MQTT

3. **Record Video** (3 min)
   - Reset device again (triple power-cycle)
   - Screen record the provisioning flow
   - Save as `REPORTS/B1/provisioning_demo.mp4`

### Pass Criteria

✅ Amber LED appears after 3rd power cycle
✅ LED transitions through all 3 colors in order
✅ Device publishes MQTT telemetry
✅ Video recording captured

---

## A1.3 iOS Gallery Tests (30 min)

### Quick Overview

Test iOS app gallery with live photo uploads.

**What You'll Need:**
- iPhone/iPad with iOS 15+
- MacBook with Xcode
- USB cable
- Backend services running (docker ps)

### Test Flow

1. **Build LOCAL Profile** (10 min)
   - Open iOS project in Xcode
   - Configure for 10.0.0.4 backend
   - Build and install on iPhone

2. **Real-Time Gallery Updates** (10 min)
   - Open gallery in app
   - Trigger snapshot: `mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/camera" -m '{"op":"snapshot"}'`
   - Watch tile appear within 5 seconds

3. **Save to Photos** (5 min)
   - Tap photo tile
   - Tap "Save to Photos"
   - Verify in Photos app

4. **Video Playback** (5 min - optional)
   - Play video clip if available
   - Test controls

5. **Success Badge** (3 min)
   - Find 24h success rate badge
   - Verify shows ~97.8%

6. **Record Demo** (2 min)
   - iPhone screen recording
   - Show all features
   - Save as `REPORTS/A1.3/gallery_recording.mp4`

### Pass Criteria

✅ App builds and runs
✅ Gallery updates in real-time (<5 sec)
✅ Save to Photos works
✅ Success badge accurate
✅ Video recording captured

---

## Ready to Start?

**Start with B1 Provisioning** - it's faster and requires less setup.

Open [MANUAL_VALIDATION_INSTRUCTIONS.md](MANUAL_VALIDATION_INSTRUCTIONS.md) for detailed step-by-step guidance.

---

**Estimated Total Time:** 45 minutes (15 min B1 + 30 min A1.3)
