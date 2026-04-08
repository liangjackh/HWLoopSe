# Performance Optimization Refactoring Guide

## Context & Objective
Profiling analysis (via cProfile/Snakeviz) has identified two major performance bottlenecks in the symbolic execution engine that are severely slowing down the path exploration:
1. **`copy.deepcopy()` overhead**: Taking ~30% of execution time during state forking.
2. **AST Parsing overhead**: The `parse_expr_to_Z3` function in `helpers/rvalue_to_z3.py` takes ~70% of the time due to massive `if-elif` chains dynamically checking `e.__class__.__name__` and `hasattr`.

**Goal**: Refactor the codebase to eliminate these bottlenecks without altering any existing logical behavior or Z3 constraints.

---

## Task 1: Eliminate `deepcopy` in Symbolic State Forking

**Target Files**:
- `engine/symbolic_state.py`
- `engine/strategies.py`

**Why this is safe**: The `store` is `Dict[str, Dict[str, z3.ExprRef]]`. Z3 `ExprRef` objects are **immutable** DAG nodes — they cannot be mutated in place. Writing `state.store[mod][var] = new_expr` only rebinds the dict entry; it never modifies the Z3 expression itself. Therefore a 1-level shallow copy of the inner dicts is semantically equivalent to `deepcopy` for this data structure.

**Instructions**:

### 1.1 Add `clone()` method to `SymbolicState` (`engine/symbolic_state.py`)

```python
def clone(self):
    """Efficient shallow clone. Safe because Z3 ExprRef values are immutable."""
    new_state = SymbolicState()
    new_state.assertion_counter = self.assertion_counter
    new_state.clock_cycle = self.clock_cycle
    new_state.cond = self.cond

    # 1-level shallow copy for dict-of-dicts (Z3 values are immutable)
    new_state.store = {mod: sigs.copy() for mod, sigs in self.store.items()}
    new_state.pending_nba = {mod: sigs.copy() for mod, sigs in self.pending_nba.items()}
    new_state.pc_constraint_set = self.pc_constraint_set.copy()

    # Reconstruct Z3 Solver (Solver objects cannot be shallow-copied)
    new_state.pc = z3.Solver()
    for a in self.pc.assertions():
        new_state.pc.add(a)

    return new_state
```

### 1.2 Replace `_clone_state()` in `MilestoneDirectedStrategy` (`engine/strategies.py:479-498`)

Replace the body of `_clone_state(self, state)` with:
```python
return state.clone()
```

### 1.3 Replace rollback snapshots in `_execute_cycle` (`engine/strategies.py:745-746`)

These two `deepcopy` calls happen on **every CFG execution** inside the hot loop — not just at fork points:
```python
# BEFORE (slow):
pre_cfg_store = deepcopy(state.store)
pre_cfg_nba = deepcopy(state.pending_nba)

# AFTER (fast):
pre_cfg_store = {mod: sigs.copy() for mod, sigs in state.store.items()}
pre_cfg_nba = {mod: sigs.copy() for mod, sigs in state.pending_nba.items()}
```

### 1.4 Remove unused `deepcopy` import from `engine/strategies.py`

After all replacements, `from copy import deepcopy` is no longer needed in `strategies.py`. Remove it.

Note: `helpers/rvalue_to_z3.py` also imports `deepcopy` but does not appear to use it in the hot path. Verify and remove if unused.

---

## Task 2: Refactor `parse_expr_to_Z3` to use Dispatch Tables

**Target File**: `helpers/rvalue_to_z3.py`

### Analysis of current structure

The function (`rvalue_to_z3.py:428-1602`) has **three** dispatch phases that execute in order. Each phase has its own long if-elif chain:

| Phase | Lines | Dispatch key | Description |
|-------|-------|-------------|-------------|
| Phase 1 | 452-691 | `e.kind` (ExpressionKind enum) | Semantic AST nodes from elaborated tree. Handles `BinaryOp`, `NamedValue`, `IntegerLiteral`, `Conversion`, `UnaryOp`, `Concatenation`, `RangeSelect`, `ElementSelect`, `Replication`. |
| Phase 2 | 693-1083 | `e.__class__.__name__` (string) | Syntax nodes from parse tree. Handles `ParenthesizedExpressionSyntax`, `BinaryExpressionSyntax`, `LiteralExpressionSyntax`, `IntegerVectorExpressionSyntax`, `IdentifierNameSyntax`, `IntegerLiteralExpressionSyntax`, `IdentifierSelectNameSyntax`, `MultipleConcatenationExpressionSyntax`, `ConcatenationExpressionSyntax`, `Token`. |
| Phase 3 | 1104-1602 | `e.kind` (SyntaxKind string) + `e.__class__.__name__` | Fallback: checks `hasattr(e, 'kind')` again, then dispatches on `'SyntaxKind' in kind_str` with nested class name checks, then falls through to more class name checks. This is a **duplicate** of Phases 1+2 with slightly different logic. |

**Key insight**: Phase 3 is largely redundant with Phases 1 and 2. Nodes that reach Phase 3 are ones that weren't caught earlier — either because they have a `kind` attribute that is a `SyntaxKind` (not `ExpressionKind`), or because they lack `kind` entirely but weren't matched by class name in Phase 2.

### Instructions

#### 2.1 Extract handler functions (do NOT change any Z3 logic)

Extract each case block into a standalone function. The function signature is always `(e, s, m) -> z3.ExprRef`. Group them by dispatch phase:

**Phase 1 handlers (ExpressionKind enum):**
```python
def _kind_binary_op(e, s, m): ...        # lines 456-521
def _kind_named_value(e, s, m): ...      # lines 524-544
def _kind_integer_literal(e, s, m): ...  # lines 547-552
def _kind_conversion(e, s, m): ...       # lines 555-559
def _kind_unary_op(e, s, m): ...         # lines 562-577
def _kind_concatenation(e, s, m): ...    # lines 580-615
def _kind_range_select(e, s, m): ...     # lines 618-638
def _kind_element_select(e, s, m): ...   # lines 641-654
def _kind_replication(e, s, m): ...      # lines 657-690
```

**Phase 2 handlers (class name string):**
```python
def _syntax_parenthesized(e, s, m): ...           # lines 696-701
def _syntax_binary_expression(e, s, m): ...       # lines 704-754
def _syntax_literal_expression(e, s, m): ...      # lines 757-779
def _syntax_integer_vector(e, s, m): ...          # lines 783-830
def _syntax_identifier_name(e, s, m): ...         # lines 867-900
def _syntax_integer_literal_expr(e, s, m): ...    # lines 901-903
def _syntax_identifier_select(e, s, m): ...       # lines 906-1001
def _syntax_multiple_concat(e, s, m): ...         # lines 1004-1039
def _syntax_concatenation(e, s, m): ...           # lines 1042-1079
def _syntax_token(e, s, m): ...                   # lines 1082-1083
def _syntax_prefix_unary(e, s, m): ...            # lines 1505-1524
def _syntax_conditional_pattern(e, s, m): ...     # lines 1587-1591
```

#### 2.2 Build two dispatch tables at module level

```python
import pyslang as ps

# Dispatch table 1: ExpressionKind enum -> handler
_KIND_DISPATCH = {
    ps.ExpressionKind.BinaryOp:       _kind_binary_op,
    ps.ExpressionKind.NamedValue:     _kind_named_value,
    ps.ExpressionKind.IntegerLiteral: _kind_integer_literal,
    ps.ExpressionKind.Conversion:     _kind_conversion,
    ps.ExpressionKind.UnaryOp:        _kind_unary_op,
    ps.ExpressionKind.Concatenation:  _kind_concatenation,
    ps.ExpressionKind.RangeSelect:    _kind_range_select,
    ps.ExpressionKind.ElementSelect:  _kind_element_select,
    ps.ExpressionKind.Replication:    _kind_replication,
}

# Dispatch table 2: class name string -> handler
_SYNTAX_DISPATCH = {
    "ParenthesizedExpressionSyntax":       _syntax_parenthesized,
    "BinaryExpressionSyntax":              _syntax_binary_expression,
    "LiteralExpressionSyntax":             _syntax_literal_expression,
    "IntegerVectorExpressionSyntax":       _syntax_integer_vector,
    "IdentifierNameSyntax":                _syntax_identifier_name,
    "IntegerLiteralExpressionSyntax":      _syntax_integer_literal_expr,
    "IdentifierSelectNameSyntax":          _syntax_identifier_select,
    "MultipleConcatenationExpressionSyntax": _syntax_multiple_concat,
    "ConcatenationExpressionSyntax":       _syntax_concatenation,
    "Token":                               _syntax_token,
    "PrefixUnaryExpressionSyntax":         _syntax_prefix_unary,
    "ConditionalPatternSyntax":            _syntax_conditional_pattern,
}
```

#### 2.3 Rewrite `parse_expr_to_Z3` main body

```python
def parse_expr_to_Z3(e, s, m):
    # Fast path 1: ExpressionKind dispatch (semantic nodes)
    kind = getattr(e, 'kind', None)
    if kind is not None:
        handler = _KIND_DISPATCH.get(kind)
        if handler:
            return handler(e, s, m)

    # Fast path 2: class name dispatch (syntax nodes)
    class_name = e.__class__.__name__
    handler = _SYNTAX_DISPATCH.get(class_name)
    if handler:
        return handler(e, s, m)

    # Slow fallback: legacy Z3 expression checks (is_eq, is_and, is_app_of)
    # and the SyntaxKind string-matching path (Phase 3).
    # Keep this as-is for correctness; it handles rare edge cases.
    return _fallback_dispatch(e, s, m)
```

The `_fallback_dispatch` function contains the remaining logic from Phase 3 (lines 1085-1602) — the `is_eq`/`is_and`/`is_app_of` checks and the `SyntaxKind` string matching. This path is only hit for nodes not caught by either dispatch table.

#### 2.4 Safety rules

- Do NOT modify `_match_bv_widths`, `parse_verilog_literal`, `_bool_to_bv`, or any operator mapping logic.
- Do NOT change the Z3 expressions returned by any handler — only restructure the control flow.
- Each handler must be a **direct extraction** of the existing code block, preserving all edge cases and debug prints.

---

## Task 3: Deduplicate Phase 3 (Optional, lower priority)

Phase 3 (lines 1104-1602) contains near-duplicate handlers for the same node types already handled in Phases 1 and 2. After Task 2, these duplicates live in `_fallback_dispatch`.

**Recommendation**: After Task 2 is verified correct, audit `_fallback_dispatch` to determine which cases are truly reachable. Any case that is already covered by `_KIND_DISPATCH` or `_SYNTAX_DISPATCH` can be removed from the fallback. This further reduces code size and eliminates subtle behavioral divergences between duplicate handlers.

This task is optional and should only be done after Tasks 1 and 2 pass verification.

---

## Verification

After completing Tasks 1 and 2, run:
```bash
bash run.sh
```

The engine must:
1. Run without `NotImplementedError`, `Z3Exception`, or `AttributeError`
2. Produce **identical** output paths and milestones as the version before refactoring
3. Show measurable speedup on the or1200 subset benchmark

### Profiling comparison
```bash
# Before refactoring
python3 -m cProfile -o before.prof -m main 1 designs/benchmarks/or1200/buggy-or1200/or1200_alu.v --sv --explore_time 60

# After refactoring
python3 -m cProfile -o after.prof -m main 1 designs/benchmarks/or1200/buggy-or1200/or1200_alu.v --sv --explore_time 60

# Compare
python3 -c "import pstats; s=pstats.Stats('before.prof'); s.sort_stats('cumulative'); s.print_stats(20)"
python3 -c "import pstats; s=pstats.Stats('after.prof'); s.sort_stats('cumulative'); s.print_stats(20)"
```

## TODO Checklist

- [x] **Task 1.1**: Add `clone()` method to `SymbolicState` in `engine/symbolic_state.py`
- [x] **Task 1.2**: Replace `_clone_state()` body in `engine/strategies.py` to call `state.clone()`
- [x] **Task 1.3**: Replace `deepcopy` rollback snapshots at `strategies.py:745-746` with shallow copies
- [x] **Task 1.4**: Remove unused `from copy import deepcopy` from `engine/strategies.py`
- [x] **Task 1.5**: Check and remove unused `deepcopy` import from `helpers/rvalue_to_z3.py`
- [x] **Task 2.1**: Extract Phase 1 handlers (ExpressionKind) into standalone functions
- [x] **Task 2.2**: Extract Phase 2 handlers (class name) into standalone functions
- [x] **Task 2.3**: Build `_KIND_DISPATCH` table (enum-keyed)
- [x] **Task 2.4**: Build `_SYNTAX_DISPATCH` table (string-keyed)
- [x] **Task 2.5**: Rewrite `parse_expr_to_Z3` main body to use both dispatch tables
- [x] **Task 2.6**: Move remaining fallback logic into `_fallback_dispatch`
- [x] **Verify**: Run `bash run.sh` and confirm identical output
- [ ] **Verify**: Profile and confirm speedup on or1200 benchmark
