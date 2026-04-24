# HackAtDAC18 v5 Analysis Summary

**Date**: 2026-04-24  
**Branch**: bmc_hallu  
**Commit**: 4fbd0a6 (Fix p6/p8: Add second fallback for constant-only assertions)

## Critical Finding: Wrong Assertions Checked

**All 12 benchmarks checked the same assertion** (`HACKDAC_p10`: JTAG password bug) regardless of their milestone JSON targets.

### Root Cause

The `isolate_property()` script in `run_hackatdac18.sh` only handled uncommented property blocks. Since `properties.sv` had all properties commented out except `HACKDAC_p10`, the script failed to uncomment the target property for each run.

### Evidence

```
Problem | JSON Target                    | Actual Assertion Checked
--------|--------------------------------|-------------------------
p3      | CSR privilege level bug        | JTAG password (p10)
p4      | GPIO lock register bug         | JTAG password (p10)
p5      | GPIO reset bug                 | JTAG password (p10)
p6      | GPIO address range constant    | JTAG password (p10)
p8      | GPIO/UDMA overlap constant     | JTAG password (p10)
p9      | JTAG password bug (variant)    | JTAG password (p10)
p10     | JTAG password bug              | JTAG password (p10) ✓
p11     | Debug unit halt bug            | JTAG password (p10)
p13     | Controller FSM loop bug        | JTAG password (p10)
p14     | ALU vector mode bug            | JTAG password (p10)
p16     | JTAG reset bug                 | JTAG password (p10)
p27     | CSR secure mode bug            | JTAG password (p10)
```

### Why Some "Succeeded"

**p6, p8** (GPIO address constants):
- Violations are unconditional: `32'h1A10AFFF != 32'h1A101FFF` evaluates to TRUE
- The wrong assertion also fired because constants are always violated
- **False positives** — succeeded for wrong reasons

**p11, p14** (debug unit, ALU bugs):
- COI extracted seeds from milestone JSON (`dbg_halt`, `rdata_sel_n`, `alu_operand`)
- Milestones were reached via sliding window
- Deferred violation mechanism reported "violation" at milestone 3/4
- **False positives** — the p10 assertion was checked, not the target assertion

**p16** (JTAG reset bug):
- Explicitly shows it violated the p10 assertion: `passchk == 1 && bitindex != 32`
- Counterexample: `bitindex = 4294967263, passchk = 1`
- **False positive** — found p10 bug, not p16 bug

### Why Others Timed Out

**p3, p4, p5, p9, p10, p13, p27**:
- Milestones were for bug X, but assertion checked was for bug Y (p10)
- Milestone-directed search tried to reach states relevant to bug X
- But the assertion for bug Y never fired in those states
- Exploration continued until timeout

## Fix Applied

Updated `run_hackatdac18.sh` to handle commented-out properties:

```python
# Before: only matched uncommented properties
m = re.match(r'^(\s*)(HACKDAC_\w+)\s*:\s*(assert|cover)\s+property\s*\(', line)

# After: strip comment prefix first, then match
stripped = re.sub(r'^[\s/]*', '', line)
m = re.match(r'(HACKDAC_\w+)\s*:\s*(assert|cover)\s+property\s*\(', stripped)

# Uncomment target property
if prop_name == target:
    out.extend(re.sub(r'^(\s*)//\s?', r'\1', bl) for bl in block_raw)
```

## Validation

Tested the fix on 7 targets — each correctly uncomments only its own property:
```
HACKDAC_p3: uncommented=['HACKDAC_p3']   ✓
HACKDAC_p4: uncommented=['HACKDAC_p4']   ✓
HACKDAC_p6: uncommented=['HACKDAC_p6']   ✓
HACKDAC_p9: uncommented=['HACKDAC_p9']   ✓
HACKDAC_p10: uncommented=['HACKDAC_p10'] ✓
HACKDAC_p16: uncommented=['HACKDAC_p16'] ✓
HACKDAC_p27: uncommented=['HACKDAC_p27'] ✓
```

## Invalid Results from v5 Run

| Problem | v5 Result | Actual Status |
|---------|-----------|---------------|
| p3      | TIMEOUT   | Unknown (wrong assertion) |
| p4      | TIMEOUT   | Unknown (wrong assertion) |
| p5      | TIMEOUT   | Unknown (wrong assertion) |
| p6      | VIOLATION | False positive (constant) |
| p8      | VIOLATION | False positive (constant) |
| p9      | TIMEOUT   | Unknown (wrong assertion) |
| p10     | TIMEOUT   | Valid (correct assertion) |
| p11     | VIOLATION | False positive (deferred) |
| p13     | TIMEOUT   | Unknown (wrong assertion) |
| p14     | VIOLATION | False positive (deferred) |
| p16     | VIOLATION | False positive (found p10) |
| p27     | TIMEOUT   | Unknown (wrong assertion) |

**Only p10's result is valid** — it checked the correct assertion and timed out.

## Next Steps

1. **Re-run the full benchmark suite** with the fixed `run_hackatdac18.sh`
2. **Compare results** to identify which bugs are actually solvable
3. **Analyze new timeouts** to determine if they're due to:
   - Unreachable milestones
   - Path explosion
   - Solver performance
   - Incorrect milestone definitions
4. **Update memory** with lessons learned

## Lessons Learned

1. **Always verify assertions match targets** — don't assume the script works correctly
2. **Check log files for actual assertion text** — the milestone JSON target is not what gets checked
3. **False positives from deferred violations** — sliding window + wrong assertion can produce spurious violations
4. **COI seeds don't guarantee correct assertion** — COI extracts from milestones, but assertion is separate

## Files Modified

- `run_hackatdac18.sh`: Fixed `isolate_property()` Python script (lines 14-57)

## Files Created

- `docs/hackdac18_v5_analysis.md`: Detailed analysis of timeout patterns
- `docs/hackdac18_v5_bug_fix.md`: Bug fix documentation
- `docs/hackdac18_v5_summary.md`: This file
