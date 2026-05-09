# HackAtDAC18 v6 Analysis

**Date**: 2026-04-26
**Branch**: bmc_hallu
**Commit**: 4fbd0a6 (Fix p6/p8: Add second fallback for constant-only assertions)
**Logs**: `logs/hackatdac18/` (generated 2026-04-23)

---

## Executive Summary

The v6 logs reveal that **all 12 benchmarks are still checking the wrong assertion** — the same p10 JTAG password assertion `(passchk == 1) |-> (bitindex == 32)`. The `run_hackatdac18.sh` property isolation fix was committed *after* these logs were generated (commit 4fbd0a6 is the same day, but the logs predate it). The v6 run with the corrected script has not yet been executed.

**Impact**: The v6 logs are structurally identical to v5 in terms of assertion correctness. The only real change is the p6/p8 COI fix (second fallback for constant-only seeds), which reduced their CFG count from 340 to 1 and cut runtime from timeout to ~10s.

---

## Results Table

| Problem | Status | Time(s) | Paths | Milestones | Assertion Checked | Valid? |
|---------|--------|---------|-------|------------|-------------------|--------|
| p3 | TIMEOUT | 300+ | 173 | 2/4 | p10 (passchk/bitindex) | No |
| p4 | TIMEOUT | 300+ | 29,073 | 3/5 | p10 (passchk/bitindex) | No |
| p5 | TIMEOUT | 300+ | 27,909 | 2/4 | p10 (passchk/bitindex) | No |
| **p6** | **VIOLATION** | **9.8** | **1** | **0/2** | **p10 (constant fires)** | **False positive** |
| **p8** | **VIOLATION** | **9.7** | **1** | **0/2** | **p10 (constant fires)** | **False positive** |
| p9 | TIMEOUT | 300+ | 28,305 | 2/4 | p10 (passchk/bitindex) | No |
| p10 | TIMEOUT | 300+ | 28,337 | 2/4 | p10 (passchk/bitindex) | No (stuck) |
| **p11** | **VIOLATION** | **15.1** | **2** | **1/4** | **p10 (deferred)** | **False positive** |
| p13 | TIMEOUT | 300+ | 173 | 2/5 | p10 (passchk/bitindex) | No |
| **p14** | **VIOLATION** | **15.0** | **2** | **1/4** | **p10 (deferred)** | **False positive** |
| **p16** | **VIOLATION** | **9.7** | **2** | **1/4** | **p10 (unconditional)** | **False positive** |
| p27 | TIMEOUT | 300+ | 172 | 2/4 | p10 (passchk/bitindex) | No |

**Success rate**: 5/12 (41.7%) — all false positives  
**Valid results**: 0/12

---

## v5 vs v6 Comparison

| Metric | v5 | v6 | Change |
|--------|----|----|--------|
| Violations | 5 | 5 | 0 |
| Timeouts | 7 | 7 | 0 |
| Valid violations | 0 | 0 | 0 |
| p6/p8 CFGs | 340 | 1 | **-339** |
| p6/p8 time | TIMEOUT (300s) | ~10s | **-290s** |
| p4 paths explored | 57,475 | 29,073 | -28k |
| p9/p10 paths explored | ~101k | ~28k | -73k |

The only meaningful change between v5 and v6 is the COI fix for p6/p8: the second fallback seeds `top_wrapper` when `seed_signals` is empty, allowing COI to prune 340 CFGs down to 1 (`jg_bind_inst`). This is why p6/p8 now complete in ~10s instead of timing out.

The reduction in paths for p4/p9/p10 is likely due to the `MAX_PATHS_PER_CFG=100` cap added in cfg.py (commit ef4b710), which limits path explosion in the JTAG TAP and GPIO modules.

---

## Detailed Analysis

### Category 1: False Positives — Constant Violations (p6, p8)

Both complete in ~10s with 1 path, 0/2 milestones.

**Mechanism**:
- COI prunes to `jg_bind_inst` only (1 CFG, 1 path)
- The assertion `(passchk == 1) |-> (bitindex == 32)` fires at cycle 0 with no free variables
- Deferred violation mechanism: violation suppressed at cycle 0, milestone 0 reached, sliding window advances to 1/2, deferred violation reported
- Counterexample: "violation is unconditional (no free variables)"

**Why it's a false positive**: p6 and p8 are GPIO address range bugs. The p10 assertion fires unconditionally because `passchk` and `bitindex` are unconstrained fresh Z3 variables — the JTAG module is not in COI, so they have no constraints. The violation says nothing about the actual GPIO bug.

**What changed from v5**: In v5, p6/p8 also fired as false positives but took 300s (340 CFGs). In v6, the COI fix reduces to 1 CFG, so they fire in 10s. Same false positive, much faster.

---

### Category 2: False Positives — Deferred Violations (p11, p14, p16)

All three complete in ~10-15s with 2 paths.

**p11** (debug unit halt bug):
- COI: full RISC-V core (22 instances, 262 paths/cycle)
- Cycle 0: path 1 executes, milestones=0/4
- Cycle 1: p10 assertion fires at `jg_bind_inst/cfg0/path0`, suppressed (milestones=1/4)
- Milestone 2 reached: "Core not in halt mode (dbg_halt == 0)"
- Sliding window skips hallucinated milestone 1 → advances to 3/4
- Deferred violation reported
- Counterexample shows RISC-V signals (alu_operand, debug_req, etc.) — unrelated to p11's actual bug

**p14** (ALU vector mode bug):
- Identical mechanism to p11
- Milestone 2 reached: "ALU receives a vector mode instruction (VEC_MODE16 or VEC_MODE8)"
- Same deferred violation pattern, same p10 assertion in counterexample

**p16** (JTAG reset bug):
- COI: `jg_bind_inst` only (1 CFG, 1 path)
- Cycle 1: p10 assertion fires with no path constraints → `[Unconditional]` path, reported immediately
- Counterexample: `bitindex = 4294967263, passchk = 1`
- This is the same p10 bug (bitindex = 0xFFFFFFE0 = -32 in signed, not 32)

**Root cause for all three**: The p10 assertion is unconditional or near-unconditional because `passchk` and `bitindex` are unconstrained. Any path that reaches `jg_bind_inst` will fire it.

---

### Category 3: Timeouts — JTAG Protocol (p9, p10)

Both explore ~28k paths over 300s, reaching milestone 2/4.

**Milestone progress**:
- Step 0 ✓: `rstn_top == 0` (reset applied)
- Step 1 ✓: `rstn_top == 1 && trstn_pad_i == 1` (reset released)
- Step 2 ✗: `bitindex > 0 && bitindex < 32` (password check in progress) — never reached
- Step 3 ✗: violation — never reached

**COI**: `adbg_tap_top` + `jg_bind_inst` (47 paths/cycle)

**Root cause**: The JTAG TAP state machine requires a specific TMS/TDI sequence to advance `bitindex`. The symbolic execution explores all 47 CFG paths per cycle but none of them increment `bitindex` past 0. The JTAG shift register logic likely requires:
1. TAP to enter SHIFT-DR state (specific TMS sequence)
2. TDI clocked in for each bit

The milestone-directed search has no protocol-level guidance to find this sequence. After 28k paths × 7 cycles, it has never seen `bitindex > 0`.

**Note**: p9 and p10 are checking the same assertion (p10's) with different milestone conditions. Neither is checking its own assertion.

---

### Category 4: Timeouts — GPIO Protocol (p4, p5)

Both explore ~28k paths over 300s.

**p4** (GPIO lock register):
- COI: `apb_gpio` + `jg_bind_inst` (4 paths/cycle)
- Milestone progress: 0 ✓, 1 ✗ (reset released + HRESETn), 2 ✓ (APB write to lock addr), 3 ✗ (r_gpio_lock == 0x12345678)
- Stuck at 3/5 milestones — milestone 3 requires `r_gpio_lock == 32'h12345678`

**Root cause for p4**: The APB write reaches the lock register address (milestone 2), but `r_gpio_lock` never takes the value `0x12345678`. The register has a lock bit: once `r_gpio_lock[0]` is set, writes are blocked. The symbolic execution can write any value, but the milestone requires the exact magic value. The path condition likely becomes UNSAT when trying to satisfy both "write succeeded" and "value == 0x12345678" simultaneously, because the register logic prevents it.

**p5** (GPIO reset persistence):
- COI: `apb_gpio` + `jg_bind_inst` (4 paths/cycle)
- Milestone progress: 0 ✓, 1 ✓ (reset released + HRESETn), 2 ✗ (r_gpio_lock != 0)
- Stuck at 2/4 — milestone 2 requires a non-zero write to `r_gpio_lock`

**Root cause for p5**: Similar to p4 — the APB write to `r_gpio_lock` is not producing a non-zero value in the symbolic store. The 4 CFG paths in `apb_gpio` may not include the write path, or the write path is being abandoned (UNSAT).

---

### Category 5: Timeouts — RISC-V Core (p3, p13, p27)

All three explore ~173 paths over 300s, reaching milestone 2/4 or 2/5.

**COI**: Full RISC-V core (22 instances, 262 paths/cycle)

**p3** (CSR privilege level):
- Milestone 2 ✗: `csr_we_int == 1` (CSR write enable)
- The CSR write enable signal never asserts in any explored path
- Requires: instruction decode → privilege check → CSR write → specific register update

**p13** (controller FSM loop):
- Milestone 2 ✗: `ctrl_fsm_ns == 5'b00001` (BOOT_SET state)
- Controller FSM never transitions from RESET (5'b00000) to BOOT_SET (5'b00001)
- Requires: specific instruction fetch + decode sequence

**p27** (CSR interrupt register):
- Milestone 2 ✗: `csr_we_int == 1` (same as p3)
- Same root cause: CSR write enable never asserts

**Common root cause**: The RISC-V core requires instruction execution to advance its internal state machines. Symbolic execution explores all 262 CFG paths per cycle but the instruction fetch/decode pipeline never produces a valid instruction that triggers CSR writes or FSM transitions. The `instr_rdata_i` input is symbolic but the decoder logic may require specific encodings that the path-directed search doesn't find.

---

## Key Findings

### Finding 1: v6 logs are pre-fix

The logs in `logs/hackatdac18/` were generated on 2026-04-23 at 15:07, before the property isolation fix was validated. All 12 problems still check the p10 assertion. The `docs/hackdac18_v6_results.md` document was a forward-looking projection, not a post-run analysis.

### Finding 2: COI fix works correctly for p6/p8

The second fallback (seed `top_wrapper` when `seed_signals` is empty) correctly prunes 340 CFGs to 1 for constant-only assertions. This is the only real improvement in v6.

### Finding 3: Deferred violation mechanism creates false positives

The sliding window + deferred violation mechanism fires whenever:
1. Any assertion violation occurs (even from wrong assertion)
2. Milestones advance via hallucination skip

For p11/p14, the milestone-directed search reaches real milestones (dbg_halt, VEC_MODE) because those signals are in the RISC-V COI. But the assertion being checked is p10's, not p11/p14's. The deferred violation reports a counterexample that is meaningless for the target bug.

### Finding 4: Milestone 2 is the universal bottleneck

Every timeout case fails at milestone 2:
- p3/p27: `csr_we_int == 1` — CSR write never triggered
- p4: `r_gpio_lock == 0x12345678` — magic value write blocked
- p5: `r_gpio_lock != 0` — any non-zero write blocked
- p9/p10: `bitindex > 0` — JTAG shift register never clocked
- p13: `ctrl_fsm_ns == BOOT_SET` — FSM never transitions

The pattern is consistent: milestone 1 (reset released) is always reachable, but milestone 2 requires protocol-level behavior that symbolic execution doesn't find.

---

## Root Cause Summary

| Problem | Stuck At | Root Cause |
|---------|----------|------------|
| p3, p27 | Milestone 2 | `csr_we_int` requires instruction decode + privilege check |
| p4 | Milestone 3 | `r_gpio_lock == 0x12345678` blocked by lock bit semantics |
| p5 | Milestone 2 | `r_gpio_lock != 0` — APB write path not explored |
| p9, p10 | Milestone 2 | `bitindex > 0` requires JTAG TAP state machine sequence |
| p13 | Milestone 2 | `ctrl_fsm_ns == BOOT_SET` requires instruction fetch |
| p6, p8 | — | Constant violation fires immediately (wrong assertion) |
| p11, p14 | — | Deferred violation from wrong assertion + milestone hallucination |
| p16 | — | Unconditional violation from wrong assertion |

---

## Recommendations

### Immediate: Run v6 with correct assertions

The property isolation fix is in place. The corrected run will produce valid results for the first time. Expected outcomes based on the milestone analysis:

- **Will likely succeed**: p6, p8 (constant violations, COI already fixed)
- **May succeed**: p16 (simple JTAG reset check, 1-2 cycles)
- **Will timeout**: p3, p5, p9, p10, p13, p27 (protocol-level milestones unreachable)
- **Unknown**: p4, p11, p14 (depend on correct assertion behavior)

### Fix 1: Protocol-aware milestone seeding for JTAG (p9, p10)

Add intermediate milestones for TAP state transitions:
- Milestone 2a: `tms_pad_i` sequence drives TAP to SHIFT-DR
- Milestone 2b: `bitindex == 1` (first bit clocked in)

Or: add concolic execution for the password matching loop.

### Fix 2: Instruction-level milestones for RISC-V core (p3, p13, p27)

The CSR write requires a specific instruction. Add:
- Milestone 2a: `instr_rdata_id_o` matches a CSR instruction encoding
- Milestone 2b: `is_decoding_o == 1`

### Fix 3: Investigate APB write path for p4/p5

The `apb_gpio` module has only 4 CFG paths. Check whether the write path to `r_gpio_lock` is:
1. Present in the CFG (not pruned by MAX_PATHS_PER_CFG)
2. Satisfiable given the APB protocol constraints
3. Correctly modeled in the symbolic store

### Fix 4: Suppress deferred violations when assertion is wrong

The deferred violation mechanism should verify that the violated assertion matches the target property name before reporting. This would eliminate the p11/p14/p16 false positives even when the wrong assertion is checked.

---

## Status

- [x] v5 logs analyzed (2026-04-23, all wrong assertions)
- [x] COI fix for p6/p8 implemented and validated (commit 4fbd0a6)
- [x] Property isolation fix implemented (run_hackatdac18.sh)
- [ ] v6 corrected run not yet executed
- [ ] Post-fix analysis pending
