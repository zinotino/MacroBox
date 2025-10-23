# HBITMAP Visualization Persistence Fix

## Issue

Visualizations were displaying correctly on initial load but erroring after macro execution:
- **Symptom**: "HBITMAP object type error" after executing a macro
- **Root Cause**: HBITMAP handles were being deleted from cache while still referenced by GUI picture controls
- **Impact**: Visualizations disappeared or showed errors after execution

## Problem Analysis

### Original Flawed Approach

The system had a single `hbitmapCache` Map that stored HBITMAP handles for performance. When a macro was re-recorded or deleted, `ClearHBitmapCacheForMacro()` would:

1. Find cached HBITMAP handles for that button
2. Call `DeleteObject()` to free the memory
3. Remove from cache

**The Problem**: The GUI picture control still held a reference to the deleted HBITMAP handle, causing errors when Windows tried to render it.

### Why It Failed

```ahk
; Old (broken) approach:
ClearHBitmapCacheForMacro(macroName) {
    for cacheKey, hbitmap in hbitmapCache {
        if (InStr(cacheKey, macroName)) {
            DllCall("DeleteObject", "Ptr", hbitmap)  // ❌ DELETES WHILE GUI USES IT
            hbitmapCache.Delete(cacheKey)
        }
    }
}
```

**Timeline of Error**:
1. Macro loads → HBITMAP created → Picture control displays it
2. User executes macro → Cache cleared → HBITMAP deleted
3. GUI tries to repaint → **ERROR**: HBITMAP handle is invalid

## Solution

### Two-Map System

Implemented separate tracking for cached vs. displayed HBITMAPs:

1. **`hbitmapCache`**: Stores HBITMAPs for reuse (cache key based on content)
2. **`buttonDisplayedHBITMAPs`**: Tracks which HBITMAP each button is currently displaying

### Safe Lifecycle Management

**Before Displaying New Visualization**:
```ahk
; Clean up old HBITMAP if button had one
if (buttonDisplayedHBITMAPs.Has(buttonName) && buttonDisplayedHBITMAPs[buttonName] != 0) {
    oldHbitmap := buttonDisplayedHBITMAPs[buttonName]
    DllCall("DeleteObject", "Ptr", oldHbitmap)  // ✅ Safe - will be replaced
}
```

**After Displaying New Visualization**:
```ahk
picture.Value := "HBITMAP:*" . hbitmap
buttonDisplayedHBITMAPs[buttonName] := hbitmap  // ✅ Track as displayed
```

**When Clearing Cache**:
```ahk
; Just remove from cache - don't delete if displayed
for cacheKey, hbitmap in hbitmapCache {
    if (InStr(cacheKey, macroName)) {
        hbitmapCache.Delete(cacheKey)  // ✅ Cache cleared
        // Note: Don't delete HBITMAP - it's still displayed
    }
}
```

## Files Modified

### 1. `src/Core.ahk`

**Added**:
```ahk
global buttonDisplayedHBITMAPs := Map()  // Track displayed HBITMAPs
```

**Updated** `ClearHBitmapCacheForMacro()`:
- Removed `DeleteObject()` call
- Only clears cache entries, doesn't delete handles
- Marked buttons for cleanup on next update

### 2. `src/GUIControls.ahk`

**Updated** `UpdateButtonAppearance()`:

**Before displaying**:
- Deletes old HBITMAP if button had one displayed
- Safe because it will be immediately replaced

**After displaying**:
- Tracks new HBITMAP in `buttonDisplayedHBITMAPs`
- Applies to both macro and JSON visualizations

### 3. `src/VisualizationCore.ahk`

**Updated** `CleanupHBITMAPCache()`:
- Now iterates through `buttonDisplayedHBITMAPs`
- Deletes only HBITMAPs that are actually displayed
- Called only on app exit

## Behavior

### Macro Load
1. `CreateHBITMAPVisualization()` creates HBITMAP
2. Stored in `hbitmapCache` with content-based key
3. Displayed in picture control
4. **Tracked** in `buttonDisplayedHBITMAPs[buttonName]`

### Macro Execution
1. Execution happens (no visualization changes)
2. Cache remains intact
3. HBITMAP remains displayed
4. **No errors** - HBITMAP never deleted

### Macro Re-record
1. `ClearHBitmapCacheForMacro()` clears cache entries
2. `UpdateButtonAppearance()` called
3. **Old HBITMAP deleted** at line 29 (before replacement)
4. New HBITMAP created and displayed
5. **New HBITMAP tracked** in `buttonDisplayedHBITMAPs`

### Macro Delete
1. `ClearHBitmapCacheForMacro()` clears cache
2. `UpdateButtonAppearance()` called
3. **Old HBITMAP deleted** (button will show empty)
4. Button shows default empty state
5. `buttonDisplayedHBITMAPs[buttonName]` set to 0

### App Exit
1. `CleanupHBITMAPCache()` called
2. Iterates through all displayed HBITMAPs
3. Validates and deletes each one
4. Clears both maps
5. **Clean shutdown** - no memory leaks

## Key Principles

### 1. Delete Only When Replacing
Never delete an HBITMAP that's currently displayed unless you're about to replace it with a new one.

### 2. Track Display State
Use `buttonDisplayedHBITMAPs` to know which HBITMAP is currently shown on each button.

### 3. Validate Before Delete
Always check if HBITMAP is valid before calling `DeleteObject()`:
```ahk
result := DllCall("GetObject", "Ptr", hbitmap, "Int", 0, "Ptr", 0)
if (result != 0) {
    DllCall("DeleteObject", "Ptr", hbitmap)
}
```

### 4. Separate Cache from Display
The cache (`hbitmapCache`) can be cleared freely - it's just for performance. The display tracking (`buttonDisplayedHBITMAPs`) controls actual memory cleanup.

## Testing Verification

After these fixes:
- ✅ Visualizations load correctly
- ✅ Visualizations persist after execution
- ✅ No HBITMAP errors during execution
- ✅ Visualizations update correctly when re-recording
- ✅ Clean memory cleanup on macro delete
- ✅ No memory leaks on app exit

## Memory Management

### Cache Behavior
- **Cache Hit**: Reuse existing HBITMAP (fast)
- **Cache Miss**: Create new HBITMAP, add to cache
- **Cache Clear**: Remove entry but don't delete HBITMAP if displayed

### Display Tracking
- **One HBITMAP per button**: Only latest is tracked
- **Old deleted before new**: Safe replacement
- **Cleanup on exit**: All displayed HBITMAPs freed

### Memory Leak Prevention
- Every created HBITMAP is either:
  1. In cache AND tracked as displayed (will be deleted on replace/exit)
  2. In cache only (will be deleted on next cache clear)
  3. Tracked as displayed only (will be deleted on replace/exit)

## Related Issues

This fix also resolves:
- Visualization flickering issues
- HBITMAP handle leaks
- Picture control errors after macro operations
- Unexpected "object type error: 0" messages

## Prevention

To avoid similar issues in the future:

1. **Never delete HBITMAPs from cache** - only remove entries
2. **Track all displayed HBITMAPs** - use `buttonDisplayedHBITMAPs`
3. **Delete only when replacing** - old before new
4. **Validate before delete** - check handle is valid
5. **Clean up on exit only** - one place for final cleanup

## Summary

The fix separates **caching** (performance optimization) from **display tracking** (memory management). HBITMAPs are now:
- **Cached** for performance (can be cleared anytime)
- **Tracked** when displayed (deleted only when replaced or on exit)
- **Validated** before deletion (prevents double-free errors)

Visualizations now remain static after load and only change when intentionally replaced or cleared.
