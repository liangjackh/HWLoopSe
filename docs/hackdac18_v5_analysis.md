# HackAtDAC18 v5 Results Analysis

**Date**: 2026-04-24  
**Commit**: 4fbd0a6 (Fix p6/p8: Add second fallback for constant-only assertions)

## CRITICAL FINDING: Wrong Assertions Being Checked

**ALL problems were checking the same assertion**: `(passchk == 1) |-> (bitindex == 32)` (HACKDAC_p10's JTAG password bug)

**Root cause**: In `properties.sv`, only `HACKDAC_p10` is uncommented. All other properties are commented out with `//`. The `isolate_property()` script in `run_hackatdac18.sh` only works on **already-uncommented** properties — it comments out non-target properties but doesn't uncomment commented-out ones.

**Impact**: The milestone-directed search was trying to reach milestones for bug X while checking the assertion for bug Y. This explains:
- Why p4/p5 (GPIO bugs) never reached their milestones — they were checking JTAG assertions
- Why p3/p27 (CSR bugs) got stuck — they were checking JTAG assertions
- Why p6/p8 succeeded — their violations are unconditional constants, so the wrong assertion still fired
- Why p11/p14/p16 succeeded — unclear, need investigation

**Fix applied**: Updated `run_hackatdac18.sh` to handle commented-out properties. The `isolate_property()` script now:
1. Detects property blocks whether commented or uncommented
2. Uncomments the target property
3. Ensures all other properties are commented out

**Next step**: Re-run the benchmark suite with the fixed script to get accurate results.

## Summary

| Problem | Status | Time(s) | Paths | Milestones | Issue |
|---------|--------|---------|-------|------------|-------|
| p3 | TIMEOUT | 300+ | 801 | 0/3 | Milestone 0 never reached |
| p4 | TIMEOUT | 300+ | 57,475 | 1/4 | Stuck at milestone 1, can't reach milestone 2 |
| p5 | TIMEOUT | 300+ | 58,167 | 0/3 | Milestone 1 never reached |
| **p6** | **VIOLATION** | **9.7s** | **2** | **0/2** | ✓ **SOLVED** |
| **p8** | **VIOLATION** | **9.8s** | **2** | **0/2** | ✓ **SOLVED** |
| p9 | TIMEOUT | 300+ | 101,637 | 0/3 | Milestone 1 never reached (JTAG bitindex) |
| p10 | TIMEOUT | 300+ | 101,635 | 0/3 | Milestone 1 never reached (JTAG correct counter) |
| **p11** | **VIOLATION** | **14.8s** | **4** | **2/3** | ✓ **SOLVED** |
| p13 | TIMEOUT | 300+ | 717 | 0/5 | Milestone 1 never reached |
| **p14** | **VIOLATION** | **14.8s** | **4** | **2/3** | ✓ **SOLVED** |
| **p16** | **VIOLATION** | **9.8s** | **4** | **0/2** | ✓ **SOLVED** |
| p27 | TIMEOUT | 300+ | 855 | 1/4 | Stuck at milestone 1 |

**Success Rate**: 5/12 (41.7%)  
**Solved**: p6, p8, p11, p14, p16  
**Timeouts**: p3, p4, p5, p9, p10, p13, p27

## Root Cause Analysis

### Category 1: Milestone 0 Never Reached (p3, p5, p13)

**p3**: Milestone 0 is `rstn_top == 1` (reset released)
- Violation fires at cycle 0 with `milestones=0/3`
- Milestone check never reports "Step 0 REACHED"
- **Root cause**: Milestone condition is likely FALSE at cycle 0 (reset is still asserted)
- All paths get suppressed, none advance milestones

**p5**: Milestone 0 is `rstn_top == 1 && HRESETn == 1`
- Only 3 milestone checks total in 300s
- **Root cause**: Same as p3 - reset signals not asserted at cycle 0

**p13**: Milestone 0 is `rstn_top == 0` (reset applied)
- Only 1 milestone check: "Step 0 REACHED" at start
- Milestone 1 is `rstn_top == 1 && ctrl_fsm_ns == 5'b00000`
- **Root cause**: Controller FSM never reaches RESET state (5'b00000)

### Category 2: Stuck at Intermediate Milestone (p4, p27)

**p4**: GPIO lock register bug
- Milestones: 0→1→2→3 (reset → APB write → lock=0x12345678 → violation)
- Reaches milestone 1 (APB write to lock register) 9 times
- **Never reaches milestone 2**: `r_gpio_lock == 32'h12345678`
- Explored 57k paths at cycle 8, all stuck at milestones=2/4
- **Root cause**: The write to `r_gpio_lock` is conditional on `r_gpio_lock[0] == '0`
  - Once lock bit 0 is set, register becomes read-only
  - Milestone 2 requires exact value 0x12345678, but paths can't satisfy this
  - Need to write 0x12345678 in a SINGLE transaction, but APB protocol or register logic prevents this

**p27**: CSR interrupt register bug
- Milestones: 0→1→2→3 (reset applied → reset released → CSR write → violation)
- Reaches milestone 0 once, then milestone 1 once
- Stuck at milestones=1/4 for all 855 paths
- **Never reaches milestone 2**: `csr_we_int == 1` (CSR write enable)
- **Root cause**: CSR write enable signal never asserts
  - Likely requires specific instruction decode + privilege level
  - RISC-V core not executing instructions that trigger CSR writes

### Category 3: JTAG Password Check (p9, p10)

**p9**: JTAG password check (bitindex != 32)
- Milestone 1: `bitindex > 0 && bitindex < 32`
- Explored 101k paths, never reaches milestone 1
- **Root cause**: JTAG TAP state machine not advancing
  - `bitindex` is a counter in the password checker
  - Requires specific JTAG protocol sequence (TMS/TDI transitions)
  - Symbolic execution not finding the right input sequence

**p10**: Similar to p9, different milestone condition
- Milestone 1: `correct > 0 && bitindex > 0`
- Same root cause: JTAG protocol not being driven correctly

## Successful Cases Analysis

### p6, p8: GPIO address range bugs
- **Why they work**: Violations are UNCONDITIONAL at cycle 0
- Milestone 0 reached (reset applied), then sliding window triggers deferred violation
- No complex state machine or protocol required
- Constant-only assertions (no free variables in Z3 model)

### p11, p14: Similar bugs (likely duplicates)
- Both complete in ~15s with 4 paths
- Reach milestone 2/3 before finding violation at cycle 1
- Moderate complexity, but milestones are reachable

### p16: Unconditional violation
- Completes in ~10s with 4 paths
- Violation at cycle 1 with no path constraints
- Similar to p6/p8 pattern

## Key Insights

1. **Milestone reachability is the bottleneck**
   - 7/12 problems timeout because intermediate milestones are unreachable
   - Not a path explosion problem (p3 only explores 801 paths in 300s)
   - Not a solver performance problem (p9/p10 explore 100k+ paths efficiently)

2. **Reset signal timing issues**
   - p3, p5: Expect `rstn_top == 1` at cycle 0, but reset is still asserted
   - Need to model reset protocol correctly (assert reset, then release)

3. **Complex protocol requirements**
   - p9, p10: JTAG requires specific TMS/TDI sequences
   - p27: CSR writes require instruction decode + privilege checks
   - p4: APB write protocol + register lock semantics

4. **Successful cases share common traits**
   - Violations are unconditional or nearly unconditional
   - Milestones are simple signal checks, not protocol states
   - Bugs manifest early (cycle 0-1)

## Recommendations

### Fix 1: Reset Protocol Modeling
For p3, p5, p13 - add explicit reset cycle:
- Cycle 0: Assert reset (`rstn_top == 0`)
- Cycle 1+: Release reset (`rstn_top == 1`)
- Update milestone definitions to match this protocol

### Fix 2: Milestone Feasibility Check
Before starting exploration:
- Check if each milestone is satisfiable given the COI
- Warn if milestone requires signals not in relevant CFGs
- Example: p27 milestone 2 requires `csr_we_int`, but CSR module may not be in COI

### Fix 3: Protocol-Aware Input Generation
For p9, p10 (JTAG):
- Add JTAG protocol constraints to guide input generation
- Or: Add intermediate milestones for JTAG state transitions
- Example: Milestone 1a: TAP in SHIFT-DR state, Milestone 1b: bitindex > 0

### Fix 4: Register Write Semantics
For p4:
- Analyze why `r_gpio_lock == 0x12345678` is unreachable
- Check if milestone 2 should be "lock register written" instead of "lock == magic value"
- May need to model APB write protocol more carefully

## Next Steps

1. **Investigate p4 register write**: Why can't we write 0x12345678 to r_gpio_lock?
2. **Fix reset protocol**: Update p3, p5, p13 milestone definitions
3. **Add milestone feasibility checks**: Detect unreachable milestones early
4. **Consider protocol-specific strategies**: JTAG, APB, CSR writes need special handling
