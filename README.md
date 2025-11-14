# MacroMonoo: Data Labeling & Macro Assistant

**Version**: 1.0.0 (Production) | **Language**: AutoHotkey v2.0 | **Single File**: `MacroMonoo.ahk`

**Built for**: Segments.ai | **Works with**: Any annotation tool exporting boxes (JSON/CSV)

---

## QUICK START (30 Seconds)

1. Download `MacroMonoo.ahk`
2. Double-click to run
3. Click "Import Boxes" → select Segments.ai JSON/CSV export
4. Ready to label

**Requirements**: Windows 10+, AutoHotkey v2.0

---

## CORE WORKFLOW (The Right Way)

```
1. Import boxes from Segments.ai (JSON/CSV)
2. Draw all remaining boxes (top-left to bottom-right ONLY)
3. Tag each box with condition: 1-9 
4. Record macro: CapsLock+F (press again to stop)
5. Replay macro on next item
6. Export results: Ctrl+E
```

---

## CRITICAL RULES

✓ **Draw boxes TOP-LEFT to BOTTOM-RIGHT** - Always, no exceptions  
✓ **Draw ALL boxes FIRST, then tag them** - Don't mix drawing and tagging  
✓ **Status bar shows "Labeled: X/X"** - Before you export or record macro  

---

## HOTKEYS - MACRO RECORDING

| Hotkey | Action |
|--------|--------|
| **CapsLock + F** | **START / STOP recording macro** |
| **CapsLock + Space** | **EMERGENCY STOP** |

**How it works**:
1. Press CapsLock+F (status shows "🎥 RECORDING ACTIVE")
2. Perform complete labeling workflow
3. Press CapsLock+F again (saves macro automatically)

---

## HOTKEYS - WASD NAVIGATION (Keyboard-First Labeling)

| Key | Action |
|-----|--------|
| **W** | Move to PREVIOUS box |
| **S** | Move to NEXT box |
| **A** | Move LEFT on current box |
| **D** | Move RIGHT on current box |
| **1-9** | Assign CONDITION type to current box |
| **Enter** | SUBMIT / CONFIRM current box |
| **Backspace** | DELETE / SKIP current box |

**WASD Workflow (Fastest)**:
```
1. Press S to go to first box
2. Press 1-9 to tag current box
3. Press Enter to confirm
4. Press S to move to next box
5. Repeat steps 2-4 for all boxes
6. Record this sequence: CapsLock+F → repeat workflow → CapsLock+F

BENEFIT: No mouse clicking needed, consistent timing in macro playback
```

**Keyboard Layout**:
```
          W (Previous)
          ↑
A (Left) ← S (Next) → D (Right)
          ↓
      1-9: Condition  |  Enter: Submit  |  Backspace: Delete
```

---

## ALL HOTKEYS REFERENCE

### Recording & Playback
| Hotkey | Action |
|--------|--------|
| CapsLock + F | Start/Stop macro recording |
| CapsLock + Space | Emergency stop (all operations) |
| Ctrl + E | Export current session to CSV |
| Ctrl + S | Save config (auto-saved every 30 sec) |

### Navigation (WASD)
| Hotkey | Action |
|--------|--------|
| W | Previous box |
| A | Left on current box |
| S | Next box |
| D | Right on current box |

### Tagging & Control
| Hotkey | Action |
|--------|--------|
| 1-9 | Assign condition to current box |
| Enter | Submit/confirm current box |
| Backspace | Delete/skip current box |
| F1 | Toggle Wide/Narrow rendering mode |
| F2 | Cycle to next condition type |

### Utility (Optional)
| Hotkey | Action |
|--------|--------|
| LShift + CapsLock | Submit current item (browser: Shift+Enter) |
| LCtrl + CapsLock | Send Backspace (browser: delete) |

---

## STEP-BY-STEP WORKFLOW

### Step 1: Export Boxes from Segments.ai

1. Complete all box drawings in Segments.ai
2. Export as JSON or CSV
3. Keep boxes file handy

### Step 2: Import Boxes into MacroMonoo

1. Click "Import Boxes"
2. Select exported JSON/CSV file
3. Boxes appear as overlays in your working window

### Step 3: Draw and Tag

**FIRST**: Draw all remaining boxes on your interface
- Click and drag: **top-left to bottom-right only**
- Never drag bottom-right to top-left
- Draw all boxes for current item

**THEN**: Tag each box with condition (1-9)
- Click box or use W/S to navigate
- Press 1-9 to assign condition type
- See status bar for confirmation
- Check `config.json` for your custom condition names

**Condition Type Examples**:
- Manufacturing: Smudge, Glare, Splash, Blockage, Crack, Discoloration, Dent, Wear, Other
- Medical: Benign, Malignant, Uncertain, Artifact, Normal, Abnormal, Pending, Review, Other
- Custom: Edit `config.json` to customize

### Step 4: Record Macro

1. Position your labeling interface on screen
2. Press **CapsLock + F** (start recording)
3. Perform complete labeling sequence:
   - Navigate to boxes (W/S or mouse)
   - Assign conditions (press 1-9)
   - Click Submit/Validate buttons or press Enter
4. Press **CapsLock + F** (stop recording)
5. Macro automatically saved with thumbnail

### Step 5: Replay on Next Item

1. Select macro from list
2. Click "Play"
3. Macro replays exact sequence
4. Adjust playback speed (0.5x to 2.0x) if needed
5. Press 1-9 during playback to override conditions for current item

### Step 6: Export Stats

1. Click "Export CSV" (or Ctrl+E)
2. File contains: box coordinates, condition counts, timing, metadata
3. Ready for ML training, QA, or reporting

---

## CONFIGURATION

### Where Settings Live

```
%USERPROFILE%\Documents\MacroMonoo\config.json
```

### Customize Condition Types

Edit `config.json`:

```json
"conditionTypes": {
  "1": "Your Condition 1",
  "2": "Your Condition 2",
  ...
  "9": "Your Condition 9"
}
```

Save and restart MacroMonoo.

---

## SHARING MACRO PROFILES WITH TEAM

### What to Share

Two files make up a shareable profile:

1. **`config.json`** - Condition definitions and settings
2. **Macro files** from `%USERPROFILE%\Documents\MacroMonoo\macros\` folder

### How to Share

**For the lead person (creating profile)**:

1. Record one complete macro that works
2. Copy these files to shared location:
   ```
   \\SharedDrive\Profiles\YourTeam\
   ├── config.json
   ├── macro_standardWorkflow.json
   ├── macro_quickReview.json
   └── README.txt (optional: describe condition types)
   ```

**For team members (importing profile)**:

1. Stop MacroMonoo (if running)
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
5. Test one macro on sample data

**VERSION YOUR PROFILES**: `config_v1.json`, `config_v2.json`, etc.

---

## FILE LOCATIONS

| File/Folder | Location |
|------------|----------|
| Config | `%USERPROFILE%\Documents\MacroMonoo\config.json` |
| Macros | `%USERPROFILE%\Documents\MacroMonoo\macros\` |
| Statistics | `%USERPROFILE%\Documents\MacroMonoo\stats.json` |
| CSV Exports | User-selected (defaults to Documents) |

---

## TROUBLESHOOTING

### Boxes Don't Import

- Verify JSON/CSV format is correct
- File must contain coordinate fields (left, top, right, bottom)
- Status bar should show "Boxes imported: N"

### Macro Won't Replay

- Ensure recording captured mouse movement (check thumbnail)
- Verify labeling interface is in same position as when recorded
- Try adjusting playback speed (0.5x slower if timing is off)

### Can't Export CSV

- Status bar must show "Labeled: X/X" (all boxes tagged)
- At least one macro must be recorded
- Check Documents folder for output file

### Condition Types Not Updating After Import

- Close MacroMonoo completely
- Verify `config.json` in Documents\MacroMonoo\ is from shared profile
- Restart MacroMonoo

### Monitor Setup Changed

- Box positions may shift if recording on different monitor
- Recalibrate via Settings → Calibrate Canvas if needed

---

## BEST PRACTICES

✓ **Draw boxes top-left to bottom-right** - Always, no exceptions  
✓ **Draw ALL boxes first, then tag** - Faster, less errors  
✓ **Use WASD keys** - Keyboard-first labeling (no mouse movement)  
✓ **Record one complete sequence** - One macro = one workflow  
✓ **Test macro on sample before batch** - Catch timing issues early  
✓ **Export and backup regularly** - Keep data safe  
✓ **Version your profiles** - `config_v1.json`, `config_v2.json`, etc.  

✗ Don't: Record partial sequences  
✗ Don't: Mix old/new condition definitions mid-session  
✗ Don't: Share macros across different monitor setups without testing  
✗ Don't: Tag boxes while drawing them  

---

## FAQ

**Q: Can I use this with non-Segments.ai tools?**  
A: Yes. Export boxes from any tool (CVAT, Labelbox, etc.) as JSON/CSV with coordinate fields.

**Q: How many macros can I save?**  
A: Unlimited. Each saved as separate `.json` file.

**Q: Can I edit boxes after recording?**  
A: No. Re-record macro or manually edit the CSV export.

**Q: Does this work on Mac/Linux?**  
A: Windows only. AutoHotkey v2 is Windows-exclusive.

**Q: Can I run multiple instances?**  
A: Not recommended. Only one mouse hook active at a time.

**Q: What if I label boxes wrong?**  
A: Redo the macro. Record a corrected version of the same labeling sequence.

---

## TECHNICAL DETAILS

**Architecture**: Single 6,700+ line AutoHotkey v2 file  
**Recording**: Mouse hook captures all movements, clicks, keystrokes  
**Visualization**: HBITMAP-based (works in corporate restricted networks)  
**Statistics**: Per-session condition tracking, CSV export  
**Performance**: Handles 1,000-5,000 boxes per session reliably  

---

**Made with AutoHotkey v2 | Built for Segments.ai | Customizable for any workflow**  
Last Updated: November 2025
