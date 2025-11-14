# MacroMonoo: Data Labeling & Macro Assistant

**Version**: 1.0.0 (Production) | **Language**: AutoHotkey v2.0 | **Single File**: `MacroMonoo.ahk`

---

## What It Does

MacroMonoo records and replays your exact labeling workflow:

1. You **draw boxes and tag them** (manually on screen)
2. You **record** this entire workflow (mouse movements, clicks, keypresses)
3. MacroMonoo **saves the macro** and assigns it to a hotkey
4. You **execute** the macro on similar items to repeat the exact sequence

**Use case**: Any repetitive labeling task where boxes and condition assignments follow the same pattern.

---

## Installation (30 Seconds)

1. Download `MacroMonoo.ahk`
2. Double-click to run
3. GUI window appears
4. Ready to label

**Requirements**: Windows 10+, AutoHotkey v2.0

---

## THE WORKFLOW

### Step 1: Prepare Your Labeling Interface

Open your labeling software (Segments.ai, CVAT, custom tool, etc.) with items ready to label.

### Step 2: Draw Boxes and Tag Them

1. Manually **draw boxes on screen** around regions of interest
   - Click and drag to create boxes
   - Tag each box with condition number: **Press 1-9**
   
2. Complete full labeling for one item:
   - All boxes drawn
   - All boxes tagged with condition (1-9)
   - Item submitted/confirmed (if your tool requires it)

**Critical rule**: 
- ✓ Draw ALL boxes first
- ✓ Then tag each with 1-9
- ✓ Don't mix drawing and tagging

### Step 3: Record the Macro

1. Position your labeling interface
2. Press **CapsLock + F** (status shows "🎥 RECORDING ACTIVE")
3. **Repeat Step 2**: Draw boxes and tag them exactly as you did before
4. Press **CapsLock + F** again (stops recording, saves macro automatically)

**What gets captured**:
- Every mouse movement
- Every click
- Every keypress (your 1-9 condition tags)
- Exact timing between all actions

### Step 4: Assign Macro to GUI Button

After recording, macro appears in the GUI with a button. The button is assigned a hotkey.

**Check the button** for its assigned hotkey (e.g., Numpad7, Numpad8, etc.).

### Step 5: Execute on Next Item

1. Load next similar item in your labeling interface
2. Press the assigned hotkey for your recorded macro
3. Macro **replays exact sequence**:
   - Mouse moves to same positions
   - Clicks at same spots
   - Presses same keys at same times
4. If item is slightly different, you can override during playback by pressing 1-9

### Step 6: Export Stats

1. Click **"📊 Stats"** button in GUI
2. Click **"💾 Export"**
3. CSV file saved with statistics:
   - Box coordinates
   - Condition assignments
   - Timing data
   - Execution log

---

## HOTKEYS

### Recording

| Hotkey | Action |
|--------|--------|
| **CapsLock + F** | **START recording macro** |
| **CapsLock + F** | **STOP recording macro** (press again) |
| **CapsLock + Space** | **EMERGENCY STOP** (cancels all operations) |

### Macro Execution (Numpad)

| Hotkey | Action |
|--------|--------|
| Numpad0 - Numpad9 | Execute saved macro |
| NumpadDot | Execute specific macro |
| NumpadMult | Execute specific macro |

### Tagging (During Labeling)

| Hotkey | Action |
|--------|--------|
| **1-9** | **Assign condition type** |

### GUI Controls

| Button | Action |
|--------|--------|
| 🎥 Record | Start/stop recording |
| 🔦 Wide / 📱 Narrow | Toggle canvas mode |
| ☕ Break | Pause operations |
| 🗑️ Clear | Clear current state |
| 📊 Stats | View statistics |
| ⚙️ Config | Open settings |
| 🚨 STOP | Emergency stop |

---

## CANVAS MODES

MacroMonoo supports two rendering modes:

- **Wide**: Full canvas for detailed work
- **Narrow**: 4:3 aspect ratio (standardized output)

Toggle with **F1** or GUI button.

---

## CONFIGURATION

### File Location

```
%USERPROFILE%\Documents\MacroMonoo\config.json
```

### Customize Condition Types

Edit `config.json` to change what 1-9 represent:

```json
"conditionTypes": {
  "1": "Your Condition 1",
  "2": "Your Condition 2",
  ...
  "9": "Your Condition 9"
}
```

**Examples**:
- Manufacturing: Smudge, Glare, Splash, Blockage, Crack, Discoloration, Dent, Wear, Other
- Medical: Benign, Malignant, Uncertain, Artifact, Normal, Abnormal, Pending, Review, Other
- Custom: Any 9 categories for your domain

Save and restart MacroMonoo for changes to take effect.

---

## SHARING MACROS WITH TEAM

### What to Share

1. **`config.json`** - Condition type definitions
2. **Macro files** from `%USERPROFILE%\Documents\MacroMonoo\macros\`

### How to Share

**For the lead person (creating profile)**:

Copy these files to shared location:
```
\\SharedDrive\Profiles\YourTeam\
├── config.json
├── macro_standardWorkflow.json
├── macro_quickReview.json
└── README.txt (optional: describe what each macro does)
```

**For team members (importing)**:

1. Close MacroMonoo
2. Copy received `config.json` to:
   ```
   %USERPROFILE%\Documents\MacroMonoo\config.json
   ```
   (Overwrite existing)

3. Copy macro files to:
   ```
   %USERPROFILE%\Documents\MacroMonoo\macros\
   ```

4. Restart MacroMonoo
5. Test macros on sample data

**Tip**: Version your profiles - `config_v1.json`, `config_v2.json`, etc.

---

## FILE LOCATIONS

| Item | Location |
|------|----------|
| Config | `%USERPROFILE%\Documents\MacroMonoo\config.json` |
| Macros | `%USERPROFILE%\Documents\MacroMonoo\macros\` |
| Statistics | `%USERPROFILE%\Documents\MacroMonoo\stats.json` |
| CSV Export | User-selected location |

---

## TROUBLESHOOTING

### Macro Doesn't Replay Correctly

- Recording may have captured different screen position
- Labeling interface window must be in same position as recording
- Try recording again if timing is off
- Macros are position-dependent and tool-dependent

### Can't Tag Boxes

- Press 1-9 during labeling (before recording)
- Press 1-9 during macro playback to override conditions
- Verify your condition type numbers exist in config.json

### Stats Export Fails

- Ensure at least one macro has been recorded
- Check that Documents\MacroMonoo\ folder exists and is writable
- CSV file should appear in selected export location

### Condition Types Not Updated After Team Import

- Close MacroMonoo completely
- Verify new `config.json` in Documents\MacroMonoo\ folder
- Check file timestamp (should be recent)
- Restart MacroMonoo

---

## BEST PRACTICES

✓ **Draw ALL boxes first, then tag them** - Faster and more consistent  
✓ **Keep your labeling interface in the same window position** - Macros are position-dependent  
✓ **Record on the same monitor/resolution you'll use for playback** - Coordinates depend on screen geometry  
✓ **Test macro on sample item before batch** - Verify sequence works on similar items  
✓ **Export stats regularly** - Keep backups of your labeling data  
✓ **Version your config files** - Track changes to condition definitions  
✓ **Document what each macro does** - Help team members know which macro to use  

✗ Don't: Record partial sequences  
✗ Don't: Share macros across different monitor setups  
✗ Don't: Change condition types mid-labeling session  
✗ Don't: Record on one tool and replay on another without testing  

---

## QUICK START CHECKLIST

- [ ] Run MacroMonoo.ahk
- [ ] Open your labeling tool
- [ ] Draw boxes for one item
- [ ] Press 1-9 to tag each box
- [ ] Press CapsLock+F to start recording
- [ ] Draw boxes and tag them again
- [ ] Press CapsLock+F to stop recording
- [ ] Macro appears in GUI with assigned hotkey
- [ ] Press that hotkey on next item to replay

---

## FAQ

**Q: Can I edit macros after recording?**  
A: Record a new version to update. Export stats and manually edit CSV if needed.

**Q: What if the labeling tool changes or updates?**  
A: Re-record macros. Tool changes may affect coordinate accuracy.

**Q: Can I run multiple instances?**  
A: Not recommended. Only one mouse hook active per system.

**Q: How many macros can I save?**  
A: Unlimited. Each saved as separate `.json` file.

**Q: Does this work with all labeling tools?**  
A: Any tool you can interact with via mouse and keyboard. Some may require position adjustment.

**Q: What if my labeling interface window moves?**  
A: Re-record macro from new position. Macros are position-specific.

---

## TECHNICAL DETAILS

**Architecture**: Single 6,700+ line AutoHotkey v2 file  
**Recording**: Mouse hook captures all movements, clicks, keypresses  
**Playback**: Replays exact sequence with captured timing  
**Visualization**: HBITMAP-based rendering (works in restricted networks)  
**Statistics**: Per-macro execution tracking, CSV export  
**Performance**: Handles complex sequences reliably  

---

**Made with AutoHotkey v2 | Single-file deployment | Windows 10+**  
Last Updated: November 2025
