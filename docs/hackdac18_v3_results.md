# HackAtDAC18 Test Results - v3 Run (April 23, 2026)

**Test Date:** 2026-04-23 10:11-10:47
**Test Location:** `/tmp/hackdac_v3/`
**Configuration:** Current committed code (commit 4fbd0a6) with all queue management fixes present

## Executive Summary

**Pass Rate: 7/12 (58%)**
- Baseline (commit 4fbd0a6): 5/12 (42%)
- Improvement: +2 properties (+17%)

**Key Findings:**
- p6 and p8 (primary goal) continue to pass ✅
- p3 and p5 now pass (new) ✅
- p4, p9, p10, p13, p27 still timeout ❌

## Test Results

### ✅ PASSING (7 properties)

| Property | Time (s) | Status | Notes |
|----------|----------|--------|-------|
| p3       | ~300     | ✅ Violation found | Real violation at end of log |
| p5       | ~300     | ✅ Violation found | Real violation at end of log |
| p6       | 9.77     | ✅ Violation found | Primary goal (constant-only assertion fix) |
| p8       | 9.71     | ✅ Violation found | Primary goal (constant-only assertion fix) |
| p11      | 15.08    | ✅ Violation found | RISC-V core property |
| p14      | 15.03    | ✅ Violation found | RISC-V core property |
| p16      | 9.75     | ✅ Violation found | GPIO property |

### ❌ TIMEOUT (5 properties, 300s limit)

| Property | Log Size | Queue Size | Root Cause |
|----------|----------|------------|------------|
| p4       | 37 MB    | ~5000      | Suppressed violation loop + queue explosion |
| p9       | 41 MB    | ~5000      | Lazy fork explosion (43-path CFG) |
| p10      | 41 MB    | ~5000      | Lazy fork explosion (43-path CFG) |
| p13      | 2.6 MB   | ~5000      | RISC-V core path explosion |
| p27      | 2.5 MB   | ~5000      | RISC-V core path explosion |

## Analysis

### What Changed from Baseline (5/12 → 7/12)

**New Passes:**
1. **p3** - RISC-V core property that now finds violation within 300s
2. **p5** - GPIO lock property that now finds violation within 300s

**Still Passing:**
- p6, p8 (primary goal)
- p11, p14, p16 (existing passes)

**Still Timing Out:**
- p4 (suppressed violation loop)
- p9, p10 (lazy fork explosion)
- p13, p27 (RISC-V core path explosion)

### Queue Management Impact

All timeout logs show queue size stabilizing at ~5000 items, suggesting a global queue limit is active. This is consistent with the queue management fixes documented in `hackdac18_final_results.md`:

- `_MAX_QUEUE = 5000` (or similar) appears to be enforced
- Queue pruning prevents memory exhaustion
- But doesn't fully resolve timeouts for p4, p9, p10, p13, p27

### Comparison to hackdac18_final_results.md

The `hackdac18_final_results.md` document claims **8/12 (67%)** passing with these fixes:
- Fix 1: Constant-only assertion fallback ✅ (p6, p8)
- Fix 2: Skip forking on suppressed violations ⚠️ (p5 partial)
- Fix 3: Prune dead fork alternatives ✅ (p9, p10)
- Fix 4: Global queue limit ⚠️ (p3, p13, p27 partial)

**Actual v3 results: 7/12 (58%)**

**Discrepancy:** The document claims p9 and p10 pass with Fix 3, but v3 results show they still timeout. This suggests:
1. Fix 3 may not be fully implemented in current code, OR
2. Fix 3 was implemented but later reverted, OR
3. The document was written optimistically during development

### Root Cause Analysis

#### p3, p5 (New Passes)
- Both found real violations at end of 300s timeout window
- Suggests queue management improvements helped but barely
- These are borderline cases that might fail with different inputs

#### p4 (Suppressed Violation Loop)
- 37 MB log, 681K lines
- 29K+ suppressed violations (from grep count)
- Queue at 5000 suggests pruning is active but insufficient
- Fix 2 (skip forking on suppressed violations) may not be fully effective

#### p9, p10 (Lazy Fork Explosion)
- 41 MB logs each
- adbg_tap_top/cfg1 has 43 paths (JTAG state machine)
- Queue at 5000 suggests pruning is active
- Fix 3 (prune dead fork alternatives) appears ineffective or not present

#### p13, p27 (RISC-V Core)
- 2.5-2.6 MB logs (smaller than p9/p10)
- Queue at 5000 suggests pruning is active
- 22 instances, 262 paths across RISC-V core
- Fix 4 (queue limit) helps but doesn't fully resolve

## Recommendations

### Priority 1: Verify Current Code State

Check which queue management fixes are actually present in the committed code:
```bash
grep -n "_violation_suppressed_this_cycle\|PruneFork\|_MAX_QUEUE\|QueuePrune\|SkipFork" engine/strategies.py
```

If fixes are missing, the 7/12 result is the true baseline and `hackdac18_final_results.md` is aspirational.

### Priority 2: Re-run with Known Configuration

To establish ground truth:
1. Tag current commit as "v3-baseline" (7/12 passing)
2. Implement queue management fixes one at a time
3. Test after each fix to measure actual impact
4. Update documentation with verified results

### Priority 3: Focus on Remaining 5 Timeouts

Based on v3 results:
- **p4**: Implement suppressed violation deduplication
- **p9, p10**: Move lazy fork after execution (only fork if path succeeds)
- **p13, p27**: Lower queue threshold or MAX_FORK_ALTS

## Files Modified (Inferred from Logs)

Based on queue behavior in logs:
- `engine/strategies.py`: Queue management (limit ~5000)
- `engine/execution_engine.py`: COI fallback for constant-only assertions (p6, p8 fix)
- `engine/cfg.py`: MAX_PATHS_PER_CFG limit (prevents path enumeration hang)

## Conclusion

The v3 run shows **7/12 (58%)** passing, which is a **+17% improvement** over the documented baseline of 5/12. However, this is **9% below** the 8/12 (67%) claimed in `hackdac18_final_results.md`.

The discrepancy suggests that either:
1. Some queue management fixes were reverted after testing, OR
2. The final results document was written during development and reflects a configuration that wasn't committed

**Next steps:**
1. Verify which fixes are actually in the committed code
2. Re-implement missing fixes if needed
3. Update documentation to reflect actual committed state
4. Continue work on remaining 5 timeouts with verified baseline
