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

### Attempt 18: SOLUTION - Exclude Asset Catalog from Sources
**Date:** 2025-11-14
**Action:** Implemented ChatGPT's expert guidance

**Root Cause Identified by ChatGPT:**
Asset catalog must be ONLY referenced as a resource, never as a source. The issue was that we were using individual source paths, which didn't explicitly exclude the asset catalog.

### Attempt 15-16 (Build 19353731166): actool still missing

```yaml
sources:
  - path: SkyFeederFieldUtility
    excludes:
      - Resources/Assets.xcassets/**
      - Support/Configurations/**
      - Support/Info.plist
      - Tests/**

resources:
  - path: SkyFeederFieldUtility/Resources/Assets.xcassets
```

**Result:** ❌ Still FAILED. CI artifact inspection shows no `Assets.car` or icon PNGs in `Payload/*.app`. `actool` does not appear anywhere in `gym` logs, confirming that excluding the catalog from `sources` prevents Xcode from compiling it.

**Current Fix (Implemented):**
1. Remove `Resources/Assets.xcassets/**` from the `sources.excludes` list.
2. Remove the redundant `resources:` entry.
3. Regenerate the project so the asset catalog once again lives under `Compile Sources` and triggers `actool`.

**What to watch for on the next build:**
- `gym` log should include a line similar to `CompileAssetCatalog ... Assets.xcassets`.
- `Inspect IPA bundle ...` step should list `Assets.car` plus `*.png` references.
- App Store validation should no longer fail for missing icons.

### Active Investigation Hypotheses
1. **Asset catalog excluded from sources** – confirmed as the main reason actool never runs.
2. **resources-only catalogs do not compile** – placing `.xcassets` in `resources` copies raw files without producing `Assets.car`.
3. **Stale generated project** – always run `xcodegen generate` after editing `project.yml` to keep build phases in sync.
4. **Copy phase removed by other target** – ensure no scripts remove `Resources` before packaging.
5. **CI cache interference** – if actool still doesn’t run after config change, wipe DerivedData and rerun.

### Attempt 20: ✅ SUCCESS - Asset Catalog Compilation Fixed (Build 19353887383)
**Date:** 2025-11-14
**Action:** Removed asset catalog from excludes list AND removed resources override (reversed incorrect ChatGPT guidance)

**CHANGES MADE (mobile/ios-field-utility/project.yml lines 33-38):**

1. **REMOVED** `Resources/Assets.xcassets/**` from the sources.excludes list
2. **DELETED** the entire `resources:` section that referenced Assets.xcassets
3. This forces XcodeGen to place the catalog back into "Compile Sources" build phase where actool runs

**BEFORE (BROKEN - Attempt 18-19):**
```yaml
sources:
  - path: SkyFeederFieldUtility
    excludes:
      - Resources/Assets.xcassets/**  # ❌ WRONG - prevents actool
      - Support/Configurations/**
      - Support/Info.plist
      - Tests/**

resources:  # ❌ WRONG - copies raw files without compilation
  - path: SkyFeederFieldUtility/Resources/Assets.xcassets
```

**AFTER (WORKING - Attempt 20):**
```yaml
sources:
  - path: SkyFeederFieldUtility
    excludes:
      - Support/Configurations/**
      - Support/Info.plist
      - Tests/**
      # ✅ Assets.xcassets NOT excluded - it MUST be compiled as a source!
      # ✅ NO resources: section - let XcodeGen handle asset catalog in sources
```

**Build Result:** ✅ **SUCCESS!**

**Verification:**
```
✅ Assets.car present in bundle: /Payload/SkyFeederFieldUtility.app/Assets.car
✅ TestFlight upload successful: "Successfully uploaded package to App Store Connect"
✅ NO App Store validation errors (all 3 icon errors resolved)
```

**Root Cause - FINAL ANSWER:**

Asset catalogs (.xcassets) **MUST be compiled as sources**, NOT excluded from sources and NOT placed only in resources.

**Why This Fix Works:**

**actool only compiles .xcassets that appear in the target's Sources build phase.** By excluding the catalog and re-adding it as a plain resource, we were copying the folder raw, so no Assets.car or PNGs ever made it into the .app. Restoring the catalog to sources reinstates actool, which produces Assets.car and satisfies App Store icon checks.

**Step-by-step:**
1. XcodeGen places files from `sources:` into the "Compile Sources" build phase
2. Only files in "Compile Sources" trigger the asset catalog compiler (actool)
3. actool generates Assets.car from the .xcassets folder
4. Excluding .xcassets from sources prevents actool from ever running
5. Placing .xcassets only in `resources:` copies raw files without compilation (no Assets.car generated)

**Why ChatGPT's Guidance Was Wrong:**

ChatGPT advised to exclude asset catalog from sources and add only to resources. This is **incorrect for iOS asset catalogs**:
- ❌ Excluding from sources: Prevents actool compilation
- ❌ Resources-only: Copies raw files, doesn't compile Assets.car
- ✅ Correct approach: Include in sources (don't exclude), let XcodeGen handle it

**Build Statistics:**
- **Total failed attempts:** 19 builds over 2 days
- **Successful build:** Build 19353887383 (Attempt 20)
- **App version:** 0.1.0 (Build 3)
- **Previous TestFlight version:** Build 2
- **Resolution time:** ~2 days of debugging

**Key Lessons Learned:**

1. **Asset catalogs are sources, not resources** - They must be compiled, not just copied
2. **XcodeGen handles .xcassets automatically** - No special configuration needed beyond including them in sources
3. **Diagnostic tools are critical** - IPA inspection revealed Assets.car was missing, not Info.plist issues
4. **External AI guidance can be wrong** - ChatGPT's advice to exclude from sources was fundamentally incorrect
5. **CI-only debugging is viable** - Solved entirely via GitHub Actions logs without local Mac access

**What to Do Next (Implementation Checklist):**

If applying this fix to a similar project:

1. **Update project.yml:**
   - Remove `Resources/Assets.xcassets/**` from sources.excludes
   - Delete any `resources:` section referencing Assets.xcassets

2. **Regenerate Xcode project:**
   ```bash
   cd mobile/ios-field-utility
   xcodegen generate
   ```
   (Or let CI's "Generate Xcode project" step do it)

3. **Verify in build logs:**
   - Look for `CompileAssetCatalog ... Assets.xcassets` in gym/xcodebuild output
   - Confirms actool is running

4. **Verify in IPA bundle:**
   - In "Inspect IPA..." step, check for `Assets.car` inside `Payload/*.app/`
   - Confirms asset catalog was compiled and included

5. **Commit and push:**
   ```bash
   git add mobile/ios-field-utility/project.yml
   git commit -m "Restore asset catalog to sources so actool runs"
   git push
   ```

**If It Still Fails, Investigate (in order):**

1. Asset catalog excluded elsewhere (search for other excludes entries)
2. `resources:` entry reintroduced by merge (ensure only sources references catalog)
3. Stale generated project (rerun `xcodegen generate`, clean DerivedData)
4. Custom script removing Resources/* before packaging
5. CI cache/DerivedData corruption (wipe cache, rerun)

Once you see actool in build logs and Assets.car in the IPA, TestFlight icon errors will disappear.

## Final Working Configuration

**project.yml (Working):**
```yaml
targets:
  SkyFeederFieldUtility:
    type: application
    platform: iOS

    settings:
      base:
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        # ... other settings

    sources:
      - path: SkyFeederFieldUtility
        excludes:
          - Support/Configurations/**
          - Support/Info.plist
          - Tests/**
          # Assets.xcassets NOT excluded - critical!

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

**What XcodeGen Does:**
1. Includes `SkyFeederFieldUtility/Resources/Assets.xcassets` in Compile Sources
2. Xcode runs actool during build
3. actool generates Assets.car from Contents.json
4. Assets.car is included in final .app bundle
5. App Store validation passes

## Status: ✅ RESOLVED

**Problem:** iOS TestFlight upload failures due to missing app icons after XcodeGen migration

**Root Cause:** Asset catalog excluded from sources prevented actool compilation

**Solution:** Don't exclude Assets.xcassets from sources - let XcodeGen include it normally

**Verification:** Build 19353887383 successfully uploaded to TestFlight with no validation errors

## References

- XcodeGen docs: https://github.com/yonaskolb/XcodeGen
- Apple Info.plist keys: https://developer.apple.com/documentation/bundleresources/information_property_list
- Asset Catalog compilation: https://developer.apple.com/documentation/xcode/managing-assets-with-asset-catalogs
- Fastlane Match: https://docs.fastlane.tools/actions/match/
- GitHub Actions workflow: `.github/workflows/ios-build-upload.yml`
- Successful Build: https://github.com/artiebot/Codex_Vs_Code/actions/runs/19353887383

---

**Last Updated:** 2025-11-14
**Status:** ✅ RESOLVED
**Successful Build:** 19353887383
**App Version:** 0.1.0 (Build 3)
**TestFlight:** Successfully uploaded
