# Performance Optimization Plan — Round 5 (Startup Cost Reduction)

## Profiling Summary (or1200_subset, 30 cycles, directed strategy, after Round 4)

Total runtime: ~2.6s (profiled), ~1.72s (wall clock without profiler overhead)

| Bottleneck | Time | Calls | % of run() | Category |
|---|---|---|---|---|
| `assertion_extractor` | 0.74s | 1 | 61% | One-time startup |
| `_build_port_propagation_map` | 0.49s | 1 | 40% | One-time startup |
| Module imports (`execution_engine`, `cfg`) | 0.78s | 1 | 64% | One-time startup |
| `_execute_cycle` (actual work) | 0.91s | 2 | 75% | Per-path work |
| `visit_stmt` | 0.59s | 1,080 | 48% | Per-path work |
| `_try_add_constraint` / `check()` | 0.46s | 527 | 38% | Per-path work |
| `_evaluate_comb_topo` | 0.36s | 3 | 30% | Per-path work |
| `substitute_symbols` | 0.20s | 152 | 16% | Per-path work |

**Key insight**: The one-time startup costs (assertion extraction, port map building, module imports) now account for ~1.4s of the ~2.6s total. These are fixed costs that don't scale with path count. The per-path work is ~0.9s for 2 cycles × 205 paths.

---

## Root Cause Analysis

### Bottleneck 1: `assertion_extractor` (0.74s, one-time)

`extract_verification_targets` (assertion_extractor.py:92) spends 0.74s doing:
- `manager.get_assertions()` — recursive AST traversal (5,067 calls, 0.07s self)
- `inspect.cleandoc` / `inspect.getdoc` — 7,555 calls, 0.05s — called on every docstring during class loading
- The bulk of the time is in PySlang AST traversal

This is called once per run. Hard to optimize without caching.

### Bottleneck 2: `_build_port_propagation_map` (0.49s, one-time)

Already identified in Round 4. The function walks the full module hierarchy. 0.49s self-time in a single function call — this is pure Python overhead from iterating PySlang AST nodes.

### Bottleneck 3: Module imports (0.78s, one-time)

`execution_engine.py:1(<module>)` takes 0.42s and `cfg.py:1(<module>)` takes 0.36s — these are Python module import times including class definition, decorator execution, and `inspect.cleandoc` calls on docstrings. This is a Python startup cost.

### Bottleneck 4: `visit_stmt` (0.59s, 1,080 calls)

The actual symbolic execution work. Each call processes one statement in a basic block. 0.59s for 1,080 calls = 0.55ms/call. This is the core engine work — hard to reduce without algorithmic changes.

### Bottleneck 5: `_try_add_constraint` / `check()` (0.46s, 527 calls)

Each `_try_add_constraint` call builds a fresh Solver from the assertions list and calls `check()`. With 527 calls and ~81 assertions per call, this is 42,687 `solver.add()` calls + 138 actual `Z3_solver_check` calls (0.20s in C++).

The 527 calls vs 138 `check()` calls means ~389 constraints were short-circuited by the `is_true`/`is_false`/dedup checks before reaching the solver. Good.

The 0.20s in `Z3_solver_check_assumptions` is irreducible — it's the actual SAT solving work.

---

## My Assessment

### What's left to optimize

**Reducible costs:**

1. **`_build_port_propagation_map` (0.49s)**: This function is called once but takes 0.49s. It walks `parent_module.body` checking `child.kind`. The inner loop iterates all body symbols even for modules with no child instances. A quick win: cache the result or skip modules with no `InstanceSymbol` children.

2. **`_try_add_constraint` solver rebuild (0.26s)**: Each of the 265 `_build_solver` calls rebuilds a Solver from scratch. We can cache the solver between `_try_add_constraint` calls and only invalidate it when new assertions are permanently added (not on push/pop). The `_LazyPC` already has `_pc_solver` caching — but it's invalidated on every `add()`. The issue is that `_try_add_constraint` does `push()` → `add()` → `check()` → `pop()` → `add()`. The second `add()` (permanent) invalidates the cache. We can avoid rebuilding by reusing the solver from the `check()` call and just adding the new constraint to it.

3. **`hasattr()` calls (0.13s, 99,957 calls)**: Scattered across `dfs()`, `visit_stmt()`, `evaluate_comb()`. Replace hot `hasattr(x, 'attr')` patterns with `getattr(x, 'attr', None) is not None` or `type(x).__name__` checks where possible.

**Irreducible costs (at current architecture):**

- Module imports (~0.78s): Python startup cost, can't be reduced without lazy imports or precompilation
- `assertion_extractor` (~0.74s): PySlang AST traversal, one-time cost
- `Z3_solver_check` (0.20s): Actual SAT solving, irreducible
- `visit_stmt` core work (0.59s): Actual symbolic execution, irreducible

**Realistic target**: ~1.0s total (down from 1.72s) by fixing items 1-3.

---

## Implementation Plan

### Task 1: Cache solver across `_try_add_constraint` push/pop [MEDIUM effort, MEDIUM impact]

**Target file**: `engine/symbolic_state.py`

The current flow in `_try_add_constraint`:
```
push()          → snapshot assertions list
add(constraint) → invalidates _pc_solver
check()         → _build_solver() rebuilds from scratch (expensive)
pop()           → restores assertions list, invalidates _pc_solver
add(constraint) → invalidates _pc_solver again
```

The key insight: after `pop()`, the assertions list is back to its pre-push state, which is exactly what `_pc_solver` was before the push. We can restore the cached solver on `pop()` instead of invalidating it.

```python
def push(self):
    self._stack.append((
        list(self._s._pc_assertions),
        self._s.pc_constraint_set.copy(),
        self._s._pc_solver,   # save solver reference too
    ))

def pop(self):
    if self._stack:
        assertions, constraint_set, solver = self._stack.pop()
        self._s._pc_assertions = assertions
        self._s.pc_constraint_set = constraint_set
        self._s._pc_solver = solver   # restore instead of invalidate
```

This means after `pop()`, the cached solver is valid again — no rebuild needed for the permanent `add()` that follows (which will invalidate it, but only once).

**Expected impact**: Reduces `_build_solver` calls from 265 to ~130 (one per actual `check()` call instead of two per `_try_add_constraint`).

### Task 2: Skip empty modules in `_build_port_propagation_map` [LOW effort, MEDIUM impact]

**Target file**: `engine/execution_engine.py`

Add an early-continue for modules with no `InstanceSymbol` children:

```python
for parent_inst, parent_module in modules_dict.items():
    if not hasattr(parent_module, 'body'):
        continue
    # Fast pre-check: skip modules with no instance children
    has_instances = any(
        child.kind == ps.SymbolKind.Instance
        for child in parent_module.body
    )
    if not has_instances:
        continue
    for child in parent_module.body:
        ...
```

This avoids the inner loop for leaf modules (which are the majority in or1200_subset).

### Task 3: Replace hot `hasattr()` with `getattr(..., None)` [LOW effort, LOW impact]

**Target files**: `helpers/slang_helpers.py`, `engine/execution_engine.py`

In tight loops, replace `hasattr(x, 'attr')` with `getattr(x, 'attr', None) is not None`. Python's `hasattr` calls `getattr` internally and catches exceptions — `getattr` with a default is slightly faster.

---

## Expected Results

| Metric | Before (Round 4) | After (Round 5) | Speedup |
|---|---|---|---|
| Execution time | 1.48s | ~1.0s | ~1.5x |
| Total time | 1.72s | ~1.2s | ~1.4x |

The remaining ~0.8s (module imports + assertion extraction) is Python startup overhead that's hard to eliminate without architectural changes (e.g., pre-compiling the design analysis).

---

## Actual Results

| Metric | Before (Round 4) | After (Round 5) | Speedup |
|---|---|---|---|
| Execution time | 1.48s | 1.50s | ~1.0x (no change) |
| Total time | 1.72s | 1.76s | ~1.0x (no change) |

**Conclusion**: Round 5 optimizations had negligible impact. The irreducible startup costs (module imports ~0.78s + assertion extraction ~0.74s) now dominate. Per-path work is already near-minimal. Further speedup requires architectural changes (e.g., caching compiled design analysis, lazy module import, or parallelizing startup).

## TODO Checklist

- [x] **Task 1**: Restore `_pc_solver` on `pop()` in `_LazyPC` to avoid solver rebuild after push/pop
- [x] **Task 2**: Add early-continue for leaf modules in `_build_port_propagation_map`
- [x] **Task 3**: Replace hot `hasattr()` with `getattr(..., None)` in tight loops
- [x] **Verify**: Run or1200_subset and confirm identical output
- [ ] **Verify**: Execution time < 1.2s — NOT ACHIEVED (irreducible startup costs dominate)
