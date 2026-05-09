# Final Summary: Two Critical Fixes Applied

**Date**: 2026-04-24  
**Branch**: bmc_hallu  
**Status**: Ready for hackdac18 re-run

---

## Issue 1: HackAtDAC18 Wrong Assertions (v5 logs)

### Problem
All 12 benchmarks in `/tmp/hackdac_v5` checked the same assertion (`HACKDAC_p10`: JTAG password bug) regardless of their milestone JSON targets.

### Root Cause
`run_hackatdac18.sh` script's `isolate_property()` function only matched uncommented properties:
```python
# Original (broken)
m = re.match(r'^(\s*)(HACKDAC_\w+)\s*:\s*(assert|cover)\s+property\s*\(', line)
```

Since all properties except p10 were commented out in `properties.sv`, the regex never matched.

### Fix Applied
Strip comment prefix before matching:
```python
# Fixed
stripped = re.sub(r'^[\s/]*', '', line)
m = re.match(r'(HACKDAC_\w+)\s*:\s*(assert|cover)\s+property\s*\(', stripped)
```

### Impact
- All v5 results except p10 are **invalid**
- 5 "successful" cases (p6, p8, p11, p14, p16) are **false positives**
- Need to re-run with correct assertions

### Files Modified
- `run_hackatdac18.sh`: Lines 14-57

---

## Issue 2: test_2.v Regression (AllSkipped)

### Problem
test_2.v failed to find violations after commit d57c4f3 introduced `[AllSkipped]` prune:
```python
# Broken behavior
if not any_cfg_executed:
    return None  # Prunes ALL items when CFGs abandon
```

### Root Cause
The `[AllSkipped]` prune was too aggressive:
1. At cycle 3, preferred path is path3 (via rotation)
2. path3 is UNSAT at cycle 3 (assertion violation path, only valid at cycle 4+)
3. Work item gets pruned with `[AllSkipped]`
4. Forked alternatives also try path3 and get pruned
5. Search exhausted, violation never found

### Fix Applied
Only prune **forked items** when `[AllSkipped]`, let **preferred-path items** advance:
```python
if not any_cfg_executed:
    is_forked_item = any(rc.get('forked', False) for rc in remaining_cfgs)
    if is_forked_item:
        return None  # Prune forked items that hit UNSAT
    # Let preferred-path items advance (forked alternatives will cover other paths)
```

### Key Insight
- **Preferred-path items**: Should advance even when UNSAT (forked alternatives will explore other paths)
- **Forked items**: Should die when UNSAT (they were created for a specific path)

### Validation
**test_2.v**:
- ✓ Violation found correctly
- ✓ No queue explosion (37 paths vs 91 in wrong fix)
- ✓ All milestones reached (0→1→2→3→4→5)
- ✓ Total time: 0.07s, SMT queries: 176

**hackdac18/p6** (smoke test):
- ✓ No regression on constant violations
- ✓ Total time: 9.7s, SMT queries: 4

### Files Modified
- `engine/strategies.py`: Lines 1370-1379

---

## Validation Summary

| Test | Status | Time | Paths | Notes |
|------|--------|------|-------|-------|
| test_2.v (before) | FAIL | - | 20 | Search exhausted at cycle 3 |
| test_2.v (after) | PASS | 0.07s | 37 | Violation found at cycle 6 |
| hackdac18/p6 | PASS | 9.7s | 1 | No regression |

---

## Documentation Created

1. **`docs/hackdac18_v5_complete_analysis.md`** - Full v5 analysis showing wrong assertions
2. **`docs/hackdac18_v5_bug_fix.md`** - Property isolation bug details
3. **`docs/0424_hackdac18_v5_findings.md`** - Detailed findings with evidence
4. **`docs/0424_allskipped_fix.md`** - AllSkipped fix explanation
5. **`docs/0424_final_summary.md`** - This document

---

## Next Steps

### 1. Re-run HackAtDAC18 Benchmarks

```bash
cd /home/ljh/haveFun/sybolicExecution/sylvia-related/siu/HWLoopSe
./run_hackatdac18.sh
```

**Expected runtime**: ~95 minutes (19 problems × 300s timeout)

**What to check**:
- Verify correct assertions are checked (grep "property:" in logs)
- Compare v5 vs v6 results
- Identify which bugs are actually solvable

### 2. Expected Outcomes

**Likely to succeed**:
- p6, p8: Constant violations (should still succeed)
- p16: Simple JTAG reset check (may succeed with correct assertion)

**Likely to timeout**:
- p4, p5: GPIO lock register (milestone 2 unreachable)
- p9, p10: JTAG password (require protocol sequence)
- p3, p13, p27: RISC-V core bugs (require instruction execution)

**Unknown**:
- p11, p14: Need correct assertion to evaluate

### 3. Post-Run Analysis

For each problem:
1. **Verify correct assertion**: `grep "property:" <log> | head -1`
2. **Check milestone progress**: `grep "\[Milestone\] Step" <log> | sort | uniq -c`
3. **Analyze timeouts**: Unreachable milestones? Path explosion? Solver?
4. **Validate counterexamples**: Does violation match target bug?

---

## Key Lessons Learned

1. **Always verify assertions match targets** — don't trust scripts
2. **Check log files for actual assertion text** — milestone JSON ≠ assertion
3. **Distinguish preferred-path items from forked items** — different lifecycle rules
4. **Forked items should die when UNSAT** — they were created for a specific path
5. **Test simple cases first** — test_2.v caught regression before full benchmarks
6. **Check actual version of passing logs** — don't assume they're from current branch

---

## Files Modified

1. **`run_hackatdac18.sh`**: Property isolation fix (lines 14-57)
2. **`engine/strategies.py`**: AllSkipped fix (lines 1370-1379)

---

## Git Status

```
Modified:
  engine/strategies.py  (AllSkipped fix)
  
Untracked:
  run_hackatdac18.sh    (Property isolation fix)
  docs/0424_*.md        (Documentation)
```

---

## Ready to Proceed

Both fixes are applied and validated:
- ✓ Property isolation fix tested (manual verification)
- ✓ AllSkipped fix tested (test_2.v passes)
- ✓ No regression on hackdac18/p6
- ✓ Documentation complete

**Ready for hackdac18 re-run.**
