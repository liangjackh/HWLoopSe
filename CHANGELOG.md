# Changelog

## [2026-01-26] [Bug Fix] Fixed empty symbolic state store issue

### Problem
The `state.store` was not being populated during symbolic execution, showing empty dictionaries like `{'place_holder': {}}` instead of containing the discovered variables.

### Root Causes & Fixes

1. **Disconnected stores** (`engine/execution_engine.py`)
   - `SymbolicDFS.symbolic_store` and `SymbolicState.store` were two separate, unconnected objects
   - The DFS traversal populated `visitor.symbolic_store` but never transferred to `state.store`
   - **Fix**: Added code to clear visitor state before each module's DFS and transfer discovered variables to `state.store[module_name]` with fresh symbols (lines 438-445)
   - Added `init_symbol` import from `helpers.utils`

2. **PySlang 9.x compatibility** (`helpers/slang_helpers.py`)
   - The `dfs()` method checked for `hasattr(symbol, "members")` which doesn't exist in PySlang 9.x
   - In PySlang 9.x, symbols are directly iterable instead of having a `members` attribute
   - **Fix**: Added fallback to try direct iteration when `members` attribute is not available (lines 555-567)

3. **Missing Net type** (`helpers/slang_helpers.py`)
   - `SymbolKind.Net` was not included in the list of symbol kinds to capture
   - **Fix**: Added `ps.SymbolKind.Net` to the symbol kinds list (line 546)

### PySlang Library Usage
- **PySlang 9.x**: Symbols (like `InstanceBody`) are directly iterable using `for child in symbol`
- **PySlang 7.x**: Symbols have a `members` attribute accessed via `symbol.members`
- The fix handles both versions by trying `members` first, then falling back to direct iteration

### Result
- `state.store` now correctly populated: `{'place_holder': {'CLK': '...', 'RST': '...', 'out': '...', 'out_wire': '...'}}`
- Variables, Parameters, Ports, and Nets are all captured with fresh symbolic identifiers

## [2026-01-26] [Feature] Added SVA assertion handling infrastructure

### Summary
Added infrastructure for handling SystemVerilog Assertions (SVA) during symbolic execution.

### Changes

1. **Immediate assertion handling** (`helpers/slang_helpers.py`)
   - Added `_handle_immediate_assertion()` method for semantic `ImmediateAssertionStatement` nodes
   - Added `_handle_immediate_assertion_syntax()` method for syntax `ImmediateAssertionStatementSyntax` nodes
   - Extracts assertion condition, converts to Z3, and checks for violations

2. **Concurrent assertion handling** (`helpers/slang_helpers.py`)
   - Added `_handle_concurrent_assertion()` method for `ConcurrentAssertionStatement` nodes
   - Added `_handle_assert_property_syntax()` method for `AssertPropertyStatement` syntax nodes
   - Added `_handle_property_spec()` method for `PropertySpecSyntax` nodes

3. **Statement visitor updates** (`helpers/slang_helpers.py`)
   - Added handlers for `StatementKind.ImmediateAssertion`, `StatementKind.ConcurrentAssertion`
   - Added handlers for `SyntaxKind.AssertPropertyStatement`, `SyntaxKind.ConcurrentAssertionMember`
   - Added handler for `SyntaxKind.SyntaxList` to iterate through children
   - Added handler for `SyntaxKind.PropertySpec` to process property specifications
   - Added `SyntaxKind.SimplePropertyExpr` to ignored expression list

### Limitations
- Named property references (e.g., `assert property (p_name)`) are detected but not fully resolved
- Property definitions need to be resolved to extract the actual assertion expression
- Currently skips Z3 check when property name reference is detected

### Result
- Assertion handling infrastructure is in place
- Immediate assertions with inline expressions can be checked
- Concurrent assertions with named property references are detected but require property resolution

## [2026-01-24] [Bug Fix] Fixed PySlang compatibility and cache handling for picorv32 analysis

### Problem
Running symbolic execution on `picorv32.v` reported "Branch points explored: 0" and crashed with multiple errors.

### Root Causes & Fixes

1. **PySlang API compatibility** (`helpers/rvalue_parser.py`)
   - Changed `ps.RangeSelectExpressionSyntax` to `ps.RangeSelectSyntax` (lines 111-120)
   - Changed `rvalue.left.name` to `rvalue.left.identifier.valueText` for `IdentifierNameSyntax` (line 126)

2. **Missing SyntaxKind handlers** (`helpers/slang_helpers.py`)
   - Added handling for `LogicalAndExpression`, `LogicalOrExpression`, `BinaryAndExpression`, `BinaryOrExpression`, `BinaryXorExpression`, `BinaryXnorExpression`, `LogicalShiftLeftExpression`, `LogicalShiftRightExpression`, `LogicalEquivalenceExpression`, `LogicalImplicationExpression` in `visit_expr()` (lines 601-610)

3. **Cache None checks** (`helpers/slang_helpers.py`)
   - Added `m.cache is not None` guards before all `m.cache.exists()`, `m.cache.get()`, and `m.cache.set()` calls (lines 739-758, 800-820, 876-886)

4. **Empty tuple handling** (`helpers/rvalue_to_z3.py`)
   - Added `len(expr) > 0` check before accessing `expr[0]` in `eval_expr()` (line 393)

### Result
- Successfully analyzed picorv32.v
- Branch points explored: 204,800
- Paths explored: 12,288
