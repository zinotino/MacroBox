# Phase 3: Manual Testing Guide

## Quick Test Summary

All Phase 2 fixes have been implemented. Now manually verify each fix works correctly.

---

## Test 1: Stats System Freeze ⏱️

**What to test:** Application doesn't freeze during rapid executions

**Steps:**
1. Create a macro with 5 boxes on Num7
2. Execute it rapidly 20 times (press Numpad7, wait briefly, repeat)
3. Watch for any freezing or UI hangs

**Expected:**
- ✅ No freezing at any point
- ✅ All 20 executions complete
- ✅ UI stays responsive

**If it fails:**
- Check `statsQueueMaxSize` is 50 in StatsData.ahk:2781
- Check `BatchWriteToCSVWithTimeout()` has timeout protection
- Verify overflow protection drops oldest items

---

## Test 2: Config Persistence 💾

**What to test:** Macros and properties persist across close/reopen

**Steps:**
1. Record a macro: Box1 (no key) → Press "3" key → Box2 → Box3 (no key)
2. Verify button shows thumbnail
3. Close application completely
4. Reopen application
5. Check if thumbnail is still visible
6. Execute the macro
7. Check CSV stats for degradation counts

**Expected:**
- ✅ Thumbnail visible after reopen
- ✅ Macro executes completely (doesn't stop after boxes)
- ✅ Stats show: 1 Smudge, 2 Splashes

**If it fails:**
- Check config.ini has `degradationType`, `degradationName`, `assignedBy` fields
- Verify `ProcessMacroLine()` in Config.ahk loads all properties
- Check `ApplyLoadedSettingsToGUI()` clears HBITMAP cache

---

## Test 3: First Click Reliability 🖱️

**What to test:** First box/click in macro execution registers reliably

**Steps:**
1. Create a macro with 3-5 boxes on Num7
2. Execute it 10 times
3. Watch carefully if the FIRST box is drawn each time
4. Count successes

**Expected:**
- ✅ 9-10 out of 10 first boxes register (90%+ success)
- ✅ Consistent behavior

**If it fails:**
- Check `PlayEventsOptimized()` has 50ms delay at start (line 265)
- Verify `MouseGetPos()` called before playback (line 264)
- Check `firstMouseOperation` flag adds 20ms delay (lines 300, 321)

---

## Test 4: Performance ⚡

**What to test:** Macro execution completes in reasonable time

**Steps:**
1. Create a macro with 10 boxes on Num7
2. Time the execution (use stopwatch or just observe)
3. Run 3-5 times to get average feel

**Expected:**
- ✅ Execution time: 1-3 seconds for 10-box macro
- ✅ No freezing after completion
- ✅ Ready for next execution immediately

**If too slow:**
- Check timing delays haven't been increased too much
- Verify stats writes are async (no blocking)

---

## Verification Checklist

After testing, verify these files:

### Files Modified in Phase 2:
- [x] `src/StatsData.ahk` - Stats freeze fixes
- [x] `src/Config.ahk` - Config loading with degradation properties
- [x] `src/ConfigIO.ahk` - Config saving with degradation properties
- [x] `src/MacroExecution.ahk` - First click reliability

### Commits Created:
- `e73e98a` - PHASE 2: Fix critical issues (all 4 phases)
- `2303e39` - FIX: Add missing degradationTypes global declaration
- `80c8920` - FIX: Add IsSet safety check for degradationTypes

---

## Success Criteria

**All tests must pass:**
- ✅ No freezing during 20 rapid executions
- ✅ Thumbnails persist after close/reopen
- ✅ Degradation properties save/load correctly
- ✅ First click registers 90%+ of the time
- ✅ Performance is 1-3 seconds for 10-box macro

**If any test fails, debug using the checklist in the implementation guide.**

---

## Next Steps After Testing

Once all tests pass:
1. Commit test results documentation
2. Tag stable release: `git tag -a phase2-complete -m "Phase 2 critical fixes complete and tested"`
3. Push to remote: `git push origin statsviz --tags`
4. Ready for production use!
