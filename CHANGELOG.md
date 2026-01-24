# Changelog

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
