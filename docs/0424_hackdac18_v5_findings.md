# HackAtDAC18 v5 Analysis - Critical Findings

**Date**: 2026-04-24  
**Analyst**: Claude Opus 4.7  
**Branch**: bmc_hallu  
**Commit**: 4fbd0a6

## Executive Summary

Analysis of the v5 benchmark run revealed that **all 12 problems were checking the wrong assertion**. The `run_hackatdac18.sh` script failed to uncomment target properties, causing every run to check `HACKDAC_p10`'s JTAG password assertion regardless of the milestone JSON target.

**Impact**: All v5 results except p10 are invalid. The 5 "successful" cases (p6, p8, p11, p14, p16) are false positives.

**Fix**: Updated `run_hackatdac18.sh` to handle commented-out properties. Ready for corrected re-run.

## Detailed Findings

### 1. Root Cause Analysis

**Problem**: The `isolate_property()` function only matched uncommented property blocks:
```python
# Original (broken)
m = re.match(r'^(\s*)(HACKDAC_\w+)\s*:\s*(assert|cover)\s+property\s*\(', line)
```

Since `properties.sv` had all properties commented out except `HACKDAC_p10`, the regex never matched commented properties, so they were never uncommented.

**Fix**: Strip comment prefix before matching:
```python
# Fixed
stripped = re.sub(r'^[\s/]*', '', line)
m = re.match(r'(HACKDAC_\w+)\s*:\s*(assert|cover)\s+property\s*\(', stripped)
```

### 2. Evidence from Logs

Extracted actual assertions from log files:

| Problem | Milestone JSON Target | Actual Assertion in Log |
|---------|----------------------|------------------------|
| p3 | `priv_lvl_n == 2'b11 && mstatus_n.mpp == 2'b00` | `(passchk == 1) \|-> (bitindex == 32)` |
| p4 | `PWDATA == 0x12345678 && s_apb_addr == 5'b10010 && r_gpio_lock == 0x12345678` | `(passchk == 1) \|-> (bitindex == 32)` |
| p6 | `GPIO_START_ADDR == 0x1A101000 && GPIO_END_ADDR == 0x1A101FFF` | `(passchk == 1) \|-> (bitindex == 32)` |
| p16 | `trstn_pad_i == 0 && correct != 0` | `(passchk == 1) \|-> (bitindex == 32)` |

All 12 problems checked the same p10 assertion.

### 3. False Positive Analysis

#### p6, p8 (GPIO Address Constants)
- **Why they "succeeded"**: Violations are unconditional constants
  - p6: `32'h1A10AFFF != 32'h1A101FFF` → always TRUE
  - p8: `32'h1A10AFFF > 32'h1A102000` → always TRUE
- **Mechanism**: Constant-only assertions fire immediately at cycle 0
- **Result**: Found violations in ~10s, but for wrong reasons

#### p11, p14 (Debug Unit, ALU Bugs)
- **Why they "succeeded"**: Deferred violation + sliding window
- **Mechanism**:
  1. COI extracted seeds from milestone JSON (`dbg_halt`, `rdata_sel_n`, `alu_operand`)
  2. Milestones were reached (milestone 2/3)
  3. Sliding window advanced to near-final milestone
  4. Deferred violation mechanism reported "violation"
- **Problem**: The p10 assertion was checked, not the target assertion
- **Counterexample**: Shows RISC-V signals, but assertion is JTAG

#### p16 (JTAG Reset Bug)
- **Why it "succeeded"**: Actually found p10's bug
- **Evidence**: Log explicitly shows:
  ```
  Violated assertion: (passchk == 1) |-> (bitindex == 32)
  bitindex = 4294967263, passchk = 1
  ```
- **Result**: Found p10 bug instead of p16 bug

### 4. Timeout Analysis

**p3, p4, p5, p9, p10, p13, p27** all timed out because:
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

### 5. Valid Result

**Only p10's result is valid**:
- Checked the correct assertion (p10 = p10)
- Timed out after exploring 101,635 paths
- Reached milestone 0/3 (reset released)
- Never reached milestone 1 (bitindex > 0)
- **Conclusion**: p10 is hard — requires JTAG protocol sequence

## Fix Validation

Tested the fixed script on 7 targets:

```bash
$ python3 test_isolate.py
HACKDAC_p3: uncommented=['HACKDAC_p3']   ✓
HACKDAC_p4: uncommented=['HACKDAC_p4']   ✓
HACKDAC_p6: uncommented=['HACKDAC_p6']   ✓
HACKDAC_p9: uncommented=['HACKDAC_p9']   ✓
HACKDAC_p10: uncommented=['HACKDAC_p10'] ✓
HACKDAC_p16: uncommented=['HACKDAC_p16'] ✓
HACKDAC_p27: uncommented=['HACKDAC_p27'] ✓
```

Each target correctly uncomments only its own property.

## Recommendations for Re-Run

### 1. Immediate Actions
- [x] Fix `run_hackatdac18.sh` to handle commented properties
- [ ] Re-run full benchmark suite (19 problems, 300s timeout each)
- [ ] Compare new results to identify truly solvable bugs

### 2. Expected Outcomes

**Likely to succeed** (based on milestone simplicity):
- p6, p8: Constant violations (should still succeed)
- p16: Simple JTAG reset check (may succeed with correct assertion)

**Likely to timeout** (based on v5 milestone analysis):
- p4, p5: GPIO lock register bugs (milestone 2 unreachable)
- p9, p10: JTAG password bugs (require protocol sequence)
- p3, p13, p27: RISC-V core bugs (require instruction execution)

**Unknown**:
- p11, p14: Debug unit and ALU bugs (need correct assertion to evaluate)

### 3. Post-Run Analysis

After re-run, analyze:
1. **New successes**: Which bugs are actually solvable?
2. **New timeouts**: Are they due to:
   - Unreachable milestones?
   - Path explosion?
   - Solver performance?
   - Incorrect milestone definitions?
3. **Counterexamples**: Validate that violations match the target bug

### 4. Milestone Improvements

For timed-out problems, consider:
- **Reset protocol**: Add explicit reset cycle (cycle 0: reset=0, cycle 1+: reset=1)
- **Feasibility checks**: Verify milestones are reachable given COI
- **Protocol-aware milestones**: For JTAG/APB/CSR, add intermediate state milestones
- **Register write semantics**: For p4/p5, investigate why `r_gpio_lock` can't be written

## Files Modified

- `run_hackatdac18.sh`: Fixed `isolate_property()` (lines 14-57)

## Files Created

- `docs/hackdac18_v5_analysis.md`: Timeout pattern analysis
- `docs/hackdac18_v5_bug_fix.md`: Bug fix documentation
- `docs/hackdac18_v5_summary.md`: Comprehensive summary
- `docs/0424_hackdac18_v5_findings.md`: This file

## Next Steps

1. **Run**: `./run_hackatdac18.sh` with fixed script
2. **Monitor**: Check logs in real-time for correct assertions
3. **Analyze**: Compare v5 vs v6 results
4. **Document**: Update findings based on corrected results
5. **Memory**: Save lessons learned about property isolation

## Lessons Learned

1. **Always verify the assertion being checked** — don't trust the script
2. **Check log files for actual assertion text** — milestone JSON ≠ assertion
3. **False positives from deferred violations** — sliding window can trigger spurious violations
4. **COI seeds ≠ correct assertion** — COI uses milestones, assertion is separate
5. **Test property isolation** — verify uncommented properties before running benchmarks
