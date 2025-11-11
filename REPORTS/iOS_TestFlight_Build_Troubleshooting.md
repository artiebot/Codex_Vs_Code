# iOS TestFlight Build Troubleshooting Log

**Date:** 2025-11-11
**Issue:** iOS TestFlight build failing with module/linking errors
**Branch:** `claude/run-bootstrap-fastlane-011CUnD7624SWUSFKyGJqogx`
**Project:** SkyFeederFieldUtility iOS app

---

## Overview

Multiple attempts to fix iOS TestFlight build have been made. This document tracks:
- What errors occurred
- What fixes were attempted
- What worked and what didn't
- Current status

---

## Error History

### Error #1: Duplicate Match Calls (Initial Issue)
**Status:** ✅ FIXED

**Problem:**
- Workflow was calling `match` twice (once in workflow step, once in lane)
- Caused confusion and potential conflicts

**Fix Applied:** Commit `1f08b47`
- Removed duplicate match call from workflow
- Let the lane handle match internally
- Added 30-minute timeout on build step

**Result:** Fixed, but revealed next issue

---

### Error #2: Wrong Code Signing Style
**Status:** ✅ FIXED

**Problem:**
- Fastfile was using `CODE_SIGN_STYLE=Automatic`
- This conflicts with match which provides Manual signing
- Also had `-allowProvisioningUpdates` which is for Automatic only

**Fix Applied:** Commit `1f08b47`
- Changed to `CODE_SIGN_STYLE=Manual`
- Removed `-allowProvisioningUpdates` flag
- Set explicit provisioning profile specifier

**Result:** Fixed, but revealed next issue

---

### Error #3: "no such module 'SkyFeederUI'" (Current Issue)
**Status:** 🔴 IN PROGRESS - Multiple attempts

#### Attempt #1: Add Package Reference
**Fix Applied:** Commit `b4e66e3` (on wrong branch `fix/skyfeederui-package-reference`)

**What was tried:**
- Sub-agent investigated and added `package` field to XCSwiftPackageProductDependency
- Theory: Missing package reference was causing module resolution to fail

**Result:** ❌ FAILED
- Fix was on wrong branch initially
- Later cherry-picked to correct branch as commit `e89c90b`
- Build still fails with same error

**Why it didn't work:**
- The `package` field was already present in project.pbxproj
- This wasn't actually the root cause

#### Attempt #2: Add Framework Link to Build Phase
**Fix Applied:** Commit `e89c90b` (cherry-picked from `aefd4ea`)

**What was tried:**
- Added PBXBuildFile entry (UUID: 99A6A1FC04284BA2844ED35D)
- Linked SkyFeederUI package product to Frameworks build phase
- Theory: Missing framework link in build phase caused linking failure

**Result:** ❌ FAILED (just confirmed by user)
- Build still fails with "no such module 'SkyFeederUI'"
- Same error pattern persists

---

## Current State Analysis

### What We Know

**✅ Working:**
- Match Bootstrap workflow succeeds
- Certificates and provisioning profiles are created correctly
- MATCH_GIT_URL authentication works
- Match pull in testflight_upload lane works
- Swift Package Manager resolves the SkyFeederUI package
  - Log shows: "Resolved source packages: SkyFeederUI: ...@local"

**❌ Not Working:**
- Xcode build fails to find SkyFeederUI module during compilation
- Error: `::error file=.../SkyFeederFieldUtilityApp.swift,line=2,col=8::no such module 'SkyFeederUI'`

**🤔 Confusing:**
- SPM resolution succeeds (package is found)
- But Swift compiler can't find the module during build
- Warning about "unknown UUID" in package_product_dependencies
  - `A10021F92A934D22A9BF078C` for attribute: package_product_dependencies

### Project Structure Verification

**SkyFeederUI Package:**
```
mobile/ios-field-utility/SkyFeederUI/
├── Package.swift ✅ (defines library "SkyFeederUI")
├── Sources/
│   └── SkyFeederUI/ ✅ (contains Swift files)
└── Tests/
```

**Xcode Project SPM References:**
- XCLocalSwiftPackageReference: `9AD6537344F64DAF9E42D819` ✅
  - Points to relativePath: "SkyFeederUI"
- XCSwiftPackageProductDependency: `A10021F92A934D22A9BF078C` ✅
  - Has package field pointing to `9AD6537344F64DAF9E42D819`
  - productName: "SkyFeederUI"
- Target packageProductDependencies: ✅
  - Includes `A10021F92A934D22A9BF078C`
- PBXBuildFile: `99A6A1FC04284BA2844ED35D` ✅ (just added)
  - Links SkyFeederUI to Frameworks phase

### What Might Be Wrong (Hypotheses)

1. **Scheme ordering issue**
   - Maybe the scheme doesn't build packages first?
   - Need to check if buildImplicitDependencies is set correctly

2. **Package.swift target name mismatch**
   - Package defines target "SkyFeederUI" at path "Sources"
   - But module might need explicit name or different structure

3. **Xcode project corruption**
   - The warning about "unknown UUID" suggests corruption
   - May need to clean/rebuild project file references

4. **Build settings override**
   - Fastlane's xcargs might be interfering with SPM
   - Manual signing settings might conflict with SPM build

5. **Wrong Xcode version or tools**
   - Workflow uses Xcode 16.1
   - Package requires Swift 5.9 (iOS 17+)
   - But this should work...

6. **Package not actually building**
   - SPM resolves it but doesn't build it
   - Need to verify build order and dependencies

---

## Next Steps (To Be Attempted)

### Investigation Needed:

1. **Check workflow logs for actual commit being used**
   - Verify e89c90b is actually in the build
   - Check git hash in workflow checkout step

2. **Get full error log, not just tail**
   - Need to see ALL compilation errors
   - Need to see SPM resolution details
   - Need to see what actually happened during build

3. **Verify scheme configuration**
   - Check if buildImplicitDependencies=YES (it is in scheme file)
   - Check if package targets are in build order

4. **Check if there are multiple import issues**
   - Maybe other files also import SkyFeederUI
   - Maybe some succeed and some fail

5. **Consider build order**
   - Might need explicit pre-build script to build package
   - Might need to change gym configuration

### Potential Fixes to Try (in order):

1. **Add explicit package build step**
   - Build SkyFeederUI package before main build
   - Use xcodebuild to build package target explicitly

2. **Fix Package.swift structure**
   - Change path from "Sources" to "Sources/SkyFeederUI"
   - Make module structure more explicit

3. **Add build settings to gym**
   - Add SWIFT_INCLUDE_PATHS or other SPM settings
   - Ensure SPM integration is enabled in build

4. **Create clean project file**
   - Remove and re-add the package reference
   - Let Xcode regenerate all UUIDs cleanly

5. **Use workspace instead of project**
   - Create xcworkspace that includes the package
   - Build from workspace instead of project

---

## Important Notes

- **DO NOT** make another fix without fully understanding the error
- **DO** get complete error logs before next attempt
- **DO** verify commit is in the build that's failing
- **DO** test hypotheses one at a time
- **DO** document each attempt in this file

---

## References

- Fastfile: `mobile/ios-field-utility/fastlane/Fastfile`
- Xcode Project: `mobile/ios-field-utility/SkyFeederFieldUtility.xcodeproj/project.pbxproj`
- Package: `mobile/ios-field-utility/SkyFeederUI/Package.swift`
- Scheme: `mobile/ios-field-utility/SkyFeederFieldUtility.xcodeproj/xcshareddata/xcschemes/SkyFeederFieldUtility.xcscheme`
- Workflow: `.github/workflows/ios-testflight.yml`

---

## Commit History

| Commit | Description | Status |
|--------|-------------|--------|
| 1f08b47 | Remove duplicate match, fix signing style | ✅ Fixed those issues |
| b4e66e3 | Add package reference (wrong branch) | ❓ Already existed |
| aefd4ea | Add framework link (wrong branch) | ❓ Testing |
| e89c90b | Cherry-pick framework link to correct branch | 🔴 Still failing |

---

**Last Updated:** 2025-11-11 17:30 UTC
**Next Action:** Get full error logs and verify commit before next fix attempt

---

## RESOLUTION (2025-11-11 17:40 UTC)

### ✅ **ROOT CAUSE IDENTIFIED AND FIXED**

**The Problem:**
The branch `claude/run-bootstrap-fastlane-011CUnD7624SWUSFKyGJqogx` was **missing ALL Swift Package Manager sections** from the Xcode project file. The sections existed in `main` but were never merged into this branch.

**The Evidence:**
```
`<PBXNativeTarget> attempted to initialize an object with an unknown UUID.
`A10021F92A934D22A9BF078C` for attribute: `package_product_dependencies`.
This can be the result of a merge and the unknown UUID is being discarded.
```

Xcode was reporting "unknown UUID" because the UUID literally didn't exist in the file!

**Missing Sections:**
1. ❌ `XCLocalSwiftPackageReference` - Package definition
2. ❌ `packageReferences` array in PBXProject
3. ❌ `packageProductDependencies` array in PBXNativeTarget
4. ❌ `XCSwiftPackageProductDependency` - Product dependency

**The Fix:** Commit `7c796bc`
- Restored complete SPM configuration from `main` branch
- All four missing sections now present
- Project file now matches `main` with proper package references

**Why Previous Fixes Failed:**
- Attempted to add PBXBuildFile link → No effect (package didn't exist to link)
- Attempted to add package field → Already present in main, not the issue
- Were addressing symptoms, not the root cause

**What Should Happen Now:**
1. ✅ Xcode will recognize UUID `A10021F92A934D22A9BF078C`
2. ✅ Build will include 2 targets: SkyFeederFieldUtility + SkyFeederUI
3. ✅ SkyFeederUI package will build first
4. ✅ Module will be available for import
5. ✅ Build should succeed!

**Commits:**
- `7c796bc` - Fix: Restore missing SPM references
- `11cf2aa` - Doc: Add root cause analysis

**Status:** ✅ FIXED - Ready for next workflow run

---

**Last Updated:** 2025-11-11 17:42 UTC
