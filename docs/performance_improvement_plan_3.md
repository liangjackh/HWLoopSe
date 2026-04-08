# Performance Optimization Plan — Round 3 (Z3 Printer Elimination)

## Profiling Summary (or1200_subset, 30 cycles, directed strategy)

| Bottleneck | Time | Calls | % Total |
|---|---|---|---|
| Z3 `__str__` / `z3printer.py` | 82s | 16,050 | 95.5% |
| `substitute_symbols` (blind `str(z3_val)`) | 47s | 152 | 55% |
| `_syntax_binary_expression` (via z3printer) | 35s | 1,336 | 41% |

All three bottlenecks trace to the same root cause: **calling `str()` on Z3 objects triggers Z3's C++ AST pretty-printer**, which recursively walks the entire expression tree. This is catastrophically expensive for large symbolic expressions.

Two mechanisms trigger this:
1. **Eager f-string evaluation**: `debug_print("TAG", f"...{z3_obj}...")` evaluates the f-string *before* `debug_print` checks `DEBUG_ENABLED`. The `str()` on the Z3 object fires unconditionally.
2. **Blind iteration in `substitute_symbols`**: `str(sym_val)` is called for every variable in the store, even when that variable doesn't appear in the target string.

---

## My Assessment

### Task 1: Guard debug_print f-strings — AGREE, critical

The `debug_print` function already checks `DEBUG_ENABLED` internally, but that's too late — Python evaluates f-string arguments at the call site. The fix is to wrap each call in `if DEBUG_ENABLED:` so the f-string is never constructed.

Locations found (with Z3 objects in f-strings):

**`helpers/slang_helpers.py`**:
- Line 1081: `debug_print("COND", f"...cond_expr={cond_expr}...")` — `cond_expr` is a PySlang AST node (not Z3), but `str()` on it may still be slow. Guard it.
- Line 1084: `debug_print("COND", f"...rst_n = {rst}...")` — `rst` can be a Z3 expression. **Hot path.**
- Line 1399: `debug_print("ASSERT", f"...cond_z3={cond_z3}")` — `cond_z3` is Z3. **Hot path.**
- Line 912: `debug_print("EVAL-COMB", f"module={m.curr_module} cname={cname}")` — `cname` is a string, cheap. Guard anyway since it's called 3,399 times.

**`helpers/rvalue_to_z3.py`**:
- Line 488: `debug_print("NamedValue", f"...store keys={list(s.store.get(...))}...")` — materializes a list every call. **Hot path.**
- Line 509: `debug_print("IntegerLiteral", f"val={val}")` — `val` is a Python int, cheap. Guard for consistency.
- Line 644: `debug_print("ParenthesizedExpressionSyntax", f"unwrapping to: {inner_expr}")` — `inner_expr` is PySlang AST. Guard it.
- Line 654: `debug_print("BinaryExpressionSyntax", f"lhs={lhs}, rhs={rhs}...")` — `lhs`/`rhs` are Z3 expressions. **Critical — 1,336 calls, 35s each.**

### Task 2: Optimize `substitute_symbols` — AGREE, easy win

The current loop calls `str(sym_val)` for every variable in the store unconditionally. With ~100 variables and 152 calls, that's ~15,000 `str()` invocations on Z3 objects. Adding a fast `if var_name in result:` pre-check before the regex/str operations will skip 95%+ of iterations.

### Task 3: Purge residual `str()` type checks in syntax nodes — PARTIALLY AGREE

The doc mentions `str(expr.sort()) == "Bool"` patterns. From my scan, the semantic-node handlers (`_kind_*`) were already fixed in Round 2. The `_syntax_*` functions don't appear to have `str(sort())` calls. However:

- `_syntax_prefix_unary` (line 964): `str(getattr(e, 'kind', ''))` — this is `str()` on a PySlang enum, not a Z3 object. Cheap but could be replaced with direct enum comparison.
- `_syntax_binary_expression` (line 653): `str(getattr(e, 'operatorToken', ''))` — this is `str()` on a PySlang token, not Z3. Cheap.

The 35s in `_syntax_binary_expression` is NOT from `str()` type checks — it's from the `debug_print` at line 654 that formats `lhs` and `rhs` (Z3 objects). **Task 1 fixes this.**

---

## Implementation Plan (ordered by impact)

### Task 1: Guard ALL debug_print calls with `if DEBUG_ENABLED:` [LOW effort, EXTREME impact]

**Target files**: `helpers/slang_helpers.py`, `helpers/rvalue_to_z3.py`

1.1. In `helpers/slang_helpers.py`, wrap these lines:
- Lines 1081-1084 (COND debug prints) → wrap in `if DEBUG_ENABLED:`
- Line 1399 (ASSERT cond_z3 print) → wrap in `if DEBUG_ENABLED:`
- Line 912 (EVAL-COMB print) → wrap in `if DEBUG_ENABLED:`

1.2. In `helpers/rvalue_to_z3.py`, wrap these lines:
- Line 488 (_kind_named_value) → wrap in `if DEBUG_ENABLED:`
- Line 509 (_kind_integer_literal) → wrap in `if DEBUG_ENABLED:`
- Line 644 (_syntax_parenthesized) → wrap in `if DEBUG_ENABLED:`
- Line 654 (_syntax_binary_expression) → wrap in `if DEBUG_ENABLED:`

**Expected impact**: Eliminates ~82s of Z3 printer overhead. This is the single biggest win.

### Task 2: Optimize `substitute_symbols` with fast pre-check [LOW effort, HIGH impact]

**Target file**: `helpers/slang_helpers.py`

2.1. Replace the loop body (lines 74-79) with:
```python
for var_name in sorted_vars:
    if var_name in result:  # Fast substring pre-check
        pattern = r'\b' + re.escape(var_name) + r'\b'
        if re.search(pattern, result):
            sym_val = store[var_name]
            result = re.sub(pattern, str(sym_val), result)
```

**Expected impact**: Eliminates ~47s of blind `str()` calls. Only variables actually present in the expression string trigger the expensive Z3 printer.

### Task 3: Clean up `str()` on PySlang enums in `_syntax_prefix_unary` [LOW effort, LOW impact]

**Target file**: `helpers/rvalue_to_z3.py`

3.1. In `_syntax_prefix_unary` (line 964), replace `str(getattr(e, 'kind', ''))` with direct attribute checks or cached enum comparison. This is minor but keeps the code consistent with Round 2's enum dispatch pattern.

---

## Results

| Metric | Before (Round 2 done) | After (Round 3 done) | Speedup |
|---|---|---|---|
| Execution time | 18.06s | 1.77s | **10.2x** |
| Total time | 18.31s | 2.03s | **9.0x** |

Counterexample output is identical — same signals, same violation detected.

## TODO Checklist

- [x] **Task 1.1**: Guard `debug_print` calls in `helpers/slang_helpers.py` with `if DEBUG_ENABLED:`
- [x] **Task 1.2**: Guard `debug_print` calls in `helpers/rvalue_to_z3.py` with `if DEBUG_ENABLED:`
- [x] **Task 2.1**: Add fast `if var_name in result:` pre-check in `substitute_symbols`
- [ ] **Task 3.1**: Replace `str(getattr(e, 'kind', ''))` in `_syntax_prefix_unary` with direct checks (minor, deferred)
- [x] **Verify**: Run or1200_subset and confirm identical output
- [x] **Verify**: Execution time < 3 seconds — achieved 1.77s
