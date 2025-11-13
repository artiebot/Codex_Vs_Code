# iOS App Store Icon / Info.plist Troubleshooting

## Last Updated
- 2025-11-13

## Observed Issues
1. App Store validation errors (409) for missing CFBundleIconName, 120x120 (iPhone) and 152x152 (iPad) icons.
2. Info.plist mismatches between expected XcodeGen output and final IPA bundle.

## Changes Implemented
- XcodeGen info: block now generates the entire Info.plist, including CFBundleIconName & icon dictionaries.
- Asset catalog confirmed to include required AppIcon entries (60x60@2x, 76x76@2x).
- GitHub Actions always inspects the generated IPA: prints Info.plist & icon files when builds succeed, or logs a skip when no IPA exists.
- Pre-build script validates Info.plist keys & logs warnings if missing.

## Latest CI Result (2025-11-13 04:00 UTC)
- IPA built & signed successfully.
- Upload to TestFlight failed with App Store validation errors:
  * Missing 120x120 and 152x152 icons
  * Missing CFBundleIconName
- These errors were captured via the IPA inspection + altool logs.

## Next Steps
- Compare Info.plist inside IPA (printed in GitHub Actions) with XcodeGen config to ensure icon keys are present.
- Consider post-build PlistBuddy script (option B) if App Store still reports missing keys.
- Re-run CI after plist adjustments & verify altool output in logs.
