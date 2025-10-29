# SkyFeeder Field Utility (A1.3)

SwiftUI iOS application that operators use to browse, manage, and export SkyFeeder captures during the A1.3 readiness phase and the downstream pilot. The project is structured as a production seed so subsequent milestones can layer in data providers, caching, gallery UX, and validation harnesses without rework.

## Structure

```
mobile/
└── ios-field-utility/
    ├── SkyFeederFieldUtility.xcodeproj   # Xcode project for iOS 17
    ├── SkyFeederFieldUtility/            # Application sources
    │   ├── App/                          # App entry point
    │   ├── Providers/                    # Data sources (filesystem, presigned HTTP, etc.)
    │   ├── Models/                       # Domain models and persistence helpers
    │   ├── Views/                        # SwiftUI screens
    │   ├── Support/                      # Utilities, configuration, routing
    │   ├── Resources/                    # Asset catalog and localized strings
    │   └── Tests/                        # Unit and UI test bundles
    └── README.md                         # This file
```

The initial scaffold keeps the UI alive with a placeholder `RootView` so the project builds cleanly. Upcoming milestones replace the placeholder with the gallery, detail, and settings experiences while maintaining the same directory layout.

## Build Targets

- **SkyFeederFieldUtility** – iOS application targeting iOS 17.0 and Swift 5.9.
- **SkyFeederFieldUtilityTests** – XCTest bundle that will house the unit/UI tests enumerated in milestone M4.

## Next Steps

- **M2 – Data Providers & Caching:** Introduce `DataProvider` protocols and local/presigned implementations, including disk-backed caches and eviction policies.
- **M3 – App Features:** Implement the gallery grid, detail view, settings, offline banners, and application badge logic.
- **M4 – Tests & Validation:** Add automated coverage and export Xcode build logs for reproducibility.
- **M5 – Device Harness:** Connect the ESP32 uploader harness to make end-to-end validation trivial.
- **M6 – Acceptance Artifacts:** Capture the iOS walkthrough, final checklist, and supporting outputs to close A1.3.

## Tooling Expectations

- **Xcode 15** or newer with iOS 17 SDK.
- **SwiftLint** / formatting tools are optional for now; guidelines will be added once the providers land.
- Build and validation scripts live under `/Scripts` to keep command reproducibility high on both macOS (for iOS) and Windows (for ESP32 tooling).

## Contributing

1. Update `/REPORTS/PLAYBOOK.md` with the work session, commands run, and artifacts produced.
2. Keep new dependencies out of the project unless explicitly approved (no third-party SDKs per guardrails).
3. When landing new features, extend the relevant validation doc under `/docs/VALIDATION_*.md` and capture assets referenced by Sanaz’s manual test plan.

This scaffolding is intentionally lightweight but opinionated so we can move fast in the next milestones without tripping over project setup or mismatched expectations.
