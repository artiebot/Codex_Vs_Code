# A1.3 Gallery Implementation Summary

This document captures the concrete code delivered for the SkyFeeder Field Utility during the iOS gallery push
(M2–M3 milestones). Use it as a high-level map when reviewing the project or performing validation for A1.3.

## Data Models
- **`Models/Capture.swift`** – Defines the capture domain object with metadata, thumbnail/asset resources, and convenience
  formatting helpers for file size and timestamps.
- **`Models/GallerySection.swift`** – Groups captures into chronological sections that the SwiftUI grid consumes.
- **`Models/UserSettings.swift`** – Wraps the `UserDefaults` storage used for provider selection, cache configuration, and
  badge behaviour, plus the observable settings model the views bind to.

## Providers & Storage
- **`Providers/CaptureProvider.swift`** – Protocol describing async capture loading plus helper extensions for grouping
  into sections.
- **`Providers/FilesystemCaptureProvider.swift`** – Reads `captures_index.json`, resolves thumbnails and HLS assets from the
  local filesystem, and supports incremental refreshes.
- **`Providers/PresignedCaptureProvider.swift`** – Fetches presigned URLs from the broker, downloads metadata JSON, and
  primes the disk cache for thumbnails/objects.
- **`Providers/SampleCaptureProvider.swift`** – Ships with canned JSON/media to keep the gallery functional in simulator
  environments.
- **`Support/DiskCache.swift`** – Shared caching layer that stores thumbnails and downloaded assets with TTL-aware eviction.
- **`Support/ImagePipeline.swift`** – Convenience wrapper that checks the disk cache before issuing network loads.

## Application Support
- **`Support/ApplicationRouter.swift`** – Centralises navigation destinations between gallery, detail, and settings.
- **`Support/ConnectivityMonitor.swift`** – NWPathMonitor-backed observable used to surface offline banners.
- **`Support/BadgeUpdater.swift`** – Maintains the application icon badge count based on unseen capture IDs.

## View Models
- **`ViewModels/GalleryViewModel.swift`** – Coordinates provider selection, grid refresh, disk caching, and badge updates
  while exposing state for loading/error/offline conditions.
- **`ViewModels/SettingsViewModel.swift`** – Binds the settings form to the `UserSettings` store and triggers provider swaps.

## SwiftUI Views
- **`Views/RootView.swift`** – Hosts the tab navigation with gallery and settings tabs plus offline banners.
- **`Views/GalleryView.swift` & `Views/CaptureGridItemView.swift`** – Render the adaptive grid, pull-to-refresh, empty state,
  and per-capture metadata badges.
- **`Views/CaptureDetailView.swift`** – Presents capture metadata, cached preview, and share/export entry point.
- **`Views/SettingsView.swift`** – Form for switching providers, editing filesystem roots or presigned endpoints, and
  configuring cache TTL / badge preferences.
- **`Views/OfflineStatusBanner.swift`** – Reusable offline indicator bound to the connectivity monitor.

## Testing
- **`Tests/FieldUtilityTests.swift`** – XCTests covering sample provider loading, disk cache read/write behaviour, and
  badge updater logic.

## Documentation Updates
- **`mobile/ios-field-utility/README.md`** – Now tracks milestone completion, outlines remaining phases, and confirms iOS 18
  compatibility.
- **`docs/VALIDATION_A1.3.md`** – Expanded manual test checklist with install prerequisites and artifact expectations for the
  gallery sign-off.
- **`README_PLAYBOOK.md`** – Updated roadmap snapshot to reflect M2–M3 completion and the outstanding validation gates.

## Validation Pointers
- Hardware runs must publish artifacts to `REPORTS/A1.3/` including gallery walkthrough video, badge screenshots, and
  provider switching logs.
- Ensure Xcode 15.4+ with iOS 17 or 18 devices is available before attempting the validation script.

