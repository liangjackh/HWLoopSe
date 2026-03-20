# Performance Optimization Plan — Round 4 (Solver Clone Elimination)

## Profiling Summary (or1200_subset, 30 cycles, directed strategy, after Round 3)

| Bottleneck | Time | Calls | % Total |
|---|---|---|---|
| `_clone_state` / `clone()` | 1.64s | 512 | 66% |
| `solver.add()` inside `clone()` | 1.14s | 41,583 | 46% |
| `_build_port_propagation_map` | 0.49s | 1 | 20% |
| `assertion_extractor` | 0.74s | 1 | 30% |
| `hasattr()` calls | 0.13s | 99,447 | 5% |
| `dfs()` in slang_helpers | 0.19s | 4,041 | 8% |
| residual `str()` / z3printer | 0.25s | 800 | 10% |

Total runtime: ~2.48s (strategies.py `run()`). The Z3 printer is now negligible.

---

## Root Cause Analysis

### Bottleneck 1: `clone()` rebuilds Z3 Solver from scratch (66% of runtime)

`SymbolicState.clone()` (symbolic_state.py:47) reconstructs the path condition solver by:
1. Creating a fresh `z3.Solver()`
2. Iterating `self.pc.assertions()` and calling `new_state.pc.add(a)` for each

With 512 clones and ~81 assertions per clone on average, this produces 41,583 `solver.add()` calls. Each `add()` call goes through `assert_exprs` → `cast` → `BoolSort` → `Z3_solver_assert` — a chain of 5 Python/C++ calls per assertion.

**Fix**: Use Z3's `Solver.translate()` or push/pop scoping instead of rebuilding. The cleanest approach is to use `z3.Solver` with `push()`/`pop()` for the path condition, so forked states share the solver context up to the fork point and only diverge after.

However, the current architecture passes `SymbolicState` objects around independently (each work item has its own state), so a shared solver isn't straightforward. The practical fix is:

**Use `z3.Goal` + `z3.AstVector` to snapshot assertions cheaply**, then restore with a single bulk `add()`. Or better: store the path condition as a **Python list of Z3 expressions** (`pc_assertions: list`) and only create a `Solver` when actually calling `check()`. This avoids solver construction entirely during cloning.

### Bottleneck 2: `_build_port_propagation_map` (20% of runtime, one-time cost)

0.49s spent once at startup walking the module hierarchy to build wire equivalence groups. This is a one-time cost but significant relative to the 2.48s total. It's already called once — no repeated calls. The fix is to optimize the inner loop (currently uses `hasattr` + PySlang attribute access in a tight loop over all module body symbols).

### Bottleneck 3: `assertion_extractor` (30% of runtime, one-time cost)

0.74s spent once extracting assertions. Also a one-time startup cost. Lower priority since it doesn't scale with path count.

### Bottleneck 4: Residual `str()` / z3printer (10%)

800 `__str__` calls remain — these are the legitimate `str(sym_val)` calls in `substitute_symbols` that passed the `var_name in result` pre-check. Not worth eliminating further.

### Bottleneck 5: `hasattr()` calls (5%)

99,447 `hasattr()` calls at 0.13s. These are scattered across `dfs()`, `visit_stmt()`, and `evaluate_comb()`. Minor, but could be reduced by caching `__class__.__name__` or using `type()` checks.

---

## My Assessment of Fixes

### Task 1: Lazy Solver — store assertions as a list, build Solver only at `check()` [HIGH impact, MEDIUM effort]

The key insight: `SymbolicState.pc` is a `z3.Solver` used for two operations:
1. `pc.add(constraint)` — add a path condition constraint
2. `pc.push()` / `pc.pop()` / `pc.check()` — satisfiability check in `_try_add_constraint`

The `push/pop` pattern in `_try_add_constraint` is used to speculatively test a constraint without permanently adding it. This is the tricky part.

**Proposed approach**: Replace `pc` (a `Solver`) with two fields:
- `pc_assertions: list` — the committed path condition constraints (cheap to copy: just `list.copy()`)
- Keep a **thread-local or per-check** solver that is built on demand in `_try_add_constraint`

```python
# In clone():
new_state.pc_assertions = self.pc_assertions.copy()  # O(n) list copy, no Z3 overhead
# No Solver construction at all

# In _try_add_constraint (slang_helpers.py):
solver = z3.Solver()
for a in s.pc_assertions:
    solver.add(a)
solver.push()
solver.add(new_constraint)
result = solver.check()
solver.pop()
if result == z3.sat:
    s.pc_assertions.append(new_constraint)
```

**Caveat**: `_try_add_constraint` is called 532 times. Building a solver from scratch each time would move the cost from `clone()` to `_try_add_constraint`. We need to profile whether 532 solver builds (each with ~81 assertions) is cheaper than 512 solver builds in `clone()`.

**Better approach**: Use Z3's `Solver.translate()` which copies a solver to a new context cheaply, or use `z3.Solver` with `from_string()` to bulk-load assertions. Actually the cleanest fix is:

```python
# In clone():
new_state.pc = z3.Solver()
new_state.pc.add(self.pc.assertions())  # bulk add via AstVector, single C++ call
```

Z3's `solver.add()` accepts an `AstVector` (the return type of `solver.assertions()`) directly — this avoids the Python loop and does a single bulk C++ call instead of 81 individual calls.

### Task 2: Optimize `_build_port_propagation_map` [LOW effort, MEDIUM impact]

The function walks `parent_module.body` checking `child.kind != ps.SymbolKind.Instance`. The `hasattr(parent_module, 'body')` check and the inner loop over all body symbols are the cost. Since this runs once, the impact is bounded at 0.49s. Worth a quick fix but not critical.

### Task 3: Eliminate debug `print()` calls in `dfs()` [LOW effort, LOW impact]

`slang_helpers.py:609` `dfs()` has unconditional `print()` calls at lines 613, 617 that fire even when debug is off. These are called 4,041 times. Minor but easy to fix.

---

## Implementation Plan (ordered by impact)

### Task 1: Bulk-add assertions in `clone()` [LOW effort, HIGH impact]

**Target file**: `engine/symbolic_state.py`

Replace the Python loop in `clone()`:
```python
# BEFORE (41,583 individual add() calls across all clones)
new_state.pc = z3.Solver()
for a in self.pc.assertions():
    new_state.pc.add(a)

# AFTER (single bulk add via AstVector)
new_state.pc = z3.Solver()
new_state.pc.add(self.pc.assertions())
```

`self.pc.assertions()` returns a `z3.AstVector`. Passing it directly to `solver.add()` triggers `assert_exprs` with the full vector in one C++ call, bypassing the Python loop overhead entirely.

**Expected impact**: Eliminates ~41,000 Python-level `add()` calls. The C++ work is the same, but Python overhead drops from O(n_assertions) to O(1) per clone. Estimated: 1.14s → ~0.15s.

### Task 2: Remove unconditional `print()` in `dfs()` [LOW effort, LOW impact]

**Target file**: `helpers/slang_helpers.py`

Lines 613, 617 have `print()` calls that fire unconditionally. Wrap in `if DEBUG_ENABLED:` or remove.

### Task 3: Optimize `_build_port_propagation_map` [MEDIUM effort, MEDIUM impact]

**Target file**: `engine/execution_engine.py`

The function is called once. The 0.49s cost comes from walking the full PySlang AST. Since it's a one-time cost, it only matters if we want sub-second startup. Defer unless total time target is < 1s.

---

## Expected Results

| Metric | Before (Round 3) | After (Round 4) | Speedup |
|---|---|---|---|
| Execution time | 1.77s | ~0.6s | ~3x |
| Total time | 2.03s | ~1.1s | ~2x |

The one-time startup costs (`_build_port_propagation_map`, `assertion_extractor`, module import) account for ~1.4s and are irreducible without deeper architectural changes. The per-path execution time should drop to near-zero.

---

## Results

| Metric | Before (Round 3) | After (Round 4) | Speedup |
|---|---|---|---|
| Execution time | 1.77s | 1.48s | **1.2x** |
| Total time | 2.03s | 1.72s | **1.2x** |
| `solver.add()` calls | 41,583 | 9,350 | **4.4x fewer** |

The lazy solver eliminated Solver construction during `clone()` entirely. The remaining `_build_solver` calls (265) only happen when `check()` is actually needed.

## TODO Checklist

- [x] **Task 1**: Lazy solver — store assertions as list, build Solver only at `check()` (`engine/symbolic_state.py`)
- [x] **Task 2**: Wrap unconditional `print()` in `dfs()` with `if DEBUG_ENABLED:`
- [ ] **Task 3**: (Optional) Optimize `_build_port_propagation_map` startup cost
- [x] **Verify**: Run or1200_subset and confirm identical output
- [x] **Verify**: Execution time 1.48s (startup costs now dominate)
