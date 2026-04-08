# Performance Optimization Plan — Round 2

## Profiling Summary (or1200_subset, 30 cycles, directed strategy)

| Bottleneck | Time | Calls | % Total |
|---|---|---|---|
| `_evaluate_comb_fixedpoint` | 227s | 3 | 98% |
| `parse_expr_to_Z3` | 182s | 134M (1.1M primitive) | 80% |
| `_match_bv_widths` | 58s | 20M | 25% |
| Z3 printer (`str()` on Z3 objects) | 15s | 1.5M | 7% |

The `deepcopy` bottleneck from Round 1 is completely eliminated.

---

## My Assessment of the Proposed Fixes

### Task 1: Replace `str()` Z3 type checks — AGREE, easy win

The analysis is correct. `str(expr.sort()) == "Bool"` triggers Z3's C++ printer on every call. The fix is mechanical.

Locations found:
- `rvalue_to_z3.py:361` — `str(left_expr.sort()) == "Bool"` in `Z3Visitor.handle_binary_expression`
- `rvalue_to_z3.py:1349-1350` — `str(s.check()) == "sat"` in `solve_pc`
- `execution_engine.py:338,353-354` — `str(s.check()) == "sat"` in `solve_pc`

Note: the `Z3Visitor` class (lines 209-397) is a **legacy class** that is NOT used in the hot path. The hot path goes through `parse_expr_to_Z3` and its dispatch handlers. So the `str(sort())` at line 361 is not actually contributing to the 15s overhead. The real culprits are:
- `str(e.op)` calls inside `_kind_binary_op` and `_kind_unary_op` — called on every BinaryOp/UnaryOp node
- `str(e.kind)` in the fallback path
- `str(s.check())` in solver checks

**Verdict**: Fix all `str()` calls, but the biggest win is replacing `str(e.op)` with direct enum comparison.

### Task 2: Topological sort for combinational logic — AGREE with caveats

The analysis is correct that `_evaluate_comb_fixedpoint` with `max_iterations=2` is wasteful. However:

**Caveat 1**: The COI analyzer (`frontend/coi_analyzer.py`) already has `comb_writes` and `comb_reads` dependency data. We can leverage this directly instead of building a new dependency graph.

**Caveat 2**: For symbolic execution, topological sort gives us single-pass evaluation ONLY if there are no combinational loops. In practice, well-formed RTL should not have combinational loops, but we should keep a fallback.

**Caveat 3**: The real multiplier is that `_evaluate_comb_fixedpoint` is called 3 times per cycle per work item. Even with topological sort, we should also consider whether all 3 calls are necessary.

### Task 3: AST memoization — PARTIALLY DISAGREE

The `id(e)` caching approach proposed in the doc is **problematic**:

1. **State-dependent handlers**: `_kind_named_value` and `_syntax_identifier_name` read from `s.store[module][var]`. The same AST node produces different Z3 expressions depending on the current symbolic state. A naive `id(e)` cache would return stale results.

2. **PySlang node identity**: PySlang AST nodes DO have stable `id()` values (they're persistent Python objects from the compilation tree), but the result depends on the mutable `s.store`, so caching by `id(e)` alone is incorrect.

**Better approach**: Instead of caching the final Z3 result, we can cache the **structural analysis** of each AST node — i.e., "this node is a BinaryOp with operator Add, left child is NamedValue 'x', right child is IntegerLiteral 3". This avoids re-doing `hasattr`/`getattr`/`__class__.__name__` checks on every call. The actual Z3 expression construction (which depends on `s.store`) still runs, but the expensive Python introspection is skipped.

However, with the dispatch table refactoring already done in Round 1, the Python introspection overhead is already O(1) dict lookups. The remaining 182s is dominated by the sheer volume of calls (134M), not per-call overhead. **The real fix is reducing call count via topological sort (Task 2), not caching.**

### Task 4: Optimize `_match_bv_widths` — AGREE, but lower priority

Using `e.type.bitWidth` from PySlang is a good idea. However, this requires threading the PySlang node through to `_match_bv_widths`, which currently only receives Z3 expressions. This is a deeper refactoring.

A simpler win: many `_match_bv_widths` calls are between two 32-bit BitVecs (the default width). We can add a fast-path check at the top:
```python
def _match_bv_widths(lhs, rhs):
    # Fast path: both are 32-bit BitVecs (most common case)
    if isinstance(lhs, BitVecRef) and isinstance(rhs, BitVecRef):
        if lhs.size() == rhs.size():
            return lhs, rhs
    # ... existing logic ...
```

---

## Implementation Plan (ordered by impact/effort ratio)

### Task 1: Eliminate `str()` on Z3 objects [LOW effort, MEDIUM impact]

**Target files**: `helpers/rvalue_to_z3.py`, `engine/execution_engine.py`

1.1. Replace `str(e.op)` with direct enum comparison in `_kind_binary_op` and `_kind_unary_op`:
```python
# BEFORE: op = str(e.op) if hasattr(e, 'op') else ""
# AFTER:  op = e.op  (compare against ps.BinaryOperator.Add etc.)
```
This requires mapping PySlang operator enums. If the enum values are not stable across versions, keep `str()` but cache the result per-node.

1.2. Replace `str(s.check()) == "sat"` with `s.check() == z3.sat` in:
- `rvalue_to_z3.py:solve_pc` (line ~1349)
- `execution_engine.py:solve_pc` (lines ~338, 353)

1.3. Replace `str(left_expr.sort()) == "Bool"` with `z3.is_bool(left_expr)` in `Z3Visitor` (line 361). Low priority since this class is not in the hot path.

1.4. Audit all `str(getattr(e, 'kind', ''))` in `_fallback_dispatch` — these are in the slow path and acceptable for now.

### Task 2: Topological sort for combinational logic [MEDIUM effort, HIGH impact]

**Target files**: `engine/strategies.py`, `frontend/coi_analyzer.py`

2.1. Add a `topo_sort_comb(comb_by_module, coi_analyzer)` function that:
- For each module, builds a dependency graph from `coi_analyzer.comb_writes` (signal → set of read signals)
- Performs topological sort using `networkx.topological_sort` (already a dependency)
- Returns `sorted_comb_by_module: Dict[str, List[node]]` with nodes in dependency order

2.2. Call `topo_sort_comb` once during `MilestoneDirectedStrategy.run()` initialization (after COI analysis, before the worklist loop).

2.3. Replace `_evaluate_comb_fixedpoint` with `_evaluate_comb_topo`:
```python
def _evaluate_comb_topo(self, visitor, manager, state):
    """Single-pass evaluation in topological order."""
    for module_name in manager.names_list:
        manager.curr_module = module_name
        for node in self._sorted_comb_by_module.get(module_name, []):
            visitor.evaluate_comb(manager, state, node)
    self._propagate_ports(state)
```

2.4. Keep `_evaluate_comb_fixedpoint` as a fallback if topological sort fails (e.g., combinational loops detected).

**Expected impact**: Cuts `evaluate_comb` calls in half (from 2 passes to 1), reducing `parse_expr_to_Z3` calls from 134M to ~67M. Combined with the `str()` fix, this should yield 2-3x speedup.

### Task 3: Fast-path `_match_bv_widths` [LOW effort, MEDIUM impact]

**Target file**: `helpers/rvalue_to_z3.py`

3.1. Add early-return for the common case (both operands same width):
```python
def _match_bv_widths(lhs, rhs):
    if isinstance(lhs, BitVecRef) and isinstance(rhs, BitVecRef):
        if lhs.size() == rhs.size():
            return lhs, rhs
    # ... rest unchanged ...
```

3.2. In binary op handlers, use PySlang's `e.type.bitWidth` when available to pre-size operands, avoiding the need for `_match_bv_widths` entirely in cases where both sides are known-width.

### Task 4: Reduce `_evaluate_comb_fixedpoint` call frequency [LOW effort, HIGH impact]

**Target file**: `engine/strategies.py`

Currently called 3 times per cycle:
1. `_initialize_state` (line 476) — necessary, keep
2. `_execute_cycle` after NBA apply (line 655) — necessary, keep
3. `_execute_cycle` after sequential logic (line 750) — **questionable**

4.1. Audit whether call #3 is necessary. If the sequential logic (always blocks) already wrote to `s.store` directly, and the combinational logic only depends on those values, then the comb evaluation after sequential logic may be redundant with the comb evaluation at the start of the NEXT cycle.

4.2. If call #3 is needed for milestone checking (which happens right after), consider evaluating only the comb nodes that feed into milestone signals (using COI data).

---

## Results

| Metric | Before (Round 1 done) | After (Round 2 done) | Speedup |
|---|---|---|---|
| Execution time | 82.66s | 18.06s | **4.6x** |
| Total time | 82.86s | 18.31s | **4.5x** |

Counterexample output is identical — same signals, same violation detected.

## TODO Checklist

- [x] **Task 1.1**: Replace `str(e.op)` with enum dispatch table `_BINARY_OP_DISPATCH` in `_kind_binary_op`, `_kind_unary_op`
- [x] **Task 1.2**: Replace `str(s.check()) == "sat"` with `s.check() == z3.sat` in `solve_pc` (both files)
- [x] **Task 1.3**: Replace `str(expr.sort())` with `z3.is_bool()` in `Z3Visitor`
- [x] **Task 2.1**: Implement `_topo_sort_comb()` with write/read dependency analysis + networkx topological_sort
- [x] **Task 2.2**: Call topo sort during strategy `run()` initialization
- [x] **Task 2.3**: Implement `_evaluate_comb_topo` (single-pass evaluation)
- [x] **Task 2.4**: Replace all `_evaluate_comb_fixedpoint` calls with `_evaluate_comb_topo`
- [x] **Task 3.1**: Add fast-path early return in `_match_bv_widths` for same-width BitVecs
- [x] **Task 4.1**: Audited: post-sequential comb eval (call #3) is needed for milestone checks on combinational wires — kept
- [x] **Verify**: Run or1200_subset and confirm identical output
- [x] **Verify**: 4.6x speedup confirmed (82.66s → 18.06s)
