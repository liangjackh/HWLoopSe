# HackAtDAC18 v5 Complete Analysis

**Date**: 2026-04-24  
**Analyst**: Claude Opus 4.7  
**Branch**: bmc_hallu  
**Commit**: 4fbd0a6

## Executive Summary

Analysis of `/tmp/hackdac_v5` logs revealed that **all 12 benchmarks checked the wrong assertion**. The `run_hackatdac18.sh` script failed to uncomment target properties, causing every run to check `HACKDAC_p10`'s JTAG password assertion.

**Impact**: All v5 results are invalid except p10. The 5 "successful" cases are false positives.

**Fix**: Updated `run_hackatdac18.sh` to handle commented properties. Ready for corrected re-run.

---

## The Bug

### Root Cause

The `isolate_property()` function only matched uncommented property blocks:

```python
# Original (broken)
m = re.match(r'^(\s*)(HACKDAC_\w+)\s*:\s*(assert|cover)\s+property\s*\(', line)
```

Since `properties.sv` had all properties commented out except `HACKDAC_p10`, the regex never matched commented properties.

### Evidence

Extracted actual assertions from log files:

| Problem | Milestone JSON Target | Actual Assertion in Log |
|---------|----------------------|------------------------|
| p3 | `priv_lvl_n == 2'b11 && mstatus_n.mpp == 2'b00` | `(passchk == 1) \|-> (bitindex == 32)` |
| p4 | `PWDATA == 0x12345678 && r_gpio_lock == 0x12345678` | `(passchk == 1) \|-> (bitindex == 32)` |
| p6 | `GPIO_START_ADDR == 0x1A101000 && GPIO_END_ADDR == 0x1A101FFF` | `(passchk == 1) \|-> (bitindex == 32)` |
| p16 | `trstn_pad_i == 0 && correct != 0` | `(passchk == 1) \|-> (bitindex == 32)` |

All 12 problems checked the p10 assertion.

---

## v5 Results Analysis

### Summary Table

| Problem | Status | Time(s) | Paths | Milestones | Issue |
|---------|--------|---------|-------|------------|-------|
| p3 | TIMEOUT | 300+ | 801 | 0/3 | Wrong assertion |
| p4 | TIMEOUT | 300+ | 57,475 | 1/4 | Wrong assertion |
| p5 | TIMEOUT | 300+ | 58,167 | 0/3 | Wrong assertion |
| **p6** | **VIOLATION** | **9.7** | **2** | **0/2** | **False positive** |
| **p8** | **VIOLATION** | **9.8** | **2** | **0/2** | **False positive** |
| p9 | TIMEOUT | 300+ | 101,637 | 0/3 | Wrong assertion |
| p10 | TIMEOUT | 300+ | 101,635 | 0/3 | **Valid result** |
| **p11** | **VIOLATION** | **14.8** | **4** | **2/4** | **False positive** |
| p13 | TIMEOUT | 300+ | 717 | 0/5 | Wrong assertion |
| **p14** | **VIOLATION** | **14.8** | **4** | **2/4** | **False positive** |
| **p16** | **VIOLATION** | **9.8** | **4** | **0/2** | **False positive** |
| p27 | TIMEOUT | 300+ | 855 | 1/4 | Wrong assertion |

**Success rate**: 5/12 (41.7%) — all false positives  
**Valid results**: 1/12 (p10 only)

### False Positive Mechanisms

#### Type 1: Constant Violations (p6, p8)

**Why they succeeded**: Assertions are unconditional constants
- p6: `32'h1A10AFFF != 32'h1A101FFF` → always TRUE
- p8: `32'h1A10AFFF > 32'h1A102000` → always TRUE

**Mechanism**: Constant-only assertions fire immediately at cycle 0 regardless of which assertion is checked.

#### Type 2: Deferred Violations (p11, p14)

**Why they succeeded**: Sliding window + deferred violation mechanism

**Mechanism**:
1. COI extracted seeds from milestone JSON (`dbg_halt`, `rdata_sel_n`, `alu_operand`)
2. Milestones were reached (2/4)
3. Sliding window advanced to near-final milestone
4. Deferred violation mechanism reported "violation"

**Problem**: The p10 assertion was checked, not the target assertion.

**Evidence**: Counterexample shows RISC-V signals, but assertion is JTAG.

#### Type 3: Wrong Bug Found (p16)

**Why it succeeded**: Actually found p10's bug

**Evidence**: Log explicitly shows:
```
Violated assertion: (passchk == 1) |-> (bitindex == 32)
bitindex = 4294967263, passchk = 1
```

**Problem**: Found p10 bug instead of p16 bug.

### Timeout Analysis

**p3, p4, p5, p9, p13, p27** timed out because:
- Milestones were defined for bug X
- Assertion checked was for bug Y (p10)
- Milestone-directed search explored states relevant to bug X
- But bug Y's assertion never fired in those states
- Exploration continued until 300s timeout

**Example (p4)**:
- Milestone 2: `r_gpio_lock == 0x12345678` (GPIO lock register)
- Assertion: `(passchk == 1) |-> (bitindex == 32)` (JTAG password)
- Explored 57,475 paths trying to reach GPIO milestone
- JTAG assertion never fired → timeout

**p10** (valid timeout):
- Checked correct assertion (p10 = p10)
- Explored 101,635 paths
- Reached milestone 0/3 (reset released)
- Never reached milestone 1 (bitindex > 0)
- **Conclusion**: p10 requires JTAG protocol sequence

---

## The Fix

### Code Changes

Updated `run_hackatdac18.sh` (lines 14-57):

```python
# Strip leading whitespace+comment prefix to find property declarations
stripped = re.sub(r'^[\s/]*', '', line)
m = re.match(r'(HACKDAC_\w+)\s*:\s*(assert|cover)\s+property\s*\(', stripped)

if m:
    prop_name = m.group(1)
    # Collect the full block until paren depth returns to 0
    block_raw = [line]
    depth = stripped.count('(') - stripped.count(')')
    j = i + 1
    while j < len(lines) and depth > 0:
        block_raw.append(lines[j])
        s = re.sub(r'^[\s/]*', '', lines[j])
        depth += s.count('(') - s.count(')')
        j += 1

    if prop_name == target:
        # Uncomment every line: strip leading //\s* prefix
        out.extend(re.sub(r'^(\s*)//\s?', r'\1', bl) for bl in block_raw)
    else:
        # Ensure every line is commented out
        def ensure_commented(bl):
            core = re.sub(r'^(\s*)//\s?', r'\1', bl)
            indent = re.match(r'^(\s*)', core).group(1)
            rest = core[len(indent):]
            return indent + '// ' + rest
        out.extend(ensure_commented(bl) for bl in block_raw)
```

### Validation

Tested on 7 targets — each correctly uncomments only its own property:

```
HACKDAC_p3: uncommented=['HACKDAC_p3']   ✓
HACKDAC_p4: uncommented=['HACKDAC_p4']   ✓
HACKDAC_p6: uncommented=['HACKDAC_p6']   ✓
HACKDAC_p9: uncommented=['HACKDAC_p9']   ✓
HACKDAC_p10: uncommented=['HACKDAC_p10'] ✓
HACKDAC_p16: uncommented=['HACKDAC_p16'] ✓
HACKDAC_p27: uncommented=['HACKDAC_p27'] ✓
```

---

## Next Steps

### 1. Re-run Benchmarks

```bash
cd /home/ljh/haveFun/sybolicExecution/sylvia-related/siu/HWLoopSe
./run_hackatdac18.sh
```

**Expected runtime**: ~95 minutes (19 problems × 300s timeout)

**Output**: Logs in `/tmp/hackdac_v6/` or `logs/hackatdac18/`

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

### 4. Milestone Improvements

For timed-out problems, consider:
- **Reset protocol**: Add explicit reset cycle (cycle 0: reset=0, cycle 1+: reset=1)
- **Feasibility checks**: Verify milestones are reachable given COI
- **Protocol-aware milestones**: For JTAG/APB/CSR, add intermediate state milestones
- **Register write semantics**: For p4/p5, investigate why `r_gpio_lock` can't be written

---

## Key Lessons

1. **Always verify assertions match targets** — don't trust the script
2. **Check log files for actual assertion text** — milestone JSON ≠ assertion
3. **False positives from deferred violations** — sliding window + wrong assertion
4. **COI seeds ≠ correct assertion** — COI uses milestones, assertion is separate
5. **Test property isolation before running** — verify uncommented properties

---

## Files Modified

- `run_hackatdac18.sh`: Fixed `isolate_property()` function (lines 14-57)

## Documentation Created

- `docs/hackdac18_v5_analysis.md`: Timeout pattern analysis
- `docs/hackdac18_v5_bug_fix.md`: Bug fix documentation
- `docs/hackdac18_v5_summary.md`: Comprehensive summary
- `docs/0424_hackdac18_v5_findings.md`: Detailed findings
- `docs/hackdac18_v5_complete_analysis.md`: This file

---

## Status

- [x] Analyzed v5 logs from `/tmp/hackdac_v5`
- [x] Identified root cause (wrong assertions checked)
- [x] Fixed `run_hackatdac18.sh` to handle commented properties
- [x] Validated fix on 7 targets
- [x] Documented findings comprehensively
- [ ] Re-run benchmarks with correct assertions
- [ ] Analyze corrected results
- [ ] Update memory with lessons learned
