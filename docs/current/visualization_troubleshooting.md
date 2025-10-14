# Visualization System Troubleshooting Guide

## Understanding the "Works at Home, Breaks at Work" Problem

### Network-Based vs Device-Based Restrictions

**Why it works at home but fails at work:**

Corporate networks often implement **Data Loss Prevention (DLP)** and security policies that:
- Monitor and block file I/O operations in real-time
- Restrict access to temp directories (`A_Temp`)
- Block file creation in user profile folders
- Prevent writes to Documents/Desktop when on corporate network
- Apply different policies based on network connection

**Key Insight:** Your device may have full local permissions, but the corporate network gateway intercepts and blocks file operations. This is why:
- ✅ Home network: No DLP → File operations work
- ❌ Corporate network: DLP active → File operations blocked

### The HBITMAP Solution

The HBITMAP in-memory visualization method (commit 9a93a12) was specifically designed to bypass these restrictions by:
- **Zero file I/O** - Everything stays in memory
- **No temp directory access** - No disk writes
- **Network-agnostic** - DLP can't block memory operations
- **Instant rendering** - Sub-millisecond cached retrieval

---

## Diagnosis: Identify Your Problem

### Quick Test: Are You Using HBITMAP or PNG?

**Check your visualization method:**
```ahk
; In Config.ahk or your settings
global corpVisualizationMethod := 1  // 1 = HBITMAP (good), 2 = PNG (will fail at work)
```

**Symptom identification:**
- If buttons show blank/missing thumbnails at work → You're using PNG fallback
- If buttons render instantly → You're using HBITMAP correctly
- If you see file paths in logs/errors → System is trying to write files

### Diagnostic Steps

1. **Check GDI+ Initialization:**
   ```ahk
   ; Should see this in your startup
   if (!gdiPlusInitialized) {
       // If this is false, visualization is broken
   }
   ```

2. **Verify Canvas Configuration:**
   - Wide canvas calibrated: `isWideCanvasCalibrated` should be `true`
   - Narrow canvas calibrated: `isNarrowCanvasCalibrated` should be `true`
   - Canvas values should be: `right > left` and `bottom > top`

3. **Check Macro recordedMode:**
   ```ahk
   ; Each macro event should have:
   {type: "box", left: x, top: y, right: x2, bottom: y2, recordedMode: "Wide"}
   ```

---

## Common Problems and Fixes

### Problem 1: PNG Fallback Being Used Instead of HBITMAP

**Symptoms:**
- Thumbnails work at home, blank at work
- Slow rendering (~100ms+)
- Error messages about file access

**Root Cause:**
HBITMAP creation is failing, system falls back to PNG file method which corporate network blocks.

**Fix:**
```ahk
// In VisualizationCore.ahk
// FORCE HBITMAP-only mode - no PNG fallback

CreateVisualizationForButton(macroEvents, buttonDims) {
    // Only try HBITMAP
    hbitmapHandle := CreateHBITMAPVisualization(macroEvents, buttonDims)
    
    if (!hbitmapHandle || hbitmapHandle = 0) {
        // DO NOT fall back to PNG
        return 0  // Return 0 instead of trying PNG
    }
    
    return hbitmapHandle
}
```

### Problem 2: Invalid Canvas Values Breaking Rendering

**Symptoms:**
- Boxes rendered incorrectly or off-screen
- Thumbnails stretched weird
- Crashes during visualization

**Root Cause:**
Canvas configuration corrupted or not calibrated.

**Fix:**
```ahk
// Run this once to reset and recalibrate
ValidateAndFixCanvasValues() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom
    global hbitmapCache
    
    // Validate wide canvas
    if (!IsNumber(wideCanvasLeft) || !IsNumber(wideCanvasRight) ||
        wideCanvasRight <= wideCanvasLeft || wideCanvasBottom <= wideCanvasTop) {
        // Reset to safe defaults
        wideCanvasLeft := 0
        wideCanvasTop := 0
        wideCanvasRight := 1920
        wideCanvasBottom := 1080
        isWideCanvasCalibrated := false
        
        // Clear cache since old visualizations are invalid
        if (IsObject(hbitmapCache)) {
            CleanupHBITMAPCache()
            hbitmapCache := Map()
        }
    }
    
    // Same for narrow canvas...
}
```

### Problem 3: Missing recordedMode Property

**Symptoms:**
- System can't determine which canvas to use
- Inconsistent rendering between sessions
- Wrong aspect ratio applied

**Root Cause:**
Macros recorded before recordedMode implementation don't have the property.

**Fix:**
```ahk
// When recording a macro, always store recordedMode
OnMouseHook(nCode, wParam, lParam) {
    // ... existing code ...
    
    if (wParam = WM_LBUTTONUP && recording) {
        // Add recordedMode when recording box
        events.Push({
            type: "box",
            left: minX,
            top: minY,
            right: maxX,
            bottom: maxY,
            recordedMode: annotationMode  // "Wide" or "Narrow"
        })
    }
}
```

### Problem 4: GDI+ Not Initializing

**Symptoms:**
- All visualization completely broken
- No thumbnails anywhere
- Errors mentioning GDI+

**Root Cause:**
GDI+ initialization sequence failing or skipped.

**Fix:**
```ahk
// In your main initialization (Core.ahk or Main.ahk)
// MUST happen before any visualization attempts

InitializeVisualizationSystem() {
    global gdiPlusInitialized, gdiPlusToken
    
    if (!gdiPlusInitialized) {
        try {
            si := Buffer(24, 0)
            NumPut("UInt", 1, si, 0)
            result := DllCall("gdiplus\GdiplusStartup", "Ptr*", &gdiPlusToken, "Ptr", si, "Ptr", 0)
            
            if (result = 0) {
                gdiPlusInitialized := true
                return true
            }
        } catch Error as e {
            MsgBox("CRITICAL: GDI+ failed to initialize: " . e.Message)
            return false
        }
    }
    
    return true
}

// Call this ONCE at startup, BEFORE creating GUI
if (!InitializeVisualizationSystem()) {
    MsgBox("Cannot start: Visualization system failed")
    ExitApp
}
```

### Problem 5: HBITMAP Cache Not Clearing Properly

**Symptoms:**
- Memory usage grows over time
- Stale visualizations displayed
- Crashes after extended use

**Root Cause:**
HBITMAP handles not being deleted, causing memory leak.

**Fix:**
```ahk
// Ensure proper cleanup on exit
OnExit((*) => CleanupHBITMAPCache())

CleanupHBITMAPCache() {
    global hbitmapCache
    
    if (!IsObject(hbitmapCache)) {
        return
    }
    
    for cacheKey, hbitmap in hbitmapCache {
        if (hbitmap && hbitmap != 0) {
            try {
                DllCall("DeleteObject", "Ptr", hbitmap)
            } catch {
                // Ignore cleanup errors
            }
        }
    }
    
    hbitmapCache := Map()  // Reset cache
}
```

---

## Removing Non-Essential Hotkeys

### Hotkeys to Remove/Disable

**In Hotkeys.ahk or Config.ahk:**

```ahk
// REMOVE OR COMMENT OUT these non-essential diagnostic hotkeys:

; F10 - Diagnostics (NOT NEEDED for normal operation)
; Hotkey("F10", (*) => DiagnoseConfigSystem())

; F11 - Test Save/Load (NOT NEEDED for normal operation)
; Hotkey("F11", (*) => TestConfigSystem())

; Ctrl+Shift+F12 - Emergency Repair (NOT NEEDED for normal operation)
; Hotkey("^+F12", (*) => RepairConfigSystem())
```

**Keep only essential hotkeys:**
- F9 (or configured key) - Recording toggle
- RCtrl - Macro execution/cancel
- Numpad keys - Button assignment
- Layer switching hotkeys
- ESC - Cancel operations

### Clean Hotkey Setup

```ahk
// Minimal essential hotkeys only
SetupEssentialHotkeys() {
    // Recording control
    Hotkey(hotkeyRecordToggle, F9_RecordingOnly, "On")  // Default F9
    
    // Layer switching (if using WASD profile)
    if (hotkeyProfileActive) {
        Hotkey("CapsLock & Q", (*) => SwitchLayer("prev"))
        Hotkey("CapsLock & E", (*) => SwitchLayer("next"))
    }
    
    // That's it! No diagnostic hotkeys needed
}
```

---

## Locking In the Working Method

### Step-by-Step: Ensure HBITMAP-Only Visualization

**1. Verify commit 9a93a12 visualization files:**
```bash
git checkout 9a93a12 -- src/Visualization*.ahk
```

**2. Force HBITMAP-only in VisualizationCore.ahk:**
```ahk
// Around line 62-110, COMMENT OUT or REMOVE SaveVisualizationPNG function
// This prevents any PNG fallback attempts

/*
SaveVisualizationPNG(bitmap, filePath) {
    // DISABLED - HBITMAP only
    return ""
}
*/
```

**3. Simplify visualization call in your UI code:**
```ahk
UpdateButtonAppearance(buttonName) {
    // ... existing code ...
    
    if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
        // Get button dimensions
        buttonDims := {width: btnW, height: btnH}
        
        // ONLY use HBITMAP method
        hbitmapHandle := CreateHBITMAPVisualization(macroEvents[layerMacroName], buttonDims)
        
        if (hbitmapHandle && hbitmapHandle != 0) {
            // Success - display it
            picture.Value := "HBITMAP:*" . hbitmapHandle
        } else {
            // Fail gracefully - show blank/placeholder
            picture.Value := ""
        }
    }
}
```

**4. Validate configuration on startup:**
```ahk
// In your main initialization sequence
ValidateAndFixCanvasValues()  // Fix any corrupt canvas values
InitializeVisualizationSystem()  // Initialize GDI+
```

**5. Test at work:**
- Record a macro at work (on corporate network)
- Verify thumbnail appears instantly
- Check that no file paths appear in any errors
- Confirm memory-only operation

---

## Verification Checklist

Use this checklist to confirm your system is locked in correctly:

- [ ] GDI+ initializes successfully (`gdiPlusInitialized = true`)
- [ ] Both canvas types calibrated (`isWideCanvasCalibrated` and `isNarrowCanvasCalibrated = true`)
- [ ] Canvas values are valid (right > left, bottom > top)
- [ ] HBITMAP cache exists (`hbitmapCache` is a Map)
- [ ] PNG fallback disabled or removed
- [ ] recordedMode property stored with every new macro
- [ ] Thumbnails render instantly (<10ms)
- [ ] No file-related errors on corporate network
- [ ] Non-essential hotkeys removed
- [ ] Cleanup properly registered with OnExit

---

## Emergency Recovery

If everything breaks at work:

**Option 1: Hard Reset to Commit 9a93a12**
```bash
# Restore ONLY visualization files
git checkout 9a93a12 -- src/Visualization*.ahk

# Or restore entire commit
git reset --hard 9a93a12
```

**Option 2: Minimal Fallback Mode**
```ahk
// If HBITMAP fails, show text-only buttons instead of blank
if (!hbitmapHandle) {
    // Don't try PNG, just use text labels
    button.Text := "Macro " . buttonName
    picture.Visible := false
}
```

**Option 3: Disable Visualization Entirely**
```ahk
// Emergency bypass - system still functions without thumbnails
global visualizationEnabled := false

if (visualizationEnabled) {
    // Only attempt visualization if enabled
    UpdateButtonAppearance(buttonName)
}
```

---

## Final Recommendations

1. **Use commit 9a93a12 as your baseline** - It's proven stable
2. **Never implement PNG fallback** - It fails on corporate networks
3. **Always store recordedMode** - Essential for canvas detection
4. **Validate canvas on startup** - Prevent corrupt values
5. **Remove diagnostic hotkeys** - Keep only essential functionality
6. **Test at work first** - Corporate network is the real test environment

The key principle: **If it needs file I/O, it will fail at work.** Keep everything in memory.

---

## Support

If problems persist:
1. Check that commit 9a93a12 visualization files are in place
2. Verify GDI+ initialization logs
3. Confirm canvas calibration values
4. Test with a fresh macro recorded at work
5. Use diagnostic output to identify specific failure point