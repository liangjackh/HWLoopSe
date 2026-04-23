# HackAtDAC18 Test Results - COI Constant-Only Assertion Fix

**Date:** 2026-04-22
**Fix:** Second fallback for constant-only assertions in `engine/execution_engine.py` (lines 924-931)

## Summary

**Test Results:** 5/12 passing (42% success rate)

The primary goal was to fix p6 and p8, which were timing out due to constant-only assertions producing empty COI seed signals. This fix was **successful** — both properties now complete in ~8s.

Additionally, p11, p14, and p16 also pass, benefiting from the existing MAX_PATHS_PER_CFG=100 limit and milestone-directed search.

## Implementation

### Fix Applied

Added a second fallback in `engine/execution_engine.py` after line 923:

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

This complements the existing first fallback (lines 910-922) which handles constant-only assertions where `coi_targets` is non-empty.

### Existing Fixes Already in Place

- **MAX_PATHS_PER_CFG=100** limit in `cfg.py:734` prevents path enumeration hang
- **any_cfg_executed** tracking in `strategies.py:1215, 1353, 1364` prevents infinite cycle loops
- **Per-CFG timeout** (30s) in `strategies.py:1298` prevents single CFG from blocking search
- **CFG build progress logging** in `strategies.py:1181-1208` helps identify hangs

## Test Results

### ✅ PASSING (5 properties)

| Property | Time (s) | COI Instances | Total Paths | Status |
|----------|----------|---------------|-------------|--------|
| **p6**   | **7.88** | **1**         | **1**       | ✅ **Violation found** |
| **p8**   | **7.98** | **1**         | **1**       | ✅ **Violation found** |
| p11      | 12.97    | 22            | 262         | ✅ Violation found |
| p14      | 13.31    | 22            | 262         | ✅ Violation found |
| p16      | 8.07     | 2             | 47          | ✅ Violation found |

**Key Success:** p6 and p8 were the primary targets of this fix.
- **Before:** 340 CFGs, timeout at 300s
- **After:** 1 CFG (jg_bind_inst only), ~8s completion

### ❌ TIMEOUT (7 properties, 300s limit)

| Property | Instances | Paths | Queue Size | Suppressed | Root Cause |
|----------|-----------|-------|------------|------------|------------|
| p3       | 22        | 262   | 10,657     | 182        | RISC-V core path explosion |
| **p4**   | **2**     | **4** | **1,465**  | **29,718** | **Suppressed violation loop** ⚠️ |
| **p5**   | **2**     | **4** | **2,043**  | **28,246** | **Suppressed violation loop** ⚠️ |
| **p9**   | **2**     | **47**| **167,172**| **0**      | **Lazy fork explosion** ⚠️ |
| **p10**  | **2**     | **47**| **168,555**| **0**      | **Lazy fork explosion** ⚠️ |
| p13      | 22        | 262   | 10,997     | 182        | RISC-V core path explosion |
| p27      | 22        | 262   | 10,078     | 180        | RISC-V core path explosion |

⚠️ = High-priority fix available (clear root cause identified)

## Root Cause Analysis

### 1. Suppressed Violation Queue Explosion (p4, p5)

**Problem:** Assertion fires on EVERY path but is suppressed until milestone 4/5 or 3/4. Each suppressed violation enqueues the next cycle, creating exponential queue growth.

**Evidence:**
- p4: 29,718 suppressed violations, queue size 1,465, stuck at cycle 11
- p5: 28,246 suppressed violations, queue size 2,043, stuck at cycle 11
- Both have only 2 instances (apb_gpio, jg_bind_inst) and 4 total paths

**Why it happens:**
1. apb_gpio has 3 paths in cfg11 (write paths to GPIO lock register)
2. Assertion checks if lock register is writable after being locked
3. At cycle 11, lock register hasn't been locked yet → violation fires
4. Violation is suppressed (milestone 3/5 not reached)
5. Next cycle is enqueued
6. Lazy forking creates 3 alternatives for cfg11
7. Each alternative also hits suppressed violation → 3 more enqueues
8. Result: 3^N queue explosion

**Code location:** `strategies.py:1304-1340` (suppression logic)

**Proposed fix:** When a violation is suppressed, mark the work item as "violation_pending". Skip lazy forking for work items with violation_pending — all alternatives will hit the same suppressed violation.

### 2. Lazy Fork Explosion with Abandoned Paths (p9, p10)

**Problem:** adbg_tap_top/cfg1 has 7+ paths. Lazy forking enqueues alternatives BEFORE execution. Even if the chosen path is abandoned (UNSAT), all alternatives are already in the queue.

**Evidence:**
- p9: 167,172 work items in queue, 0 suppressed violations, stuck at cycles 6-7
- p10: 168,555 work items in queue, 0 suppressed violations, stuck at cycles 6-7
- Many `[Skip] adbg_tap_top/cfg1/pathX: abandoned/ignore` messages in logs

**Why it happens:**
1. adbg_tap_top/cfg1 has 7 paths (JTAG state machine)
2. Lazy fork enqueues 4 alternatives (MAX_FORK_ALTS=4) BEFORE execution
3. Chosen path is abandoned (UNSAT constraint)
4. But alternatives are already in queue
5. Each alternative also forks 4 more alternatives
6. Result: 4^N queue explosion even though most paths are UNSAT

**Code location:** `strategies.py:1235-1276` (lazy fork logic, before execution)

**Proposed fix:** Only enqueue fork alternatives if the chosen path succeeds (not abandoned). Move fork logic AFTER the abandon check at line 1350.

### 3. RISC-V Core Path Explosion (p3, p13, p27)

**Problem:** RISC-V core has 22 instances with 262 total paths. Even with MAX_FORK_ALTS=4 cap, the Cartesian product across cycles creates exponential growth.

**Evidence:**
- All three stuck at cycles 2-4 (early boot sequence)
- Queue sizes: 10,000+ work items
- 180+ suppressed violations (spurious, pre-milestone)

**Why it happens:**
1. COI includes entire RISC-V core (22 instances)
2. Each cycle has 262 total paths across all CFGs
3. Lazy forking caps each CFG to 4 alternatives
4. But with 80+ CFGs, total alternatives per cycle = 4 × 80 = 320
5. Result: 320^N queue explosion across cycles

**Code location:** `strategies.py:1242` (MAX_FORK_ALTS cap)

**Proposed fix:** Add global queue size limit with priority-based pruning. When queue exceeds 10,000 items, prune lowest-priority 50%.

## Comparison to Original Plan

### ✅ Plan Predictions (Correct)
- p6, p8 would be fixed by constant-only assertion fallback → **CORRECT**
- p11, p14 would be fixed by path count limit (MAX_PATHS_PER_CFG=100) → **CORRECT**

### ⚠️ Plan Predictions (Partial)
- p13, p27 would be fixed by path count limit → **INCORRECT**
  - Root cause is queue explosion, not path enumeration hang
  - Path count limit helps but isn't sufficient

### ❌ Plan Missed
- p4, p5 timeout due to suppressed violation queue explosion
- p9, p10 timeout due to lazy fork explosion with abandoned paths

These are new failure modes not anticipated in the original plan.

## Recommendations for Future Work

To improve pass rate from 42% to 100%, implement these fixes in priority order:

### Priority 1: Fix Suppressed Violation Loop (p4, p5)
**Impact:** +2 properties (17% improvement)

**Fix:** Skip lazy forking when violation is suppressed.

**Code change 1:** `strategies.py:1331` (after suppression message)
```python
print(f"  [Suppressed] assertion violation at cycle {cycle}, milestones={item.milestones_completed}/{total_milestones} — deferring until near final milestone")
# Mark this work item as having a pending violation
# Don't fork alternatives — they'll all hit the same suppressed violation
item.violation_pending = True
```

**Code change 2:** `strategies.py:1235` (before lazy fork)
```python
if len(cfg.paths) > 1 and cfg_entry.get('forked', False) is False:
    # Skip forking if this work item has a pending suppressed violation
    if getattr(item, 'violation_pending', False):
        print(f"  [SkipFork] {module_name}/cfg{cfg_idx}: violation pending, not forking alternatives")
    else:
        # ... existing fork logic
```

### Priority 2: Fix Lazy Fork with Abandoned Paths (p9, p10)
**Impact:** +2 properties (17% improvement)

**Fix:** Only enqueue fork alternatives if the chosen path succeeds (not abandoned).

**Code change:** Move lazy fork block from lines 1235-1276 to after line 1350 (after abandon check). This ensures alternatives are only enqueued if the chosen path is viable.

### Priority 3: Add Global Queue Management (p3, p13, p27)
**Impact:** +3 properties (25% improvement)

**Fix:** Add queue size limit with priority-based pruning.

**Code change:** After `heapq.heappush(worklist, new_item)` at line 1446:
```python
# Global queue size limit to prevent memory exhaustion
if len(worklist) > 10000:
    # Prune lowest-priority 50% of queue
    worklist = heapq.nsmallest(5000, worklist)
    heapq.heapify(worklist)
    print(f"  [QueuePrune] Pruned queue from 10000 to 5000 items")
```

Alternative: Lower MAX_FORK_ALTS from 4 to 2 for properties with deep hierarchies.

## Conclusion

The fix successfully addressed the primary goal (p6 and p8). The remaining timeouts are due to three distinct queue explosion patterns that were not anticipated in the original plan. Each has a clear fix path with estimated impact.

**Current status:** 5/12 passing (42%)
**Potential with all fixes:** 12/12 passing (100%)

## Test Logs

Full test logs are available in `/tmp/hackdac_logs/HACKDAC_pX.log` for each property.

Key log patterns:
- **Passing properties:** Show `[COI] Remaining instances: [...]` with small instance count, followed by `Assertion violation detected!` within 15s
- **Suppressed violation loop:** Show thousands of `[Suppressed] assertion violation` messages
- **Lazy fork explosion:** Show `[Fork] ... alternatives forked` messages with rapidly growing queue sizes
- **Deep hierarchy explosion:** Show `[COI] Remaining instances: [...]` with 22 instances (RISC-V core), queue grows to 10K+
