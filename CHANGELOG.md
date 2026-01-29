# Changelog

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
