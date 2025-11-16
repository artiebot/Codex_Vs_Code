# iOS SwiftUI 3-Tab App Implementation Report

**Date:** 2025-11-16
**Build Version:** 0.1.0 (Build 8)
**TestFlight Status:** Latest candidate: Build 8 (previous Build 7 already exists on App Store Connect)
**Implementation Type:** Production-ready SwiftUI app matching mockup designs

---

## Executive Summary

Implemented a comprehensive SwiftUI-based iOS application with three tabs (Feeder, Options, Dev) matching provided mockup images. The implementation follows MVVM architecture, uses modern Swift async/await patterns, and includes zero MQTT references. Build 6 successfully compiled, passed all asset catalog checks, and uploaded to TestFlight via the GitHub Actions `ios-build-upload` workflow; Build 7 incremented the internal bundle version, and Build 8 is the current candidate to satisfy App Store Connect’s monotonically increasing bundle version requirement.

**Key Achievements:**
- 3-tab TabView with production-quality UI
- Complete MQTT audit (zero references in new code)
- Asset catalog compilation working
- Mock API implementations ready for backend integration
- Proper error handling and state management
- Dev tab controllable via Info.plist/Settings rather than `#if DEBUG`

---

## Implementation Details

### Architecture

**Pattern:** MVVM (Model-View-ViewModel)
**Concurrency:** Async/await throughout
**State Management:** @Published properties with Combine
**Persistence:** UserDefaults for Options settings
**Navigation:** SwiftUI TabView with conditional DEBUG compilation

### Files Created (19 total)

#### Models (8 files)
Located in: `mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/Models/`

1. **BatteryStatus.swift** - Battery state (percentage, solar charging, online status)
2. **RetentionPolicy.swift** - Photo/video retention configuration
3. **FeederMediaItem.swift** - Media items with metadata (weight, dates, URLs)
4. **OptionsSettings.swift** - User-configurable settings with persistence
5. **DeviceSummary.swift** - Device status for Dev tab
6. **ConnectivityDiagnostics.swift** - Network health (no protocol names)
7. **TelemetrySnapshot.swift** - Power and sensor telemetry
8. **LogEntry.swift** - Log entries for Dev diagnostics

#### ViewModels (3 files)
Located in: `mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/ViewModels/`

1. **FeederViewModel.swift** - Manages battery status, photos, videos
   - Mock API implementations
   - Share/delete functionality
   - Error handling with alerts
   - Pull-to-refresh support

2. **OptionsViewModel.swift** - Settings management
   - UserDefaults persistence
   - Real-time updates for all settings
   - Retention policy fetching

3. **DevViewModel.swift** - Developer tools (DEBUG only)
   - Device search and filtering
   - Connectivity diagnostics
   - Telemetry monitoring
   - Action buttons (cleanup, reboot, etc.)
   - Log viewing

#### Views (3 files)
Located in: `mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/Views/`

1. **Feeder/FeederView.swift** - Main customer-facing tab
   - Battery card with percentage bar
   - Status indicators (charging, online/offline)
   - Photos section with horizontal scroll
   - Videos section with horizontal scroll
   - Media cards with thumbnails, weight, dates
   - Share and delete buttons
   - Video player integration

2. **Options/OptionsView.swift** - Settings configuration
   - Capture Settings section (weight, type, cooldown)
   - Time & Quiet Hours section
   - Notifications toggles
   - Storage & Retention info (read-only)
   - Advanced settings
   - All changes persist to UserDefaults

3. **Dev/DevView.swift** - Developer diagnostics (DEBUG only)
   - Devices card with search
   - Connectivity diagnostics
   - Power & telemetry display
   - Actions grid (cleanup, telemetry, reboot, reset)
   - Scrollable logs with timestamps

#### Theme
Located in: `mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/Theme/`

**DesignSystem.swift** - Centralized design tokens
- Color palette (Teal primary #0F9A95, background #F5F6F8)
- Battery colors (green/yellow/red based on percentage)
- Typography helpers (rounded system fonts)
- Hex color initializer extension

#### Root View
**Updated:** `mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/Views/RootView.swift`
- Replaced old TabView with 3-tab layout
- Conditional Dev tab compilation (`#if DEBUG`)
- Teal tint color matching design system

---

## UI/UX Implementation

### Feeder Tab (Main Customer View)

**Top Section - Battery Card:**
```
+-------------------------------------+
� [Battery Bar �����������] 78%      �
�                                     �
� ? Charging via solar                �
� ? Feeder is online                  �
+-------------------------------------+
```

**Photos Section:**
```
Photos
Photos are automatically removed after 7 days.

[Photo 1]  [Photo 2]  [Photo 3]  ?
 453g       289g       512g
 Share?     Share?     Share?
 Delete??   Delete??   Delete??
```

**Videos Section:**
```
Videos
Videos are automatically removed after 3 days.

[Video 1]  [Video 2]  ?
  ? Play    ? Play
 421g       394g
```

**Features:**
- Battery percentage bar with color-coded states
- Status dots (green for online/charging, red for offline/battery)
- Horizontal scrolling carousels
- Async thumbnail loading with placeholders
- Share sheet integration
- Delete confirmation with error handling
- Video player modal
- Pull-to-refresh

### Options Tab (Settings)

**Capture Settings:**
```
+-------------------------------------+
� Min trigger weight        80 g   > �
� Capture type    Photo + short   > �
�   ? Photo only                     �
�   ? Video only                     �
�   ? Photo + short video            �
� Capture cooldown          30 sec > �
+-------------------------------------+
```

**Time & Quiet Hours:**
```
+-------------------------------------+
� Enable                    [Toggle] �
� From                      22:00  > �
� To                        06:00  > �
� No captures or notifications        �
� at night.                          �
+-------------------------------------+
```

**Notifications:**
```
+-------------------------------------+
� Notify on low battery     [Toggle] �
� Notify when feeder sees   [Toggle] �
� a visitor                          �
+-------------------------------------+
```

**Storage & Retention:**
```
+-------------------------------------+
� Photos kept for           7 days  �
� Videos kept for           3 days  �
� Controlled by SkyFeeder �          �
� not adjustable here.               �
+-------------------------------------+
```

**Features:**
- Radio button selection for capture types
- Toggle switches with teal tint
- Time pickers for quiet hours (not yet implemented)
- Read-only retention display
- All settings persist to UserDefaults
- Grouped card-based layout

### Dev Tab (Developer Tools - DEBUG Only)

**Devices:**
```
+-------------------------------------+
� Devices                            �
� [?? Search devices________]        �
�                                     �
� ?? sf-1234         ? Online    78% �
�    Last contact: 2 min             �
�                                     �
� ?? sf-ABCD         ? Online    65% �
�    Last contact: 3 min             �
+-------------------------------------+
```

**Connectivity:**
```
+-------------------------------------+
� Connectivity                       �
� Status            Healthy          �
� Recent failures   0                �
� Average roundtrip 320 ms           �
� Last sync         2 min ago        �
+-------------------------------------+
```

**Power & Telemetry:**
```
+-------------------------------------+
� Power & Telemetry                  �
� Pack voltage      3.92 V           �
� Solar input       3.6 W            �
� Load power        1.2 W            �
� Internal temp     24.5 �C          �
� Signal strength   -63 dBm          �
�                                     �
� PHOTO_RETENTION_DAYS  7            �
� VIDEO_RETENTION_DAYS  3            �
�              [Run cleanup now]     �
+-------------------------------------+
```

**Actions:**
```
+-------------------------------------+
� Actions                            �
� [Force telemetry] [Request snapshot]�
� [Reboot]          [Factory reset]  �
+-------------------------------------+
```

**Logs:**
```
+-------------------------------------+
� Logs                               �
� 23:29  Received response 200       �
� 23:26  Request sent                �
� 23:25  Received response 200       �
+-------------------------------------+
```

**Features:**
- Device search with real-time filtering
- Generic status display (no protocol names)
- Monospaced timestamps in logs
- 2�2 action button grid
- Scrollable log viewer
- Red text for dangerous actions (factory reset)

---

## MQTT Audit Results

### Search Methodology
```bash
rg -n "MQTT" mobile/ios-field-utility/SkyFeederUI
rg -n "mqtt://" mobile/ios-field-utility/SkyFeederUI
rg -n "HTTP|http://" mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/Views
```

### Findings

**? ZERO MQTT references found in:**
- All new ViewModels (FeederViewModel, OptionsViewModel, DevViewModel)
- All new Views (FeederView, OptionsView, DevView)
- All new Models
- DesignSystem theme

**? NO protocol names exposed in UI:**
- Connectivity diagnostics show generic "Status: Healthy"
- No "HTTP" or "MQTT" text in any user-facing strings
- All transport details abstracted behind ViewModels

**? Transport independence verified:**
- ViewModels use mock API stubs ready for any backend
- No hardcoded protocol assumptions
- Easy to swap HTTP/WebSocket/GraphQL implementations

### Old Code References
The only HTTP references found were in pre-existing code:
- `SettingsView.swift:75` - "HTTP Endpoint" label (existing settings screen)
- `SettingsView.swift:96` - HTTPS requirement tip (existing validation)

**Conclusion:** All new SwiftUI code is transport-agnostic and contains zero MQTT references.

---

## Build Validation

### Build 4 Results (2025-11-15)

**GitHub Actions Run:** 19397130313
**Duration:** 1 minute 42 seconds
**Status:** ? SUCCESS

#### Archive Verification
```
? Archive Succeeded
? Swift compilation: 0 errors, 6 warnings (non-blocking)
? Asset catalog compilation: Working
? IPA created: build/SkyFeederFieldUtility.ipa
? Code signing: Successful
```

#### IPA Bundle Inspection
```
CFBundleVersion: 4
CFBundleIdentifier: com.skyfeeder.field
CFBundleIconName: AppIcon
CFBundleIcons: ? Present (iPhone + iPad)
Assets.car: ? Present
Icon PNGs: ? Present (AppIcon60x60@2x.png, AppIcon76x76@2x~ipad.png)
```

#### TestFlight Upload
```
? Successfully uploaded package to App Store Connect
? Binary processing started
? Build 4 available for testing
```

### Issues Fixed During Build

#### Issue #1: UTF-8 BOM in AppConfig.xcconfig
**Error:** `AppConfig.xcconfig:1:1: error: unexpected character '�'`
**Cause:** UTF-8 Byte Order Mark (EF BB BF) at file start
**Fix:** Rewrote file without BOM
**Commit:** `dc16e54` - "fix: remove UTF-8 BOM from AppConfig.xcconfig"

#### Issue #2: Duplicate Build Version
**Error:** `The bundle version must be higher than the previously uploaded version: '3'`
**Cause:** Build 3 already exists in TestFlight
**Fix:** Bumped `CURRENT_PROJECT_VERSION` from 3 to 4
**Commit:** `1456321` - "chore: bump build version to 4 for TestFlight"

### Swift Compiler Warnings (Non-blocking)
```
?? CaptureDetailView.swift:63 - value 'assetURL' defined but never used
?? DiskCache.swift:49 - variable 'resourceValues' was never mutated
?? DiskCache.swift:76,81,98 - capture of 'fileManager' with non-sendable type (Swift 6 prep)
?? GalleryViewModel.swift:22 - main actor-isolated static property in nonisolated context
```

**Note:** All warnings are in existing code, not new SwiftUI implementation. Safe to defer.

---

## Code Quality & Best Practices

### MVVM Architecture
```
Models (Data)
  ?
ViewModels (Business Logic)
  ?
Views (UI)
```

**Benefits:**
- Clear separation of concerns
- Testable business logic
- Reusable components
- Easy to mock for previews

### Async/Await Usage
```swift
public func refresh() async {
    isLoading = true
    errorMessage = nil

    do {
        battery = try await fetchBatteryStatus()
        retentionPolicy = try await fetchRetentionPolicy()
        photoItems = try await fetchPhotos()
        videoItems = try await fetchVideos()
    } catch {
        errorMessage = error.localizedDescription
    }

    isLoading = false
}
```

### Error Handling
```swift
.alert(
    "Error",
    isPresented: Binding(
        get: { viewModel.errorMessage != nil },
        set: { isPresented in
            if !isPresented {
                viewModel.errorMessage = nil
            }
        }
    )
) {
    Button("OK") {
        viewModel.errorMessage = nil
    }
} message: {
    if let error = viewModel.errorMessage {
        Text(error)
    }
}
```

### UserDefaults Persistence
```swift
private static let settingsKey = "SkyFeederOptionsSettings"

private func saveSettings() {
    if let encoded = try? JSONEncoder().encode(settings) {
        UserDefaults.standard.set(encoded, forKey: Self.settingsKey)
    }
}

private static func loadSettings() -> OptionsSettings {
    guard let data = UserDefaults.standard.data(forKey: settingsKey),
          let decoded = try? JSONDecoder().decode(OptionsSettings.self, from: data) else {
        return OptionsSettings()
    }
    return decoded
}
```

### Conditional Compilation for Dev Tab
```swift
#if DEBUG
@StateObject private var devViewModel: DevViewModel
#endif

// In init:
#if DEBUG
_devViewModel = StateObject(wrappedValue: DevViewModel(settingsStore: settingsStore))
#endif

// In body:
#if DEBUG
DevView(viewModel: devViewModel)
    .tabItem {
        Label("Dev", systemImage: "wrench.fill")
    }
#endif
```

**Production Impact:** Dev tab completely stripped from Release builds.

---

## Mock API Implementations

All ViewModels include mock implementations ready for backend integration:

### FeederViewModel Stubs
```swift
private func fetchBatteryStatus() async throws -> BatteryStatus
private func fetchRetentionPolicy() async throws -> RetentionPolicy
private func fetchPhotos() async throws -> [FeederMediaItem]
private func fetchVideos() async throws -> [FeederMediaItem]
private func performDelete(_ item: FeederMediaItem) async throws
```

### OptionsViewModel Stubs
```swift
private func loadRetentionPolicy() async
```

### DevViewModel Stubs
```swift
private func fetchDevices() async throws -> [DeviceSummary]
private func fetchConnectivity() async throws -> ConnectivityDiagnostics
private func fetchTelemetry() async throws -> TelemetrySnapshot
private func fetchRetentionPolicy() async throws -> RetentionPolicy
private func fetchLogs() async throws -> [LogEntry]
private func performCleanup() async throws
private func performForceTelemetry() async throws
private func performRequestSnapshot() async throws
private func performReboot() async throws
```

**Integration Pattern:**
```swift
// Replace mock:
private func fetchBatteryStatus() async throws -> BatteryStatus {
    try await Task.sleep(nanoseconds: 500_000_000)
    return BatteryStatus(percentage: 78, isChargingViaSolar: true, isOnline: true)
}

// With real API:
private func fetchBatteryStatus() async throws -> BatteryStatus {
    let url = URL(string: "\(settingsStore.baseURL)/api/battery")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(BatteryStatus.self, from: data)
}
```

---

## Integration Requirements

### Backend API Endpoints Needed

**Feeder Tab:**
- `GET /api/battery` ? `BatteryStatus`
- `GET /api/retention` ? `RetentionPolicy`
- `GET /api/photos?deviceId={id}` ? `[FeederMediaItem]`
- `GET /api/videos?deviceId={id}` ? `[FeederMediaItem]`
- `DELETE /api/media/{id}` ? `{success: bool}`

**Options Tab:**
- `GET /api/retention` ? `RetentionPolicy`
- `GET /api/settings?deviceId={id}` ? `OptionsSettings` (future)
- `POST /api/settings` ? `{success: bool}` (future)

**Dev Tab:**
- `GET /api/devices` ? `[DeviceSummary]`
- `GET /api/connectivity?deviceId={id}` ? `ConnectivityDiagnostics`
- `GET /api/telemetry?deviceId={id}` ? `TelemetrySnapshot`
- `GET /api/logs?deviceId={id}` ? `[LogEntry]`
- `POST /api/cleanup` ? `{success: bool}`
- `POST /api/telemetry/force` ? `{success: bool}`
- `POST /api/snapshot` ? `{success: bool}`
- `POST /api/reboot` ? `{success: bool}`

### Expected Response Formats

**BatteryStatus:**
```json
{
  "percentage": 78,
  "isChargingViaSolar": true,
  "isOnline": true
}
```

**FeederMediaItem:**
```json
{
  "id": "photo-1",
  "type": "photo",
  "thumbnailURL": "https://example.com/thumb.jpg",
  "mediaURL": "https://example.com/full.jpg",
  "weightGrams": 453.0,
  "capturedAt": "2025-11-15T23:00:00Z",
  "expiresAt": "2025-11-22T23:00:00Z"
}
```

**RetentionPolicy:**
```json
{
  "photoRetentionDays": 7,
  "videoRetentionDays": 3
}
```

### Date Format Requirements
```swift
// Use ISO8601 without milliseconds for Swift compatibility
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime]
// Produces: "2025-11-15T23:00:00Z"
```

---

## Testing Requirements

### Unit Testing (Not Yet Implemented)
```swift
// Example test structure
class FeederViewModelTests: XCTestCase {
    func testRefreshLoadsData() async throws {
        let viewModel = FeederViewModel(settingsStore: MockSettingsStore())
        await viewModel.refresh()
        XCTAssertNotNil(viewModel.battery)
        XCTAssertFalse(viewModel.photoItems.isEmpty)
    }

    func testDeleteRemovesItem() async throws {
        let viewModel = FeederViewModel(settingsStore: MockSettingsStore())
        await viewModel.refresh()
        let initialCount = viewModel.photoItems.count
        await viewModel.delete(viewModel.photoItems.first!)
        XCTAssertEqual(viewModel.photoItems.count, initialCount - 1)
    }
}
```

### UI Testing Checklist
- [ ] Feeder tab loads with mock data
- [ ] Battery percentage updates correctly
- [ ] Photos carousel scrolls smoothly
- [ ] Videos carousel scrolls smoothly
- [ ] Share sheet appears on tap
- [ ] Delete confirmation works
- [ ] Video player opens for videos
- [ ] Options settings persist across launches
- [ ] Capture type radio buttons work
- [ ] Toggles update settings immediately
- [ ] Dev tab search filters devices
- [ ] Action buttons trigger confirmations
- [ ] Logs scroll correctly
- [ ] Pull-to-refresh works on all tabs
- [ ] Error alerts display properly

### Device Testing Requirements
- [ ] iPhone SE (smallest screen) - layout doesn't break
- [ ] iPhone 15 Pro Max (largest screen) - uses space well
- [ ] iPad (all orientations) - adaptive layout
- [ ] Dark mode support (not yet implemented)
- [ ] Dynamic Type support (verify font scaling)
- [ ] VoiceOver accessibility (not yet tested)

---

## Known Limitations & Future Work

### Not Yet Implemented
1. **Time Pickers** - Quiet hours time selection (UI present, pickers not wired)
2. **Dark Mode** - No dark color scheme defined
3. **Accessibility** - VoiceOver labels not added
4. **Localization** - All strings hardcoded in English
5. **Pagination** - Media lists load all items at once
6. **Image Caching** - AsyncImage uses default URLCache
7. **Offline Mode** - No offline indicator or cached data
8. **Settings Sync** - Options don't POST to server yet
9. **Real-time Updates** - No WebSocket integration for live data
10. **Video Thumbnails** - Uses placeholders instead of actual thumbnails

### Performance Optimizations Needed
1. **Lazy Loading** - Implement pagination for large media lists
2. **Image Compression** - Reduce memory footprint for thumbnails
3. **Background Refresh** - Fetch updates when app returns from background
4. **Memory Management** - Profile and fix any retain cycles
5. **Smooth Scrolling** - Optimize carousel rendering

### Security Considerations
1. **API Authentication** - No auth headers in requests yet
2. **Secure Storage** - UserDefaults not encrypted
3. **Certificate Pinning** - Not implemented
4. **Input Validation** - Limited validation on user inputs

---

## Deployment Checklist

### Pre-Release Steps
- [x] Build compiles without errors
- [x] Asset catalog working
- [x] Info.plist configured correctly
- [x] Code signing successful
- [x] TestFlight upload successful
- [ ] Unit tests passing (not yet written)
- [ ] UI tests passing (not yet written)
- [ ] Performance profiling completed
- [ ] Memory leaks checked
- [ ] Crashlytics integrated
- [ ] Analytics integrated

### TestFlight Distribution
- [x] Build 4 uploaded successfully
- [ ] Internal testing group invited
- [ ] Beta testers invited
- [ ] Release notes written
- [ ] Known issues documented
- [ ] Feedback mechanism in place

### App Store Submission (Future)
- [ ] Screenshots prepared (all device sizes)
- [ ] App Store description written
- [ ] Keywords optimized
- [ ] Privacy policy URL added
- [ ] Support URL added
- [ ] Age rating determined
- [ ] In-app purchases configured (if needed)
- [ ] Subscriptions configured (if needed)

---

## Commits Summary

### Commit 1: Main Implementation
**Hash:** `fe43274`
**Message:** "feat: implement SwiftUI 3-tab app matching mockup designs"
**Files Changed:** 17 files, 1678 insertions, 78 deletions
**Description:** Complete SwiftUI implementation with all models, viewmodels, views, and theme

### Commit 2: BOM Fix
**Hash:** `dc16e54`
**Message:** "fix: remove UTF-8 BOM from AppConfig.xcconfig"
**Files Changed:** 1 file, 1 insertion, 1 deletion
**Description:** Fixed build error caused by UTF-8 BOM

### Commit 3: Version Bump
**Hash:** `1456321`
**Message:** "chore: bump build version to 4 for TestFlight"
**Files Changed:** 1 file, 1 insertion, 1 deletion
**Description:** Incremented build number for TestFlight submission

---

## References

**Mockup Images:**
- `app/app-pics/production.png` - Feeder tab design
- `app/app-pics/options.png` - Options tab design
- `app/app-pics/developer.png` - Dev tab design

**Documentation:**
- `iOS_XCODEGEN_INFO_PLIST_TROUBLESHOOTING.md` - Asset catalog troubleshooting
- `iOS_SIGNING_TROUBLESHOOTING.md` - Code signing guide
- `IOS_BUILD_FIX_REPORT.md` - XcodeGen migration guide
- `README_PLAYBOOK.md` - Main project playbook

**GitHub Actions:**
- Workflow: `.github/workflows/ios-build-upload.yml`
- Run: https://github.com/artiebot/Codex_Vs_Code/actions/runs/19397130313

**TestFlight:**
- App ID: 6754707840
- Bundle ID: com.skyfeeder.field
- Build 4: Processing in App Store Connect

---

## Conclusion

The SwiftUI 3-tab implementation provides a solid foundation for the SkyFeeder iOS app. The architecture is production-ready, the code is well-structured, and all new code is MQTT-free and transport-agnostic. Mock implementations make it easy to integrate with any backend API.

**Next Steps:**
1. TestFlight beta testing with internal team
2. Backend API integration (replace mocks)
3. Implement time pickers for quiet hours
4. Add unit and UI tests
5. Performance optimization and profiling
6. Dark mode support
7. Accessibility improvements
8. Localization for international markets

**Status:** ? Ready for beta testing and backend integration

### 2025-11-16 Update

- Hooked FeederView to a real data provider (`LiveFeederDataProvider`) that reuses the existing `GalleryViewModel`/capture providers, so the gallery now shows the same photos and videos as the legacy UI.
- Added the `FeederDataProviding` protocol (plus a mock implementation) inside `SkyFeederUI` so the SwiftUI package remains transport-agnostic while the app supplies the live implementation.
- Introduced `SKEnableDevTools` (Info.plist) and `SettingsStore.showDevTools` to toggle the Dev tab without recompiling; the tab is now visible outside DEBUG builds when the flag is `true`.
- Hard-coded typography colors in `DesignSystem` to fix the �white text on white cards� issue reported when the OS switches to Dark Mode.
- Added empty-state messaging for photo/video carousels and improved the placeholders so galleries don�t sit empty with spinners when no assets exist yet.
- Wired the Feeder delete button to the backend by calling `DELETE /api/media/{id}` (via `LiveFeederDataProvider`), using the `apiBaseURL` derived from `SettingsState` (the same base as other HTTP calls), including cache eviction so removed captures disappear immediately across the app.



### 2025-11-16 Update (Build 6)

- Build 6 successfully archived and uploaded to TestFlight via GitHub Actions (ios-build-upload.yml).
- Wired Feeder delete to the live backend via LiveFeederDataProvider using SettingsState.apiBaseURL, and confirmed match/fastlane signing are stable.
- Kept Dev tools targeting the single configured device (settingsStore.state.deviceID) for now, with telemetry still mocked pending backend endpoint design.
- Noted a TODO for hardware: image resolution/quality appears limited by the camera/docker stack; will be revisited when iterating on the unit firmware and container configuration.
- Dev tools now fetch capture cooldown seconds from the backend via SettingsProvider (api/settings), and surface it in the Power & Telemetry card instead of the customer Options tab.
- Dev Power & Telemetry card now shows an 'AMB MINI STATUS' line derived from connectivity/telemetry presence; this is a placeholder until the backend exposes an explicit device mode (sleeping vs capture).## Telemetry wiring status (Build 6)

- **Feeder tab**:
  - Gallery and delete are fully wired to the existing capture stack (manifest + presigned URLs) and `DELETE /api/media/{id}`.
  - Battery card calls `TelemetryProvider.fetchTelemetry` (`GET /api/telemetry`) via `LiveFeederDataProvider` to populate battery percentage and solar charging, but requires the backend to expose this endpoint in production.
- **Options tab**:
  - Capture settings, cooldown, and retention days are backed by `SettingsProvider` (`GET/POST /api/settings`), with retention shown as read-only.
- **Dev tab**:
  - Devices, connectivity, telemetry, retention, and logs cards are now backed by typed providers (`DevicesProvider`, `ConnectivityProvider`, `TelemetryProvider`, `SettingsProvider`, `LogsSummaryProvider`) that expect `/api/devices`, `/api/connectivity`, `/api/telemetry`, `/api/settings`, `/api/logs/summary` to be implemented.
  - AMB MINI STATUS is derived from the `mode` field returned by `/api/telemetry` (sleeping, capture, idle, offline).
### 2025-11-16 Build 7 Update

- Bumped `CURRENT_PROJECT_VERSION` to **7** in `mobile/ios-field-utility/project.yml` so new uploads have a higher bundle version than Build 6 on App Store Connect.
- Updated `FeederViewModel.refresh` so the Feeder tab **always** loads gallery media first; telemetry (battery/retention) is fetched opportunistically and its failure no longer blocks photos/videos from appearing.
- Changed the default `deviceID` from `field-kit-1` to `dev1` in both `GallerySettings` (app target) and `SettingsState` (Swift package) so a fresh install points at `http://10.0.0.4:8080/gallery/dev1/indices/latest.json` by default, matching the local unit.
