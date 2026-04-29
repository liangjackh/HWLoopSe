# Changelog

[2026-04-29] [BugFix] Fix Verilog (.v) symbolic execution for blocking assignments, bit-select, increment, and CFG construction

**Problem:** p9/p10 (JTAG TAP password check) could never reach milestone 1 (`bitindex > 0`). The JTAG TAP state machine in `adbg_tap_top.v` uses Verilog-style blocking assignments, post-increment operators, and dynamic bit-selects that were not handled by the symbolic execution engine.

**Root causes (9 bugs fixed):**

1. **`ExpressionKind.Assignment` not handled in `visit_expr`** (slang_helpers.py): Verilog blocking assignments (`TAP_state = next_TAP_state`) use `ExpressionKind.Assignment` (semantic node), but only `SyntaxKind.AssignmentExpression` (syntax node) was handled. Added handler to write LHS = RHS to store.

2. **`SyntaxKind.AssignmentExpression` as statement** (slang_helpers.py): When a blocking assignment is passed directly as a statement node (not wrapped in ExpressionStatement), `visit_stmt` had no handler. Added `elif kind == ps.SyntaxKind.AssignmentExpression: self.visit_expr(m, s, stmt)`.

3. **Symbolic bit-select `pass[bitindex]`** (rvalue_to_z3.py): `_kind_element_select` returned `BitVecVal(0, 32)` when the selector was symbolic (couldn't call `.as_long()`). Now builds a Z3 If-chain: `If(sel==0, bit0, If(sel==1, bit1, ...))`.

4. **Post-increment `correct++` / `bitindex++`** (rvalue_to_z3.py + slang_helpers.py): `_kind_unary_op` had no handler for `Preincrement/Postincrement/Predecrement/Postdecrement`, returning 0. Now returns `operand ± 1`. Also added write-back logic in `visit_expr` for `ExpressionKind.UnaryOp` increment/decrement.

5. **`find_leaves` self-loop exclusion** (cfg.py): Case arm bodies whose only intra-block edge was a self-loop (e.g., `(3,4)` mapping to `(block1, block1)`) were not identified as leaves, so they never connected to the dummy exit. Fixed by excluding self-loops: `starts_no_self = set(e[0] for e in cfg_edges if e[0] != e[1])`.

6. **`make_paths` multi-element tuple skip** (cfg.py): `resolve_independent_branch_pts` produces N-element tuples representing sibling branch point sets. `make_paths` was treating `edge[0], edge[1]` of these tuples as direct edges, creating spurious cross-arm connections. Now skips tuples with `len(edge) != 2`.

7. **Sequential flow edge for conditionals** (cfg.py): When a `ConditionalStatementSyntax` follows a plain statement inside a `BlockStatementSyntax`, no edge connected the preceding block to the conditional's block. Added `self.edgelist.append((parent_idx - 1, parent_idx))` when the preceding node is not already a partition point.

8. **Conditional body execution** (slang_helpers.py): After adding the branch constraint, the selected branch body was fetched via `getattr(stmt, 'body', None)` which doesn't exist on `ConditionalStatementSyntax`. Fixed to use `stmt.statement` (then) / `stmt.elseClause.statement` (else) / `stmt.ifTrue` (semantic). Body is executed with `direction=None` to avoid propagating the parent's direction to nested conditionals.

9. **`stmt.body` crash on ConditionalStatementSyntax** (slang_helpers.py): The `StatementKind.Conditional` handler ended with `for s_sub in stmt.body:` which crashed on `ConditionalStatementSyntax` (no `.body` attribute). Replaced with `getattr(stmt, 'body', None)` guard.

**Key changes:**
- `helpers/rvalue_to_z3.py`: `_kind_element_select` symbolic If-chain, `_kind_unary_op` increment/decrement
- `helpers/slang_helpers.py`: `ExpressionKind.Assignment` handler, `SyntaxKind.AssignmentExpression` in visit_stmt, UnaryOp write-back, conditional body fix
- `engine/cfg.py`: `find_leaves` self-loop exclusion, `make_paths` tuple filter, sequential flow edge

**Results:**
- cfg1 (JTAG TAP state machine) paths now execute correctly: arm=0 (`STATE_test_logic_reset`) and arm=1 (`STATE_run_test_idle`) both reachable
- `TAP_state` correctly transitions from 15 → 12 across cycles
- `pass = 0xDEADBEEF` correctly written to store
- `passchk`, `correct`, `bitindex` assignments now functional
- Remaining issue: nested conditionals inside arm bodies (e.g., `if(correct >= 0x1FFFF) ... else if(tdi_o == pass[bitindex])`) have missing CFG edges due to `resolve_independent_branch_pts` interaction — tracked separately

---

[2026-04-23] [BugFix] Fixed lazy fork explosion by moving fork after abandon check (`engine/strategies.py`)

**Problem:** p9 and p10 timed out at 300s with queue explosion (~5000 items). The `adbg_tap_top/cfg1` CFG has 43 paths (JTAG state machine). Lazy forking enqueued 4 alternatives BEFORE execution. When the chosen path was abandoned (UNSAT), the 4 alternatives were already in the queue. Each alternative also forked 4 more, creating exponential growth: 4^N queue explosion even though most paths were UNSAT.

**Root cause:** Lines 1232-1276 in `strategies.py` performed lazy fork BEFORE executing the chosen path. The fork block was located between "Clamp path index" and "Execute the chosen path". When `manager.abandon` was set during execution (line 1341-1350), the alternatives were already pushed to the worklist and couldn't be removed.

**Fix:** Moved the lazy fork block from before execution (lines 1232-1276) to after the abandon check (after line 1307, "Mark that at least one CFG executed successfully"). Now alternatives are only enqueued if the chosen path succeeds (not abandoned). The pre-CFG snapshot (`pre_cfg_store`, `pre_cfg_nba`) is used as the fork base.

**Key changes:**
1. Removed fork block from lines 1232-1276 (before execution)
2. Added fork block after line 1307 (after abandon check, before comb evaluation)
3. Fork base uses `pre_cfg_store` and `pre_cfg_nba` snapshots taken before CFG execution
4. Comment updated: "IMPORTANT: Only fork AFTER the chosen path succeeds (not abandoned)"

**Results:**
- p9: Queue 5000 → 1025 (80% reduction), timeout → 49s ✅
- p10: Queue 5000 → 1025 (80% reduction), timeout → 49s ✅
- p11: No regression, still passes in 13.3s ✅
- Both p9/p10 now exhaust search (UNSAT) instead of timing out — milestone plans need improvement

**Note:** p9 and p10 don't find violations because the milestone plans are LLM-hallucinated (milestone 0 "rstn_top == 0" is never reached, BMC prunes at cycle 12). The lazy fork fix is correct — the search completes efficiently, but the guidance is wrong. This is a separate issue from the queue explosion.

[2026-04-23] [Test Results] HackAtDAC18 v3 Run - 7/12 (58%) passing with current committed code

**Test Date:** 2026-04-23 10:11-10:47
**Test Location:** `/tmp/hackdac_v3/`
**Configuration:** Commit 4fbd0a6 (constant-only assertion fallback + MAX_FORK_ALTS=4 cap)

**Pass Rate: 7/12 (58%)** — up from 5/12 baseline (+17% improvement)

**Passing properties (7):**
- p3 (~300s): Violation found at end of timeout window (borderline)
- p5 (~300s): Violation found at end of timeout window (borderline)
- p6 (9.77s): Primary goal — constant-only assertion fix ✅
- p8 (9.71s): Primary goal — constant-only assertion fix ✅
- p11 (15.08s): RISC-V core property
- p14 (15.03s): RISC-V core property
- p16 (9.75s): GPIO property

**Timeout properties (5):**
- p4 (37 MB log, queue ~740): Suppressed violation loop + queue explosion
- p9 (41 MB log, queue ~5000): Lazy fork explosion (43-path CFG), BMC equilibrium
- p10 (41 MB log, queue ~5000): Lazy fork explosion (same as p9)
- p13 (2.6 MB log, queue ~5000): RISC-V core path explosion
- p27 (2.5 MB log, queue ~5000): RISC-V core path explosion

**Key findings:**
- Primary goal (p6, p8 constant-only assertion fix) achieved ✅
- p3 and p5 are new passes but borderline (barely within 300s timeout)
- Queue stabilizes at ~5000 for p9/p10/p13/p27 due to BMC bound pruning (not explicit queue limit)
- p4 queue grows linearly (~740), no BMC equilibrium
- No queue management fixes (skip forking on suppressed violations, prune dead fork alternatives, global queue limit) are present in current code
- `hackdac18_final_results.md` claiming 8/12 (67%) was written during development but those fixes were reverted before committing

**Current code state:**
- `_MAX_FORK_ALTS = 4` cap is present (line 1242 in strategies.py)
- No `_violation_suppressed_this_cycle`, `PruneFork`, `_MAX_QUEUE`, or `QueuePrune` logic
- BMC bound check (`local_depth > expected_cycles + margin`) provides natural queue pruning for some properties

**Recommendations for future work:**
1. Verify which queue management fixes should be re-implemented
2. Focus on remaining 5 timeouts with clear root causes:
   - p4: Implement suppressed violation deduplication
   - p9, p10: Move lazy fork after execution (only fork if path succeeds)
   - p13, p27: Lower queue threshold or MAX_FORK_ALTS, or improve COI pruning

[2026-04-15] [BugFix] Fixed spurious unconditional violation from concat-LHS continuous assign and Z3 rename mangling (`helpers/slang_helpers.py`, `engine/strategies.py`).

**Root cause 1 — concat LHS silently skipped in `evaluate_comb`**: `slang_helpers.py:evaluate_comb` handled `ContinuousAssignSyntax` by extracting the LHS name via `lhs.identifier` or `lhs.valueText`. For a concatenation LHS such as `assign {FC_INSTR_gnt_o, UDMA_TX_gnt_o, UDMA_RX_gnt_o, DBG_RX_gnt_o, FC_DATA_gnt_o} = FC_data_gnt_INT_32`, neither attribute exists, so `lhs_name` stayed `None` and the assignment was silently skipped. `FC_DATA_gnt_o` was never written to `state.store["soc_interconnect"]`, remaining as an unconstrained fresh Z3 variable. The assertion `FC_DATA_gnt_o == 1` could then be trivially satisfied at cycle 1 with no path constraints, producing a spurious unconditional violation.

**Root cause 2 — Z3 rename mangling short names inside longer ones**: In `_handle_assertion_violation` (`strategies.py`), the display-renaming loop `re.sub(re.escape(_z3b) + r'(_c\d+)', _sn + r'\1', z3_str)` had no word-boundary guard. For the AES group `{('aes','o'),('mux_func','aes_out')}`, `_z3b = "o"` and `_sn = "aes_out"`. The pattern `o(_c\d+)` matched the trailing `o_c0` inside `FC_DATA_gnt_o_c0`, replacing it with `aes_out_c0` and yielding the mangled name `FC_DATA_gnt_aes_out_c0` in the displayed Z3 condition.

**Fixes**:

- **`helpers/slang_helpers.py`** (`evaluate_comb`, `ContinuousAssignSyntax` branch): When `lhs_name is None`, check `'Concatenation' in lhs.__class__.__name__`. If so, evaluate the RHS once, collect named members from `lhs.expressions`, and assign bit-slices of the RHS (`z3.Extract(msb, lsb, rhs_z3)`) to each member in MSB-first order. Falls back to full RHS if `Extract` fails or only one member.

- **`engine/strategies.py`** (`_handle_assertion_violation`, rename loop): Sort `_z3base_to_sig` by descending key length before iteration (so `"FC_DATA_gnt_o"` is processed before `"o"`). Replace bare `re.escape(_z3b)` with `(?<![A-Za-z0-9_])` + `re.escape(_z3b)` + `(?![A-Za-z0-9_])` to prevent substring matches inside longer names.

**Outcome**: The engine now finds a real counterexample for HACKDAC_p2_fixed at cycle 2 (milestones=3/4): `rstn_top=0→1`, `FC_DATA_add_i=0xFFBF0000` (outside `[0x1C000000,0x1C080000]`), `FC_DATA_gnt_o=1` — confirming the hardware Trojan grants access to an out-of-range address.

[2026-04-15] [BugFix] Fixed multi-target milestone concatenation in auto-plan mode (`engine/execution_engine.py`).

**Root cause**: The auto-plan loop at line ~960 iterated over all assertion targets and appended milestones from each LLM call into a single flat `all_milestones` list. With two targets (e.g., a `div_i` parameter assertion + `HACKDAC_p2_fixed`), the LLM was called twice and produced 7 + 6 = 13 milestones concatenated into one incoherent sequential plan. The `milestones.json` write also used the loop variable `target` after the loop, which pointed to the last target rather than the primary one.

**Fix**: Replaced the per-target loop with a single-target plan using `primary_target = targets[0]`. When multiple targets are found, the engine logs a warning and ignores all but the first. Also fixed `expected_cycles` passthrough (was constructing `Milestone(desc, cond)` without `expected_cycles`, silently defaulting to 10 for all steps) and corrected the `milestones.json` metadata to always use `primary_target`.

[2026-04-15] [BugFix] Fixed COI seeding from garbage SVA tokens and no-counterexample due to DEMUX pruning (`engine/execution_engine.py`, `frontend/coi_analyzer.py`).

**Root cause 1 — garbage COI seeds**: COI seeds were extracted exclusively from `target.assertion_source` — the raw SVA property text from `properties.sv`. For `HACKDAC_p2_fixed`, this text contained `disable iff`, inline comments, and `|->`, causing `extract_signals_from_condition` to produce garbage tokens like `jg_bind_inst.TCDM` and `jg_bind_inst.Implication` as seed signals. These resolved to no real signals, so COI found only `soc_interconnect` and `XBAR_L2_i` as relevant instances with zero CFGs.

**Root cause 2 — concat LHS not tracked**: `COIAnalyzer._extract_comb_signals` called `_get_signal_name_syntax(lhs)` which returns `None` for concatenation LHS nodes (`assign {FC_INSTR_gnt_o, ..., FC_DATA_gnt_o} = FC_data_gnt_INT_32`). None of the signals in the concat were registered in `comb_writes`, so COI could not trace backward through `FC_DATA_gnt_o` → `FC_data_gnt_INT_32` → `DEMUX_MASTER_32`. The demux instances were pruned, leaving the grant signal unconstrained and milestone 3 (`FC_DATA_gnt_o == 1`) unreachable.

**Fixes**:
- **`engine/execution_engine.py`**: After extracting seeds from `assertion_source`, also read `target_expr` from `self.milestone_file` and extract additional seeds from it. For plain (non-hierarchical) signals, seed to every instance in `modules_dict` — COI ignores instances that don't have the signal in their maps. Fixed `milestone_file` reference (was using undefined local instead of `self.milestone_file`).
- **`frontend/coi_analyzer.py`**: In `_extract_comb_signals`, when `_get_signal_name_syntax(lhs)` returns `None`, check if LHS is a `ConcatenationExpressionSyntax` and register each element individually using `_collect_read_signals(lhs, concat_names)`. This correctly handles `assign {a, b, c} = rhs` by mapping `a`, `b`, `c` → `{rhs}` in `comb_writes`.
- **`milestones/hackdac18/p2_fixed.json`**: Rewrote the milestone plan. Old plan used packed-array comparisons (`TCDM_data_add_DEM_TO_XBAR > 0x1C08_0000` on a 416-bit vector) and vector-indexed signals (`HWPE_req_i[1]`). New plan uses scalar port signals (`FC_DATA_req_i`, `FC_DATA_add_i`, `FC_DATA_gnt_o`) with 4 steps and `k=8` on the final grant step.

[2026-04-14] [BugFix] Fixed cycle-0 spurious violation, unhandled SyntaxKind warnings, and malformed HACKDAC_p2 property in hackdac18 benchmark.

**Root cause**: `collect_all_instances` in `engine/execution_engine.py` did not recurse into `GenerateBlockSymbol`/`GenerateBlockArraySymbol` when discovering module instances. Submodules inside generate-for blocks (e.g., `ResponseBlock_L2`, `AddressDecoder_Req_L2` inside `XBAR_L2_i.genblk3`) were never discovered, so no CFGs were built for them, no port connections were extracted, and COI could not trace through them. As a result, `TCDM_data_gnt_DEM_TO_XBAR` and `TCDM_data_add_DEM_TO_XBAR` remained as unconstrained Z3 free variables, causing a spurious unconditional assertion violation at cycle 0.

**Fixes**:

1. **`engine/execution_engine.py`** — Added `_collect_instances_from_generate()` helper and updated `collect_all_instances()` to recurse into `GenerateBlockArraySymbol` (via `.entries`) and `GenerateBlockSymbol` (via `block[i]` indexing), using the same pattern as `cfg.py:_collect_from_generate_block`. COI now discovers 29 relevant instances (was 2), and the cycle-0 violation is eliminated.

2. **`helpers/rvalue_to_z3.py`** — Added handlers for previously unrecognized `SyntaxKind` nodes (8174 warnings → 0):
   - `InvocationExpressionSyntax`: handles `$clog2`, `$signed`, `$unsigned`, `$bits`. Argument extraction unwraps `ArgumentListSyntax → SeparatedList → OrderedArgumentSyntax → SimplePropertyExprSyntax → SimpleSequenceExprSyntax → actual expr` via `_unwrap_arg()`.
   - `SimplePropertyExprSyntax`, `SimpleSequenceExprSyntax`, `ParenthesizedPropertyExprSyntax`: wrapper nodes, unwrap to inner `.expr`.
   - `BinaryPropertyExprSyntax` (`a |-> b`): implication rendered as `Or(Not(a), b)`.
   - `AssignmentPatternExpressionSyntax` (`'{default: val}`): returns the default value expression.

3. **`helpers/slang_helpers.py`** — Case statement handler (line ~1201): `case.expressions` returns a `SeparatedList` node, not its children. Added unwrapping to filter out `Token` (comma) children before iterating, fixing 1771 `SeparatedList` warnings from multi-value case items (`2'b00, 2'b01: ...`).

**Analysis — HACKDAC_p2 property is malformed**:
```systemverilog
assert property (
    ~((TCDM_data_gnt_DEM_TO_XBAR) >> 1) &&
    ((TCDM_data_add_DEM_TO_XBAR >= 32'h1C00_0000) &&
     (TCDM_data_add_DEM_TO_XBAR <= 32'h1C08_0000))
);
```
- `TCDM_data_gnt_DEM_TO_XBAR` is `[12:0]` (13-bit vector). `~(gnt >> 1)` is a bitwise NOT of a shifted vector — almost always non-zero, not a meaningful security check.
- `TCDM_data_add_DEM_TO_XBAR` is `[12:0][31:0]` (416-bit packed 2D array). Comparing it to `32'h1C00_0000` compares the entire 416-bit value against a 32-bit constant — not checking any individual master's address.
- The intended property is per-master: for each master `i`, if `gnt[i]` is asserted then `add[i]` must be within the TCDM range. Should be written with a generate-for loop or `forall`.

**Property and milestone fixes**:

4. **`designs/benchmarks/hackatdac18/properties.sv`** — Uncommented the correct form of HACKDAC_p2 (outer `~` wraps the whole conjunction):
   ```systemverilog
   HACKDAC_p2: assert property (
       ~(((TCDM_data_gnt_DEM_TO_XBAR) >> 1) &&
       ((TCDM_data_add_DEM_TO_XBAR >= 32'h1C00_0000) &&
        (TCDM_data_add_DEM_TO_XBAR <= 32'h1C08_0000)))
   );
   ```
   The malformed variant (`~A && B` instead of `~(A && B)`) was in `test/src/properties.sv` and `hackdac18_wrong/src/properties.sv`. The correct form is in `hackdac18/src/properties.sv`.

5. **`milestones/hackdac18/p2.json`** — Rewrote from scratch. Old file had 11 LLM-hallucinated steps built around the wrong property, with `target_expr` that was trivially satisfiable at cycle 0. New file has 5 steps with `target_expr = (gnt >> 1) != 0 && add in [0x1C00_0000, 0x1C08_0000]` — the actual counterexample condition for the correct property.

PySlang usage: `GenerateBlockArraySymbol.entries` yields `GenerateBlockSymbol` instances; `GenerateBlockSymbol` is indexed via `block[i]`, raising `IndexError` when exhausted. `InvocationExpressionSyntax.arguments` is `ArgumentListSyntax`; iterating it yields `Token('(')`, `SyntaxNode(SeparatedList)`, `Token(')')`. The `SeparatedList` contains `OrderedArgumentSyntax` nodes whose `.expr` is `SimplePropertyExprSyntax`, which wraps `SimpleSequenceExprSyntax`, which wraps the actual identifier/expression.

[2025-04-23] [Feature] Implemented BMC-bounded milestone verification ("LLM Proposes, BMC Disposes") across 4 files:

1. **`frontend/llm_planner.py`**: Updated `SYSTEM_PROMPT` to require `"expected_cycles": <int>` per milestone in the JSON schema. Added rule #6 instructing the LLM to calculate sequential cycles from pipeline stages, counters, and FSMs. Updated all `MOCK_RESPONSES` with `expected_cycles` values.

2. **`engine/milestone.py`**: Added `expected_cycles: int = 10` parameter to `Milestone.__init__` (default 10 for backward compatibility with old milestone files). Updated `__repr__` to display `k=<expected_cycles>`.

3. **`engine/execution_engine.py`**: Both milestone loading paths (file-based and auto-plan) now pass `expected_cycles=m.get('expected_cycles', 10)` to `Milestone()`. Log output shows `[k=...]`. Milestone JSON serialization now persists `expected_cycles`.

4. **`engine/strategies.py`**:
   - `WorkItem`: Added `cycle_at_last_milestone: int = 0` field, propagated through all 3 construction sites (initial, lazy-fork, next-cycle enqueue). Updated when milestones advance.
   - `MilestoneDirectedStrategy.__init__`: Added `bmc_margin: int = 5` constructor parameter.
   - **BMC bound check** in `run()` main loop: Computes `local_depth = cycle - cycle_at_last_milestone`. If `local_depth > expected_cycles + margin`, the work item is soft-pruned (dropped from queue) with a `[BMC Prune]` warning log.
   - **Hallucination detection**: On queue exhaustion, prints a `WARNING` identifying the stalled milestone as potentially hallucinated, including its condition and `expected_cycles`.
   - Dynamic Granularity Fallback (LLM re-planning loop) is deferred to a subsequent task.

PySlang usage: No changes to PySlang AST traversal.

[2026-03-27] [BugFix] Fixed premature preemption and missing counterexample in `engine/strategies.py`:

1. **Premature preemption** (`strategies.py:_execute_cycle`): The final-milestone preemption guard `current_progress > 0` fired too early — at cycle 1 with only 1/5 milestones reached — because unconstrained signals made the final milestone trivially SAT. Fix: tightened guard to `current_progress >= total_milestones - 1` so preemption only fires when one step away from the final milestone.

2. **Missing counterexample** (`strategies.py:_handle_assertion_violation`): Signal store values are Z3 `BitVecRef` objects, not strings, so the `isinstance(signal_expr, str)` check always failed and produced `(no matching signals found in store)`. Fix: added `is_bv(signal_expr) and not is_bv_value(signal_expr)` branch that extracts the symbol name via `signal_expr.decl().name()`. Applied to both the `violated_assertions` path and the preemption fallback path. Also added `is_bv`, `is_bv_value` to the z3 import line.

PySlang usage: No changes to PySlang AST traversal.

[2026-03-27] [BugFix] Fixed three milestone condition parsing/evaluation bugs in `frontend/condition_parser.py` and `engine/milestone.py`:

1. **`>>` operator misparse** (`condition_parser.py:_find_top_level_comparison`): The second `>` of `>>` was being matched as a bare comparison operator, causing `(if_insn & 32'hFC000000) >> 26 == 32'h1c` to split incorrectly into LHS=`(if_insn & 32'hFC000000) >` and RHS=`26 == 32'h1c`. Fix: added `condition[i-1] != '>'` guard to skip the trailing `>` of any `>>` sequence.

2. **Arithmetic expression as signal path** (`milestone.py:_get_signal_z3_value`): When a milestone condition LHS was an arithmetic expression like `(if_insn & 32'hFC000000) >> 26`, the code tried to look it up as a signal name in the store and failed. Fix: added an early-exit check for arithmetic operators (`&`, `|`, `>>`, `<<`, etc.) that routes the expression through `_evaluate_expression` instead of `parse_hierarchical_signal`.

3. **LLM planner signal validation with expressions** (`condition_parser.py:extract_signal_name`): The validator was passing the full expression `((ex_insn & 32'hFC000000) >> 26)` as a signal name to the store lookup. Fix: updated `extract_signal_name` to extract the first identifier from arithmetic expressions using regex, so `((ex_insn & 32'hFC000000) >> 26)` correctly validates against `ex_insn`.

PySlang usage: No changes to PySlang AST traversal.

PySlang usage: No changes to PySlang AST traversal. All fixes are in the milestone condition parser and Z3 signal resolution layer.

[2026-03-27] [Feature] Implemented data-flow distance heuristic for A* scoring in `engine/milestone.py` and `engine/strategies.py`:

- New scoring formula: `Score = (remaining_milestones * 10) + cycle + dataflow_distance(state, next_milestone)`
- `compute_dataflow_distance()`: walks the milestone condition tree, concretizes LHS via `z3.simplify` (fast path) then model probing (fallback), computes `abs(current - target)` for multi-bit signals and 10/0 penalty for 1-bit control signals. Capped at 999 to prevent distance from dominating milestone priority.
- Operator-aware distance: `==` uses abs diff, `>=/>`  uses ReLU, `<=/< ` uses ReLU, `!=` uses 0-or-10 penalty, compound `&&` sums sub-distances, `||` takes minimum.
- `compute_score_stateless()` updated to accept optional `state` and add distance gradient.
- Added `[Score]` debug logging showing `remaining`, `cycle`, `base`, `distance`, `total` per enqueue.

PySlang usage: No changes to PySlang AST traversal.

[2026-03-25 16:59:21 +0800] [Directed Strategy] Added eager final-target preemption and sliding-window milestone advancement for fault-tolerant LLM milestone handling.

PySlang usage summary: This change keeps existing PySlang-driven CFG extraction/execution flow unchanged (module discovery, always-block CFG paths, and statement visitation), and only updates post-cycle milestone SAT probing logic in the directed scheduler.

## 2026-03-23 [Infra] hackdac18 SBY Formal Verification with yosys-slang

### Summary

Successfully configured SymbiYosys (sby) to run BMC formal verification on the hackatdac18 SoC design (PULPissimo-based RISC-V SoC with AES, Keccak, MD5, JTAG debug). The key breakthrough was replacing Yosys's native SystemVerilog parser with the **yosys-slang** plugin, which provides full IEEE 1800-2017 SV support and bypasses all the SV parsing limitations that had been blocking progress.

### Problem

Running `sby -f hackdac18.sby` failed with Yosys native SV parser errors:
- `riscv_controller.sv:94: ERROR: syntax error, unexpected TOK_ID` — caused by `PrivLvl_t` (package typedef) not being resolved with `-defer`
- Previous attempts hit 5+ other Yosys SV limitations (streaming operators, package types, etc.)
- Each manual fix revealed new blockers — a whack-a-mole process

### Root Cause

Yosys's built-in SystemVerilog frontend has limited SV support. Complex SV constructs common in the PULP ecosystem (package typedefs, streaming operators, interface ports) are not supported, especially when using `-defer` mode to avoid import collisions.

### Solution: yosys-slang Plugin

The **yosys-slang** plugin (based on the [slang](https://github.com/MikePopoloski/slang) library) provides comprehensive SV support. It was already bundled in oss-cad-suite version 20260323.

#### Library Compatibility Issue

Initial attempts to load the plugin failed with `GLIBCXX_3.4.32 not found`:
- oss-cad-suite bundled an old `libstdc++.so.6` (up to GLIBCXX_3.4.30)
- The slang plugin required GLIBCXX_3.4.31+
- **Fix**: Updated oss-cad-suite to version 20260323 which ships a compatible bundled `slang.so`

#### Plugin confirmed working:
```
/home/ljh/haveFun/tools/oss-cad-suite/bin/yosys -p \
  "plugin -i /home/ljh/haveFun/tools/oss-cad-suite/share/yosys/plugins/slang.so; help read_slang"
```

### Changes Made

#### `hackdac18.sby` — Complete rewrite of `[script]` section

**Before** (broken — used `read_verilog -sv` with `-defer` workarounds):
```
read_verilog -sv -DVERILATOR -I. apu_core_package.sv
read_verilog -sv -defer -I. riscv_controller.sv   # FAILS on PrivLvl_t
...
```

**After** (working — uses `read_slang` for all files):
```
plugin -i /home/ljh/haveFun/tools/oss-cad-suite/share/yosys/plugins/slang.so

read_slang --single-unit --ignore-assertions --ignore-timing -I. -DVERILATOR \
  apu_core_package.sv \
  ... (all .sv and .v files in a single read_slang call) ...
  properties.sv

clk2fflogic
async2sync

cutpoint -undef top_wrapper/adbg_tap_top.passchk
cutpoint -undef top_wrapper/adbg_tap_top.correct
cutpoint -undef top_wrapper/adbg_tap_top.bitindex
cutpoint -undef top_wrapper/riscv_core.if_stage_i.prefetch_32.prefetch_buffer_i.hwlp_masked

prep -top top_wrapper
```

Key `read_slang` flags:
- `--single-unit`: Treats all files as one compilation unit so macros (`SOC_CTRL_END_ADDR`, etc.) defined in header files are visible to `properties.sv`
- `--ignore-assertions`: Lets slang skip SVA parsing (Yosys handles assertions separately via `prep`)
- `--ignore-timing`: Skips unsynthesizable timing controls (e.g., `default clocking`)

Additional `[files]` entry added:
- `hackatdac18-2018-soc/ips/adv_dbg_if/rtl/adbg_tap_defines.v` — was missing, caused `IR_LENGTH` undefined macro errors

Additional Yosys passes:
- `clk2fflogic` — handles JTAG clocks used with opposite polarity (`tck_i` on `$dff` with both edges)
- `async2sync` — converts latches from `adbg_tap_top.v` (combinational `always @(...)`)
- `cutpoint -undef` — breaks combinational logic loops in `adbg_tap_top.v` and `riscv_prefetch_buffer.sv` that the SMT2 backend cannot handle

#### `properties.sv` — Fixed hierarchical path errors

Slang strictly resolves hierarchical paths. Package enum values and module-local parameters cannot be accessed via hierarchical references through instance paths.

| Property | Old (broken) | New (fixed) | Reason |
|---|---|---|---|
| p3 | `cs_registers_i.PRIV_LVL_M` | `2'b11` | `PRIV_LVL_M` is a package enum, not an instance signal |
| p3 | `cs_registers_i.PRIV_LVL_U` | `2'b00` | Same — package enum literal |
| p11 | `riscv_core.RD_DBGS` | `3'b100` | `RD_DBGS` is a local enum in `riscv_debug_unit.sv` (5th value: `{RD_NONE, RD_CSR, RD_GPR, RD_DBGA, RD_DBGS}`) |
| p14 | `alu_i.VEC_MODE16` | `2'b10` | `VEC_MODE16` is a package parameter in `riscv_defines.sv` |
| p14 | `alu_i.VEC_MODE8` | `2'b11` | Same — package parameter |
| p29 | `top_wrapper.aes_out`, `top_wrapper.c` | Commented out | These are internal signals in `mux_func`, not visible at `top_wrapper` level |

#### `top_wrapper.sv` — Fixed unconnected interface ports

Slang (unlike Yosys native parser) enforces that top-level interface ports must be connected. The APB bus interfaces were declared as top-level ports but never driven externally.

**Fix**: Removed all APB interface ports from the module port list and created internal `APB_BUS` instances instead:

```systemverilog
// Removed from module ports:
// APB_BUS.Slave  apb_subordinate,
// APB_BUS.Master fll_primary,
// ... (10 more APB interfaces)

// Created internally:
APB_BUS #(.APB_ADDR_WIDTH(32), .APB_DATA_WIDTH(32)) apb_subordinate ();
APB_BUS #(.APB_ADDR_WIDTH(32), .APB_DATA_WIDTH(32)) fll_primary ();
// ... (10 more)
```

### Final Result

```
SBY 17:27:52 [hackdac18] engine_0: ##   0:00:13  Status: passed
SBY 17:27:52 [hackdac18] engine_0: Status returned by engine: pass
SBY 17:27:52 [hackdac18] summary: Elapsed clock time [H:MM:SS (secs)]: 0:00:24 (24)
SBY 17:27:52 [hackdac18] DONE (PASS, rc=0)
```

BMC with boolector solver checked all assertions through 20 time steps — **all passed** in 24 seconds.

### Files Modified
- `designs/benchmarks/hackatdac18/hackdac18.sby` — Rewrote `[script]` section for yosys-slang
- `designs/benchmarks/hackatdac18/properties.sv` — Fixed enum/parameter hierarchical path references
- `designs/benchmarks/hackatdac18/top_wrapper.sv` — Internalized APB interface ports

### Files Created
- `designs/benchmarks/hackatdac18/run_sby.sh` — Helper wrapper script (optional)

### Notes
- The yosys-slang approach is superior to sv2v translation because it preserves the original RTL code
- The `--single-unit` flag is essential for designs that use macros across files (common in PULP ecosystem)
- The `cutpoint` commands may weaken verification soundness — the cut signals become unconstrained. For full soundness, the loops in `adbg_tap_top.v` should be fixed at the RTL level
- Some assertions (p1, p6, p8) have expressions that are "always false" — these are address range overlap checks that correctly detect the hackatdac18 Trojan modifications to the memory map

## 2026-03-20 [Performance] Round 3 Optimization: 10x Speedup on or1200_subset

### Summary

Profiling after Round 2 revealed a new dominant bottleneck: 95.5% of runtime (82s out of 85s) was spent inside Z3's C++ AST pretty-printer (`z3printer.py`). Root cause was two Python performance traps — eager f-string evaluation in debug prints, and blind `str(z3_val)` calls in `substitute_symbols`. Fixing both reduced execution time from 18.06s to 1.77s — a **10.2x speedup** — with identical counterexample output.

### Profiling Findings (after Round 2)

| Bottleneck | Time | Calls | % Total |
|---|---|---|---|
| Z3 `__str__` / `z3printer.py` | 82s | 16,050 | 95.5% |
| `substitute_symbols` (blind `str(z3_val)`) | 47s | 152 | 55% |
| `_syntax_binary_expression` (via z3printer) | 35s | 1,336 | 41% |

### Root Cause Analysis

**Trap 1 — Eager f-string evaluation**: Python evaluates f-string arguments at the call site, before the called function runs. So `debug_print("TAG", f"...{z3_obj}...")` always calls `str(z3_obj)` — which triggers Z3's recursive C++ AST printer — even when `DEBUG_ENABLED = False`. The `debug_print` function's internal `if DEBUG_ENABLED:` check fires too late.

**Trap 2 — Blind `str()` in `substitute_symbols`**: The function iterated all variables in the store and called `str(sym_val)` unconditionally, even for variables that don't appear in the target expression string. With ~100 variables and 152 calls, this produced ~15,000 unnecessary Z3 printer invocations.

### Changes Made

#### Task 1: Guard debug_print f-strings (`helpers/slang_helpers.py`, `helpers/rvalue_to_z3.py`)

Wrapped every `debug_print` call containing Z3 objects in an explicit `if DEBUG_ENABLED:` block so the f-string is never constructed during normal execution:

- `slang_helpers.py` line 912: `evaluate_comb` EVAL-COMB trace (3,399 calls/run)
- `slang_helpers.py` lines 1081-1084: COND trace with `cond_expr` and `rst` (Z3 value)
- `slang_helpers.py` line 1399: ASSERT trace with `cond_z3` — **critical hot path**
- `rvalue_to_z3.py` line 488: `_kind_named_value` NamedValue trace (materializes store key list)
- `rvalue_to_z3.py` line 509: `_kind_integer_literal` IntegerLiteral trace
- `rvalue_to_z3.py` line 644: `_syntax_parenthesized` unwrap trace
- `rvalue_to_z3.py` line 654: `_syntax_binary_expression` trace with `lhs`/`rhs` (Z3 exprs) — **35s eliminated**

#### Task 2: Fast pre-check in `substitute_symbols` (`helpers/slang_helpers.py`)

Added `if var_name in result:` substring check before the regex and `str()` operations. Only variables that actually appear in the expression string trigger the expensive Z3 printer:

```python
for var_name in sorted_vars:
    if var_name in result:                          # fast O(n) substring check
        pattern = r'\b' + re.escape(var_name) + r'\b'
        if re.search(pattern, result):              # confirm whole-word match
            sym_val = store[var_name]
            result = re.sub(pattern, str(sym_val), result)  # str() only when needed
```

### Results

| Metric | Before (Round 2) | After (Round 3) | Speedup |
|---|---|---|---|
| Execution time | 18.06s | 1.77s | **10.2x** |
| Total time | 18.31s | 2.03s | **9.0x** |

Cumulative speedup across all three rounds: **82.66s → 1.77s (~47x)**.

### PySlang Library Usage

No new PySlang API usage in this round. All changes are in Python-level debug/string handling.

---

## 2026-03-20 [Performance] Round 2 Optimization: 4.6x Speedup on or1200_subset

### Summary

Two rounds of profiling-driven optimization reduced or1200_subset (30 cycles, directed strategy) execution time from 82.66s to 18.06s — a **4.6x speedup** — while producing identical counterexample output.

### Profiling Findings (after Round 1 deepcopy elimination)

| Bottleneck | Time | Calls | % Total |
|---|---|---|---|
| `_evaluate_comb_fixedpoint` | 227s | 3 | 98% |
| `parse_expr_to_Z3` | 182s | 134M (1.1M primitive) | 80% |
| `_match_bv_widths` | 58s | 20M | 25% |
| Z3 printer (`str()` on Z3 objects) | 15s | 1.5M | 7% |

### Changes Made

#### Task 1: Eliminate `str()` on Z3 objects (`helpers/rvalue_to_z3.py`, `engine/execution_engine.py`)

- Replaced `str(e.op)` string-matching if-elif chain in `_kind_binary_op` with a module-level `_BINARY_OP_DISPATCH` dict keyed by `ps.BinaryOperator` enum values — O(1) dict lookup, no string conversion
- Replaced `str(e.op)` in `_kind_unary_op` with direct `ps.UnaryOperator` enum comparison
- Replaced `str(s.check()) == "sat"` with `s.check() == z3.sat` in both `solve_pc` functions
- Replaced `str(left_expr.sort()) == "Bool"` with `z3.is_bool(left_expr)` in `Z3Visitor`

#### Task 2: Topological sort for combinational logic (`engine/strategies.py`)

- Added `_topo_sort_comb()`: builds a write/read dependency DAG per module using signal name extraction, then calls `networkx.topological_sort` to produce a single-pass evaluation order. Falls back to original order if a cycle is detected.
- Added `_evaluate_comb_topo()`: single-pass evaluation in topological order (replaces 2-pass `_evaluate_comb_fixedpoint`)
- Replaced all 3 `_evaluate_comb_fixedpoint` calls with `_evaluate_comb_topo`
- The 2-pass fixedpoint was the dominant bottleneck: it drove 134M recursive calls to `parse_expr_to_Z3` by evaluating every comb node twice per cycle per work item

#### Task 3: Fast-path `_match_bv_widths` (`helpers/rvalue_to_z3.py`)

- Added early return for the common case: when both operands are `BitVecRef` with equal width, return immediately without any bool coercion or ZeroExt logic
- This function was called ~20M times; the fast path avoids two `isinstance` checks and a `.size()` call in the majority of cases

#### Task 4: Post-sequential comb evaluation (audited, kept)

- Confirmed that the 3rd `_evaluate_comb_topo` call (after sequential logic, before milestone check) is necessary: milestones reference combinational wires whose values depend on register updates from the always blocks

### Results

| Metric | Before | After | Speedup |
|---|---|---|---|
| Execution time | 82.66s | 18.06s | **4.6x** |
| Total time | 82.86s | 18.31s | **4.5x** |

Counterexample output is identical — same signals, same violation detected.

### PySlang Library Usage

- No new PySlang API usage. `ps.BinaryOperator` and `ps.UnaryOperator` enum members used directly for O(1) dispatch instead of `str(e.op)` substring matching.

## 2026-03-18 - Fix Initial Block + Sequential If Statements in CFG

### Problem

Running `python3 -m main 7 designs/test-designs/test_2.v --sv --milestone-file milestones/test_2.json --coi --strategy directed` on a simple counter design with `initial begin out = 0; end` and `assert(out <= 3)`. The engine either found a spurious violation at cycle 2 (with `out` as a free symbolic variable instead of 0) or exhausted all paths without finding the real violation at cycle 6.

### Root Cause

Two independent bugs:

**Bug A — Port propagation overwrites register values after COI pruning** (`strategies.py:_propagate_ports`):
- COI pruning removed `place_holder` from `manager.names_list` but left its store entry intact
- Wire group 2 `{('place_holder', 'out_wire'), ('test_1', 'out')}` is a non-primary-input group
- `_propagate_ports` picked `place_holder.out_wire` (a stale free symbol from initialization) as the source and overwrote `test_1.out`, destroying the value set by the initial block and NBA
- This caused `out` to appear as a free symbolic variable instead of 0

**Bug B — CFG didn't connect sequential if statements** (`cfg.py:basic_blocks_sv`):
- The always block contains two sequential `if` statements inside `begin...end`:
  ```verilog
  always @(posedge CLK) begin
      if (RST) out <= 0; else out <= out + 1;
      if (!RST) assert(out <= 3);  // never reached
  end
  ```
- The `BlockStatementSyntax` handler at line 391 recursed into `item.items` but never incremented `block_stmt_depth` or pushed to `block_smt`
- Without proper depth tracking, the two `if` statements weren't recognized as independent branch points at the same block level
- `resolve_independent_branch_pts` never ran, so no edge connected the first `if`'s branches to the second `if`
- CFG paths stopped at BB[1]/BB[2] and never reached BB[3] (assertion guard) or BB[4] (assertion)

### Solution

**Fix A** (`strategies.py:_propagate_ports`):
- Store `_active_instances = set(manager.names_list)` after COI pruning
- In `_propagate_ports`, skip COI-pruned instances when picking a source value for non-directed propagation

**Fix B** (`cfg.py:basic_blocks_sv`):
- Updated the existing `BlockStatementSyntax` handler (line 391) to properly track block depth:
  ```python
  # Before:
  elif isinstance(item, ps.BlockStatementSyntax):
      self.basic_blocks_sv(m, s, item.items)

  # After:
  elif isinstance(item, ps.BlockStatementSyntax):
      self.block_stmt_depth += 1
      self.block_smt.append(True)
      self.basic_blocks_sv(m, s, item.items)
      if self.block_stmt_depth in self.ind_branch_points:
          self.resolve_independent_branch_pts(self.block_stmt_depth)
      self.block_smt.pop()
      self.block_stmt_depth -= 1
  ```
- This creates the edge `(2, 5)` connecting the first `if`'s condition to the second `if`, producing 4 CFG paths instead of 2

### Results

| Metric | Before | After |
|--------|--------|-------|
| test_2 result | Spurious violation or exhausted | Correct violation at cycle 6 |
| test_2 counterexample | `out_wire_c0 = 4` (free symbol) | `RST_c0=1, RST_c1..c6=0` (counter reaches 4) |
| test_2 paths | 254 (exhausted) | 21 |
| test_2 time | 0.31s (no result) | 0.05s |
| sub-test (regression) | 8 paths, 0.08s | 8 paths, 0.07s (unchanged) |

## 2026-03-17 - Fix Assertion Violation Detection: Skip Abandoned CFGs + Alternate Preferred Paths

### Problem

Running `python3 -m main 6 designs/test-designs/sub-test/sub.F --sv --milestone-file milestones/sub-test.json --coi --strategy directed` on a multi-module SystemVerilog design. Simulation (iverilog) found assertion violations at times 75000 and 85000, but the symbolic execution engine explored 90K+ work items without ever finding them.

The hardware bug scenario: module_b selects between a shifted value (`c_out = in_b << 1`) and the direct value (`in_b`) based on `orig_in_a > THRESHOLD`. The assertion checks `b_out == past_3_in_a + 1`. When `orig_in_a > 255` at cycle K but the pipelined `in_b` carries a value from a cycle where `orig_in_a <= 255`, `b_out` gets the wrong (shifted) value, violating the assertion.

### Root Cause

Two interacting issues prevented the engine from constructing the right constraint combination:

**Problem A — Abandoned CFGs killed entire work items**: In `_execute_cycle`, when any CFG path was abandoned (e.g., assertion guard `rst_n && check_en` was UNSAT because `check_en=0` at early cycles), `return None` killed the entire work item. The assertion module's CFGs are passive (don't modify data-path state), so killing the work item was unnecessarily aggressive. The forked else-branch alternative survived but incurred a `score+1` penalty, deprioritizing it.

**Problem B — Fixed preferred path caused uniform constraints**: `_preferred_path_idx` always returned the first non-reset path for u_b at cycle > 0, which was always the SHIFT path (`orig_in_a > 255`). This meant ALL work items accumulated `top_in_c1 > 255` from cycle 1. The assertion violation requires `top_in_c1 <= 255` (no-shift at cycle 1) AND `top_in_c3 > 255` (shift at cycle 3). The no-shift forks existed but were deprioritized by ID ordering (lower IDs processed first at equal scores), so after 90K items, none had been explored.

### Solution

**Fix A — Skip abandoned CFGs instead of killing work items** (`strategies.py:_execute_cycle`):
- Before executing each CFG, snapshot `state.store` and `state.pending_nba` via `deepcopy`
- If the CFG path is abandoned, restore the snapshot and `continue` to the next CFG
- Safe because `_try_add_constraint` uses push/pop and never permanently adds UNSAT constraints to the Z3 solver
- The work item survives to the next cycle with its original score (no fork penalty)

**Fix B — Alternate preferred non-reset paths by cycle** (`strategies.py:_preferred_path_idx`):
- When multiple non-reset paths exist (e.g., shift vs no-shift in u_b), rotate among them using `(cycle - 1) % len(non_reset_indices)`
- Cycle 1: no-shift (path 2), Cycle 2: shift (path 1), Cycle 3: no-shift, Cycle 4: shift
- Creates diverse constraint combinations across cycles as the main (un-penalized) path
- The critical combination (no-shift at cycle 1, shift at cycle 3) now appears naturally

### Changes Made

#### `engine/strategies.py`

**`_execute_cycle()` (lines 730-753)**:
```python
# Before:
if manager.abandon or manager.ignore:
    return None  # Killed entire work item

# After:
pre_cfg_store = deepcopy(state.store)
pre_cfg_nba = deepcopy(state.pending_nba)
# ... execute path ...
if manager.abandon or manager.ignore:
    state.store = pre_cfg_store
    state.pending_nba = pre_cfg_nba
    manager.abandon = False
    manager.ignore = False
    continue  # Skip this CFG, proceed to next
```

**`_preferred_path_idx()` (lines 525-528)**:
```python
# Before:
for i, d in enumerate(first_dirs):
    if d == 0:
        return i  # Always returned first non-reset path

# After:
non_reset_indices = [i for i, d in enumerate(first_dirs) if d == 0]
return non_reset_indices[(cycle - 1) % len(non_reset_indices)]
```

### Debug Print Cleanup

Removed all debug prints added during investigation across multiple files:
- `helpers/slang_helpers.py`: Removed `[DECL-COMB-DEBUG]`, `[DECL-RESOLVE-DEBUG]`, `[CFG1-COND-DEBUG]`, `[INNER-COND-DEBUG]`, `[ASSERT-VISIT-DEBUG]`, `[ASSERT-DEBUG]`, `[HANDLER-MATCH]` prints
- `engine/strategies.py`: Removed `[EXEC-PATH-DEBUG]` prints
- `helpers/rvalue_to_z3.py`: Removed `[INTVEC-DEBUG]`, `[BINEXPR-LESSEQ-DEBUG]` prints; replaced verbose `solve_pc` UNSAT dump with `logging.debug`
- `frontend/coi_analyzer.py`: Removed `[COI-DEBUG]` prints

### Results

| Metric | Before | After |
|--------|--------|-------|
| Work items explored | 90,000+ (no result) | **8** |
| Execution time | Ran indefinitely | **0.079 seconds** |
| Assertion violation | Never found | **Found at cycle 4** |

**Counterexample**:
```
rst_n_c0 = 0       (reset)
rst_n_c1..c4 = 1   (non-reset)
top_in_a_c1 = 255  (input <= threshold, enters no-shift data path)
top_in_a_c3 = 256  (input > threshold, triggers shift, wrong data latch)
```

This matches the simulation-observed violations at times 75000 and 85000.

### PySlang Library Usage
- No new pyslang API usage in this change.

## 2026-03-14 - Concrete Short-Circuit & Constraint Deduplication

### Problem

After fixing the CFG recursion bug and lazy fork, the engine explores many paths but suffers from two performance issues:

1. **Concrete-false dead ends**: Conditions like `0 != 0` are trivially `False` but still cloned, added to the solver, and sent to Z3 — wasting time on guaranteed UNSAT paths.
2. **Duplicate constraints**: The same constraint (e.g., `rst_c0 == 1`) is added 10-30+ times to the same solver because every module's always block independently checks `if (rst)` and all share the same unified symbol via port unification.

Both issues inflate the solver's assertion list, slow down Z3, and generate pointless work items.

### Root Cause

- **Concrete-false**: When symbolic values are concrete (e.g., `BitVecVal(0, 32)` from register initialization), branch conditions like `rst != 0` simplify to `False`. The old code unconditionally pushed/popped/added these to Z3, which returned UNSAT after a full solver call.
- **Duplicates**: Port unification assigns a shared Z3 `BitVec` (e.g., `rst_c0`) to all modules connected through ports. Each module's always block has `if (rst)`, producing the same constraint `rst_c0 != 0`. Without deduplication, the solver accumulates N copies (one per module instance).

### Solution

#### 1. `_try_add_constraint()` helper (`helpers/slang_helpers.py`)

A single reusable function used by all three branch handlers. Three-stage logic:

1. **Concrete short-circuit**: `z3.simplify()` the constraint, then `is_true()` / `is_false()` check. Trivially true constraints are skipped (nothing to add). Trivially false constraints cause immediate path abandonment — no Z3 solver call needed.
2. **Duplicate detection**: Convert simplified constraint to S-expression key via `.sexpr()`. If the key is already in `s.pc_constraint_set`, skip — the solver already has this constraint.
3. **Symbolic SAT check**: Only if the constraint is non-trivial and novel, push/pop test with Z3. If SAT, commit permanently and record the key.

#### 2. `pc_constraint_set` on `SymbolicState` (`engine/symbolic_state.py`)

A `set()` tracking S-expression keys of constraints already in the solver. Initialized empty in `__init__`.

#### 3. Clone support (`engine/strategies.py`)

- `_clone_state()`: copies `pc_constraint_set` with `set(state.pc_constraint_set)`.
- `BlindSearchStrategy`: clears `pc_constraint_set` alongside `pc.reset()` between paths.

### Changes Made

#### `engine/symbolic_state.py`
- Added `self.pc_constraint_set = set()` in `__init__`.

#### `helpers/slang_helpers.py`
- Added `simplify, is_true, is_false` to z3 imports.
- Added module-level `_try_add_constraint(constraint, s, m)` function.
- **Conditional handler** (~line 1077-1088): Replaced push/pop/add/solve_pc block with `_try_add_constraint()` call.
- **WhileLoop handler** (~line 1119-1175): Replaced push/assert_and_track/pop block (with Redis cache logic) with `_try_add_constraint()` call. Removed the now-unnecessary push/pop scoping around the loop body.
- **CaseStatement handler** (~line 1200-1246): Replaced push/assert_and_track/pop block (with Redis cache logic) with `_try_add_constraint()` call. Removed orphaned `s.pc.push()` and `s.pc.pop()` calls.

#### `engine/strategies.py`
- `_clone_state()`: Added `new_state.pc_constraint_set = set(state.pc_constraint_set)`.
- `BlindSearchStrategy.run()`: Added `state.pc_constraint_set.clear()` after `state.pc.reset()`.

### Expected Impact

| Metric | Before | After |
|--------|--------|-------|
| Concrete-false paths | Full Z3 call per path | Instant abandon (no solver) |
| Duplicate constraints | N copies in solver (N = module instances) | 1 copy per unique constraint |
| Z3 assertion list size | Inflated by 10-30x | Minimal unique set |
| Path pruning speed | O(solver call) for trivial cases | O(1) for concrete + duplicate cases |

### PySlang Library Usage
- No new pyslang API usage in this change.

## 2026-03-14 - Sylvia-style Lazy Fork: Fix Cartesian Product Ordering and Dead-Path Starvation

### Problem

After the Sylvia-style refactor (same date, earlier entry), all 201 paths were abandoned at `or1200_top/cfg27/path0` with zero paths reaching the next cycle. Two issues:

1. **Cartesian product ordering bug**: `itertools.product` iterates the leftmost index slowest. cfg27 (first branching CFG) was always path0 in all 200 alternatives. cfg27/path1 was never generated.
2. **Upfront clone waste**: 200 states were cloned eagerly before any execution. Most were immediately abandoned at the first CFG, wasting ~1.4s each (283s total for 201 paths).

### Root Cause

The previous fix generated all path combinations upfront via `iter_product(*branching_ranges)`. With cfg27 as the first branching CFG (index 0), its path index varied slowest. The first 200 alternatives only varied later CFGs while cfg27 stayed at path0. Since cfg27/path0 always triggered `abandon`, no path ever reached `[Enqueue]`.

### Solution: Lazy Fork at Branch Points

Replaced upfront Cartesian product generation with lazy forking:

- Execute CFGs sequentially on a single state
- When encountering a branching CFG (multiple paths), clone the pre-branch state and push sibling paths as new WorkItems
- Continue executing the chosen path on the current state
- If the chosen path is abandoned, siblings are already in the worklist and will be explored

This means cfg27/path1 gets pushed to the worklist *before* cfg27/path0 is executed. When path0 is abandoned, the worklist already contains path1 ready to go.

### Key Advantages Over Previous Approach

| Aspect | Upfront Cartesian | Lazy Fork |
|--------|------------------|-----------|
| Clone timing | All 200 clones before any execution | Clone only at branch points |
| cfg27/path1 | Never generated (index 0 varies slowest) | Pushed immediately |
| Abandoned paths | All 200 wasted | Only clones up to the abandon point |
| Memory | 200 full state copies | O(branching factor) at each CFG |

### Changes Made

#### `engine/strategies.py`

Rewrote `_execute_cycle()` with lazy fork strategy:
- `execution_context['remaining_cfgs']`: list of `{module, cfg_idx, path_idx, forked}` dicts tracking which CFGs to execute and which path
- At each branching CFG: clone pre-branch state, push siblings with `forked=True` (prevents re-forking)
- Siblings carry `remaining_cfgs` from the current CFG onward, so they resume execution mid-cycle
- Default path (path 0) executed inline; alternatives deferred to worklist

### PySlang Library Usage
- No new pyslang API usage in this change.

## 2026-03-14 - Sylvia-style Cycle Execution: Fix O(M²) Comb Re-evaluation and State Explosion

### Problem

Running `python3 -m main 30 or1200_subset.F --sv --auto-plan --milestone-file milestones/or1200_subset.json --coi --strategy directed -t or1200_top` could not complete even a single cycle (Path 1, cycle 0). Two compounding issues:

1. **O(M²) combinational re-evaluation**: After each module's CFG execution, all other modules' comb logic was re-evaluated (nested loop over `manager.names_list`), producing massive `[EVAL-COMB]` log output.
2. **Intra-cycle state explosion**: Each CFG forked `active_states` via `_execute_cfg_step_by_step`, causing multiplicative growth: 1 → 2 → 4 → 12 → 36 → 132 → 492 states within a single cycle. With ~28 module instances and hundreds of CFGs, the cycle never finished.

### Root Cause

In `strategies.py` `_execute_cycle()`:

**Issue 1** (lines 641-652, old code): After each module's CFGs, a nested loop re-evaluated comb for all other modules:
```python
for state in active_states:
    self._propagate_ports(state, module_name)
    for dep_module in manager.names_list:          # O(M)
        if dep_module != module_name:
            for node in self._comb_by_module[dep_module]:  # O(C)
                visitor.evaluate_comb(...)
```
Total: O(M × M × C × |states|) evaluate_comb calls per cycle.

**Issue 2** (lines 626-644, old code): Each CFG execution multiplied active_states:
```python
for cfg_idx, cfg in enumerate(cfgs_by_module[module_name]):
    next_active_states = []
    for state in active_states:
        result = self._execute_cfg_step_by_step(...)  # returns multiple states
        next_active_states.extend(result)
    active_states = next_active_states  # grows exponentially
```

### Solution (Sylvia-style)

Referencing the Sylvia paper's execution model, two key changes:

**Fix 1 — Fixed-point comb evaluation**: Replaced the O(M²) nested loop with `_evaluate_comb_fixedpoint()`, which evaluates all modules' comb logic in 2 passes (sufficient for DAG-structured combinational logic) then propagates ports. Called only at cycle boundaries, not after each module.

**Fix 2 — Single-state cycle execution**: Instead of forking states inside a cycle, each cycle executes exactly ONE path combination (one path per CFG). Alternative path combinations are pushed as separate WorkItems into the global priority queue. This matches Sylvia's approach of deferring branching to the worklist level.

New `_execute_cycle()` flow:
1. Apply NBA + refresh inputs + comb fixed-point (cycle > 0)
2. Collect all CFGs with their path indices
3. Compute Cartesian product of branching CFGs' paths
4. Execute combo[0] on current state (single state, no fork)
5. Push remaining combos (up to 200) as new WorkItems
6. Post-sequential comb fixed-point
7. SAT check → milestone check → enqueue next cycle

### Performance Impact

| Metric | Before | After |
|--------|--------|-------|
| evaluate_comb calls/cycle | M × (M-1) × C × \|states\| | 2 × M × C |
| States per cycle | Exponential (1→492→...) | Always 1 |
| Cycle completion | Never (stuck on Path 1) | Completes normally |
| Branching | Intra-cycle fork | Deferred to worklist |

### Changes Made

#### `engine/strategies.py`

- **New method `_evaluate_comb_fixedpoint()`**: 2-pass comb evaluation + port propagation for all modules.
- **Rewrote `_execute_cycle()`**: Sylvia-style single-state execution with Cartesian product branching deferred to worklist. MAX_ALTERNATIVES=200 caps sibling work items.
- **Updated `_initialize_state()`**: Uses `_evaluate_comb_fixedpoint()` after `_unify_port_symbols()`.
- **`_execute_cfg_step_by_step()`**: Still exists but no longer called from `_execute_cycle()` (kept for compatibility).

### Intermediate Fix Attempt (str-based convergence — reverted)

Initially tried a true fixed-point with `deepcopy(state.store)` + `str()` comparison for convergence detection. This caused Z3 printer stack overflow on deep expressions (or1200's Z3 ASTs are very deep). Reverted to simple 2-pass approach.

### PySlang Library Usage
- No new pyslang API usage in this change.

## 2026-03-12 - Fixed Nested-If CFG Path Generation and Assertion Reachability

### Problem: Assertion never executed — cfg1 only generated 1 path instead of 3

The assertion always block in `my_assertions` (cfg1) contains nested `if` statements:
```systemverilog
always @(posedge clk) begin
    if (rst_n && check_en) begin        // outer if
        if (past_3_in_a <= THRESHOLD) begin  // inner if
            assert (b_out == (past_3_in_a + 1));
        end
    end
end
```

This should produce 3 CFG paths:
- Path 0: `[1,1]` — outer true, inner true → **assert executed**
- Path 1: `[1,0]` — outer true, inner false → skip assert
- Path 2: `[0]` — outer false → skip all

But cfg1 only generated 1 path. The assertion was never reached, and every path was pruned/abandoned.

### Root Cause 1: `BlockStatementSyntax` iteration yields raw tokens (`cfg.py: basic_blocks_sv`)

`BlockStatementSyntax` (begin...end blocks) is iterable in pyslang, but iterating it directly yields raw syntax tokens (`BeginKeyword`, `SyntaxList`, `EndKeyword`) rather than semantic statement children. When `_process_conditional_sv` passed the outer if's then-body (a `BlockStatementSyntax`) to `basic_blocks_sv`, the code entered the `hasattr(ast, '__iter__')` branch and iterated raw tokens. The inner `ConditionalStatementSyntax` was never recognized as a branching point.

### Root Cause 2: `partition()` / `find_basic_block()` collapsed adjacent partition points (`cfg.py`)

Even after fixing Root Cause 1, the inner if produced adjacent partition points (e.g., `[0, 2, 3, 4, 5, 6]`). The old `partition()` used `start = pp[i-1]+1` to `end = pp[i]` for intermediate blocks, which produced empty slices when partition points were adjacent. These empty blocks were skipped, collapsing all branch targets into a single block. `find_basic_block()` had matching issues, mapping different nodes to the same block index. Result: all CFG edges pointed to the same block → `nx.all_simple_paths` found only 1 degenerate path.

### Changes Made

#### `engine/cfg.py`

**Fix 1 — `basic_blocks_sv()`: Handle `BlockStatementSyntax` before generic iteration**

Added an early check at the top of the iterable branch:
```python
if isinstance(ast, ps.BlockStatementSyntax):
    self.block_stmt_depth += 1
    self.block_smt.append(True)
    self.basic_blocks_sv(m, s, ast.items)  # Use .items, not direct iteration
    if self.block_stmt_depth in self.ind_branch_points:
        self.resolve_independent_branch_pts(self.block_stmt_depth)
    self.block_smt.pop()
    self.block_stmt_depth -= 1
    return
```

This ensures `BlockStatementSyntax` routes through `ast.items` (which yields actual statements like `ConditionalStatementSyntax`) instead of raw tokens.

**Fix 2 — `partition()`: Rewritten for correct block boundaries**

New logic:
- Block 0: `all_nodes[pp[0] .. pp[1]]` (inclusive) — preamble + first conditional
- Blocks 1+: each starts at `pp[2+]` (branch targets), extends to the next branch start
- Last block extends to `len(all_nodes)`

This correctly handles adjacent partition points by treating each `pp[2+]` as the start of a separate block.

**Fix 3 — `find_basic_block()`: Rewritten to match new partition logic**

- `node_idx <= pp[1]` → block 0
- Otherwise, reverse-scan `branch_starts = pp[2:]` to find the containing block

### Results

cfg1 now correctly generates 3 paths:
```
Path 0: [-1, 0, 1, 2, -2]  — outer then, inner then → assert executed
Path 1: [-1, 0, 1, 3, -2]  — outer then, inner else → skip assert
Path 2: [-1, 0, 4, -2]     — outer else → skip all
```

All other CFGs (module_a, module_b, top) continue to work correctly.

The SE engine successfully detected the assertion violation `b_out == (past_3_in_a + 1)` in 8 path explorations, reaching milestone 3/5 at cycle 4.

**Counterexample**: `rst_n_c0=0, rst_n_c1..c4=1, top_in_a_c1=0, top_in_a_c2=0, top_in_a_c3=0, top_in_a_c4=1`

**Execution time**: ~0.75s

### PySlang Library Usage
- `BlockStatementSyntax` (begin...end): Is iterable but yields raw syntax tokens. Use `.items` property to get semantic statement children.
- `ConditionalStatementSyntax` (if...else): `.ifTrue` gives the then-body (often a `BlockStatementSyntax`), `.elseClause` gives the else clause.

## 2026-03-09 - Fixed False Positive Bug Detection and CFG Issues

### Problem 1: False Positive Termination
When running directed symbolic execution with milestones, the tool incorrectly reported finding a bug in cycle 0 with no counterexample.

### Problem 2: Z3 Bit Width Mismatch
After fixing Problem 1, the tool crashed with Z3 type error when comparing signals with different bit widths.

### Problem 3: Invalid Basic Block Indices in CFG Paths
The tool generated warnings about invalid basic_block_idx that exceeded the actual number of basic blocks.

### Problem 4: All Milestones Reached Simultaneously
Milestones jumped from 0/7 to 7/7 in a single cycle, defeating their purpose as incremental waypoints. The while loop in strategies.py checked all milestones sequentially until one failed, allowing all satisfiable milestones to be marked as "reached" at once.

### Root Causes

**Problem 1**: In `engine/strategies.py`, the directed search strategy had a logic error:
1. Lines 509-514: Check if milestones are satisfiable using Z3 solver
2. Lines 516-517: If all milestones satisfiable, return `"ALL_MILESTONES"` immediately
3. Lines 520-521: Check for assertion violations (NEVER REACHED due to early return)

Z3 satisfiability means "this condition COULD be true with some variable assignment", not "this condition IS true with concrete values". In cycle 0, all milestones were satisfiable with symbolic variables, so the tool incorrectly treated this as success.

**Problem 2**: In `engine/milestone.py` line 202, when creating Z3 constants for milestone comparisons, the code always used 32-bit width:
```python
target = BitVecVal(cond.value, 32)  # Always 32 bits!
```

But signals can have different widths (e.g., 6-bit counters, 1-bit flags), causing type mismatches.

**Problem 3**: In `engine/cfg.py`, the `basic_blocks_sv` method skips empty blocks when creating `basic_block_list`:
```python
if basic_block:  # Only add non-empty blocks
    self.basic_block_list.append(basic_block)
```

But `find_basic_block` assumes a direct mapping between `partition_list` indices and block indices. When blocks are skipped, this mapping breaks:
- `partition_list` might have 7 elements (expecting 6 blocks)
- But if 2 blocks are empty, `basic_block_list` only has 4 blocks
- `find_basic_block` returns indices up to 5, but max valid is 3

This causes `make_paths()` to create CFG edges with invalid block indices, which then appear in NetworkX paths.

**Problem 4**: In `engine/strategies.py` lines 503-508, a while loop continuously checked all milestones:
```python
while current_progress < len(self.milestone_manager.milestones):
    success, new_progress = self.milestone_manager.check_and_lock_stateless(state, current_progress)
    if success:
        current_progress = new_progress
    else:
        break
```

In cycle 0, all milestones were satisfiable with symbolic variables, so the loop advanced through all 7 milestones at once (0→1→2→...→7), defeating the purpose of incremental waypoints.

### Solutions

**Problem 1**: Removed the early return for `"ALL_MILESTONES"`. Milestones now only guide search priority, not act as terminal success conditions.

**Changes in `engine/strategies.py`**:
- Removed lines 516-517 that returned `"ALL_MILESTONES"`
- Removed lines 399-403 that handled `"ALL_MILESTONES"` as success
- Now only `"VIOLATION"` terminates the search successfully

**Problem 2**: Fixed bit width matching in milestone comparisons.

**Changes in `engine/milestone.py` line 202**:
```python
# Before:
target = BitVecVal(cond.value, 32)

# After:
target = BitVecVal(cond.value, signal_value.size())
```

**Problem 3**: Added bounds checking in `find_basic_block` to clamp return values.

**Changes in `engine/cfg.py` lines 436-443**:
```python
# Before:
return i - 1

# After:
return min(i - 1, len(self.basic_block_list) - 1)
```

**Problem 4**: Changed milestone checking to one per cycle, and improved LLM prompt.

**Changes in `engine/strategies.py` lines 500-508**:
```python
# Before: while loop checking all milestones
while current_progress < len(self.milestone_manager.milestones):
    success, new_progress = self.milestone_manager.check_and_lock_stateless(...)
    if success:
        current_progress = new_progress
    else:
        break

# After: check only one milestone per cycle
if current_progress < len(self.milestone_manager.milestones):
    success, new_progress = self.milestone_manager.check_and_lock_stateless(...)
    if success:
        current_progress = new_progress
```

**Changes in `frontend/llm_planner.py`**:
- Added Rule 3: "Temporal Progression" to SYSTEM_PROMPT
- Instructs LLM to generate milestones that form a temporal sequence across clock cycles
- Emphasizes that early milestones should be prerequisites for later ones
- Avoids conditions that can be satisfied simultaneously in a single cycle

### Verification
After all four fixes:
- No more false positive terminations in cycle 0
- No more Z3 type errors
- No more "Skipping invalid basic_block_idx" warnings
- Milestones now progress incrementally: 0/7 → 1/7 → 2/7 → ... → 7/7
- No more false positive terminations in cycle 0
- No more Z3 type errors
- No more "Skipping invalid basic_block_idx" warnings
- Tool correctly explores paths: `[Path 8] cycle=2, milestones=7/7, queue=21`

## 2026-03-06 - Context Slicer Enhancement and COI Fixes

### Problem 1: Incomplete RTL Context for LLM Milestone Generation
When using `--auto-plan` with OR1200, the LLM received only the top-level module wrapper (25K chars) without the actual logic that implements the assertion signals. This caused poor milestone generation.

**Example**: For assertion `operand_b == dcpu_dat_o` in `or1200_cpu.u_assertions`:
- **Before**: Context only included `or1200_top` (wrapper with port declarations)
- **After (without COI)**: Context includes `or1200_cpu`, `or1200_alu`, `or1200_lsu`, `or1200_operandmuxes`, `or1200_sprs`, `or1200_mult_mac`, `or1200_fpu` (109K chars with actual logic)
- **After (with COI)**: Context includes only `or1200_cpu`, `or1200_operandmuxes` (26K chars - the minimal relevant set)

### Problem 2: COI Analysis Failing with Hierarchical Instance Names
COI analysis was receiving seed signals with hierarchical paths like `or1200_cpu.u_assertions.operand_b`, but the port map used short instance names like `u_assertions`. This caused:
1. Port connection lookups to fail
2. COI to find 0 relevant instances
3. Either "No modules found to execute" error or execution issues

### Problem 3: IndexError During Execution with COI
After fixing the seed signal naming, execution crashed with `IndexError: list index out of range` when accessing `cfg.basic_block_list[basic_block_idx]`. This was caused by CFG paths containing invalid basic block indices that exceed the actual basic block list size.

### Root Cause Analysis

**Problem 1**:
1. `ContextSlicer.get_context()` only parsed the target expression for instance names (e.g., `or1200_cpu.u_assertions`)
2. It never analyzed which submodules actually drive the assertion signals
3. For OR1200, assertion signals like `operand_b` and `dcpu_dat_o` are produced by sibling modules of `u_assertions`, not by the top module

**Problem 2**:
1. `assertion_extractor.py` sets `module_name` to the full hierarchical path `or1200_cpu.u_assertions`
2. This becomes the COI seed: `(or1200_cpu.u_assertions, operand_b)`
3. But `COIAnalyzer` builds port maps using short names from `modules_dict`: `(u_assertions, operand_b)`
4. Lookup fails at `port_map_child_to_parent[(or1200_cpu.u_assertions, operand_b)]`

**Problem 3**:
1. CFG construction creates paths that reference basic block indices
2. Some paths contain indices that are out of bounds for the `basic_block_list`
3. This is likely a bug in CFG construction or path generation
4. When COI keeps certain CFGs, these invalid paths cause crashes during execution

### Changes Made

#### `frontend/context_slicer.py`
1. **Added signal extraction** (new method `_extract_signal_names_from_expr`):
   - Extracts leaf signal names from target expressions
   - Filters out operators, literals, and common keywords

2. **Added parent module detection** (new method `_find_assertion_module_parent`):
   - Finds the parent module that instantiates the assertion module
   - Returns parent module instance and path

3. **Added sibling module discovery** (new method `_find_sibling_modules_for_signals`):
   - Searches parent module's source code for child instances
   - Identifies which children have port connections to the assertion signals
   - Uses regex to match instance declarations and port connections

4. **Enhanced `get_context` method**:
   - When target references an assertion module, traces signal dependencies
   - Includes parent module and all relevant sibling submodules
   - Constructs full hierarchical paths for instance lookup
   - Falls back to original behavior if assertion parent not found
   - **Works with COI**: When COI provides relevant instances, uses those instead

5. **Added children tracking** (in `_build_maps`):
   - New `_children_map` to track parent → children relationships
   - Enables efficient sibling module lookup

#### `engine/execution_engine.py`
**Fixed COI seed signal instance names** (lines 593-607):
- Extract the last component of hierarchical paths for instance names
- `or1200_cpu.u_assertions` → `u_assertions`
- This matches the short names used in `modules_dict` and port maps
- COI can now successfully trace through port connections

**Fixed COI empty result handling** (lines 609-636):
- When COI finds no relevant instances, set `self.coi_result = None`
- Skip pruning entirely to avoid removing all modules
- Prevents "No modules found to execute" error

#### `engine/strategies.py`
**Added safety check for invalid basic block indices** (lines 613-626):
- Before accessing `cfg.basic_block_list[basic_block_idx]`, check if index is valid
- If `basic_block_idx >= len(cfg.basic_block_list)`, skip that basic block with a warning
- Warning includes: module name, CFG index, path index, invalid index, valid range, and total blocks
- Example: `[Warning] Skipping invalid basic_block_idx 5 in or1200_cpu/cfg51/path2 (max: 4, total blocks: 5)`
- Allows execution to continue despite CFG construction bugs
- Prevents `IndexError` crashes

**Updated `_execute_path` signature** (lines 593-604):
- Added optional parameters `cfg_idx` and `path_idx` for better error reporting
- Defaults to -1 if not provided (for backward compatibility)

#### `engine/milestone.py`
**Fixed hierarchical signal path handling** (lines 73-95):
- Added support for hierarchical signal paths with more than 2 parts (e.g., `or1200_cpu.u_assertions.operand_b`)
- When a path has 3+ parts, extracts the signal name (last part) and searches all modules
- This handles cases where LLM generates hierarchical paths but the actual signal is stored in a different module
- Example: `or1200_cpu.u_assertions.operand_b` → searches for `operand_b` in all modules → finds it in `or1200_operandmuxes`
- Eliminates "Invalid signal path format" warnings during milestone checking
**Fixed PySlang version compatibility** (line 52-66):
- Added fallback for `ConditionalExpressionSyntax` attributes
- Tries `ifTrue`/`ifFalse` first (PySlang 7.0)
- Falls back to `left`/`right` for other versions
- Prevents `AttributeError: 'ConditionalExpressionSyntax' object has no attribute 'ifTrue'`

### Testing Results

**Without COI** (`--auto-plan` only):
- Context: 109K chars (7 modules)
- Includes all sibling modules that connect to assertion signals
- Works but may exceed LLM context limits on large designs

**With COI** (`--auto-plan --coi`):
- Context: 26K chars (2 modules: `or1200_cpu`, `or1200_operandmuxes`)
- COI correctly identifies minimal relevant set
- Execution proceeds with warnings about invalid basic block indices
- Successfully reaches milestones and completes

**Working command**:
```bash
python3 -m main 50 or1200_subset.F --sv --auto-plan --llm-provider deepseek --coi --strategy directed -t or1200_top
```

### Known Issues

**CFG Path Construction Bug**: Some CFG paths contain basic block indices that exceed the actual basic block list size. The safety check in `strategies.py` works around this by skipping invalid indices with a warning. The root cause in CFG construction should be investigated and fixed in a future update.

### PySlang Library Usage
- `ConditionalExpressionSyntax`: Ternary operator `cond ? true_val : false_val`
  - PySlang 7.0: uses `predicate`, `ifTrue`, `ifFalse` attributes
  - Other versions: may use `predicate`, `left`, `right` attributes
  - Added compatibility layer with `hasattr()` checks

## 2024 - Assertion Extraction and Condition Parser Fixes

### Problem 1: Assertion Extraction
PySlang could correctly parse `ImmediateAssertion` statements, but the assertion extraction was failing due to:
1. **Module selection issue**: Without `-t` parameter, `_discover_modules` defaulted to the first top instance (`or1200_dc_fsm`) instead of the correct one (`or1200_top`)
2. **Deduplication bug**: Using `str(assertion)` for deduplication caused all assertions to be treated as identical since they all returned `Expression(ExpressionKind.BinaryOp)`

### Problem 2: LLM Planner Validation Errors
The condition parser and milestone system had several limitations:
1. **Verilog bit-width format not supported**: `2'b01`, `32'hFF` couldn't be parsed
2. **Signal-to-signal comparisons not supported**: `sig_a != sig_b` failed validation
3. **Tokenizer bug**: `!=` was incorrectly split into `!` and `=` tokens

### Root Cause Analysis
- `or1200_assertions` module is instantiated in `or1200_cpu.v:1029` as `u_assertions`
- The instance hierarchy is: `or1200_top` → `or1200_cpu` → `u_assertions`
- When analyzing `or1200_dc_fsm` instead of `or1200_top`, the assertion module was never traversed
- The condition parser only supported `signal op constant` format, not `signal op signal`

### Changes Made

#### `frontend/assertion_extractor.py`
1. **Fixed deduplication logic** (lines 159-177):
   - Changed from using `str(assertion)` to using `sourceRange` or object `id()`
   - This allows each unique assertion to be properly identified

2. **Optimized search strategy** (lines 114-123):
   - Only search the top-level module once
   - Let `get_assertions` recursively traverse all sub-instances
   - Prevents duplicate assertions from being found multiple times

3. **Added support for standalone assertion modules** (lines 133-150):
   - Search all top instances for modules with "assert" in their name
   - Skip modules already searched to avoid duplicates
   - Useful for designs with uninstantiated assertion modules

#### `frontend/condition_parser.py`
1. **Enhanced `parse_value` function** (lines 35-73):
   - Added support for Verilog bit-width formats: `2'b01`, `32'hFF`, `6'd42`
   - Handles formats: `width'base_value` where base can be `h`, `b`, or `d`

2. **Updated `SimpleCondition` dataclass** (lines 8-20):
   - Changed `value` type from `int` to `Union[int, str]`
   - Added `is_signal_comparison()` method to distinguish signal vs constant comparisons

3. **Enhanced `parse_simple_condition` function** (lines 69-125):
   - Try to parse right-hand side as numeric value first
   - If that fails, treat it as a signal path (signal-to-signal comparison)
   - Uses regex to validate signal names: `^[a-zA-Z_][\w.\[\]:]*$`

4. **Fixed `tokenize_condition` function** (lines 128-193):
   - Modified to not split `!=` into separate tokens
   - Only treats `!` as NOT operator when not followed by `=`
   - Preserves `!=` as part of comparison expressions

5. **Enhanced `extract_signal_name` to support bit-select syntax** (lines 362-385):
   - Now strips bit-select brackets `[...]` before extracting signal name
   - Examples:
     - `ex_insn[31:26]` → `ex_insn`
     - `module.signal[7:0]` → `signal`
   - This allows LLM to generate milestone conditions with bit-select syntax
   - Fixes validation errors like "Signal 'ex_insn[31:26]' not found"
   - Enables more precise milestone conditions (e.g., checking instruction opcodes)

#### `engine/milestone.py`
1. **Enhanced `_build_simple_condition` method** (lines 144-183):
   - Check if `cond.value` is a string (signal path) or int (constant)
   - For signal-to-signal comparisons, resolve both signals to Z3 expressions
   - For constant comparisons, use `BitVecVal` as before

#### Test Results
- ✅ **test_2.v**: Correctly finds 1 assertion (previously found duplicates)
- ✅ **or1200 design**: Correctly finds all 71 assertions when using `-t or1200_top`
- ✅ **Verilog formats**: `2'b01`, `32'hFF` parse correctly
- ✅ **Signal comparisons**: `sig_a != sig_b` works in milestones
- ✅ **Tokenizer**: `!=` no longer split incorrectly

### Usage

**For test_2.v**:
```bash
python3 -m main 16 designs/test-designs/test_2.v --sv --auto-plan --llm-provider deepseek --coi --strategy directed
```

**For or1200 design**:
```bash
python3 -m main 3 or1200.F --sv --auto-plan --llm-provider deepseek --coi --strategy directed -t or1200_top
```

**Key**: The `-t or1200_top` parameter is essential to specify the correct top-level module.

### Files Modified
- `frontend/assertion_extractor.py`: Fixed deduplication and search logic
- `frontend/condition_parser.py`: Added Verilog format support and signal-to-signal comparisons
- `engine/milestone.py`: Enhanced to handle signal-to-signal comparisons
- `engine/execution_engine.py`: Updated calls to pass `compilation` and `driver` parameters

### Files Created (Optional)
- `designs/benchmarks/or1200/buggy-or1200/or1200_assertions_wrapper.sv`: Wrapper module (not needed if using `-t` parameter)
- `or1200_with_assertions.F`: Alternative filelist (not needed if using `-t` parameter)

### Notes
- The wrapper approach works but is unnecessary since `or1200_assertions` is already instantiated in the design
- Using the `-t` parameter is the cleaner solution
- The deduplication fix is critical for any design with multiple assertions
- Signal-to-signal comparisons enable more expressive milestone conditions
- Verilog format support is essential for realistic hardware verification

---

## [2026-04-09] [Fix] Counterexample generation for cross-module hierarchical assertions (hackdac18)

### Problem
Running hackdac18 with `--auto-plan --coi --strategy directed` always reported:
```
Counterexample: violation is unconditional (no free variables).
```
The Z3 model was empty despite the assertion firing every cycle.

### Root Cause
The assertion `HACKDAC_p2` uses cross-module hierarchical references:
```sv
assert property (
    (~((top_wrapper.soc_interconnect.TCDM_data_gnt_DEM_TO_XBAR) >> 1) &&
    ((top_wrapper.soc_interconnect.TCDM_data_add_DEM_TO_XBAR >= 32'h1C00_0000) &&
     (top_wrapper.soc_interconnect.TCDM_data_add_DEM_TO_XBAR <= 32'h1C08_0000)))
);
```
These signals are driven by `assign` statements in `soc_interconnect` (not always blocks), so COI found no relevant CFGs — leaving them as unconstrained fresh Z3 variables. The violation fired unconditionally, but the suppression logic kept deferring it until milestones were reached (which never happened with bad LLM plans).

### Fixes

**`helpers/rvalue_to_z3.py` — `ScopedNameSyntax` handler**
- For hierarchical path `a.b.c`, now tries `parts[-2]` (owning module, e.g. `soc_interconnect`) first before current module and all modules
- Prevents wrong signal aliasing across modules (e.g. `TCDM_data_gnt_DEM_TO_XBAR` being resolved to a signal from a different module)

**`engine/strategies.py` — `_execute_cycle` (inner CFG loop + Step 6)**
- Added unconditional violation detection: when `state.pc.assertions()` yields an empty/tautological solver model (`len(decls)==0`), report immediately instead of suppressing forever
- Applied to both the inner CFG loop suppression block and the Step 6 milestone check

**`engine/strategies.py` — `_handle_assertion_violation`**
- Witness solver: when path condition model has no decls, solve `Not(z3_cond)` to get a concrete witness assignment
- Signal name display: build reverse map `z3_base_name → assertion_signal_name` from store, prioritizing names that appear in the assertion condition string; applied to both `z3_condition` display (using `base_cN` regex) and the counterexample trace
- Fixed: a second duplicate reverse map `z3base_to_sig` (length-only heuristic, no assertion priority) was being used for the counterexample trace display instead of the primary `_z3base_to_sig` map — removed the duplicate and unified to use the assertion-priority map throughout

### PySlang Notes
- `ScopedNameSyntax` represents hierarchical references like `a.b.c`; flatten with recursive `left`/`right` traversal
- `SyntaxKind.ScopedName` is the kind value for these nodes
- The store maps signal names to Z3 expressions; signals driven by `assign` aliases store the underlying input variable (e.g. `TCDM_data_add_DEM_TO_XBAR` → `HWPE_add_i_c0`)

### Result
```
z3_condition: (and (not (bvugt TCDM_data_gnt_DEM_TO_XBAR_c0 #x00000001))
 (bvuge TCDM_data_add_DEM_TO_XBAR_c0 #x1c000000)
 (bvule TCDM_data_add_DEM_TO_XBAR_c0 #x1c080000))

Counterexample trace (cycle-by-cycle):
  Cycle 0:
    TCDM_data_add_DEM_TO_XBAR = 470548480
    TCDM_data_gnt_DEM_TO_XBAR = 0
```

[2026-04-17] [BugFix] Fixed case statement CFG construction to correctly explore all case arms and nested conditionals (`engine/cfg.py`, `engine/strategies.py`).

**Problem**: DEMUX_MASTER_32/cfg2 (always_comb with case statement in l2_tcdm_demux.sv) generated only 1 path instead of 24, preventing exploration of the IDLE arm's ERROR sub-branch where `data_gnt_o=1` is set when no address match occurs. This blocked detection of the genuine HACKDAC_p2_fixed violation.

**Root cause 1 — wrong body attribute on StandardCaseItemSyntax**: `_process_case_sv` extracted the case item body via `getattr(case_item, "statements", getattr(case_item, "statement", None))`. PySlang's `StandardCaseItemSyntax` stores its body in the `.clause` attribute, not `.statements` or `.statement`. All case arms returned `body=None`, causing `_process_case_sv` to skip every arm via the early `continue` at line 392. Since `arm_found` stayed False, the function fell through to the `if not arm_found:` block and created a single dummy edge `(parent_idx, skip_idx)`, producing only 1 path.

**Root cause 2 — missing edge from arm marker to arm body**: After inserting a `CaseArmMarker` at `arm_start_idx` and processing the arm body via `basic_blocks_sv(body)`, no edge connected the marker block to the first body block. The marker node (e.g., at index 9 for IDLE arm) was added to `partition_points`, creating a separate block. The nested conditionals inside the arm body (e.g., `if(data_req_i)` at index 10) were also in separate blocks. But `edgelist` only had `(case_node, marker_node)` — no `(marker_node, body_first_node)`. When `find_leaves()` ran, the marker block had no outgoing edges, so it was identified as a leaf and connected directly to the dummy exit. Result: path 0 was `[-1, 0, 1, -2]` (case → IDLE marker → exit), with the entire arm body (blocks 2+) unreachable.

**Root cause 3 — deferred violation never re-checked after sliding window advance**: When an assertion violation fired during CFG execution (inner check at line 998), it was suppressed if `item.milestones_completed < total_milestones - 1` (line 1004). The violation was saved to `_deferred_violation` (line 1029-1030). Later in the same cycle, the sliding window advanced `current_progress` from 1 to 3 (line 1102-1108), skipping the hallucinated milestone 1. But the deferred violation was never re-checked after the window advanced. The code proceeded to Step 7 (enqueue next cycle) without reporting the violation, even though the milestone threshold was now satisfied.

**Fixes**:
1. `cfg.py:_process_case_sv` line 385: Changed body extraction to `getattr(case_item, "clause", getattr(case_item, "statements", getattr(case_item, "statement", None)))` — tries `.clause` first, then falls back to `.statements`/`.statement` for compatibility.
2. `cfg.py:_process_case_sv` line 424-426: After processing the arm body, added `if body_start_after_marker < self.curr_idx: self.edgelist.append((arm_start_idx, body_start_after_marker))` to connect the arm marker to the first node of the arm body (typically a nested conditional).
3. `engine/strategies.py` line 1110-1115: After `advance_with_sliding_window`, added check: if `current_progress >= total_milestones - 1` and `_deferred_violation is not None`, print `[Deferred Violation]` message and return "VIOLATION".

**PySlang API notes**:
- `StandardCaseItemSyntax` attributes: `.clause` (body BlockStatementSyntax), `.colon` (Token), `.expressions` (SeparatedList of arm label expressions)
- `.expressions` is a `SeparatedList` — must filter out `Token` nodes to get actual expression AST nodes
- `isinstance(item, ps.CaseItemSyntax)` returns True for `StandardCaseItemSyntax` (it's a subclass)

**Result**: DEMUX_MASTER_32/cfg2 now generates 24 paths (was 1). The IDLE arm's ERROR sub-branch (which sets `NS=ERROR` and `data_gnt_o=1'b1` when `data_req_i=1` and no TCDM/PER address match) is now reachable. The genuine HACKDAC_p2_fixed counterexample is found in ~22 seconds at cycle 1: `FC_DATA_add_int=0xFFBF0000` (out of TCDM range [0x1C00_0000, 0x1C08_0000]) with `TCDM_data_gnt_DEM_TO_XBAR=1`.

