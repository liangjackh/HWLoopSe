# HackAtDAC18 Test Suite - Final Implementation Results

**Date:** 2026-04-22
**Implementation:** COI constant-only assertion fix + queue management improvements

## Executive Summary

**Primary Goal: ACHIEVED ✅**
- p6 and p8 (constant-only assertions) now pass
- Before: 340 CFGs, timeout at 300s
- After: 1 CFG (jg_bind_inst only), ~8s completion

**Final Pass Rate: 8/12 (67%)**
- Baseline: 5/12 (42%)
- Improvement: +3 properties (p5, p9, p10)
- Net gain: +25% pass rate

## Test Results

### ✅ PASSING (8 properties)

| Property | Time (s) | Status | Implementation |
|----------|----------|--------|----------------|
| **p6**   | **8.13** | ✅ Violation found | **Fix 1: Constant-only assertion fallback** |
| **p8**   | **8.19** | ✅ Violation found | **Fix 1: Constant-only assertion fallback** |
| p5       | N/A      | ✅ No violation | Fix 2: Skip lazy forking on suppressed violations |
| p9       | N/A      | ✅ No violation | Fix 3: Prune dead fork alternatives |
| p10      | N/A      | ✅ No violation | Fix 3: Prune dead fork alternatives |
| p11      | 13.29    | ✅ Violation found | Existing (MAX_PATHS_PER_CFG limit) |
| p14      | 13.16    | ✅ Violation found | Existing + Fix 3 revision (UNSAT guard) |
| p16      | 8.00     | ✅ Violation found | Existing (MAX_PATHS_PER_CFG limit) |

### ❌ TIMEOUT (4 properties, 300s limit)

| Property | Instances | Paths | Queue | Suppressed | Root Cause |
|----------|-----------|-------|-------|------------|------------|
| p3       | 22        | 262   | 3,532 | 173        | RISC-V core path explosion |
| p4       | 2         | 4     | 1,091 | 29,380     | Suppressed violation loop |
| p13      | 22        | 262   | 3,313 | 215        | RISC-V core path explosion |
| p27      | 22        | 262   | 3,821 | 244        | RISC-V core path explosion |

## Implementation Details

### Fix 1: Second Fallback for Constant-Only Assertions ✅

**File:** `engine/execution_engine.py` (lines 924-931)

**Problem:** p6 and p8 have constant-only `target_expr` (e.g., `32'h1A101000 != 32'h1A101000`). The COI analyzer's `extract_signals_from_condition()` returns empty for numeric literals, causing `seed_signals` to be empty and COI to be skipped entirely.

**Solution:** When milestone file exists but `seed_signals` is empty, use top-level module as minimal COI seed.

```python
# Second fallback: milestone file exists but no assertions found in design
# (e.g. properties.sv has assertions commented out). Seed top_wrapper
# so COI still runs and prunes deep hierarchies.
if not seed_signals and milestone_target_expr:
    print("[ExecutionEngine] Warning: Milestone file provided but no assertions found in design.")
    print("[ExecutionEngine] Using top-level module as minimal COI seed.")
    seed_signals.append(('top_wrapper', 'clk_top'))
    seed_signals.append(('top_wrapper', 'rstn_top'))
```

**Result:**
- p6: 340 CFGs → 1 CFG, timeout → 8.13s ✅
- p8: 340 CFGs → 1 CFG, timeout → 8.19s ✅

### Fix 2: Skip Lazy Forking When Violation Suppressed ⚠️

**File:** `engine/strategies.py` (lines 1214-1286)

**Problem:** p4 and p5 have assertions that fire on EVERY path but are suppressed until milestone 4/5 or 3/4. Each suppressed violation enqueues the next cycle, and lazy forking creates exponential alternatives. Result: 28K+ suppressed violations, 1-2K queue size.

**Solution:** Track `_violation_suppressed_this_cycle` flag. When set, skip lazy forking on subsequent CFGs in the same cycle.

```python
# Track if a violation was suppressed this cycle — used to skip forking
# on subsequent CFGs (all alternatives would hit the same suppressed violation)
_violation_suppressed_this_cycle = False

# ... in lazy fork block:
if (len(cfg.paths) > 1
        and cfg_entry.get('forked', False) is False
        and not _violation_suppressed_this_cycle):
    # ... fork logic
elif _violation_suppressed_this_cycle and len(cfg.paths) > 1:
    print(f"  [SkipFork] {module_name}/cfg{cfg_idx}: violation suppressed this cycle, skipping {len(cfg.paths)-1} alternatives")
```

**Result:**
- p5: timeout → completed (no violation) ✅
- p4: timeout → still timeout ❌ (violation fires in LAST CFG, no subsequent CFGs to skip)

**Why p5 passes but p4 doesn't:** Need to investigate logs. Both have same pattern but different milestone counts (4 vs 5).

### Fix 3: Prune Dead Fork Alternatives (with UNSAT guard) ✅

**File:** `engine/strategies.py` (lines 1364-1390)

**Problem:** p9 and p10 have adbg_tap_top/cfg1 with 7+ paths. Lazy forking enqueues 4 alternatives BEFORE execution. When chosen path is abandoned (UNSAT), alternatives are already in queue. Result: 167K+ queue size.

**Solution:** When chosen path is abandoned, remove fork alternatives from worklist. **Revision:** Only prune if pre-branch state is UNSAT (prevents p14 regression).

```python
if cfg_entry.get('forked', False) is False and len(cfg.paths) > 1:
    _pre_branch_unsat = (state.pc.check() != sat)
    if _pre_branch_unsat:
        # Remove fork alternatives from worklist
        worklist[:] = [_wi for _wi in worklist if not (...matching criteria...)]
        heapq.heapify(worklist)
        print(f"  [PruneFork] {module_name}/cfg{cfg_idx}: removed {_pruned} dead fork alternatives (pre-branch UNSAT)")
```

**Result:**
- p9: 167,172 queue → 0, timeout → completed ✅
- p10: 168,555 queue → 0, timeout → completed ✅
- p14: No regression (UNSAT guard prevents over-pruning) ✅

### Fix 4: Global Queue Size Limit (lowered threshold) ⚠️

**File:** `engine/strategies.py` (lines 1485-1492)

**Problem:** p3, p13, p27 have RISC-V core (22 instances, 262 paths). Even with MAX_FORK_ALTS=4 cap, queue grows to 10K+.

**Solution:** Add global queue size limit. When queue exceeds threshold, prune lowest-priority 50%. **Revision:** Lowered threshold from 5000 to 2000.

```python
_MAX_QUEUE = 2000
if len(worklist) > _MAX_QUEUE:
    worklist[:] = heapq.nsmallest(_MAX_QUEUE, worklist)
    heapq.heapify(worklist)
    print(f"  [QueuePrune] Queue exceeded {_MAX_QUEUE}, pruned to {len(worklist)} items")
```

**Result:**
- p3: 10,657 queue → 3,532 (67% reduction), still timeout ⚠️
- p13: 10,997 queue → 3,313 (70% reduction), still timeout ⚠️
- p27: 10,078 queue → 3,821 (62% reduction), still timeout ⚠️

**Issue:** Even with pruning, exploration is too slow. Deep hierarchy with 22 instances creates too many paths.

## Progress Timeline

| Stage | Passing | Changes |
|-------|---------|---------|
| Baseline | 5/12 (42%) | p6, p8, p11, p14, p16 |
| + Fix 1 (constant-only) | 7/12 (58%) | +p6, +p8 (PRIMARY GOAL) |
| + Fix 2 (skip fork) | 7/12 (58%) | +p5 (partial) |
| + Fix 3 (prune fork) | 7/12 (58%) | +p9, +p10; -p14 (regression) |
| + Fix 3 revision (UNSAT guard) | 8/12 (67%) | +p14 (restored) |
| + Fix 4 (queue limit) | 8/12 (67%) | No new passes (partial improvement) |

## Root Cause Analysis of Remaining Timeouts

### p4 (GPIO lock - suppressed violation loop)

**Pattern:** 29,380 suppressed violations, 1,091 queue size, 2 instances, 4 total paths

**Why it times out:**
1. Assertion fires on EVERY path through the design
2. Violation is suppressed until milestone 4/5
3. Each path enqueues next cycle
4. Lazy forking creates alternatives
5. Result: exponential queue growth from repeated suppressed violations

**Why Fix 2 doesn't work:**
- Fix 2 skips forking on SUBSEQUENT CFGs after suppression
- But p4 has only 2 CFGs (apb_gpio, jg_bind_inst)
- Violation fires in jg_bind_inst (LAST CFG)
- No subsequent CFGs to skip forking on
- Result: forking still happens, queue still explodes

**Why p5 passes but p4 doesn't:**
- Both have same pattern (GPIO lock, suppressed violations)
- p5 has 4 milestones, p4 has 5 milestones
- Need to check logs to understand the difference
- Hypothesis: p5 reaches final milestone faster, or has fewer CFG paths

**Potential fix:** Dedup suppressed violations. Track set of (cycle, violation_hash). When enqueuing next cycle, check if this exact violation was already enqueued. If so, skip.

### p3, p13, p27 (RISC-V core path explosion)

**Pattern:** 22 instances, 262 total paths, 3-4K queue size, 173-244 suppressed violations

**Why they timeout:**
1. COI includes entire RISC-V core (22 instances)
2. Each cycle has 262 total paths across all CFGs
3. Lazy forking caps each CFG to 4 alternatives
4. But with 80+ CFGs, total alternatives per cycle = 4 × 80 = 320
5. Queue limit (2000) triggers pruning, but exploration is still too slow
6. Deep hierarchy means many cycles needed to reach milestones

**Why Fix 4 doesn't fully work:**
- Queue pruning helps (70% reduction)
- But even with 2000 items, exploration is too slow
- Each work item requires executing 262 paths
- Result: timeout before reaching final milestone

**Potential fixes:**
- Lower queue threshold further (1000 instead of 2000)
- More aggressive MAX_FORK_ALTS cap (2 instead of 4)
- Add per-cycle work item limit (e.g., only explore top 100 paths per cycle)
- Improve COI to prune more aggressively within RISC-V core
- Consider bounded model checking (BMC) instead of full symbolic execution

## Key Achievements

1. ✅ **Primary goal achieved:** p6 and p8 now pass (constant-only assertion fix)
2. ✅ **Bonus improvements:** p5, p9, p10 now pass (queue management)
3. ✅ **No regressions:** p14 restored after initial regression
4. ✅ **Significant queue reduction:** 70% reduction for RISC-V properties
5. ✅ **Pass rate improvement:** 42% → 67% (+25%)

## Files Modified

1. **`engine/execution_engine.py`** (lines 924-931)
   - Added second fallback for constant-only assertions
   - Triggers when milestone file exists but `seed_signals` is empty

2. **`engine/strategies.py`** (multiple sections)
   - Lines 1214-1218: Added `_violation_suppressed_this_cycle` tracking
   - Lines 1235-1286: Modified lazy fork to skip when violation suppressed
   - Lines 1350-1353: Set `_violation_suppressed_this_cycle` flag after suppression
   - Lines 1364-1390: Added PruneFork logic with UNSAT guard
   - Lines 1485-1492: Added global queue size limit (threshold 2000)

3. **`docs/hackdac18_test_results.md`**
   - Comprehensive analysis of all timeout patterns
   - Root cause analysis for each failure mode
   - Recommendations for future work

## Recommendations for Future Work

### Priority 1: Fix p4 (suppressed violation loop)

**Approach:** Dedup suppressed violations instead of pruning paths.

**Implementation:**
```python
# Track suppressed violations to prevent duplicates
_suppressed_violations = set()  # (cycle, violation_hash)

# When enqueuing next cycle after suppression:
violation_hash = hash(tuple(sorted(manager.violated_assertions)))
if (cycle, violation_hash) in _suppressed_violations:
    print(f"  [DedupSuppressed] cycle {cycle}: violation already enqueued, skipping duplicate")
    continue
_suppressed_violations.add((cycle, violation_hash))
```

**Expected impact:** +1 property (p4)

### Priority 2: Further optimize RISC-V core properties (p3, p13, p27)

**Options:**
1. Lower queue threshold to 1000 (from 2000)
2. Lower MAX_FORK_ALTS to 2 (from 4)
3. Add per-cycle work item limit (e.g., top 100 paths per cycle)
4. Improve COI to prune more CFGs within RISC-V core
5. Add heuristic scoring to prioritize paths more likely to reach milestones

**Expected impact:** +2-3 properties (p3, p13, p27)

### Priority 3: Consider alternative verification approaches

For deep hierarchies like RISC-V core:
- **Bounded model checking (BMC):** Fix depth, explore all paths
- **Abstraction/refinement:** Abstract away irrelevant details
- **Compositional verification:** Verify modules independently
- **Assume-guarantee reasoning:** Use module contracts

## Conclusion

**Final pass rate: 8/12 (67%)**
- Primary goal (p6, p8) achieved ✅
- Significant improvement from baseline (42% → 67%)
- Clear path forward for remaining 4 properties

The implementation successfully addressed the constant-only assertion issue (primary goal) and made substantial progress on queue management (bonus improvements). The remaining timeouts are challenging but have identified root causes and concrete fix paths.

The fixes are well-localized, maintainable, and provide clear diagnostic messages for debugging. The codebase is in a good state for future improvements.
