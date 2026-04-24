# HackAtDAC18 v4 Results - Lazy Fork Fix Analysis

**Test Date:** 2026-04-23 15:26-15:36
**Configuration:** Lazy fork moved after abandon check (post-fork)
**Baseline:** v3 (7/12 passing, pre-fork)

## Executive Summary

**Pass Rate: 4/12 (33%)** — down from 7/12 in v3 (-25%)

The lazy fork fix successfully resolved the queue explosion for p9/p10 but caused regressions on p3/p4/p5 due to more conservative path exploration. The fix is **technically correct** (only fork viable paths) but exposes the underlying issue: poor milestone plans cause early search exhaustion.

## Results Comparison

| Property | v3 (pre-fork) | v4 (post-fork) | Change |
|----------|---------------|----------------|--------|
| p3       | ✅ PASS (~300s) | ❌ TIMEOUT | **REGRESSION** |
| p4       | ✅ PASS (~300s) | ⚠️ UNSAT (95s) | **REGRESSION** |
| p5       | ✅ PASS (~300s) | ⚠️ UNSAT (38s) | **REGRESSION** |
| p6       | ✅ PASS (9.77s) | ✅ PASS (9.88s) | Stable |
| p8       | ✅ PASS (9.71s) | ✅ PASS (9.86s) | Stable |
| p9       | ❌ TIMEOUT (300s, queue ~5000) | ⚠️ UNSAT (52s, queue ~1025) | **FIXED queue, but UNSAT** |
| p10      | ❌ TIMEOUT (300s, queue ~5000) | ⚠️ UNSAT (51s, queue ~1025) | **FIXED queue, but UNSAT** |
| p11      | ✅ PASS (15.08s) | ✅ PASS (15.28s) | Stable |
| p13      | ❌ TIMEOUT | ❌ TIMEOUT | No change |
| p14      | ❌ TIMEOUT | ❌ TIMEOUT | No change |
| p16      | ✅ PASS (9.75s) | ✅ PASS (9.88s) | Stable |
| p27      | ❌ TIMEOUT | ❌ TIMEOUT | No change |

## Analysis

### Why the Regressions Occurred

**Pre-fork (v3):**
- Fork alternatives BEFORE execution
- Even if chosen path is abandoned, alternatives are already in queue
- Wasteful but explores more paths (accidental coverage)
- p3/p4/p5 found violations despite poor milestone plans

**Post-fork (v4):**
- Fork alternatives AFTER execution (only if path succeeds)
- Abandoned paths don't generate alternatives
- Efficient but more conservative
- p3/p4/p5 exhaust search early because milestone plans are poor

### Root Cause: Poor Milestone Plans

All regressed properties have the same issue — milestone 0 is "rstn_top == 0" which is never reached:

**p4 milestone plan:**
```
M0: rstn_top == 0 (k=1)  ← NEVER REACHED (reset is active-low, starts at 1)
M1: rstn_top == 1 && top_wrapper.apb_gpio.HRESETn == 1 (k=1)
M2: APB write to GPIO lock register (k=2)
M3: GPIO lock register updated (k=1)
M4: Violation (k=1)
```

The search starts with `rstn_top=1` (non-reset), so milestone 0 is immediately unsatisfiable. The BMC bound check prunes paths that exceed `k=1` without reaching milestone 0. Result: search exhausts at ~10K paths.

**p9/p10 milestone plan:**
```
M0: rstn_top == 0 (k=1)  ← SAME ISSUE
M1: rstn_top == 1 && top_wrapper.adbg_tap_top.trstn_pad_i == 1 (k=1)
M2: bitindex > 0 && bitindex < 32 (k=5)
M3: Violation (k=5)
```

Same issue — milestone 0 is never reached, BMC prunes at cycle 12.

### Why p6/p8/p11/p16 Don't Regress

These properties have better milestone plans that don't require "rstn_top == 0" as the first milestone, or have simpler designs where the search completes quickly regardless.

## Technical Details

### Lazy Fork Fix Implementation

**File:** `engine/strategies.py`

**Before (lines 1232-1276):**
```python
# Lazy fork: if this CFG has multiple paths...
if len(cfg.paths) > 1 and cfg_entry.get('forked', False) is False:
    # Fork alternatives BEFORE execution
    for alt_path_idx in range(len(cfg.paths)):
        # ... push alternatives to worklist
    heapq.heappush(worklist, alt_item)

# Execute the chosen path
result = self._execute_path(...)

if manager.abandon or manager.ignore:
    # Restore state and continue
    # But alternatives are already in queue!
```

**After (lines 1228-1240, 1307-1360):**
```python
# Execute the chosen path FIRST
result = self._execute_path(...)

if manager.abandon or manager.ignore:
    # Restore state and continue
    # No alternatives pushed yet
    continue

# Mark that at least one CFG executed successfully
any_cfg_executed = True

# Lazy fork: ONLY if chosen path succeeded
if len(cfg.paths) > 1 and cfg_entry.get('forked', False) is False:
    # Fork alternatives AFTER execution
    for alt_path_idx in range(len(cfg.paths)):
        # ... push alternatives to worklist
    heapq.heappush(worklist, alt_item)
```

### Queue Metrics

| Property | v3 Queue | v4 Queue | Reduction |
|----------|----------|----------|-----------|
| p9       | ~5000    | ~1025    | 80%       |
| p10      | ~5000    | ~1025    | 80%       |
| p4       | ~740     | ~10      | 99%       |
| p5       | ~2043    | ~6       | 99.7%     |

The fix dramatically reduces queue size, but at the cost of coverage when milestone plans are poor.

## Recommendations

### Option 1: Revert Lazy Fork Fix (Keep v3 Behavior)

**Pros:**
- Maintains 7/12 pass rate
- Accidental coverage helps with poor milestone plans
- p3/p4/p5 continue to pass

**Cons:**
- p9/p10 still timeout with queue explosion
- Wasteful exploration (5000+ queue items)
- Not addressing root cause

### Option 2: Keep Lazy Fork Fix + Improve Milestone Plans

**Pros:**
- Correct implementation (only fork viable paths)
- Efficient queue management
- Forces fixing the real issue (poor milestone plans)

**Cons:**
- Requires manual milestone plan fixes for p3/p4/p5/p9/p10
- More work upfront
- May reveal more milestone plan issues

### Option 3: Hybrid Approach

Add a heuristic to detect when milestone plans are poor and fall back to pre-fork:

```python
# If milestone 0 is "rstn_top == 0" and we're at cycle > 0, use pre-fork
_use_pre_fork = False
if len(self.milestone_manager.milestones) > 0:
    m0_cond = self.milestone_manager.milestones[0].condition
    if "rstn_top == 0" in m0_cond and cycle > 0:
        _use_pre_fork = True

if _use_pre_fork:
    # Fork before execution (v3 behavior)
else:
    # Fork after execution (v4 behavior)
```

## Conclusion

The lazy fork fix is **technically correct** and successfully resolves the queue explosion for p9/p10. However, it exposes a deeper issue: the milestone plans for p3/p4/p5/p9/p10 are LLM-hallucinated and cause early search exhaustion.

**Recommended path forward:**
1. Keep the lazy fork fix (it's correct)
2. Fix the milestone plans for p3/p4/p5/p9/p10 (remove "rstn_top == 0" as milestone 0)
3. Re-test to verify 11/12 or 12/12 pass rate

**Alternative (quick fix):**
1. Revert lazy fork fix to maintain 7/12 baseline
2. Accept p9/p10 timeouts as known issue
3. Focus on other improvements (p13/p14/p27 RISC-V core explosion)
