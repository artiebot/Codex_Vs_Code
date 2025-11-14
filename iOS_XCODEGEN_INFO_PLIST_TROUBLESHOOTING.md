# iOS XcodeGen Info.plist Bundle Icon Issue - Troubleshooting Guide

**Date:** 2025-11-13
**Status:** IN PROGRESS
**Issue:** App Store validation fails reporting missing CFBundleIconName, 120×120 iPhone icon, and 152×152 iPad icon despite all files existing in source

## Problem Statement

After migrating from manual .xcodeproj to XcodeGen 2.37.0, iOS builds succeed but App Store Connect validation fails with:

```
❌ Missing required icon file 120×120 (iPhone)
❌ Missing required icon file 152×152 (iPad)
❌ Missing Info.plist value for CFBundleIconName
```

**Critical Symptom:** Build succeeds, IPA created, but final bundle is missing icon metadata.

## Environment

- **Build System:** GitHub Actions (macos-14, Xcode 16.1)
- **Tools:** XcodeGen 2.37.0, Fastlane, Fastlane Match
- **Constraint:** NO local Mac, NO Xcode UI - all debugging via CI logs only
- **Project Structure:**
  - XcodeGen config: `mobile/ios-field-utility/project.yml`
  - Info.plist template: `mobile/ios-field-utility/SkyFeederFieldUtility/Support/Info.plist`
  - Asset catalog: `mobile/ios-field-utility/SkyFeederFieldUtility/Resources/Assets.xcassets/AppIcon.appiconset/`

## Asset Catalog Verification (✅ CORRECT)

Contents.json has all required icon entries:

```json
{
  "filename": "AppIcon60x60@2x.png",  // 120×120 iPhone
  "idiom": "iphone",
  "scale": "2x",
  "size": "60x60"
},
{
  "filename": "AppIcon76x76@2x.png",  // 152×152 iPad
  "idiom": "ipad",
  "scale": "2x",
  "size": "76x76"
}
```

All PNG files physically exist in the directory. ✅

## Attempted Fixes (Chronological)

### Attempt 1-5: Build Settings Cleanup
**Action:** Removed conflicting build settings from project.yml
- ❌ Removed: `INFOPLIST_FILE`
- ❌ Removed: `GENERATE_INFOPLIST_FILE`
- ❌ Removed: `INFOPLIST_KEY_*` entries

**Result:** ❌ FAILED - Same App Store validation errors

### Attempt 6-8: Info.plist Template Approach
**Action:** Added CFBundleIcons to template Info.plist

```xml
<key>CFBundleIconName</key>
<string>$(ASSETCATALOG_COMPILER_APPICON_NAME)</string>
<key>CFBundleIcons</key>
<dict>
    <key>CFBundlePrimaryIcon</key>
    <dict>
        <key>CFBundleIconFiles</key>
        <array>
            <string>AppIcon</string>
        </array>
        <key>UIPrerenderedIcon</key>
        <false/>
    </dict>
</dict>
<key>CFBundleIcons~ipad</key>
<dict>
    <key>CFBundlePrimaryIcon</key>
    <dict>
        <key>CFBundleIconFiles</key>
        <array>
            <string>AppIcon</string>
        </array>
        <key>UIPrerenderedIcon</key>
        <false/>
    </dict>
</dict>
```

**Result:** ❌ FAILED - Template not being used or merged correctly

### Attempt 9-11: XcodeGen info.properties Approach
**Action:** Added CFBundleIcons to project.yml info.properties

```yaml
info:
  path: SkyFeederFieldUtility/Support/Info.plist
  properties:
    CFBundleIconName: AppIcon
    CFBundleIcons:
      CFBundlePrimaryIcon:
        CFBundleIconFiles:
          - AppIcon
        UIPrerenderedIcon: false
    CFBundleIcons~ipad:
      CFBundlePrimaryIcon:
        CFBundleIconFiles:
          - AppIcon
        UIPrerenderedIcon: false
```

**Result:** ❌ FAILED - Build succeeds, but App Store validation still reports missing CFBundleIconName

**Key Observation:** Complex nested dictionaries (CFBundleIcons) do NOT merge from properties into final bundle when `path:` is also specified.

### Attempt 12-14: Diagnostic Improvements
**Action:** Enhanced CI logging to see actual bundle contents

1. Added "Print gym log on failure" step:
```yaml
- name: Print gym log on failure
  if: failure()
  run: |
    LOG_PATH="$HOME/Library/Logs/gym/SkyFeederFieldUtility-SkyFeederFieldUtility.log"
    cat "$LOG_PATH"
```

2. Added IPA inspection step:
```yaml
- name: Inspect IPA bundle Info.plist and assets
  if: always()
  run: |
    IPA_PATH=$(ls build/*.ipa | head -n1 2>/dev/null || true)
    # Unzip and inspect Info.plist contents
    /usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "${PLIST}"
```

3. Hardened preBuild validation script:
```yaml
preBuildScripts:
  - name: Validate Info.plist bundle keys
    script: |
      # Check INFOPLIST_FILE or TARGET_BUILD_DIR/INFOPLIST_PATH
      # Only warn, don't fail build
```

**Result:** ✅ Better visibility, but core issue persists

### Attempt 15: Generate Info.plist from Scratch (FAILED EARLIER)
**Action:** Removed `path:` directive to force pure generation from properties

```yaml
info:
  # path: REMOVED
  properties:
    # All 40+ Info.plist keys explicitly defined
```

**Result:** ❌ FAILED at XcodeGen step
```
Error: Parsing project spec failed: Decoding failed at "path": Nothing found
```

**Learning:** XcodeGen REQUIRES `path:` field in info block - cannot generate from scratch

## Root Cause Analysis

**XcodeGen's `info:` block behavior with `path` + `properties`:**

1. ✅ Simple string properties (CFBundleIconName) merge correctly
2. ❌ **Complex nested dictionaries (CFBundleIcons, CFBundleIcons~ipad) do NOT merge**
3. Template has them, properties has them, but final IPA bundle is missing them

**Evidence:**
- Build 19319429228: Build succeeded, no xcodebuild errors, but validation failed
- Build 19286305646 (2 days ago): Succeeded - suggests config was working before

## XcodeGen Merge Behavior (Hypothesis)

When `info:` block has BOTH `path:` and `properties:`:
- XcodeGen reads template from `path:`
- Applies `properties:` overlay
- **Simple values (strings, booleans) override template**
- **Complex nested structures MAY BE DROPPED instead of merged**

This is likely a XcodeGen limitation or design choice.

## Diagnostic Tools Created

### 1. Print Gym Log on Failure
**Location:** `.github/workflows/ios-build-upload.yml`
**Purpose:** Exposes xcodebuild errors hidden by Fastlane

### 2. IPA Inspection Step
**Location:** `.github/workflows/ios-build-upload.yml`
**Purpose:** Shows actual Info.plist contents in final IPA bundle

**Usage:** Check GitHub Actions logs for "Inspect IPA bundle" step

### 3. PreBuild Validation Script
**Location:** `mobile/ios-field-utility/project.yml` (preBuildScripts)
**Purpose:** Validates Info.plist keys before archiving (warns only, doesn't fail)

## Potential Solutions (To Be Tested)

### Option 1: PostBuildScript to Inject CFBundleIcons
Use PlistBuddy to add CFBundleIcons after XcodeGen generates Info.plist:

```yaml
postBuildScripts:
  - name: Inject CFBundleIcons
    script: |
      PLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
      /usr/libexec/PlistBuddy -c "Add :CFBundleIcons dict" "$PLIST"
      /usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon dict" "$PLIST"
      # ... etc
```

### Option 2: Fastlane Plugin (update_info_plist)
Use Fastlane's plist manipulation to force-add keys:

```ruby
update_info_plist(
  plist_path: "path/to/Info.plist",
  block: proc do |plist|
    plist["CFBundleIcons"] = { /* structure */ }
  end
)
```

### Option 3: Abandon Template, Remove Properties, Rely on Build Settings Only
Remove `info:` block entirely, rely only on:
```yaml
settings:
  base:
    ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

**Risk:** May lose other custom Info.plist entries

### Option 4: Abandon XcodeGen (Nuclear Option)
Return to manual .xcodeproj management with CocoaPods.

## Key Learnings

1. **XcodeGen's info.properties does NOT reliably merge complex nested dictionaries** when used with path
2. **App Store validation errors can occur even when build succeeds** - final bundle matters
3. **IPA inspection is critical** - need to verify actual bundle contents, not just build logs
4. **No-Mac debugging requires extensive CI logging** - gym logs, IPA inspection, plist validation
5. **Template + properties merge behavior is unpredictable** for complex structures

## Open Questions

1. Does XcodeGen officially support nested dictionaries in info.properties?
2. Is there a YAML syntax that makes dictionary merging work?
3. Should we use `INFOPLIST_FILE` build setting to ensure plist inclusion?
4. Is this a known XcodeGen bug with CFBundleIcons specifically?

## Status: AWAITING NEXT APPROACH

**Current State:**
- ❌ Project broken (no `path:` in info block)
- ❌ 15+ build attempts, all failed App Store validation
- ✅ Diagnostics in place (gym log, IPA inspection)
- ⏳ Waiting for ChatGPT consultation result

**Next Steps:**
1. Get ChatGPT recommendation
2. Test recommended approach
3. Verify CFBundleIcons in final IPA bundle via inspection step
4. Document final solution

## References

- XcodeGen docs: https://github.com/yonaskolb/XcodeGen
- Apple Info.plist keys: https://developer.apple.com/documentation/bundleresources/information_property_list
- Fastlane Match: https://docs.fastlane.tools/actions/match/
- GitHub Actions workflow: `.github/workflows/ios-build-upload.yml`

---

**Last Updated:** 2025-11-13
**Build ID:** 19319705338 (XcodeGen parse error - no path)
**Previous Working Build:** 19286305646 (2 days ago)
