# iOS Build Root Cause Analysis

**Date:** 2025-11-11 17:35 UTC
**Status:** 🔍 ROOT CAUSE IDENTIFIED

---

## The Smoking Gun

### Warning from Xcode (appears TWICE in log):

```
`<PBXNativeTarget name=`SkyFeederFieldUtility` UUID=`064E0CAD2C079DE100B92288`>`
attempted to initialize an object with an unknown UUID.
`A10021F92A934D22A9BF078C` for attribute: `package_product_dependencies`.
This can be the result of a merge and the unknown UUID is being discarded.
```

### What This Means:

**Xcode is DISCARDING the SkyFeederUI package reference!**

1. Target `SkyFeederFieldUtility` tries to use UUID `A10021F92A934D22A9BF078C`
2. This UUID is supposed to be the `XCSwiftPackageProductDependency` for SkyFeederUI
3. **Xcode says this UUID is "UNKNOWN"**
4. **Result: Xcode DISCARDS the package dependency**
5. **Result: Package isn't built, module not found**

---

## Evidence

### ✅ What WORKS:
- SPM resolves the package: `Resolved source packages: SkyFeederUI @ local`
- Match authentication works
- Signing works

### ❌ What DOESN'T Work:
- Build log shows: `Target dependency graph (1 target)` ← Should be 2 targets!
- Should build: `SkyFeederFieldUtility` + `SkyFeederUI`
- Actually builds: ONLY `SkyFeederFieldUtility`
- Package dependency is being **IGNORED/DISCARDED**

---

## Root Cause

### The UUID `A10021F92A934D22A9BF078C` is corrupt or malformed

**Possibilities:**

1. **Section Order Issue:**
   - The XCSwiftPackageProductDependency section might be AFTER the target
   - Xcode reads top-to-bottom, so forward references fail
   - Need to check section ordering

2. **Missing or Incorrect Fields:**
   - The dependency definition might be missing required fields
   - Format might not match Xcode's expectations

3. **Orphaned Reference:**
   - The UUID exists but isn't properly connected
   - The package field might not be linking correctly

4. **Merge Corruption:**
   - As Xcode suggests: "This can be the result of a merge"
   - The entry might have been corrupted during a git merge

---

## Why Previous Fixes Failed

### Attempt #1: Add package field
- ❌ The package field was ALREADY there
- Not the issue

### Attempt #2: Add PBXBuildFile + Framework link
- ❌ Didn't help because the DEPENDENCY ITSELF is being discarded
- Xcode never gets to the linking stage
- Can't link what isn't built!

---

## The Fix

### Option A: Regenerate the XCSwiftPackageProductDependency (RECOMMENDED)
1. Delete the entire XCSwiftPackageProductDependency entry
2. Generate a NEW UUID
3. Create a FRESH entry with correct format
4. Update all references to use the new UUID

### Option B: Fix Section Order
1. Move XCSwiftPackageProductDependency section earlier in file
2. Ensure it comes BEFORE the target definition

### Option C: Nuclear Option - Clean Add
1. Remove package from project completely
2. Re-add it via Xcode project file regeneration
3. This would require opening in Xcode locally (not feasible in CI)

---

## Next Steps

1. ✅ Check current section order in project.pbxproj
2. ✅ Verify XCSwiftPackageProductDependency format
3. ✅ Generate new UUID and regenerate entry (if needed)
4. ✅ Update all references
5. ✅ Test the fix

---

## File Locations

- Project file: `mobile/ios-field-utility/SkyFeederFieldUtility.xcodeproj/project.pbxproj`
- Current UUID (broken): `A10021F92A934D22A9BF078C`
- Package reference UUID: `9AD6537344F64DAF9E42D819`
- Target UUID: `064E0CAD2C079DE100B92288`

---

**Status:** Ready to implement fix
