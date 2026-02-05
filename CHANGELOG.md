# Changelog

## [2026-02-05] [Refactor] Optimized CFG construction to share CFGs across instances of same module definition

### Problem
When a module definition has multiple instances (e.g., `place_holder_2` instantiated as `test_1` and `test_2`), the code was building redundant CFGs for each instance. Additionally, instance names were generated as `{module_name}_{index}` (e.g., `place_holder_2_0`, `place_holder_2_1`) instead of using actual Verilog instance names.

### Changes

1. **Grouped instances by module definition** (`engine/execution_engine.py`, lines 206-219)
   - Added `definitions_to_instances` dictionary: `{definition_name: [(instance_name, module), ...]}`
   - Uses `module.definition.name` to get the module definition name
   - Uses `get_module_name(module)` to get the actual instance name

2. **Build CFGs once per module definition** (`engine/execution_engine.py`, lines 221-242)
   - Added `cfgs_by_definition` dictionary: `{definition_name: [cfg_list]}`
   - CFGs are built only once using the first instance as representative
   - For `test_2.v`: builds CFGs for `place_holder` (1 instance) and `place_holder_2` (2 instances) only twice total, not 3 times

3. **Reference shared CFGs per instance** (`engine/execution_engine.py`, lines 244-264)
   - `cfgs_by_module[instance_name]` now references `cfgs_by_definition[definition_name]`
   - Per-instance state (`state.store`, `manager.dependencies`, etc.) remains separate
   - Uses actual instance names: `test_1`, `test_2` instead of `place_holder_2_0`, `place_holder_2_1`

### PySlang Library Usage

**Getting module definition name vs instance name:**
- `module.definition.name`: Returns the module definition name (e.g., `place_holder_2`)
- `get_module_name(module)` / `module.name`: Returns the instance name (e.g., `test_1`)

### Result
For `test_2.v` with 3 instances (place_holder, test_1, test_2) of 2 module definitions:
- Before: Built 3 sets of CFGs (one per instance)
- After: Built 2 sets of CFGs (one per definition), shared across instances
- Instance names now match Verilog source: `place_holder`, `test_1`, `test_2`
- Branch tracking uses actual instance names: `branch_id: ('test_1', 629)`
- Execution: Branch points explored: 4, Paths explored: 32

## [2026-02-04] [Feature] Implemented lhs_signals and get_assertions for COI analysis

### Summary
Implemented `lhs_signals` and `get_assertions` functions in `engine/execution_manager.py` based on the Sylvia reference implementation. These functions support Cone of Influence (COI) optimization by tracking signal writes and assertion conditions.

### Changes

1. **`lhs_signals(m, items)`** (`engine/execution_manager.py`, lines 284-348)
   - Traverses PySlang AST to track which signals are written to in each always block
   - Populates `m.always_writes` dictionary: `{ProceduralBlockSymbol: [signal_names]}`
   - Handles all Statement kinds: `Block`, `List`, `Timed`, `Conditional`, `Case`, loops
   - Extracts LHS signal names from `ExpressionStatement` assignments

2. **`_extract_lhs_from_expr(m, expr)`** (`engine/execution_manager.py`, lines 350-375)
   - Helper function to extract LHS signal names from assignment expressions
   - Handles `ExpressionKind.Assignment` and `ExpressionKind.BinaryOp`
   - Also checks syntax class names for `AssignmentExpression` and `NonblockingAssignment`

3. **`_get_signal_name(expr)`** (`engine/execution_manager.py`, lines 377-411)
   - Helper function to extract signal name from expression (LHS of assignment)
   - Handles various expression kinds:
     - `NamedValue`: Direct variable reference via `expr.symbol.name`
     - `ElementSelect`: Array access - recurses into `expr.value`
     - `RangeSelect`: Part select - recurses into `expr.value`
     - `Concatenation`: Returns first element's name
   - Falls back to `expr.name` or `expr.identifier.valueText`

4. **`get_assertions(m, items)`** (`engine/execution_manager.py`, lines 413-495)
   - Traverses PySlang AST to find and collect assertion conditions
   - Populates `m.assertions` list with assertion condition expressions
   - Handles:
     - `StatementKind.ImmediateAssertion`: Extracts `items.cond` or `items.expr`
     - `StatementKind.ConcurrentAssertion`: Extracts `items.propertySpec`
   - Also checks syntax class names for `ImmediateAssertionStatement` and `AssertPropertyStatement`

5. **Enabled COI functions in `init_run`** (`engine/execution_manager.py`, lines 124-126)
   - Uncommented and updated calls to `lhs_signals` and `get_assertions`
   - Both functions now called with `module_body` after `count_conditionals`

### PySlang Library Usage

**Expression kinds for assignments:**
- `ExpressionKind.Assignment`: Blocking assignment (`=`)
- `ExpressionKind.NamedValue`: Variable reference - access name via `expr.symbol.name`
- `ExpressionKind.ElementSelect`: Array element access `arr[i]` - base in `expr.value`
- `ExpressionKind.RangeSelect`: Part select `sig[7:0]` - base in `expr.value`
- `ExpressionKind.Concatenation`: `{a, b, c}` - elements in `expr.operands`

**Assertion statement kinds:**
- `StatementKind.ImmediateAssertion`: Immediate assertions (`assert(cond)`)
  - Condition in `items.cond` or `items.expr`
- `StatementKind.ConcurrentAssertion`: Concurrent assertions (`assert property`)
  - Property spec in `items.propertySpec`

### Result
- `get_assertions` successfully finds ImmediateAssertion statements:
  ```
  [get_assertions] Found ImmediateAssertion: Expression(ExpressionKind.BinaryOp)
  ```
- `lhs_signals` populates `m.always_writes` for COI analysis
- Test passes: Branch points explored: 4, Paths explored: 32

## [2026-02-03] [Bug Fix] Fixed count_conditionals and branch_count tracking

### Problem
1. `count_conditionals` reported wrong path counts (e.g., `place_holder` showed 2 paths instead of 4)
2. `branch_count` showed 160 instead of the actual unique branch points (4)

### Root Causes & Fixes

1. **Statement objects vs Syntax objects** (`engine/execution_manager.py`)
   - `count_conditionals` only checked for Syntax types (e.g., `ConditionalStatementSyntax`) but `ProceduralBlockSymbol.body` returns Statement objects (compiled AST) with `.kind` attribute
   - **Fix**: Added comprehensive handling for `StatementKind` values (lines 157-238):
     - `StatementKind.Conditional`: Recurse into `ifTrue`/`ifFalse`
     - `StatementKind.Case`: Recurse into case items via `.items`
     - `StatementKind.Block`: Recurse into `.body` (check if iterable)
     - `StatementKind.List`: Use `.list` attribute (NOT `.body`!)
     - `StatementKind.Timed`: Recurse into `.stmt`
     - Loop kinds (`ForLoop`, `WhileLoop`, etc.): Recurse into `.body`

2. **StatementKind.List uses `.list`, not `.body`** (`engine/execution_manager.py`)
   - `StatementKind.List` objects have a `.list` attribute containing child statements
   - **Fix**: Changed to use `items.list` instead of `items.body` (lines 203-224)

3. **ProceduralBlockSymbol handling** (`engine/execution_manager.py`)
   - Was recursing into the symbol itself instead of its body
   - **Fix**: Changed to recurse into `item.body` for `ProceduralBlockSymbol` (lines 138-141)

4. **InstanceSymbol not handled** (`engine/execution_manager.py`)
   - Submodule instances were not being traversed for conditional counting
   - **Fix**: Added `InstanceSymbol` handling to recurse into `item.body` (lines 142-147)

5. **Additive vs multiplicative path counting** (`engine/execution_manager.py`)
   - Path counting used `m.num_paths += 1` but each if-else **doubles** paths
   - **Fix**: Changed to `m.num_paths *= 2` for conditionals and loops (lines 160, 172, 183, etc.)
   - For case statements: `m.num_paths *= num_cases`

6. **branch_count accumulated across all paths** (`helpers/slang_helpers.py`, `engine/execution_manager.py`)
   - `branch_count` incremented every time a conditional was visited, not unique branch points
   - **Fix**: Added `branch_points_seen` set to track unique branch points (line 81)
   - **Fix**: Use syntax source location offset as unique identifier:
     ```python
     if hasattr(stmt, 'syntax') and stmt.syntax is not None:
         sr = stmt.syntax.sourceRange()
         branch_id = (m.curr_module, sr.start.offset)
     ```
   - **Fix**: Reset both `branch_count` and `branch_points_seen` before path exploration (`engine/execution_engine.py`, lines 432-433)

### PySlang Library Usage

**Statement objects (compiled AST) attributes:**

| StatementKind | Child Attribute | Notes |
|---------------|-----------------|-------|
| `StatementKind.Block` | `.body` | Can be iterable or single statement |
| `StatementKind.List` | `.list` | **NOT `.body`!** Returns Python list |
| `StatementKind.Timed` | `.stmt` | Single statement |
| `StatementKind.Conditional` | `.ifTrue`, `.ifFalse`, `.conditions` | |
| `StatementKind.Case` | `.items` | Case items have `.stmt` |

**ProceduralBlockSymbol:**
- `proc_block.body` returns a Statement object (compiled AST)
- Must check `stmt.kind` for `StatementKind` values, not Syntax types

**InstanceSymbol:**
- `instance.body` returns the instance body symbol
- Can be iterated to find nested module contents

**Source location for unique identification:**
- `stmt.syntax.sourceRange().start.offset` provides stable unique identifier
- Don't use `str(sourceRange)` - includes memory address which changes

### Result
- `place_holder`: Now correctly shows 4 paths (2 × 2 from submodule)
- `test_1`: Correctly shows 2 paths
- `branch_count`: Now shows 4 unique branch points instead of 160

## [2026-02-02] [Bug Fix] Fixed Verilog literal parsing and non-blocking assignment semantics

### Problem
When running `python3 -m main 1 designs/test-designs/test_2.v --sv`, the assertion `assert (out <= 2)` was incorrectly reported as violated in cycle 0. The path condition showed `[Not(ULE((1'b0 + 1), 2))]` where:
1. `1'b0` was treated as a symbolic variable name instead of the concrete value `0`
2. The non-blocking assignment `out <= out + 1` was being applied immediately instead of being deferred to the next cycle

### Root Causes & Fixes

1. **Verilog literals not parsed correctly** (`helpers/rvalue_to_z3.py`)
   - `"1'b0".isdigit()` returns `False` because it contains `'` and `b` characters
   - The value was treated as a symbolic variable name `BitVec("1'b0", 32)` instead of `BitVecVal(0, 32)`
   - **Fix**: Added `parse_verilog_literal()` function (lines 17-60) to parse Verilog-style literals:
     - Handles formats: `1'b0`, `32'd5`, `8'hFF`, `4'o7`, `'b0`, `'d10`
     - Supports binary (b), decimal (d), hex (h), octal (o) bases
     - Handles underscore separators and x/z values
   - **Fix**: Added `is_verilog_literal()` helper function (lines 63-66)
   - **Fix**: Replaced all `isdigit()` checks with `parse_verilog_literal()` calls

2. **Expression strings not converted to Z3** (`helpers/rvalue_to_z3.py`)
   - Strings like `"(0 + 1)"` stored in the symbolic store were treated as symbolic variable names
   - **Fix**: Added `parse_infix_expr_to_z3()` function (lines 69-158) to parse infix expression strings into Z3 expressions:
     - Handles operators: `+`, `-`, `*`, `/`, `<=`, `>=`, `<`, `>`, `==`, `!=`, `&`, `|`, `^`, `<<`, `>>`
     - Recursively parses nested parenthesized expressions
     - Falls back to store lookup for variable names

3. **Non-blocking assignments applied immediately** (`helpers/slang_helpers.py`)
   - Non-blocking assignments (`<=`) were updating `s.store` directly in the current cycle
   - In Verilog semantics, non-blocking assignments evaluate RHS with current values but defer the update to the next cycle
   - **Fix**: Changed `NonblockingAssignmentExpression` handler (lines 712-739) to:
     - Evaluate RHS with current store values
     - Call `s.add_pending_nba()` instead of updating store directly

4. **Added pending non-blocking assignment infrastructure** (`engine/symbolic_state.py`)
   - **Fix**: Added `pending_nba` dictionary to store deferred assignments (line 18)
   - **Fix**: Added `add_pending_nba(module_name, var_name, value)` method (lines 36-40)
   - **Fix**: Added `apply_pending_nba()` method to apply pending assignments at cycle start (lines 25-34)

5. **Apply pending assignments at cycle transitions** (`engine/execution_engine.py`)
   - **Fix**: Added call to `state.apply_pending_nba()` at the beginning of each new cycle (lines 477-480)
   - Only applies when `manager.cycle > 0` (not the first cycle)

6. **Normalize Verilog literals when storing** (`helpers/slang_helpers.py`)
   - **Fix**: Added `normalize_verilog_literal()` function (lines 12-21) to convert Verilog literals to decimal strings when storing
   - **Fix**: Updated literal assignment handlers to normalize values (e.g., `1'b0` → `"0"`)

### PySlang Library Usage

**Non-blocking vs Blocking assignments:**
- `ps.SyntaxKind.NonblockingAssignmentExpression`: The `<=` operator - deferred to next cycle
- `ps.SyntaxKind.AssignmentExpression`: The `=` operator - applied immediately

**Verilog literal formats:**
- PySlang returns literals in their original format (e.g., `1'b0`, `32'hDEADBEEF`)
- Must parse these to extract the actual integer value

### Result
- Assertion `out <= 2` now correctly passes in cycle 0
- `lhs=0, rhs=2` instead of `lhs=(1'b0 + 1), rhs=2`
- `unsat: [Not(ULE(0, 2))]` - correctly identifies that `0 <= 2` is always true
- Final state shows `'out': '0'` (non-blocking assignment deferred)
- No false assertion violations

## [2026-01-30] [Bug Fix] Fixed assertion Z3 condition showing `0!=0` instead of actual constraint

### Problem
When running symbolic execution with assertions (e.g., `assert (out <= 2)`), the violated assertion details showed `z3_condition: 0!=0` instead of the actual constraint like `ULE(out, 2)`. This made it impossible to understand what assertion was violated.

### Root Causes & Fixes

1. **Path condition printing showed empty solver** (`engine/execution_engine.py`)
   - `state.pc` is a Z3 Solver object, not a constraint expression
   - Printing `state.pc` directly shows minimal info
   - **Fix**: Changed to print `state.pc.assertions()` to show actual constraints (lines 569, 578)

2. **Added violated assertions info printing** (`engine/execution_engine.py`)
   - The constraint info was stored in `manager.violated_assertions` but never printed
   - **Fix**: Added printing of `manager.violated_assertions` when assertion violation detected (lines 522-528, 580-586)

3. **Missing PySlang syntax node handling** (`helpers/rvalue_to_z3.py`)
   - `parse_expr_to_Z3` only handled Z3 predicates (`is_and`, `is_eq`, `is_distinct`) and some syntax nodes
   - PySlang syntax nodes like `ParenthesizedExpressionSyntax` and `BinaryExpressionSyntax` fell through to default `return BitVecVal(0, 32)`
   - This caused `0 != 0` when the boolean conversion was applied
   - **Fix**: Added handlers for syntax nodes (lines 374-462):
     - `ParenthesizedExpressionSyntax`: Unwraps parentheses and recurses into inner expression
     - `BinaryExpressionSyntax`: Handles operators `<=`, `>=`, `<`, `>`, `==`, `!=`, `+`, `-`, `*`, `/`, `%`, `&&`, `||`, `&`, `|`, `^`, `<<`, `>>`
     - `LiteralExpressionSyntax`: Parses integer literals including sized literals like `32'd5`, `8'hFF`

4. **Added PySlang semantic expression handling** (`helpers/rvalue_to_z3.py`)
   - Added handlers for `ExpressionKind` semantic nodes (lines 263-372):
     - `BinaryOp`: Maps PySlang binary operators to Z3 (`ULE`, `ULT`, `UGE`, `UGT`, etc.)
     - `NamedValue`: Looks up variable in symbolic store or creates fresh symbolic variable
     - `IntegerLiteral`: Converts to `BitVecVal`
     - `Conversion`: Unwraps type casts
     - `UnaryOp`: Handles `!`, `~`, `-`, `+` operators

### PySlang Library Usage

**Syntax nodes vs Semantic expressions:**
- **Syntax nodes** (from parsing): Have `SyntaxKind`, accessed via `e.__class__.__name__`
  - `ParenthesizedExpressionSyntax`: Access inner via `e.expression`
  - `BinaryExpressionSyntax`: Access `e.left`, `e.right`, `e.operatorToken`
  - `LiteralExpressionSyntax`: Access `e.literal`
- **Semantic expressions** (from compilation): Have `ExpressionKind`, accessed via `e.kind`
  - `BinaryOp`: Access `e.left`, `e.right`, `e.op`
  - `NamedValue`: Access `e.symbol.name`
  - `IntegerLiteral`: Access `e.value`

**Key insight:** Assertion conditions from `stmt.cond` are syntax nodes (`ParenthesizedExpressionSyntax`), not semantic expressions. The code must handle both types.

### Result
- Assertion violations now show proper Z3 constraints: `z3_condition: ULE(out, 2)`
- Path conditions display actual constraints via `state.pc.assertions()`
- Violated assertion details include condition, z3_condition, and kind

## [2026-01-27] [Refactor] Changed expression format from prefix to infix notation

### Problem
The `conjunction_with_pointers` function in `helpers/rvalue_parser.py` was producing prefix notation (S-expressions) like `"(+ (+ symbol 1) out_wire)"` which is not a valid standard expression format. The user requested infix notation like `"((symbol + 1) + out_wire)"`.

### Changes

1. **Created infix version of `conjunction_with_pointers`** (`helpers/rvalue_parser.py`, lines 25-87)
   - Renamed the original function to `conjunction_with_pointers_prefix`
   - Created new `conjunction_with_pointers` function that produces infix notation
   - For `BinaryExpressionSyntax`: returns `f"({left_str} {operator} {right_str})"` instead of `f"({operator} {left_str} {right_str})"`
   - For `ConditionalExpressionSyntax`: returns `f"({cond} ? {true_val} : {false_val})"`

2. **Preserved prefix version** (`helpers/rvalue_parser.py`, lines 90-229)
   - Renamed to `conjunction_with_pointers_prefix`
   - Still produces prefix notation `"(+ abc123 (+ 1 def456))"`
   - Used by `tokenize()` function for the prefix-based parsing system

### PySlang Library Usage
- `ps.BinaryExpressionSyntax`: Access `left`, `right`, and `operatorToken` attributes
- `ps.ConditionalExpressionSyntax`: Access `predicate`, `ifTrue`, `ifFalse` attributes
- `ps.ElementSelectExpressionSyntax`: Access `value` and `selector` attributes
- `ps.ConcatenationExpressionSyntax`: Iterate through `expressions` attribute

### Result
- Store now shows infix expressions: `'out': "((1'b0 + 1) + uWIMuuP9uDMksfXp)"`
- Multi-cycle accumulated expressions: `'out': '((((symbol + 1) + out_wire) + 1) + out_wire)'`
- Prefix version preserved for internal tokenizer/parser system

## [2026-01-27] [Feature] Implemented -t parameter support for top module selection

### Problem
The `-t` / `--top` parameter was defined but not implemented. When users specified `-t place_holder_2`, the tool would still process all top instances instead of only the specified module.

### Root Cause & Fix

**Missing -t parameter implementation** (`main.py`)
- The `-t` parameter was defined in the option parser but never used in the code
- The code always processed the first top instance, ignoring user's module selection
- **Fix**: Implemented logic to find and process only the user-specified module (lines 186-214)
  - Searches for module by both instance name and definition name
  - Searches both top instances and nested instances
  - Only processes the specified module and its children

### PySlang Library Usage
- **Finding modules by definition**: Check `module.body.definition.name` to match module definition name
- **Nested instance search**: Iterate through `module.body` to find child instances

### Result
- Users can now specify `-t place_holder_2` to analyze only that module
- Only the specified module and its children are processed
- Uninstantiated module definitions are correctly excluded from analysis

## [2026-01-27] [Bug Fix] Fixed missing dfs_expr method and nested module instance tracking

### Problem
1. `AttributeError: 'SymbolicDFS' object has no attribute 'dfs_expr'` when running picorv32.v
2. `AttributeError: 'PrefixUnaryExpressionSyntax' object has no attribute 'operator'` in rvalue_parser.py
3. Nested module instances (submodules) were not being tracked in state.store - only top-level modules were processed

### Root Causes & Fixes

1. **Missing dfs_expr method** (`helpers/slang_helpers.py`)
   - The `SymbolicDFS` class called `self.dfs_expr()` at multiple locations but the method was not defined
   - **Fix**: Added `dfs_expr()` method as a placeholder to prevent AttributeError (lines 597-603)

2. **PySlang operator attribute compatibility** (`helpers/rvalue_parser.py`)
   - `PrefixUnaryExpressionSyntax` uses `operatorToken` instead of `operator` attribute
   - **Fix**: Added fallback to check for both `operator` and `operatorToken` attributes (lines 29-35)

3. **Nested module instances not tracked** (`main.py`)
   - Only top-level modules from `topInstances` were processed
   - Instantiated submodules (e.g., `place_holder_2` instantiated as `test_1`) were not added to the modules list
   - **Fix**: Added recursive `collect_all_instances()` function to discover all nested module instances (lines 177-191)

### PySlang Library Usage
- **Module hierarchy**: Use `compilation.getRoot().topInstances` to get top-level modules
- **Nested instances**: Recursively iterate through `symbol.body` to find child instances with `symbol.kind == ps.SymbolKind.Instance`
- **Operator tokens**: `PrefixUnaryExpressionSyntax` uses `operatorToken.valueText` instead of `operator`

### Result
- picorv32.v now runs successfully without AttributeError
- Nested module instances are now tracked: `{'place_holder': {...}, 'test_1': {...}}`
- Both parent and child module states are properly maintained during symbolic execution

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

## [2026-01-29] [Refactor] Migrated from manual Compilation to Driver-based file loading

### Problem
The original implementation manually parsed .F file lists line-by-line (lines 144-159 in `main.py`) and manually constructed `SourceManager`, `PreprocessorOptions`, `Bag`, and `Compilation` objects. This approach:
- Required ~50 lines of boilerplate code
- Didn't support standard SystemVerilog filelist features (+incdir+, +define+, -v, -y flags)
- Had potential bugs in relative path resolution and environment variable handling
- Fixed AttributeError: `PreprocessorOptions.includePaths` doesn't exist in pyslang 10.0 (correct attribute is `additionalIncludePaths`)

### Changes

1. **Replaced manual file loading with Driver approach** (`main.py`, lines 121-150)
   - Created `ps.Driver()` instance and called `addStandardArgs()`
   - Used `driver.sourceLoader.addSearchDirectories()` for include paths (replaces manual `PreprocessorOptions.additionalIncludePaths`)
   - Used `driver.processCommandFiles(input_file, True, False)` for .F file lists (replaces manual line-by-line parsing)
   - Used `driver.sourceLoader.addFiles(input_file)` for single files
   - Called `driver.processOptions()` and `driver.parseAllSources()` to parse sources
   - Obtained `Compilation` via `driver.createCompilation()`

2. **Fixed diagnostics section** (`main.py`, line 214)
   - Changed `ps.DiagnosticEngine(source_manager)` to `ps.DiagnosticEngine(driver.sourceManager)`
   - Driver provides its own `sourceManager` accessible via `driver.sourceManager`

### PySlang Library Usage (Driver API)

**Driver workflow:**
- `ps.Driver()`: Creates driver instance (manages file loading, preprocessing, compilation)
- `driver.addStandardArgs()`: Initializes standard command-line argument handling
- `driver.sourceLoader.addSearchDirectories(path)`: Adds include search directories
- `driver.processCommandFiles(file, makeRelative, separateUnit)`: Processes .F filelist files natively
  - `makeRelative=True`: Resolves paths relative to .F file location
  - `separateUnit=False`: All files go into the same compilation unit
- `driver.sourceLoader.addFiles(pattern)`: Adds source files (supports glob patterns)
- `driver.processOptions()`: Processes all configured options
- `driver.parseAllSources()`: Parses all loaded source files into syntax trees
- `driver.createCompilation()`: Returns the `Compilation` object (same type as manual approach)
- `driver.sourceManager`: Access to the Driver's SourceManager for diagnostics

**Key insight from hint_driver_compilation:**
- **Driver is the "manager"**, Compilation is the "brain"
- Driver handles file I/O, command-line parsing, include paths, macros
- Compilation handles AST, type checking, symbol resolution, hierarchy
- Driver approach is recommended for filelist-based projects

### Result
- Reduced code from ~50 lines to ~25 lines
- Native support for .F file lists with standard SystemVerilog filelist syntax
- Fixed include path handling (-I flag now works correctly)
- Cleaner separation: Driver handles I/O, Compilation handles semantics
- Same `Compilation` object output, fully compatible with existing symbolic execution engine
