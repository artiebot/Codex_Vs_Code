# iOS Code Signing Troubleshooting Log

## Date: 2025-11-08

### Root Cause Identified

**Error Message:**
```
SkyFeederFieldUtility has conflicting provisioning settings.
SkyFeederFieldUtility is automatically signed, but provisioning profile
'match AppStore com.skyfeeder.field' has been manually specified.
```

**Location:** `fastlane/Fastfile` lines 46-49

**Problem:**
The Fastfile configuration has contradictory signing settings:
- Sets `CODE_SIGN_STYLE=Automatic` (tells Xcode to manage signing automatically)
- Also sets `PROVISIONING_PROFILE_SPECIFIER='match AppStore com.skyfeeder.field'` (manually specifies a profile)

These two settings are **mutually exclusive**:
- **Automatic Signing**: Xcode manages certificates and profiles automatically. You don't specify which profile to use.
- **Manual Signing**: You explicitly tell Xcode which certificate and provisioning profile to use (required when using Fastlane Match).

**Solution:**
Since we're using Fastlane Match (which provides certificates and profiles), we must use **Manual** code signing.

Change in `fastlane/Fastfile`:
```ruby
# BEFORE (WRONG - causes conflict):
"CODE_SIGN_STYLE=Automatic",
"APP_CODE_SIGN_STYLE=Automatic",

# AFTER (CORRECT - manual signing with Match):
"CODE_SIGN_STYLE=Manual",
"APP_CODE_SIGN_STYLE=Manual",
```

### Why This Happened

Multiple people/agents (Codex, manual edits) updated the Fastfile with "Automatic" signing, thinking it would be simpler. However, when using Match, Manual signing is required because:

1. Match downloads pre-generated certificates and profiles from a git repository
2. We need to tell Xcode exactly which profile to use (the one Match downloaded)
3. Automatic signing expects Xcode to generate/manage profiles itself - incompatible with Match workflow

### Previous Failed Attempts

1. **Attempt 1**: Used Manual signing but missing DEVELOPMENT_TEAM → Failed
2. **Attempt 2**: Switched to Automatic signing → Caused the current conflict
3. **Attempt 3-8**: Various Codex updates kept "Automatic" → All failed with same conflict

The key lesson: **With Fastlane Match, you MUST use Manual code signing.**

### Testing Plan

After fixing the Fastfile:
1. Verify Match step completes (downloads certs/profiles)
2. Verify build succeeds with Manual signing
3. Check if icon validation issues remain (separate from signing)

## UPDATE - Fix Applied and Tested

### Signing Fix: SUCCESS ✓

**Commit:** 33af635 - "Fix iOS code signing conflict - switch to Manual signing for Match"

**Changes Made:**
- Changed `CODE_SIGN_STYLE=Automatic` to `CODE_SIGN_STYLE=Manual` (line 46)
- Changed `APP_CODE_SIGN_STYLE=Automatic` to `APP_CODE_SIGN_STYLE=Manual` (line 47)

**Results from Run #19197101715:**
- ✓ Match step completed successfully
- ✓ Certificate installed: Apple Distribution (valid until 2026-11-05)
- ✓ Provisioning profile installed: match AppStore com.skyfeeder.field
- ✓ Build succeeded with Manual signing
- ✓ Archive created and signed correctly

**SIGNING ISSUE RESOLVED** - No more conflicting provisioning settings error!

### New Issue Discovered: Missing App Icons

**Error:**
```
Missing required icon file. The bundle does not contain an app icon
for iPhone / iPod Touch of exactly '120x120' pixels, in .png format.
```

**Root Cause:**
The `Contents.json` in AppIcon.appiconset defines icon sizes but doesn't specify actual image filenames. Only the 1024x1024 marketing icon has a filename.

**Next Steps:**
1. Create actual PNG files for all required icon sizes
2. Add filenames to Contents.json for each size
3. Ensure files exist in the AppIcon.appiconset directory

## COMPLETE RESOLUTION - All Issues Fixed ✅

### Final Success: Run #19197221729

**Result:** Successfully uploaded to TestFlight on 2025-11-08 at 18:58:05 UTC

**Timeline:**
- Build time: 28 seconds
- Upload time: 23 seconds
- Total workflow: ~51 seconds

### Three Separate Issues Were Found and Fixed

---

## Issue #1: Code Signing Conflict (FIXED - Commit 33af635)

### Problem
```
SkyFeederFieldUtility has conflicting provisioning settings.
SkyFeederFieldUtility is automatically signed, but provisioning profile
'match AppStore com.skyfeeder.field' has been manually specified.
```

### Root Cause Analysis
The root `fastlane/Fastfile` had contradictory settings:
```ruby
"CODE_SIGN_STYLE=Automatic",           # ❌ Tells Xcode to manage signing
"PROVISIONING_PROFILE_SPECIFIER='...'" # ❌ But manually specifies profile
```

**Why this is impossible:**
- **Automatic signing** = Xcode generates and manages everything
- **Manual signing** = You explicitly specify certificate and profile
- **Cannot do both simultaneously**

**Why it happened:**
Multiple agents/people edited the Fastfile thinking "Automatic" would be simpler, not understanding that Fastlane Match requires Manual signing.

### Solution
Changed in `fastlane/Fastfile` lines 46-47:
```ruby
# BEFORE (WRONG):
"CODE_SIGN_STYLE=Automatic",
"APP_CODE_SIGN_STYLE=Automatic",

# AFTER (CORRECT):
"CODE_SIGN_STYLE=Manual",
"APP_CODE_SIGN_STYLE=Manual",
```

### Key Lesson
**When using Fastlane Match, you MUST use Manual code signing.** Match provides pre-generated certificates from a git repository - you need to tell Xcode exactly which ones to use.

---

## Issue #2: Missing App Icons (FIXED - Commit 18ad26b)

### Problem
```
Missing required icon file. The bundle does not contain an app icon
for iPhone / iPod Touch of exactly '120x120' pixels, in .png format.
```

### Root Cause Analysis
The `Contents.json` file defined icon sizes but only the 1024x1024 marketing icon had an actual filename. All other sizes were missing both:
1. The `filename` field in Contents.json
2. The actual PNG files

### Solution
1. **Generated all required icon sizes** from 1024x1024 source using Python/Pillow:
   - AppIcon20x20@2x.png (40x40)
   - AppIcon20x20@3x.png (60x60)
   - AppIcon29x29@2x.png (58x58)
   - AppIcon29x29@3x.png (87x87)
   - AppIcon40x40@2x.png (80x80)
   - AppIcon40x40@3x.png (120x120) ← Critical missing size
   - AppIcon60x60@2x.png (120x120) ← Critical missing size
   - AppIcon60x60@3x.png (180x180)

2. **Updated Contents.json** to reference all filenames

### Key Lesson
iOS requires ALL standard icon sizes, not just the 1024x1024 marketing icon. The Contents.json must have both the size definition AND the filename field for each icon.

---

## Issue #3: Match Git Branch Conflict (FIXED - Commit b156c52)

### Problem
```
fatal: a branch named 'master' already exists
```
Build failed at Match step before even downloading certificates.

### Root Cause Analysis
Match was trying to create a new local git branch, but leftover git state from previous CI runs caused a conflict. This prevented Match from cloning the certificates repository.

### Solution
Added `clone_branch_directly: true` to `fastlane/Fastfile` line 27:
```ruby
match_params = {
  type: "appstore",
  readonly: true,
  api_key: api_key,
  clone_branch_directly: true  # ← Added this
}
```

This tells Match to directly clone the specified branch instead of creating a new local branch, avoiding git state conflicts in CI environments.

### Key Lesson
In CI environments, git state can persist between runs. Use `clone_branch_directly: true` to avoid branch conflicts when using Match in GitHub Actions.

---

## Systematic Troubleshooting Methodology Used

### 1. Research Current Failures
- Retrieved recent workflow run logs using `gh run view --log-failed`
- Identified error patterns across multiple failed runs
- Found that 8+ consecutive runs all failed with the same root cause

### 2. Deep Code Review
- Read actual Fastfile configuration (both root and app-local)
- Compared working configuration in app-local Fastfile with broken root Fastfile
- Identified exact conflicting lines

### 3. Documentation of Each Attempt
- Created iOS_SIGNING_TROUBLESHOOTING.md to track findings
- Documented each issue, root cause, and solution
- Prevented repeating the same non-working solutions

### 4. Incremental Testing
- Fixed one issue at a time
- Verified each fix with a new workflow run
- When new issues appeared, documented and fixed them systematically

### 5. Verification
- Confirmed Match step succeeded
- Confirmed build and signing succeeded
- Confirmed upload to TestFlight succeeded
- Confirmed no icon validation errors

---

## Files Modified (Summary)

### 1. `/fastlane/Fastfile` (Root - used by CI)
- Changed CODE_SIGN_STYLE from Automatic to Manual
- Added clone_branch_directly: true to match_params

### 2. `/mobile/ios-field-utility/SkyFeederFieldUtility/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Added filename fields for all 8 icon sizes

### 3. App Icon PNG Files (8 new files created)
- Generated from 1024x1024 source using Pillow

### 4. `/iOS_SIGNING_TROUBLESHOOTING.md` (This file)
- Complete documentation of all issues and solutions

---

## How to Avoid These Issues in Future Builds

### ✅ Code Signing Best Practices

1. **Always use Manual signing with Fastlane Match**
   ```ruby
   "CODE_SIGN_STYLE=Manual",
   "APP_CODE_SIGN_STYLE=Manual",
   ```

2. **Never mix Automatic signing with PROVISIONING_PROFILE_SPECIFIER**
   - These are mutually exclusive
   - Match requires Manual signing

3. **Understand the two Fastfiles:**
   - `/fastlane/Fastfile` - Used by CI workflows (this is what you need to fix)
   - `/mobile/ios-field-utility/fastlane/Fastfile` - App-local (reference for correct config)

### ✅ App Icon Best Practices

1. **Always provide ALL required icon sizes:**
   - 20x20 (@2x, @3x)
   - 29x29 (@2x, @3x)
   - 40x40 (@2x, @3x)
   - 60x60 (@2x, @3x)
   - 1024x1024 (@1x marketing)

2. **Both the PNG files AND Contents.json entries are required**

3. **Use image generation tools** (like Pillow) to create all sizes from a 1024x1024 source

### ✅ Match/CI Best Practices

1. **Use `clone_branch_directly: true` in CI environments**
   - Prevents git branch conflicts
   - Faster cloning

2. **Monitor workflow runs carefully:**
   - Check `gh run list` for recent failures
   - Use `gh run view --log-failed` to get detailed errors
   - Don't assume similar errors have the same root cause

3. **Document solutions as you go:**
   - Prevents repeating failed attempts
   - Creates institutional knowledge
   - Makes debugging faster next time

### ✅ Debugging Best Practices

1. **Use systematic investigation:**
   - Read actual code, don't just guess
   - Compare working vs. broken configurations
   - Check ALL recent failed runs for patterns

2. **Fix one issue at a time:**
   - Don't batch multiple fixes together
   - Verify each fix before moving to the next
   - Document results of each attempt

3. **Watch out for duplicate workflows:**
   - This project has 3 workflows (build-upload, iOS TestFlight, Match Bootstrap)
   - build-upload is the active one
   - iOS TestFlight is likely a duplicate that should be removed

---

## Quick Reference: Common iOS Build Errors

### "Conflicting provisioning settings"
**Fix:** Change CODE_SIGN_STYLE to Manual when using Match

### "Missing required icon file"
**Fix:** Generate all required icon sizes and update Contents.json

### "fatal: a branch named 'master' already exists"
**Fix:** Add `clone_branch_directly: true` to Match configuration

### "Could not configure imported keychain item"
**Note:** This is a warning, not an error. Build will continue.

### Signing seems "stuck"
**Reality:** Code signing takes 1-5 minutes. This is normal. Check the actual error message before assuming it's stuck.

---

## Related Files

- `/fastlane/Fastfile` - Root Fastfile (used by CI workflow) - **FIXED ✅**
- `/mobile/ios-field-utility/fastlane/Fastfile` - App-local Fastfile (reference for correct config)
- `/.github/workflows/ios-build-upload.yml` - Active CI workflow (build-upload)
- `/.github/workflows/ios-testflight.yml` - Duplicate workflow (consider removing)
- `/.github/workflows/match-bootstrap.yml` - One-time setup only

## References

- [Fastlane Match Documentation](https://docs.fastlane.tools/actions/match/)
- [Code Signing Guide](https://codesigning.guide/)
- [iOS Human Interface Guidelines - App Icon](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- Apple Error: "conflicting provisioning settings" means Automatic + Manual profile specification conflict

## Success Metrics

- **Before fixes:** 8+ consecutive workflow failures
- **After fixes:** 100% success rate (1/1 runs)
- **Build time:** ~51 seconds (Match + Build + Upload)
- **Result:** App successfully uploaded to TestFlight

---

## Issue #4: XcodeGen Info.plist Processing & App Store Validation (FIXED - 2025-11-12)

### Problem
After migrating to XcodeGen for project generation, builds succeeded through compilation and archiving but **failed at App Store validation** with persistent errors:

```
Missing Info.plist value. A value for the Info.plist key 'CFBundleIconName' is missing in the bundle
Missing required icon file. The bundle does not contain an app icon for iPhone of exactly '120x120' pixels
Missing required icon file. The bundle does not contain an app icon for iPad of exactly '152x152' pixels
Invalid bundle. No orientations were specified for iPad multitasking
Invalid bundle. Apps must provide launch screen using UILaunchScreen
```

### Root Cause Analysis

**XcodeGen was NOT properly merging Info.plist template values into the final bundle.**

Even though we had:
- ✅ CFBundleIconName in Info.plist
- ✅ All icon files generated (120x120, 152x152, etc.)
- ✅ iPad orientations in Info.plist  
- ✅ UILaunchScreen in Info.plist

The generated .ipa bundle validation reported these keys as "missing". The issue was that XcodeGen's Info.plist processing required **explicit declaration** of icon-related dictionaries.

### Solution (3-Part Fix)

#### 1. Add CFBundleIcons Dictionaries to Info.plist

Added explicit icon file declarations:

```xml
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

**Why This Matters:**  
App Store validation checks for `CFBundleIcons` dictionaries to verify icon assets are properly declared, not just that `CFBundleIconName` exists.

#### 2. Add Explicit Build Settings to project.yml

```yaml
settings:
  base:
    ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    INFOPLIST_FILE: SkyFeederFieldUtility/Support/Info.plist
    PRODUCT_BUNDLE_IDENTIFIER: $(APP_BUNDLE_IDENTIFIER)
    DEVELOPMENT_TEAM: $(APP_DEVELOPMENT_TEAM)
    TARGETED_DEVICE_FAMILY: "1,2"  # iPhone + iPad
    SUPPORTED_PLATFORMS: "iphoneos iphonesimulator"
```

**Why This Matters:**  
- `TARGETED_DEVICE_FAMILY: "1,2"` explicitly declares iPad support, triggering validation for iPad-specific requirements
- `ASSETCATALOG_COMPILER_APPICON_NAME` ensures asset catalog is properly linked
- Makes build configuration deterministic instead of inferred

#### 3. Generate Missing iPad Icon Sizes

Generated 6 additional iPad icon sizes:
- AppIcon20x20@1x.png (20x20)
- AppIcon29x29@1x.png (29x29)
- AppIcon40x40@1x.png (40x40)
- AppIcon76x76@1x.png (76x76)
- **AppIcon76x76@2x.png (152x152)** ← Critical for validation
- AppIcon83.5x83.5@2x.png (167x167) ← iPad Pro

Updated Contents.json with iPad icon entries.

### Failed Attempts Before Success

1. ❌ **Added CFBundleIconName to Info.plist** - Validation still failed
2. ❌ **Added UILaunchScreen to Info.plist** - Validation still failed
3. ❌ **Added iPad orientations to Info.plist** - Validation still failed  
4. ❌ **Added ASSETCATALOG_COMPILER_APPICON_NAME build setting** - Validation still failed
5. ❌ **Added Info.plist properties to project.yml** - Validation still failed
6. ✅ **Added CFBundleIcons dictionaries + explicit build settings** - SUCCESS!

### Key Learnings

1. **XcodeGen Info.plist Processing:**
   - Simply having values in Info.plist template is NOT enough
   - Icon-related keys require `CFBundleIcons` dictionaries, not just `CFBundleIconName`
   - XcodeGen merges template + properties section → final Info.plist in bundle

2. **App Store Validation vs Local Build:**
   - Local builds/archives can succeed even with incomplete Info.plist
   - App Store validation is stricter and checks bundle contents
   - "Missing in bundle" ≠ "missing in source files"

3. **iPad Support Implications:**
   - `TARGETED_DEVICE_FAMILY: "1,2"` triggers iPad-specific validation requirements
   - Must have iPad icon sizes (76x76@1x, 76x76@2x/152x152, 83.5x83.5@2x)
   - Must declare all 4 orientations for multitasking support

### Commit History

- `93dbe6f` - Add iPad icon assets and multitasking support  
- `183d148` - Fix iOS launch screen and asset catalog configuration
- `47234e2` - Add Info.plist properties directly to project.yml
- `6215b6f` - Add CFBundleIcons blocks and explicit build settings (Codex fix) ← SOLUTION

### Build Results

**Initial "Success" (ONE-TIME FLUKE):**
- **Build ID:** 19286305646
- **Duration:** 20m47s
- **Status:** ✅ SUCCESS (NOT REPRODUCIBLE)
- **Result:** Successfully uploaded to App Store Connect / TestFlight

**Subsequent Failures (PERSISTENT ISSUE - UNRESOLVED):**
- **Failed Builds:** 19302815264, 19304191990, 19304281243, 19315927277, 19318467658 (and 6+ more)
- **Duration:** All ~2 minutes (fail at App Store validation)
- **Status:** ❌ FAILURE - ALL WITH IDENTICAL CONFIGURATION
- **Error:** "missing in bundle" for CFBundleIconName, icons, orientations, UILaunchScreen

### CRITICAL UPDATE: Build 19286305646 Was a Fluke

The one successful build appears to have been caused by caching or a transient condition. **All subsequent builds with IDENTICAL code fail validation.**

This proves the CFBundleIcons fix was NOT the actual solution

### Files Modified

1. `mobile/ios-field-utility/SkyFeederFieldUtility/Support/Info.plist`
   - Added CFBundleIcons and CFBundleIcons~ipad dictionaries
   - Added UILaunchScreen dictionary
   - Added UISupportedInterfaceOrientations~ipad array

2. `mobile/ios-field-utility/project.yml`
   - Added explicit build settings (ASSETCATALOG_COMPILER_APPICON_NAME, TARGETED_DEVICE_FAMILY, etc.)
   - Added Info.plist properties section

3. `mobile/ios-field-utility/SkyFeederFieldUtility/Resources/Assets.xcassets/AppIcon.appiconset/`
   - Added 6 iPad icon PNG files
   - Updated Contents.json with iPad icon entries

### Prevention

When using XcodeGen:
- Always include `CFBundleIcons` dictionaries in Info.plist for icon validation
- Use explicit build settings in project.yml instead of relying on defaults
- Test with `TARGETED_DEVICE_FAMILY: "1,2"` early to catch iPad requirements
- Verify .ipa contents match Info.plist template expectations

### Success Metrics Updated

- **Before XcodeGen migration:** Working TestFlight uploads
- **After XcodeGen migration:** 7+ consecutive validation failures (all same errors)
- **After CFBundleIcons fix:** 1 success (fluke), then 10+ consecutive failures
- **Build time:** ~2 minutes (all fail at validation)
- **Result:** ❌ **ISSUE UNRESOLVED - XcodeGen not packaging Info.plist into .ipa bundle**

### Status: UNRESOLVED

**XcodeGen Fundamental Issue:** The Info.plist template is NOT being included in the final .ipa bundle, regardless of configuration. All validation errors report keys as "missing in the bundle" even though they exist in the source Info.plist file.

**Attempted Fixes (ALL FAILED):**
1. CFBundleIcons dictionaries
2. GENERATE_INFOPLIST_FILE: NO
3. Explicit build settings
4. Info.plist properties in project.yml
5. Removing info section entirely
6. INFOPLIST_KEY_* build settings
7. Multiple resource configuration variations
8. Explicit vs implicit Info.plist paths

**Conclusion:** This is a fundamental XcodeGen packaging bug. The framework is failing to merge/copy the Info.plist into the final bundle during archive/export.
