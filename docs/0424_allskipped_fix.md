# AllSkipped Fix: Distinguish Preferred vs Forked Items

**Date**: 2026-04-24  
**Issue**: test_2.v regression after commit d57c4f3  
**Root Cause**: `[AllSkipped]` prune was too aggressive, killing preferred-path items when their path was UNSAT

## Problem

**Commit d57c4f3** introduced an `any_cfg_executed` guard that prunes work items when all CFGs abandon:

```python
if not any_cfg_executed:
    print(f"[AllSkipped] cycle {cycle}: all CFGs abandoned — pruning path")
    return None
```

This caused test_2.v to fail because:
1. At cycle 3, the preferred path is path3 (via `_preferred_path_idx` rotation)
2. path3 is UNSAT at cycle 3 (assertion violation path, only valid at cycle 4+)
3. The work item gets pruned with `[AllSkipped]`
4. The forked alternatives (path0, path1, path2) from cycle 2 also try path3 at cycle 3
5. All get pruned, search exhausted

## Root Cause Analysis

The passing log (`log_test_2`) came from an **older version** (before commit d57c4f3) that had:
- **No `any_cfg_executed` guard** — work items always advanced to next cycle
- **No lazy forking** — different exploration strategy entirely
- **Different score formula** — `milestones_remaining * 1000 + cycle` directly

When a CFG abandoned in the old version, the work item just skipped it and continued to the next cycle. This worked because:
- The preferred-path item advanced with unchanged state (harmless)
- The forked alternatives from previous cycles covered the other paths
- No queue explosion because there was no lazy forking creating many forked items

## The Wrong Fix (Attempted First)

**Attempt 1**: Fork alternatives when preferred path abandons
- Added fork logic in the `if manager.abandon` branch
- Created `[Fork-Abandoned]` to fork even when path fails
- **Problem**: Caused queue explosion (91 paths vs 20 in passing log)
- **Why**: Every forked item that hit UNSAT also forked alternatives, creating duplicates

**Attempt 2**: Remove `[AllSkipped]` prune entirely
- Let all `[AllSkipped]` items advance to next cycle
- **Problem**: Caused queue explosion (91 paths)
- **Why**: Forked items that hit UNSAT advanced with unchanged state, creating duplicates

## The Correct Fix

**Only allow preferred-path items to advance when `[AllSkipped]`**:

```python
if not any_cfg_executed:
    is_forked_item = any(rc.get('forked', False) for rc in remaining_cfgs)
    if is_forked_item:
        print(f"[AllSkipped] cycle {cycle}: forked item, all CFGs abandoned — pruning path")
        return None
    print(f"[AllSkipped] cycle {cycle}: preferred-path item, all CFGs abandoned — continuing to next cycle")
```

### Key Insight

**Preferred-path items** (not forked) should advance even when their preferred path is UNSAT:
- They carry the "main" state forward
- Their forked alternatives (created at previous cycles) will explore other paths
- Advancing with unchanged state is harmless — it's just a placeholder

**Forked items** should die when they hit UNSAT:
- They were created to explore a specific path
- If that path is UNSAT, they have no purpose
- Their siblings (other forked alternatives) will cover the other paths
- Advancing would create duplicates

## Validation

### test_2.v Results

**Before fix** (d57c4f3):
```
[Path 4] cycle=3: path3 abandoned
[AllSkipped] cycle 3: all CFGs abandoned — pruning path
Search exhausted (UNSAT)
Paths explored: 20
```

**After fix**:
```
[Path 4] cycle=3: path3 abandoned
[AllSkipped] cycle 3: preferred-path item — continuing to next cycle
Assertion violation detected!
Paths explored: 37
Total time: 0.07s
SMT queries: 176
```

✓ Violation found correctly  
✓ No exponential queue growth (37 paths vs 91 in wrong fix)  
✓ All milestones reached (0→1→2→3→4→5)

### HackAtDAC18 Smoke Test (p6)

```
Assertion violation detected!
Total time: 9.7s
SMT queries: 4
```

✓ No regression on constant violations

## Path Count Comparison

| Version | Paths | Notes |
|---------|-------|-------|
| Passing log (old) | 18 | No lazy forking, different strategy |
| Current fix | 37 | Lazy forking + preferred-path advance |
| Wrong fix (fork-on-abandon) | 91 | Queue explosion from re-forking |
| Wrong fix (all advance) | 91 | Queue explosion from forked duplicates |

The 37 vs 18 difference is expected — the current version uses lazy forking which creates more work items, but it's still reasonable (no explosion).

## Implementation Details

### How to Detect Forked Items

A forked item has `'forked': True` in its `remaining_cfgs` list:

```python
is_forked_item = any(rc.get('forked', False) for rc in remaining_cfgs)
```

When lazy forking creates alternatives, it marks them:

```python
alt_remaining.append({
    'module': module_name,
    'cfg_idx': cfg_idx,
    'path_idx': alt_path_idx,
    'forked': True,  # <-- marks this as a forked item
})
```

Preferred-path items (created at cycle start) have no `'forked'` flag:

```python
remaining_cfgs.append({
    'module': module_name,
    'cfg_idx': cfg_idx,
    'path_idx': self._preferred_path_idx(cfg, cycle),
    # no 'forked' flag — this is the preferred path
})
```

### Why This Works

**Scenario**: At cycle 3, path3 is UNSAT

**Preferred-path item** (Path 4):
- Tries path3 (preferred at cycle 3)
- path3 abandons → `[AllSkipped]`
- `is_forked_item = False` → continues to cycle 4
- Forked alternatives (path0, path1, path2) from cycle 2 are already queued

**Forked items** (Path 5, 6, 7 from cycle 2 fork):
- Try path0, path1, path2 at cycle 3
- Some succeed, some abandon
- If abandon → `[AllSkipped]` → `is_forked_item = True` → pruned
- No duplicates created

## Files Modified

- `engine/strategies.py`: Lines 1370-1379 (AllSkipped guard)

## Documentation Created

- `docs/0424_allskipped_fix.md`: This document
- `docs/0424_lazy_fork_fix.md`: Initial (wrong) fork-on-abandon approach (superseded)

## Key Lessons

1. **Distinguish preferred-path items from forked items** — they have different lifecycle rules
2. **Forked items should die when UNSAT** — they were created for a specific path
3. **Preferred-path items should advance even when UNSAT** — forked alternatives will cover other paths
4. **Check the actual version of passing logs** — don't assume they're from the current branch
5. **Test simple cases first** — test_2.v caught the regression before running full benchmarks

## Next Steps

1. ✓ Fix verified on test_2.v
2. ✓ Smoke test on hackdac18/p6 (no regression)
3. [ ] Re-run full hackdac18 suite with both fixes:
   - Property isolation fix (`run_hackatdac18.sh`)
   - AllSkipped fix (`engine/strategies.py`)
4. [ ] Compare results to v5 to understand impact of correct assertions
