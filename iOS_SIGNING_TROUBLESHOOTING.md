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

### Related Files

- `/fastlane/Fastfile` - Root Fastfile (used by CI workflow) - **NEEDS FIX**
- `/mobile/ios-field-utility/fastlane/Fastfile` - App-local Fastfile (already has Manual signing, not used by workflow)
- `/.github/workflows/ios-build-upload.yml` - CI workflow configuration

### References

- [Fastlane Match Documentation](https://docs.fastlane.tools/actions/match/)
- [Code Signing Guide](https://codesigning.guide/)
- Apple Error: "conflicting provisioning settings" means Automatic + Manual profile specification conflict
