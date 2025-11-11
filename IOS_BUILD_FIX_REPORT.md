# iOS TestFlight Build Fix Report

**Date**: 2025-11-11
**Status**: MANUAL INTERVENTION REQUIRED (macOS/Xcode)

---

## Executive Summary

The iOS TestFlight build is failing with "no such module 'SkyFeederUI'" error. The root cause is that the SkyFeederUI Swift Package is not properly configured in the Xcode project. **This requires opening the project in Xcode on macOS** to properly resolve.

---

## Root Cause Analysis

### Issue
The A1.3.5 iOS code was created in two separate locations:
1. **SkyFeederUI/** - Swift Package containing all new iOS code (views, viewmodels, providers)
2. **SkyFeeder/App/SkyFeederApp.swift** - New app entry point that imports SkyFeederUI
3. **SkyFeederFieldUtility/** - Old app target (still in Xcode project)

**The Xcode project (`SkyFeederFieldUtility.xcodeproj`) was never updated to link the SkyFeederUI package to the app target.**

### Attempted Fixes (All Failed)

1. ✅ Updated `SkyFeederFieldUtilityApp.swift` to import SkyFeederUI and use new code
2. ✅ Added XCLocalSwiftPackageReference for SkyFeederUI package
3. ✅ Added XCSwiftPackageProductDependency with package reference
4. ✅ Fixed Package.swift target path (`Sources/SkyFeederUI` instead of `Sources`)
5. ✅ Added PBXBuildFile for SkyFeederUI to Frameworks build phase
6. ❌ **Xcode still reports "unknown UUID" errors and discards the package dependencies**

### Current Errors

From latest build log:
```
`<PBXNativeTarget name=`SkyFeederFieldUtility` UUID=`064E0CAD2C079DE100B92288`>` attempted to initialize an object with an unknown UUID. `A10021F92A934D22A9BF078C` for attribute: `package_product_dependencies`. This can be the result of a merge and the unknown UUID is being discarded.

`<PBXBuildFile UUID=`F1A2B3C4D5E6F7890A1B2C3D`>` attempted to initialize an object with an unknown UUID. `A10021F92A934D22A9BF078C` for attribute: `product_ref`. This can be the result of a merge and the unknown UUID is being discarded.
```

**Translation**: Xcode doesn't recognize the package product dependency and build file entries added via manual editing. The project.pbxproj file format is fragile and Xcode is rejecting the manually-added entries.

---

## Solution: macOS/Xcode Steps Required

### Option 1: Add SkyFeederUI Package to Xcode Project (RECOMMENDED)

**On macOS with Xcode 15+:**

1. Open `mobile/ios-field-utility/SkyFeederFieldUtility.xcodeproj` in Xcode
2. Select the project in the navigator (top item)
3. Select the "SkyFeederFieldUtility" app target
4. Go to "General" tab
5. Scroll to "Frameworks, Libraries, and Embedded Content"
6. Click "+" button
7. Click "Add Other..." → "Add Package Dependency..."
8. Click "Add Local..."
9. Navigate to `mobile/ios-field-utility/SkyFeederUI` folder
10. Click "Add Package"
11. Select "SkyFeederUI" library
12. Click "Add"
13. Clean build folder (Cmd+Shift+K)
14. Build (Cmd+B) - should succeed
15. Commit the project.pbxproj changes

### Option 2: Copy Sources Directly (FALLBACK)

If package linking fails, copy all SkyFeederUI sources into main target:

1. In Xcode, right-click on SkyFeederFieldUtility group
2. Select "Add Files to 'SkyFeederFieldUtility'..."
3. Navigate to `SkyFeederUI/Sources/SkyFeederUI/`
4. Select all folders (Models, Providers, ViewModels, Views, etc.)
5. Check "Copy items if needed"
6. Check "Create groups"
7. Select "SkyFeederFieldUtility" target
8. Click "Add"
9. Update `SkyFeederFieldUtilityApp.swift` to remove `import SkyFeederUI` line
10. Clean and build

---

## Files Modified (Manual Editing Attempts)

### Successfully Modified
1. `mobile/ios-field-utility/SkyFeederFieldUtility/App/SkyFeederFieldUtilityApp.swift`
   - Updated to import SkyFeederUI and use SkyFeederRootView

2. `mobile/ios-field-utility/SkyFeederFieldUtility/Support/Info.plist`
   - Added SKAllowLocalHttp and SKDefaultProvider keys

3. `mobile/ios-field-utility/SkyFeederUI/Package.swift`
   - Fixed target paths to match directory structure

4. `mobile/ios-field-utility/SkyFeederFieldUtility.xcodeproj/project.pbxproj`
   - ❌ Manual edits not recognized by Xcode (see errors above)

---

## Build History

| Run ID | Commit | Result | Error |
|--------|--------|--------|-------|
| 19270593000 | 40f0a5a | FAILURE | no such module 'SkyFeederUI' |
| 19281067338 | 6ce7f2c | FAILURE | no such module 'SkyFeederUI' |
| 19281178606 | b658635 | FAILURE | no such module 'SkyFeederUI' + unknown UUID |
| 19281273481 | e76a6eb | FAILURE | no such module 'SkyFeederUI' + unknown UUID |

All builds fail at the same point: compiling `SkyFeederFieldUtilityApp.swift` which tries to `import SkyFeederUI`.

---

## Next Steps (REQUIRED ON MACOS)

1. **Immediate**: Follow "Option 1" steps above in Xcode on macOS to properly add the SkyFeederUI package
2. **Alternative**: If package fails, use "Option 2" to copy sources directly
3. **Validate**: Run build in Xcode (Cmd+B) to verify it compiles
4. **Test**: Run in simulator to verify app launches
5. **Deploy**: Trigger TestFlight workflow (`gh workflow run ios-testflight.yml`)

---

## Validation Checklist (After Fix)

Once the build succeeds:

- [ ] Build completes without errors in Xcode
- [ ] App runs in iOS Simulator
- [ ] Dashboard view loads with all cards
- [ ] Can navigate to Device Settings
- [ ] Can navigate to Storage Management
- [ ] GitHub Actions TestFlight build succeeds
- [ ] IPA uploads to TestFlight successfully

---

## Technical Notes

### Why Manual project.pbxproj Editing Failed

The Xcode project file format (`.pbxproj`) is a complex property list format with strict UUID referencing rules. Manually adding entries can fail because:

1. **UUID Validation**: Xcode validates that all UUIDs reference valid objects in the correct sections
2. **Cross-References**: Package dependencies require precise cross-references between multiple sections
3. **Format Sensitivity**: Even small formatting errors cause Xcode to reject entries
4. **Caching**: Xcode caches project structure and may not recognize manually-added entries

**The only reliable way to modify Xcode projects is through the Xcode IDE itself.**

### Package Structure (Confirmed Correct)

The SkyFeederUI package structure is valid:
```
SkyFeederUI/
├── Package.swift ✅ (fixed paths)
├── Sources/
│   └── SkyFeederUI/  ✅ (all source files present)
│       ├── Models/
│       ├── Providers/
│       ├── ViewModels/
│       ├── Views/
│       ├── Support/
│       ├── Theme/
│       └── Utilities/
└── Tests/
    └── SkyFeederUITests/
```

---

## Commit History (All Fixes Applied)

```bash
e76a6eb fix(ios): Link SkyFeederUI package product to Frameworks build phase
b658635 fix(ios): Add package reference to XCSwiftPackageProductDependency
6ce7f2c fix(ios): Correct SkyFeederUI Package.swift target paths
40f0a5a fix(ios): Link SkyFeederUI package and update app entry point for TestFlight builds
c9dd876 feat(A1.3.5): Complete iOS Dashboard Polish - All 5 Slices + Video Proxy Fix
```

All code fixes are committed and pushed to `main` branch. Only Xcode project configuration remains.

---

## Additional Resources

- [Xcode Package Dependencies](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)
- [Swift Package Manager](https://swift.org/package-manager/)
- iOS Signing Troubleshooting: See `iOS_SIGNING_TROUBLESHOOTING.md`
- Validation Checklist: See `VALIDATION_A1.3.5_SLICE5.md`
