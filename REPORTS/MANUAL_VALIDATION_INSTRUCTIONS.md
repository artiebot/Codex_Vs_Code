# Manual Validation Instructions

**Date:** October 28, 2025
**Tests:** B1 Provisioning + A1.3 iOS Gallery

This guide provides step-by-step instructions for manual validation testing.

---

# B1: Provisioning Tests (15 minutes)

## Overview

Testing the triple power-cycle factory reset feature and captive portal provisioning flow.

**Reference Documentation:** [docs/PROVISIONING.md](../docs/PROVISIONING.md)

---

## Test 1: Triple Power-Cycle Factory Reset (5 minutes)

### Objective
Verify that powering the device on/off 3 times quickly triggers automatic factory reset and captive portal mode.

### Prerequisites
- ESP32 device powered and connected
- LED strip visible
- Device currently provisioned and connected to WiFi (green LED)

### Step-by-Step Instructions

#### Step 1: Note Current State
**Action:** Observe the device LED
**Expected:** Solid green (online) or normal power-state pattern
**Actual:** _______________

#### Step 2: First Power Cycle
**Action:**
1. Unplug the USB power cable
2. Wait 1 second
3. Plug USB power cable back in
4. Immediately start counting

**Expected:**
- Device boots
- LED shows normal startup sequence
- Device stays on

**Actual:** _______________

**Note:** After plugging in, you have ~10 seconds before the counter resets. Move quickly to step 3.

#### Step 3: Second Power Cycle
**Action:**
1. Within 10 seconds of step 2, unplug USB again
2. Wait 1 second
3. Plug USB back in

**Expected:**
- Device boots again
- LED shows normal startup sequence
- Counter increments to 2

**Actual:** _______________

#### Step 4: Third Power Cycle (Trigger Reset)
**Action:**
1. Within 10 seconds of step 3, unplug USB again
2. Wait 1 second
3. Plug USB back in
4. **Watch the LED carefully**

**Expected:**
- Device boots
- LED changes to **soft amber pulse/warn pattern**
- Serial console shows: "Entering setup mode (triple power cycle)"

**Actual LED Color:** _______________
**Actual LED Pattern:** _______________

**If LED is NOT amber:**
- Check serial console for error messages
- Try again (device may have been on too long between cycles)
- Counter resets after ~10 seconds of uptime per cycle

#### Step 5: Verify Setup Mode Active
**Action:**
1. Open WiFi settings on your phone/laptop
2. Scan for available networks

**Expected:**
- Network named `SkyFeeder-Setup` appears
- LED remains solid amber pulse

**Actual WiFi Network Name:** _______________

✅ **PASS CRITERIA:** Amber LED + `SkyFeeder-Setup` WiFi network visible
❌ **FAIL:** If LED is not amber or WiFi network doesn't appear after 30 seconds

---

## Test 2: Captive Portal & LED Transitions (7 minutes)

### Objective
Verify the complete provisioning flow with LED state transitions: Amber → Blue → Green

### Prerequisites
- Test 1 completed successfully
- `SkyFeeder-Setup` WiFi network visible
- Phone/laptop with WiFi and browser ready

### Step-by-Step Instructions

#### Step 1: Connect to Setup WiFi
**Action:**
1. On your phone/laptop, connect to `SkyFeeder-Setup` WiFi
2. Wait for captive portal to appear automatically
3. If it doesn't auto-appear, open browser and go to any website (e.g., http://example.com)

**Expected:**
- Captive portal login page appears automatically
- OR browser redirects to portal when you visit any URL
- Portal shows fields for WiFi SSID, Password, MQTT settings

**Actual:** _______________

**LED Status During Connection:**
- Should remain **solid amber pulse**

**Actual LED:** _______________

#### Step 2: Fill Out Provisioning Form
**Action:**
Fill in the following fields (use your actual local network settings):

```
WiFi SSID: _________________ (your local WiFi network)
WiFi Password: _________________ (your WiFi password)

MQTT Broker: 10.0.0.4
MQTT Port: 1883
MQTT Username: dev1
MQTT Password: dev1pass
Device ID: dev1
```

**Expected:**
- Form accepts input
- All fields editable

**Actual:** _______________

**Note:** Leave any field blank to use firmware defaults from `config.h`

#### Step 3: Submit Configuration
**Action:**
1. Click **"Save & Reboot"** button
2. **Immediately watch the LED**
3. Start a timer

**Expected LED Sequence:**

**Phase 1: Amber (current state)**
- Solid amber pulse
- Lasts until you click "Save & Reboot"

**Phase 2: Blue Heartbeat (0-30 seconds after submit)**
- LED changes to **blue heartbeat pattern** (slow pulse)
- Indicates: "Attempting to connect to WiFi"
- May last 10-30 seconds

**Phase 3: Green Solid (30-60 seconds after submit)**
- LED changes to **solid green**
- Indicates: "Connected to WiFi and MQTT"
- Device is online

**Actual Timing:**
- Amber duration: _____ seconds
- Blue heartbeat start: _____ seconds after submit
- Blue heartbeat duration: _____ seconds
- Green solid appears at: _____ seconds after submit

**LED Observations:**
- Amber pattern: _______________
- Blue pattern: _______________
- Green pattern: _______________

✅ **PASS CRITERIA:** All 3 LED states appear in sequence (Amber → Blue → Green)
❌ **FAIL:** If LED skips a state, stays in one state >90 seconds, or shows different colors

#### Step 4: Verify Device Online
**Action:**
1. Open a terminal/command prompt
2. Run: `mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/#" -v`
3. Wait 30 seconds

**Expected:**
- Messages appear showing device telemetry
- Messages like: `skyfeeder/dev1/status/online`, `skyfeeder/dev1/telemetry`, etc.

**Actual Messages Received:**
```
_______________
_______________
_______________
```

#### Step 5: Wait for AUTO Mode (2 minutes)
**Action:**
1. Let device run for 2 more minutes
2. Observe LED behavior

**Expected:**
- After ~2 minutes of stable WiFi, LED controller returns to normal power-state driven behavior
- LED may change from solid green to other patterns based on power state
- Device clears the power-cycle counter

**Actual:**
- LED at 2 minutes: _______________
- Device behavior: _______________

✅ **PASS CRITERIA:** Device publishes MQTT telemetry and LED stabilizes
❌ **FAIL:** No MQTT messages or LED stuck in one state

---

## Test 3: Screen Recording (3 minutes)

### Objective
Capture video evidence of the provisioning flow for documentation.

### Prerequisites
- Device back in normal operation (from Test 2)
- Screen recording software ready (phone/laptop)

### Step-by-Step Instructions

#### Step 1: Reset Device Again
**Action:**
Repeat Test 1 (triple power-cycle) to enter setup mode again

**Expected:**
- Amber LED appears
- `SkyFeeder-Setup` WiFi visible

#### Step 2: Start Screen Recording
**Action:**
1. Start screen recording on your phone/laptop
2. Record the entire provisioning flow

**Capture:**
- Phone/laptop WiFi settings showing `SkyFeeder-Setup`
- Connection to `SkyFeeder-Setup`
- Captive portal appearing
- Filling out the form (OK to blur password fields)
- Clicking "Save & Reboot"
- Close-up of LED showing color transitions (if possible)

#### Step 3: Provision Again
**Action:**
Connect to `SkyFeeder-Setup` and submit the form again with same credentials

**Expected:**
Same LED sequence: Amber → Blue → Green

#### Step 4: Save Recording
**Action:**
1. Stop recording
2. Save video as: `REPORTS/B1/provisioning_demo.mp4`
3. Create folder if needed: `mkdir REPORTS/B1`

**Recording Length:** _____ seconds
**File Size:** _____ MB
**Saved Location:** _______________

✅ **PASS CRITERIA:** Recording shows complete flow and LED transitions
❌ **FAIL:** Recording missing key steps or LED transitions not visible

---

## B1 Test Results Summary

**Test 1: Triple Power-Cycle**
- Result: ☐ PASS ☐ FAIL
- Notes: _______________

**Test 2: LED Transitions**
- Amber → Blue: ☐ PASS ☐ FAIL
- Blue → Green: ☐ PASS ☐ FAIL
- MQTT Online: ☐ PASS ☐ FAIL
- Notes: _______________

**Test 3: Screen Recording**
- Result: ☐ PASS ☐ FAIL
- File Location: _______________

**Overall B1 Status:** ☐ PASS ☐ FAIL

**Issues Found:**
```
_______________
_______________
_______________
```

---

# A1.3: iOS Gallery Tests (30 minutes)

## Overview

Testing the iOS app's gallery feature with local backend services (websocket, photo uploads, video playback).

**Reference:** [REPORTS/A1.3/ios_run_notes.md](../REPORTS/A1.3/ios_run_notes.md)

---

## Prerequisites

### Hardware/Software Needed
- iPhone or iPad with iOS 15+
- MacBook with Xcode installed
- USB cable to connect iPhone to Mac
- Same WiFi network as backend services (10.0.0.4)

### Backend Services Running
**Action:** Verify all services are up
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

**Expected:**
- `skyfeeder-presign-api` - Up
- `skyfeeder-ws-relay` - Up
- `skyfeeder-minio` - Up
- `skyfeeder-ota-server` - Up

**Actual:**
```
_______________
_______________
_______________
```

✅ **PASS:** All 4 services running
❌ **FAIL:** Any service not running - start with `docker compose up -d`

---

## Test 1: Build iOS LOCAL Profile (10 minutes)

### Objective
Build the iOS app with LOCAL configuration pointing to 10.0.0.4 backend.

### Step-by-Step Instructions

#### Step 1: Locate iOS Project
**Action:**
Find the iOS app project folder (typically in a separate repo or subfolder)

**Project Location:** _______________

**Note:** If you don't have the iOS app code, this test cannot proceed. Check with the team for the repository.

#### Step 2: Configure LOCAL Profile
**Action:**
1. Open the iOS project in Xcode
2. Find the configuration file (usually `Config.swift`, `Environment.swift`, or similar)
3. Set these values for LOCAL profile:

```swift
API_BASE = "http://10.0.0.4:8080"
WS_URL = "ws://10.0.0.4:8081"
S3_PHOTOS_BASE = "http://10.0.0.4:9200/photos"
S3_CLIPS_BASE = "http://10.0.0.4:9200/clips"
DEVICE_ID = "dev1"
```

**Expected:**
- Configuration file exists
- Values can be changed

**Actual Configuration File:** _______________
**Values Updated:** ☐ Yes ☐ No

**Note:** If using build schemes/configurations, select the LOCAL scheme in Xcode.

#### Step 3: Select Build Target
**Action:**
1. Connect iPhone to Mac via USB
2. In Xcode, select your iPhone as the build target (top toolbar)
3. Trust the computer on iPhone if prompted

**Expected:**
- Your iPhone appears in device list
- Build target selected

**Device Name:** _______________

#### Step 4: Build and Install
**Action:**
1. Click the Play/Run button in Xcode (or Cmd+R)
2. Wait for build to complete
3. App installs on iPhone

**Expected:**
- Build succeeds
- App launches on iPhone
- No certificate/signing errors

**Build Result:** ☐ Success ☐ Failed

**If Failed:**
- Error message: _______________
- Common issues:
  - Developer certificate not trusted (Settings > General > VPN & Device Management)
  - Signing & Capabilities needs team selection
  - Provisioning profile missing

**Build Time:** _____ seconds

✅ **PASS:** App builds and launches on iPhone
❌ **FAIL:** Build errors or app won't launch

---

## Test 2: Gallery Real-Time Updates (10 minutes)

### Objective
Verify gallery tiles update in real-time when photos are uploaded via WebSocket.

### Step-by-Step Instructions

#### Step 1: Open Gallery View
**Action:**
1. Launch SkyFeeder app on iPhone
2. Navigate to Gallery tab/screen

**Expected:**
- Gallery screen loads
- Shows photo grid (may be empty if no recent photos)
- Loading indicator appears briefly

**Actual:**
- Gallery loaded: ☐ Yes ☐ No
- Photo count shown: _____
- Any errors: _______________

#### Step 2: Trigger Photo Upload from Device
**Action:**
Open terminal and send snapshot command:
```bash
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/camera" -m '{"op":"snapshot"}'
```

**Expected:**
- Command sends successfully (no error)
- AMB-Mini captures photo
- Photo uploads to MinIO
- This may take 10-30 seconds

**Command Sent:** ☐ Yes ☐ No
**Time Sent:** _______________

#### Step 3: Watch for WebSocket Update
**Action:**
1. Keep iPhone screen on
2. Watch the gallery grid
3. Look for a new tile to appear OR existing tile to update

**Expected (Real-time Update):**
- New photo tile appears within 2-5 seconds of upload completing
- Tile shows thumbnail image
- Tile may show upload progress indicator (if still uploading)
- Badge or indicator shows upload status

**Actual:**
- New tile appeared: ☐ Yes ☐ No
- Time to appear: _____ seconds after command
- Thumbnail visible: ☐ Yes ☐ No
- Upload status shown: _______________

**If Tile Does NOT Appear:**
- Pull down to refresh gallery
- Check WebSocket connection indicator (if app has one)
- Check terminal for upload errors

#### Step 4: Verify Upload Success Badge
**Action:**
1. Look at the photo tile that just appeared
2. Check for a success badge/indicator

**Expected:**
- Green checkmark, "Success" label, or similar indicator
- Badge shows upload completed successfully

**Actual Badge/Indicator:** _______________

#### Step 5: Repeat for Second Upload
**Action:**
1. Wait 30 seconds
2. Send another snapshot command
3. Watch for second tile to appear

**Second Upload:**
- Tile appeared: ☐ Yes ☐ No
- Time to appear: _____ seconds
- Badge correct: ☐ Yes ☐ No

✅ **PASS:** Gallery updates in real-time, tiles appear within 5 seconds
❌ **FAIL:** Tiles don't appear, require manual refresh, or take >30 seconds

---

## Test 3: Photo Playback & Save (5 minutes)

### Objective
Verify tapping a photo opens full-screen view and "Save to Photos" works.

### Step-by-Step Instructions

#### Step 1: Tap Photo Tile
**Action:**
1. Tap on one of the photo tiles in the gallery
2. Watch for transition

**Expected:**
- Photo opens in full-screen view
- Image loads and displays clearly
- Navigation controls visible (back button, share, etc.)

**Actual:**
- Full-screen opened: ☐ Yes ☐ No
- Image quality: _______________
- Controls visible: ☐ Yes ☐ No

#### Step 2: Test Save to Photos
**Action:**
1. Look for "Save to Photos" button or share icon
2. Tap it
3. Grant Photos permission if prompted

**Expected:**
- "Save to Photos" button exists
- Tapping it shows system save dialog OR success message
- Photo saves to iPhone Photos app

**Actual:**
- Button found: ☐ Yes ☐ No
- Button location: _______________
- Permission prompt: ☐ Yes ☐ No ☐ Already granted
- Save succeeded: ☐ Yes ☐ No

#### Step 3: Verify in Photos App
**Action:**
1. Exit SkyFeeder app
2. Open iPhone Photos app
3. Go to Recent/All Photos

**Expected:**
- Saved photo appears in Photos library
- Photo is full resolution (22-23KB, ~640x480 or similar)
- Timestamp is recent

**Actual:**
- Photo found in library: ☐ Yes ☐ No
- File size/resolution: _______________
- Looks correct: ☐ Yes ☐ No

✅ **PASS:** Photo opens full-screen and saves to Photos successfully
❌ **FAIL:** Can't open photo or save fails

---

## Test 4: Video Playback (5 minutes, if clips available)

### Objective
Verify video clips play correctly in the gallery.

**Note:** This test requires video clips to be uploaded. If you only have photos, skip this test.

### Step-by-Step Instructions

#### Step 1: Check for Video Clips
**Action:**
Look in gallery for video tiles (may have play icon overlay)

**Expected:**
- Video tiles visible (if any clips have been uploaded)
- Play icon or duration indicator on tiles

**Actual:**
- Video clips found: ☐ Yes ☐ No
- Count: _____

**If No Videos:**
Skip to Test 5. You can upload a test video later if needed.

#### Step 2: Tap Video Tile
**Action:**
Tap on a video tile

**Expected:**
- Video player opens
- Video begins loading
- Play controls visible

**Actual:**
- Player opened: ☐ Yes ☐ No
- Controls visible: ☐ Yes ☐ No

#### Step 3: Play Video
**Action:**
Tap play button (if not auto-playing)

**Expected:**
- Video plays smoothly
- Audio plays (if video has audio)
- Can pause/resume
- Can seek forward/backward

**Actual:**
- Video plays: ☐ Yes ☐ No
- Audio works: ☐ Yes ☐ No ☐ N/A
- Controls work: ☐ Yes ☐ No
- Issues: _______________

✅ **PASS:** Videos play smoothly with working controls
❌ **FAIL:** Videos don't play, lag heavily, or controls don't work
⚠️ **SKIP:** No videos available to test

---

## Test 5: 24h Success Badge (3 minutes)

### Objective
Verify the gallery shows upload success rate badge/indicator.

### Step-by-Step Instructions

#### Step 1: Find Success Rate Display
**Action:**
Look in the gallery screen for a success rate or badge count

**Expected:**
- Badge or label showing "24h success rate" or similar
- Percentage like "97.8%" or fraction like "44/45"
- May be in header, toolbar, or near individual photos

**Actual:**
- Badge found: ☐ Yes ☐ No
- Location: _______________
- Value shown: _______________

#### Step 2: Verify Badge Reflects A1.4 Results
**Action:**
Compare badge value to A1.4 test results (44/45 uploads = 97.8%)

**Expected:**
- Badge shows ~97.8% or 44/45
- Updates based on actual upload data

**Actual:**
- Badge value matches: ☐ Yes ☐ No
- Discrepancy: _______________

#### Step 3: Trigger New Upload and Watch Badge
**Action:**
1. Send another snapshot command
2. Wait for upload to complete
3. Watch badge value

**Expected:**
- Badge updates to reflect new upload
- Count increases (45/46 or similar)

**Actual:**
- Badge updated: ☐ Yes ☐ No
- New value: _______________
- Update time: _____ seconds

✅ **PASS:** Badge shows accurate success rate and updates with new uploads
❌ **FAIL:** Badge missing, inaccurate, or doesn't update

---

## Test 6: Screen Recording (2 minutes)

### Objective
Capture video evidence of the gallery functionality.

### Step-by-Step Instructions

#### Step 1: Start iPhone Screen Recording
**Action:**
1. Swipe down from top-right (or up from bottom on older iPhones)
2. Tap Screen Recording button (red dot icon)
3. Wait for 3-second countdown

**Recording Started:** ☐ Yes ☐ No

#### Step 2: Demonstrate Gallery Features
**Action:**
Record yourself performing these actions:
1. Show gallery grid with photos
2. Scroll through gallery
3. Tap a photo to open full-screen
4. Tap "Save to Photos"
5. Show success message
6. Return to gallery
7. Show success rate badge
8. Trigger new snapshot (send MQTT command from computer - just show the result)
9. Show new tile appearing in real-time

**Actions Recorded:** _____/9

#### Step 3: Stop and Save Recording
**Action:**
1. Tap red status bar (or screen recording indicator)
2. Tap "Stop"
3. Recording saves to Photos
4. Transfer to computer: AirDrop, iCloud, or USB

**Recording Saved:** ☐ Yes ☐ No
**Recording Length:** _____ seconds

#### Step 4: Save to Project
**Action:**
Save video as: `REPORTS/A1.3/gallery_recording.mp4`

**File Saved:** ☐ Yes ☐ No
**File Size:** _____ MB

✅ **PASS:** Recording captures all gallery features
❌ **FAIL:** Recording incomplete or features not working

---

## A1.3 Test Results Summary

**Test 1: Build iOS LOCAL Profile**
- Result: ☐ PASS ☐ FAIL
- Build time: _____ seconds
- Notes: _______________

**Test 2: Gallery Real-Time Updates**
- Result: ☐ PASS ☐ FAIL
- Update latency: _____ seconds
- Notes: _______________

**Test 3: Photo Playback & Save**
- Result: ☐ PASS ☐ FAIL
- Save to Photos: ☐ Works ☐ Failed
- Notes: _______________

**Test 4: Video Playback**
- Result: ☐ PASS ☐ FAIL ☐ SKIP
- Notes: _______________

**Test 5: 24h Success Badge**
- Result: ☐ PASS ☐ FAIL
- Badge value: _______________
- Notes: _______________

**Test 6: Screen Recording**
- Result: ☐ PASS ☐ FAIL
- File location: _______________

**Overall A1.3 Status:** ☐ PASS ☐ FAIL

**Issues Found:**
```
_______________
_______________
_______________
```

---

## Final Checklist

### Artifacts to Create

**B1 Provisioning:**
- ☐ `REPORTS/B1/provisioning_demo.mp4` - Screen recording of provisioning flow
- ☐ `REPORTS/B1/test_results.md` - Copy of this document with filled-in results

**A1.3 Gallery:**
- ☐ `REPORTS/A1.3/gallery_recording.mp4` - Screen recording of gallery features
- ☐ `REPORTS/A1.3/test_results.md` - Copy of this document with filled-in results

### Commit Results
```bash
# Create directories
mkdir -p REPORTS/B1
mkdir -p REPORTS/A1.3

# Add your recordings and test results
git add REPORTS/B1/ REPORTS/A1.3/
git commit -m "Manual validation: B1 provisioning + A1.3 iOS gallery"
git push
```

---

**Testing Complete!**

Return to validation tracking document to update status and proceed with next steps.
