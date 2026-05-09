# Lazy Fork Fix: Fork on Abandon

**Date**: 2026-04-24  
**Issue**: test_2.v regression after commit d57c4f3  
**Root Cause**: Lazy fork moved AFTER path execution, breaking exploration when preferred path is UNSAT

## Problem

**Commit d57c4f3** moved lazy forking from BEFORE to AFTER path execution to prevent exponential queue growth when the preferred path is UNSAT. However, this created a new problem:

**If the preferred path is UNSAT, no alternatives get forked, and the search gets stuck.**

### Failure Pattern (test_2.v)

```
Cycle 0: preferred=path0 (reset) → succeeds, forks path1/2/3 ✓
Cycle 1: preferred=path1 → succeeds, forks path0/2/3 ✓
Cycle 2: preferred=path2 → succeeds, forks path0/1/3 ✓
Cycle 3: preferred=path3 → FAILS (UNSAT), NO FORK ✗
  - All work items from cycle 2 also try path3 at cycle 3
  - All fail, search exhausted
  - Never reaches milestone 3 (out==2)
```

### Why path3 is UNSAT at cycle 3

The always block has:
```systemverilog
always @(posedge CLK) begin
  if (RST) out <= 0;
  else out <= out + 1;
  if (!RST) assert(out <= 3);
end
```

At cycle 3:
- `out` should be 2 (incremented from 1)
- Milestone 3 requires: `RST==0 && out==2`
- path3 is likely the assertion-violation path (`out > 3`), which is UNSAT until cycle 4

## Solution

**Fork alternatives regardless of whether the chosen path succeeds or is abandoned.**

### Key Insight

The original concern (exponential queue growth) was about forking when the preferred path is UNSAT. But the real issue is **re-forking already-forked items**. The solution:

1. **Fork when preferred path succeeds** (original behavior)
2. **Fork when preferred path is abandoned** (new behavior)
3. **Never fork already-forked items** (preserved by `_should_fork` check)

This ensures:
- Alternatives are always explored (fixes test_2.v)
- No exponential growth from re-forking (preserved by `forked` flag)
- Preferred path rotation still works (unchanged)

## Implementation

### Code Changes

**File**: `engine/strategies.py`  
**Lines**: 1296-1360

```python
# Compute _should_fork BEFORE the abandon check
_should_fork = (len(cfg.paths) > 1 and cfg_entry.get('forked', False) is False)

if manager.abandon or manager.ignore:
    # Restore state to pre-CFG snapshot
    state.store = pre_cfg_store
    state.pending_nba = pre_cfg_nba
    print(f"  [Skip] {module_name}/cfg{cfg_idx}/path{chosen_path_idx}: abandoned/ignore, rolling back and continuing")

    # Fork alternatives BEFORE continuing, so they can be explored even if
    # the preferred path was UNSAT. This prevents the search from getting stuck.
    if _should_fork:
        # ... fork logic (same as success case) ...
        print(f"  [Fork-Abandoned] {module_name}/cfg{cfg_idx}: {_n_alts} alternatives forked ...")

    manager.abandon = False
    manager.ignore = False
    continue

# Mark that at least one CFG executed successfully
any_cfg_executed = True

# Lazy fork: fork alternatives after successful execution too
if _should_fork:
    # ... fork logic (same as abandon case) ...
    print(f"  [Fork] {module_name}/cfg{cfg_idx}: {_n_alts} alternatives forked ...")
```

### Key Points

1. **`_should_fork` computed once** before the abandon check
2. **Fork logic duplicated** in both abandon and success branches
3. **`[Fork-Abandoned]` vs `[Fork]`** log messages distinguish the two cases
4. **`forked` flag** prevents re-forking already-forked items

## Validation

### test_2.v Results

**Before fix**:
```
[Path 4] cycle=3: path3 abandoned, NO FORK
[AllSkipped] cycle 3: all CFGs abandoned — pruning path
Search exhausted (UNSAT)
Paths explored: 20
```

**After fix**:
```
[Path 4] cycle=3: path3 abandoned, Fork-Abandoned 3 alternatives
[Path 11] cycle=6: path3 abandoned, Fork-Abandoned 3 alternatives
Assertion violation detected!
Paths explored: 20
Total time: 0.05s
```

### Queue Growth Analysis

**Concern**: Does forking on abandon cause exponential growth?

**Answer**: No, because:
1. Only non-forked items fork (checked by `_should_fork`)
2. Forked items have `forked=True`, so they never re-fork
3. Each work item forks at most once per CFG

**Evidence from test_2.v**:
```
Path 1 (cycle 0): Fork → queue=3
Path 2 (cycle 1): Fork → queue=6
Path 3 (cycle 2): Fork → queue=9
Path 4 (cycle 3): Fork-Abandoned → queue=12
Path 8 (cycle 4): Fork → queue=13
Path 9 (cycle 4): Fork → queue=16
Path 10 (cycle 5): Fork → queue=19
Path 11 (cycle 6): Fork-Abandoned → queue=22
```

Queue grows linearly, not exponentially. Peak queue size: 22 items.

### Multiple Fork-Abandoned Messages

**Observation**: Path 11 and Path 18 both fork at cycle 6.

**Explanation**: They are **different work items** that both happen to try path3 as their preferred path at cycle 6:
- Path 11: continuation of Path 10 (reached milestone 5)
- Path 18: continuation of Path 17 (reached milestone 5)

Both are non-forked items (natural continuations with preferred path), so both correctly fork alternatives when path3 abandons.

## Impact on HackAtDAC18

**Expected**: No regression, possible improvement.

**Reasoning**:
1. The fix only affects cases where the preferred path is UNSAT
2. HackAtDAC18 problems that timed out may benefit from better exploration
3. Problems that succeeded should be unaffected (they already found violations)

**Action**: Re-run hackdac18 benchmarks to verify no regression.

## Lessons Learned

1. **Fork on abandon is necessary** for completeness when preferred path is UNSAT
2. **The `forked` flag is critical** to prevent exponential growth
3. **Preferred path rotation** creates multiple non-forked work items at the same cycle
4. **Test simple cases** (like test_2.v) to catch regressions early

## Files Modified

- `engine/strategies.py`: Lines 1296-1360 (lazy fork logic)

## Files Created

- `docs/0424_lazy_fork_fix.md`: This document
