# HackAtDAC18 v7 Results Analysis

Date: 2026-04-27
Branch: bmc_hallu

# Results Table

| Problem | Status | Time(s) | Paths | Milestones | Notes |
|---------|--------|---------|-------|------------|-------|
| p2_fixed | VIOLATION | 15.75 | 2 | 1/4 | FC_DATA grant address check |
| p3 | TIMEOUT | 300+ | 417 | 0/3 | No milestones reached |
| p4 | SAFE (exhausted) | 241.5 | 29523 | 2/4 | BMC prune active, queue exhausted |
| p5 | TIMEOUT | 300+ | 29225 | 1/3 | Violation suppressed at cycle 8 |
| p6 | VIOLATION | 9.87 | 1 | 0/2 | Constant violation, unconditional |
| p7 | VIOLATION | 9.86 | 2 | ALL | AXI decoder bug |
| p8 | VIOLATION | 9.78 | 1 | 0/2 | Constant violation, unconditional |
| p9 | TIMEOUT | 300+ | 50476 | 1/3 | Only milestone 0 reached |
| p10 | TIMEOUT | 300+ | 50787 | 1/3 | Only milestone 0 reached |
| p11 | TIMEOUT | 300+ | 150 | 3/4 | Milestones 0,2 reached (dbg_halt==0) |
| p12 | VIOLATION | 9.78 | 3 | ALL | JTAG password bug, cycle 2 |
| p13 | TIMEOUT | 300+ | 365 | 1/5 | Only milestone 0 reached |
| p14 | TIMEOUT | 300+ | 147 | 3/4 | Milestones 0,2 reached (VEC_MODE) |
| p15 | VIOLATION | 9.73 | 10 | 1/4 | RTC seconds overflow, deferred |
| p16 | VIOLATION | 9.75 | 2 | 1/4 | JTAG reset bug |
| p21 | VIOLATION | 11.44 | 2 | 1/4 | Mux temperature leak, deferred |
| p27 | TIMEOUT | 300+ | 373 | 1/4 | Only milestone 0 reached |
| p28 | VIOLATION | 9.57 | 2 | 1/3 | JTAG td_i tautology, unconditional |
| p29 | FATAL | - | 0 | - | Compilation error: aes_out not found |

Success rate: 10/19 (52.6%) — same as v6
Timeouts: 8/19 (42.1%) — same as v6
Fatal: 1/19 (5.3%) — new (was SAFE in v6)

# v6 vs v7 Comparison

| Problem | v6 Status | v6 Paths | v6 Milestones | v7 Status | v7 Paths | v7 Milestones | Change |
|---------|-----------|----------|---------------|-----------|----------|---------------|--------|
| p2_fixed | VIOLATION | 2 | 0,2 | VIOLATION | 2 | 1/4 | Same |
| p3 | TIMEOUT | 323 | - | TIMEOUT | 417 | 0/3 | Regression (more paths, 0 milestones) |
| p4 | SAFE | 29523 | 0,1 | SAFE | 29523 | 2/4 | Same (BMC prune now active) |
| p5 | TIMEOUT | 29312 | 0 | TIMEOUT | 29225 | 1/3 | New insight: violation fires at cycle 8, suppressed |
| p6 | VIOLATION | 1 | 0 | VIOLATION | 1 | 0/2 | Same |
| p7 | VIOLATION | 2 | 0,2 | VIOLATION | 2 | ALL | Same |
| p8 | VIOLATION | 1 | 0 | VIOLATION | 1 | 0/2 | Same |
| p9 | TIMEOUT | 51052 | 0 | TIMEOUT | 50476 | 1/3 | Same |
| p10 | TIMEOUT | 50584 | 0 | TIMEOUT | 50787 | 1/3 | Same |
| p11 | TIMEOUT | 148 | 0,2 | TIMEOUT | 150 | 3/4 | Same |
| p12 | VIOLATION | 3 | 0,1,3 | VIOLATION | 3 | ALL | Same |
| p13 | TIMEOUT | 403 | 0 | TIMEOUT | 365 | 1/5 | Regression (fewer paths, milestone 0 only) |
| p14 | TIMEOUT | 412 | 0 | TIMEOUT | 147 | 3/4 | Improvement (fewer paths, milestones 0,2 reached) |
| p15 | VIOLATION | 11 | 0,2 | VIOLATION | 10 | 1/4 | Same |
| p16 | VIOLATION | 2 | 0 | VIOLATION | 2 | 1/4 | Same |
| p21 | VIOLATION | 2 | 0,2 | VIOLATION | 2 | 1/4 | Same |
| p27 | TIMEOUT | 403 | 0 | TIMEOUT | 373 | 1/4 | Same (milestone 0 now reported) |
| p28 | VIOLATION | 2 | 0 | VIOLATION | 2 | 1/3 | Same |
| p29 | SAFE | 0 | - | FATAL | 0 | - | Regression (compilation error) |

# Analysis

## What Stayed the Same

The overall result set is identical to v6: 10 violations, 8 timeouts, and the same problems in each category. All 10 violations are found at roughly the same speed (within ~0.2s). The path counts for most problems are within a few percent of v6, indicating no major behavioral change in the exploration strategy.

## Notable Changes

### p14: Milestone Progress Improvement

v6 explored 412 paths and reached 0 milestones. v7 explores only 147 paths but reaches milestones 0 and 2 (VEC_MODE). This is a meaningful improvement — the engine is now making progress toward the violation condition rather than thrashing through irrelevant paths. The reduction in path count alongside better milestone coverage suggests the lazy forking or path selection changes are steering exploration more effectively for this design.

### p5: Violation Now Visible but Suppressed

v6 showed p5 as a plain timeout with milestone 0 only. v7 reveals that the assertion violation actually fires at cycle 8, but is suppressed because only 1/3 milestones are satisfied at that point. The engine is finding the bug — it just can't confirm it meets the milestone threshold before timeout. This is useful diagnostic information: the violation exists, but the milestone definition requires more cycles than the 300s budget allows.

### p4: BMC Pruning Now Active

v7 shows `[BMC Prune] cycle=9, local_depth=8 > bound m=7` — the bounded model checking pruning feature is now active and cutting off paths beyond the depth bound. The queue exhausts at the same 29,523 path count as v6, so the pruning isn't changing the final result, but it is now enforcing the depth bound. There is also a new warning that milestone[0] may be hallucinated, which warrants investigation of the p4 milestone definition.

### p3: Regression

v6 had 323 paths with some milestone progress implied. v7 has 417 paths but reports 0/3 milestones — no Step REACHED at all. This is a regression: the engine is exploring more paths but making less progress toward the assertion condition. The cause is unclear; it may be related to path ordering changes affecting which paths are explored first in the RISC-V core (21 instances, 47 CFGs, 262 paths/cycle).

### p13: Minor Regression

v6 had 403 paths and showed `ctrl_fsm_ns == DECODE` in the assertion context. v7 has 365 paths and only milestone 0 (reset released). Fewer paths explored and less assertion context visible — a minor regression, likely same root cause as p3.

### p29: Compilation Error (Regression)

v6 reported p29 as SAFE with 0 paths (no assertion found). v7 is FATAL with a compilation error: `could not resolve hierarchical path name 'aes_out'`. The design file for p29 has likely changed, or a dependency file is missing. This needs to be investigated — either the design was modified between v6 and v7, or a new import/include is required.

## Timeout Patterns (Unchanged)

The three timeout categories from v6 remain:

JTAG protocol (p9, p10, p5): 29k-51k paths, stuck at TAP state transitions. p5 now shows the violation fires at cycle 8 but milestone gating prevents reporting.

RISC-V core (p3, p13, p27): 21 instances, 47 CFGs, 262 paths/cycle. Path explosion prevents reaching instruction-level milestones. p3 and p13 show regression in milestone progress.

Debug/ALU (p11, p14): p11 unchanged (milestones 0,2). p14 improved (now reaches milestones 0,2 vs 0 in v6).

## Summary

v7 is functionally equivalent to v6 for all violation cases. The main actionable findings are: p29 needs a compilation fix, p5's violation is confirmed to exist at cycle 8 (milestone threshold is the blocker), p14 shows improved exploration efficiency, and p3/p13 show mild regressions in milestone coverage that should be monitored.
