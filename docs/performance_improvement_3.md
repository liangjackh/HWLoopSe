# Performance Optimization Guide: Round 3 (Z3 Printer Elimination)

## Context & Objective
Profiling analysis (`profile_output_v2.txt`) reveals a massive new bottleneck: **95.5% of the total execution time (82 seconds) is spent entirely inside Z3's string formatting methods (`z3printer.py`, `__str__`)**. 

This is caused by two critical Python performance traps:
1. **Eager Evaluation of f-strings**: `debug_print(..., f"{z3_obj}")` evaluates the f-string (and calls Z3's extremely slow C++ AST printer) *before* checking if debugging is actually enabled.
2. **Blind String Conversion**: The fallback mechanism in `substitute_symbols` calls `str(z3_val)` on hundreds of signals in the store, even if those signals don't exist in the target expression.

**Goal**: Eradicate all implicit and explicit `str()` calls on Z3 objects in the hot paths.

---

## Task 1: Fix Eager f-string Evaluation in Debug Prints

**Target Files**: 
- `helpers/slang_helpers.py`
- `helpers/rvalue_to_z3.py`
- (And any other files importing `debug_print` or `logging`)

**Instructions**:
1. Search globally for `debug_print` or `logging.debug` calls that use f-strings containing Z3 variables (like `cond_z3`, `rst`, `case_z3`, `rhs_z3`).
2. **CRITICAL FIX**: Wrap EVERY such `debug_print` call inside an explicit `if DEBUG_ENABLED:` block (or `if self.engine.debug:` if inside an engine class) so the f-string is never evaluated during normal execution.
3. Example of required refactoring:
   ```python
   # BEFORE (BAD - evaluates Z3 printer even if debug is off)
   debug_print("COND", f"store[{m.curr_module}].rst_n = {rst} (type={type(rst).__name__})")
   
   # AFTER (GOOD - safely bypasses f-string evaluation)
   if DEBUG_ENABLED:
       debug_print("COND", f"store[{m.curr_module}].rst_n = {rst} (type={type(rst).__name__})")
    ```
4. Pay special attention to visit_stmt and `_handle_immediate_assertion_syntax` in helpers/slang_helpers.py, as these were identified in the profiler.
---

## Task 2: Optimize substitute_symbols (Stop Blind Conversions)

**Instructions**
1. Locate the substitute_symbols(expr_str: str, store: dict) -> str function.

2.Currently, it iterates through all variables in store and executes re.sub(pattern, str(sym_val), result). Calling str(sym_val) on every Z3 object in the store takes ~47 seconds globally.
3. Modify the loop to ONLY compute str(sym_val) if the variable actually exists in the string.
4. Replace the loop with this optimized version:
   ```python
   for var_name in sorted_vars:
    # Fast pre-check: only do expensive regex/str operations if var_name might be in the string
    if var_name in result:
        pattern = r'\b' + re.escape(var_name) + r'\b'
        # Strict check to ensure it matches a whole word
        if re.search(pattern, result):
            sym_val = store[var_name]
            # Only call str() on the Z3 object if we absolutely have to replace it
            result = re.sub(pattern, str(sym_val), result)
    ```
---

## Task3: Purge Residual `str()` Type Checks in Syntax Nodes
**Target File:**
- `helpers/rvalue_to_z3.py`

**Instructions**
1. We previously cleaned up semantic node handlers, but the profiler shows 35 seconds spent in `_syntax_binary_expression` due to `z3printer.py`.

2. Thoroughly scan `_syntax_binary_expression` and any other `_syntax_` prefixed functions.

3. Look for code that does type checking via string matching:

- Replace `if str(expr.sort()) == "Bool":` or `"Bool" in str(expr.sort())` with `if z3.is_bool(expr):`

- Replace `if str(expr.sort()) == "BitVec":` with if z3.is_bv(expr):

4. Also remove or wrap any `debug_print` calls in these functions using the rule from Task 1.

## Verification
Run your standard verification test (e.g., `bash run.sh`). The execution should succeed and produce the exact same counterexamples, but the execution time should drop dramatically (expecting < 3 seconds).
