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

### Attempt 16: CRITICAL DISCOVERY - Asset Catalog Missing (Build 19353348238)
**Date:** 2025-11-14
**Action:** Restored `path:` field, committed troubleshooting documentation, monitored build

**Build Result:** ❌ FAILED App Store validation with same 3 errors

**BREAKTHROUGH FINDING:**

**IPA Inspection revealed:**
```
✅ CFBundleIconName = AppIcon (PRESENT in bundle)
✅ CFBundleIcons = Dict { CFBundlePrimaryIcon = Dict { CFBundleIconFiles = Array { AppIcon }, UIPrerenderedIcon = false } } (PRESENT)
✅ CFBundleIcons~ipad = Dict { CFBundlePrimaryIcon = Dict { CFBundleIconFiles = Array { AppIcon }, UIPrerenderedIcon = false } } (PRESENT)
❌ Top-level image assets: EMPTY - No PNG files, No Assets.car file
```

**ROOT CAUSE IDENTIFIED:**

The problem is NOT with Info.plist merging. The Info.plist keys ARE correctly present in the final bundle.

**THE REAL PROBLEM: The asset catalog (Assets.xcassets) is NOT being compiled or included in the final .app bundle.**

The bundle should contain either:
1. Individual PNG files (AppIcon60x60@2x.png, AppIcon76x76@2x.png, etc.) OR
2. A compiled Assets.car file

But the bundle contains NEITHER. The asset catalog is completely missing from the build output.

**Evidence:**
```bash
# Expected in bundle:
/Payload/SkyFeederFieldUtility.app/Assets.car  # Compiled asset catalog
# OR individual PNG files

# Actual result:
(empty - no asset files at all)
```

**Why App Store validation fails:**
- Info.plist correctly references "AppIcon" via CFBundleIconName
- Info.plist correctly declares CFBundleIcons structure
- BUT the actual icon assets referenced by "AppIcon" don't exist in the bundle
- Apple looks for 120×120 and 152×152 icon files but finds nothing

**Key Insight:**
Previous hypothesis about XcodeGen Info.plist merging was WRONG. XcodeGen IS correctly generating Info.plist with all required keys. The actual issue is asset catalog compilation/inclusion failing silently.

## Updated Root Cause Analysis

**The problem is asset catalog compilation, not Info.plist configuration.**

**Possible causes:**
1. ASSETCATALOG_COMPILER_APPICON_NAME not being read during compilation
2. Assets.xcassets path not registered correctly with XcodeGen
3. Asset catalog compilation step silently failing in xcodebuild
4. Build settings preventing asset catalog from being copied to bundle
5. File references in generated .xcodeproj missing asset catalog

**What we know:**
- ✅ Asset catalog files exist in source (verified in git)
- ✅ Contents.json has correct structure
- ✅ Info.plist correctly references "AppIcon"
- ❌ Asset catalog never makes it into final .app bundle
- ❌ No PNG files, no Assets.car in bundle

### Attempt 17: FIX APPLIED - Explicit Asset Catalog Reference
**Date:** 2025-11-14
**Action:** Following ChatGPT's guidance to fix asset catalog inclusion

**Changes Made:**

1. **Verified PNG Icons in png/ folder:**
   - icon-1024.png: 1024×1024 ✅
   - icon-60@2x.png: 120×120 ✅
   - icon-60@3x.png: 180×180 ✅
   - icon-76@2x.png: 152×152 ✅
   - icon-83.5@2x.png: 167×167 ✅

2. **Copied fresh PNGs to AppIcon.appiconset:**
   - All icon files copied from png/ folder to asset catalog
   - Verified all have correct dimensions matching expected sizes

3. **Verified Contents.json structure:**
   ```json
   {
     "images": [
       {"size": "60x60", "idiom": "iphone", "scale": "2x", "filename": "icon-60@2x.png"},
       {"size": "60x60", "idiom": "iphone", "scale": "3x", "filename": "icon-60@3x.png"},
       {"size": "76x76", "idiom": "ipad", "scale": "2x", "filename": "icon-76@2x.png"},
       {"size": "83.5x83.5", "idiom": "ipad", "scale": "2x", "filename": "icon-83.5@2x.png"},
       {"size": "1024x1024", "idiom": "ios-marketing", "scale": "1x", "filename": "icon-1024.png"}
     ]
   }
   ```

4. **CRITICAL FIX - Made asset catalog reference explicit in project.yml:**
   ```yaml
   # Changed from:
   resources:
     - path: SkyFeederFieldUtility/Resources

   # To:
   resources:
     - path: SkyFeederFieldUtility/Resources/Assets.xcassets
   ```

**Root Cause:**
XcodeGen was not properly including the asset catalog because the resources path was too broad (`SkyFeederFieldUtility/Resources`). By explicitly referencing `SkyFeederFieldUtility/Resources/Assets.xcassets`, XcodeGen should now properly include the asset catalog in the generated .xcodeproj.

**Expected Result:**
Asset catalog should now be compiled and included in the final .app bundle, providing the required icon files for App Store validation.

**Build Result (Build 19353547521):** ❌ FAILED - Asset catalog still missing

**Evidence:**
- IPA inspection: No PNG files, no Assets.car in bundle
- Build log analysis: NO "actool" (asset catalog compiler) execution found
- Conclusion: XcodeGen is NOT including Assets.xcassets in generated .xcodeproj

**Attempted fix DID NOT WORK.** Explicit path to Assets.xcassets did not cause XcodeGen to include it.

## Status: BLOCKED - Need XcodeGen Expert Guidance

**Current State:**
- ✅ Info.plist generation WORKING correctly (all keys present)
- ✅ Asset catalog files verified (all PNGs correct dimensions)
- ✅ Contents.json verified (correct structure)
- ❌ Attempt 1: Broad resources path (`SkyFeederFieldUtility/Resources`) - FAILED
- ❌ Attempt 2: Explicit asset catalog path (`SkyFeederFieldUtility/Resources/Assets.xcassets`) - FAILED
- ❌ XcodeGen NOT including asset catalog in generated .xcodeproj
- ❌ Asset catalog NOT being compiled (no actool in build logs)
- ❌ 17 build attempts, all failed App Store validation

**Core Issue:**
XcodeGen is not generating the correct .xcodeproj configuration to include the Assets.xcassets folder, regardless of how it's referenced in the resources section. The asset catalog compiler (actool) never runs during the build.

**Questions for ChatGPT:**
1. What is the correct YAML syntax in XcodeGen 2.37.0 to include an Assets.xcassets asset catalog?
2. Should asset catalogs be in `resources:` or `sources:` section?
3. Does XcodeGen require a specific file type or option for asset catalogs?
4. Is there a known bug in XcodeGen 2.37.0 with asset catalog inclusion?
5. Should we check the generated .xcodeproj to verify if Assets.xcassets is referenced?

## Prompt for ChatGPT

```
I'm debugging an iOS build issue with XcodeGen 2.37.0. After migrating from manual .xcodeproj to XcodeGen, app builds succeed but App Store validation fails because the asset catalog is completely missing from the final .app bundle.

VERIFIED FACTS:
✅ Asset catalog exists at: mobile/ios-field-utility/SkyFeederFieldUtility/Resources/Assets.xcassets/AppIcon.appiconset/
✅ All PNG icons verified (120x120, 180x180, 152x152, 167x167, 1024x1024)
✅ Contents.json has correct structure with all required iOS icon sizes
✅ Info.plist correctly includes CFBundleIconName, CFBundleIcons, CFBundleIcons~ipad
✅ Build setting: ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
❌ Final .app bundle contains NO PNG files and NO Assets.car file
❌ Build logs show NO "actool" (asset catalog compiler) execution
❌ XcodeGen is NOT including Assets.xcassets in generated .xcodeproj

PROJECT.YML ATTEMPTS:
Attempt 1 (FAILED):
resources:
  - path: SkyFeederFieldUtility/Resources

Attempt 2 (FAILED):
resources:
  - path: SkyFeederFieldUtility/Resources/Assets.xcassets

QUESTION:
What is the correct XcodeGen 2.37.0 YAML syntax to properly include an Assets.xcassets asset catalog so that:
1. It's included in the generated .xcodeproj
2. The actool compiler runs during build
3. Assets.car appears in the final bundle

Please provide the exact YAML configuration needed in the resources or sources section of project.yml.
```

## References

- XcodeGen docs: https://github.com/yonaskolb/XcodeGen
- Apple Info.plist keys: https://developer.apple.com/documentation/bundleresources/information_property_list
- Asset Catalog compilation: https://developer.apple.com/documentation/xcode/managing-assets-with-asset-catalogs
- Fastlane Match: https://docs.fastlane.tools/actions/match/
- GitHub Actions workflow: `.github/workflows/ios-build-upload.yml`

---

**Last Updated:** 2025-11-14
**Build ID:** 19353547521 (FAILED - Asset catalog still missing, actool never runs)
**Attempts:** 17 builds, all failed App Store validation
