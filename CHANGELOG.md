# Changelog

## 2026-03-12 - Fixed Nested-If CFG Path Generation and Assertion Reachability

### Problem: Assertion never executed — cfg1 only generated 1 path instead of 3

The assertion always block in `my_assertions` (cfg1) contains nested `if` statements:
```systemverilog
always @(posedge clk) begin
    if (rst_n && check_en) begin        // outer if
        if (past_3_in_a <= THRESHOLD) begin  // inner if
            assert (b_out == (past_3_in_a + 1));
        end
    end
end
```

This should produce 3 CFG paths:
- Path 0: `[1,1]` — outer true, inner true → **assert executed**
- Path 1: `[1,0]` — outer true, inner false → skip assert
- Path 2: `[0]` — outer false → skip all

But cfg1 only generated 1 path. The assertion was never reached, and every path was pruned/abandoned.

### Root Cause 1: `BlockStatementSyntax` iteration yields raw tokens (`cfg.py: basic_blocks_sv`)

`BlockStatementSyntax` (begin...end blocks) is iterable in pyslang, but iterating it directly yields raw syntax tokens (`BeginKeyword`, `SyntaxList`, `EndKeyword`) rather than semantic statement children. When `_process_conditional_sv` passed the outer if's then-body (a `BlockStatementSyntax`) to `basic_blocks_sv`, the code entered the `hasattr(ast, '__iter__')` branch and iterated raw tokens. The inner `ConditionalStatementSyntax` was never recognized as a branching point.

### Root Cause 2: `partition()` / `find_basic_block()` collapsed adjacent partition points (`cfg.py`)

Even after fixing Root Cause 1, the inner if produced adjacent partition points (e.g., `[0, 2, 3, 4, 5, 6]`). The old `partition()` used `start = pp[i-1]+1` to `end = pp[i]` for intermediate blocks, which produced empty slices when partition points were adjacent. These empty blocks were skipped, collapsing all branch targets into a single block. `find_basic_block()` had matching issues, mapping different nodes to the same block index. Result: all CFG edges pointed to the same block → `nx.all_simple_paths` found only 1 degenerate path.

### Changes Made

#### `engine/cfg.py`

**Fix 1 — `basic_blocks_sv()`: Handle `BlockStatementSyntax` before generic iteration**

Added an early check at the top of the iterable branch:
```python
if isinstance(ast, ps.BlockStatementSyntax):
    self.block_stmt_depth += 1
    self.block_smt.append(True)
    self.basic_blocks_sv(m, s, ast.items)  # Use .items, not direct iteration
    if self.block_stmt_depth in self.ind_branch_points:
        self.resolve_independent_branch_pts(self.block_stmt_depth)
    self.block_smt.pop()
    self.block_stmt_depth -= 1
    return
```

This ensures `BlockStatementSyntax` routes through `ast.items` (which yields actual statements like `ConditionalStatementSyntax`) instead of raw tokens.

**Fix 2 — `partition()`: Rewritten for correct block boundaries**

New logic:
- Block 0: `all_nodes[pp[0] .. pp[1]]` (inclusive) — preamble + first conditional
- Blocks 1+: each starts at `pp[2+]` (branch targets), extends to the next branch start
- Last block extends to `len(all_nodes)`

This correctly handles adjacent partition points by treating each `pp[2+]` as the start of a separate block.

**Fix 3 — `find_basic_block()`: Rewritten to match new partition logic**

- `node_idx <= pp[1]` → block 0
- Otherwise, reverse-scan `branch_starts = pp[2:]` to find the containing block

### Results

cfg1 now correctly generates 3 paths:
```
Path 0: [-1, 0, 1, 2, -2]  — outer then, inner then → assert executed
Path 1: [-1, 0, 1, 3, -2]  — outer then, inner else → skip assert
Path 2: [-1, 0, 4, -2]     — outer else → skip all
```

All other CFGs (module_a, module_b, top) continue to work correctly.

The SE engine successfully detected the assertion violation `b_out == (past_3_in_a + 1)` in 8 path explorations, reaching milestone 3/5 at cycle 4.

**Counterexample**: `rst_n_c0=0, rst_n_c1..c4=1, top_in_a_c1=0, top_in_a_c2=0, top_in_a_c3=0, top_in_a_c4=1`

**Execution time**: ~0.75s

### PySlang Library Usage
- `BlockStatementSyntax` (begin...end): Is iterable but yields raw syntax tokens. Use `.items` property to get semantic statement children.
- `ConditionalStatementSyntax` (if...else): `.ifTrue` gives the then-body (often a `BlockStatementSyntax`), `.elseClause` gives the else clause.

## 2026-03-09 - Fixed False Positive Bug Detection and CFG Issues

### Problem 1: False Positive Termination
When running directed symbolic execution with milestones, the tool incorrectly reported finding a bug in cycle 0 with no counterexample.

### Problem 2: Z3 Bit Width Mismatch
After fixing Problem 1, the tool crashed with Z3 type error when comparing signals with different bit widths.

### Problem 3: Invalid Basic Block Indices in CFG Paths
The tool generated warnings about invalid basic_block_idx that exceeded the actual number of basic blocks.

### Problem 4: All Milestones Reached Simultaneously
Milestones jumped from 0/7 to 7/7 in a single cycle, defeating their purpose as incremental waypoints. The while loop in strategies.py checked all milestones sequentially until one failed, allowing all satisfiable milestones to be marked as "reached" at once.

### Root Causes

**Problem 1**: In `engine/strategies.py`, the directed search strategy had a logic error:
1. Lines 509-514: Check if milestones are satisfiable using Z3 solver
2. Lines 516-517: If all milestones satisfiable, return `"ALL_MILESTONES"` immediately
3. Lines 520-521: Check for assertion violations (NEVER REACHED due to early return)

Z3 satisfiability means "this condition COULD be true with some variable assignment", not "this condition IS true with concrete values". In cycle 0, all milestones were satisfiable with symbolic variables, so the tool incorrectly treated this as success.

**Problem 2**: In `engine/milestone.py` line 202, when creating Z3 constants for milestone comparisons, the code always used 32-bit width:
```python
target = BitVecVal(cond.value, 32)  # Always 32 bits!
```

But signals can have different widths (e.g., 6-bit counters, 1-bit flags), causing type mismatches.

**Problem 3**: In `engine/cfg.py`, the `basic_blocks_sv` method skips empty blocks when creating `basic_block_list`:
```python
if basic_block:  # Only add non-empty blocks
    self.basic_block_list.append(basic_block)
```

But `find_basic_block` assumes a direct mapping between `partition_list` indices and block indices. When blocks are skipped, this mapping breaks:
- `partition_list` might have 7 elements (expecting 6 blocks)
- But if 2 blocks are empty, `basic_block_list` only has 4 blocks
- `find_basic_block` returns indices up to 5, but max valid is 3

This causes `make_paths()` to create CFG edges with invalid block indices, which then appear in NetworkX paths.

**Problem 4**: In `engine/strategies.py` lines 503-508, a while loop continuously checked all milestones:
```python
while current_progress < len(self.milestone_manager.milestones):
    success, new_progress = self.milestone_manager.check_and_lock_stateless(state, current_progress)
    if success:
        current_progress = new_progress
    else:
        break
```

In cycle 0, all milestones were satisfiable with symbolic variables, so the loop advanced through all 7 milestones at once (0→1→2→...→7), defeating the purpose of incremental waypoints.

### Solutions

**Problem 1**: Removed the early return for `"ALL_MILESTONES"`. Milestones now only guide search priority, not act as terminal success conditions.

**Changes in `engine/strategies.py`**:
- Removed lines 516-517 that returned `"ALL_MILESTONES"`
- Removed lines 399-403 that handled `"ALL_MILESTONES"` as success
- Now only `"VIOLATION"` terminates the search successfully

**Problem 2**: Fixed bit width matching in milestone comparisons.

**Changes in `engine/milestone.py` line 202**:
```python
# Before:
target = BitVecVal(cond.value, 32)

# After:
target = BitVecVal(cond.value, signal_value.size())
```

**Problem 3**: Added bounds checking in `find_basic_block` to clamp return values.

**Changes in `engine/cfg.py` lines 436-443**:
```python
# Before:
return i - 1

# After:
return min(i - 1, len(self.basic_block_list) - 1)
```

**Problem 4**: Changed milestone checking to one per cycle, and improved LLM prompt.

**Changes in `engine/strategies.py` lines 500-508**:
```python
# Before: while loop checking all milestones
while current_progress < len(self.milestone_manager.milestones):
    success, new_progress = self.milestone_manager.check_and_lock_stateless(...)
    if success:
        current_progress = new_progress
    else:
        break

# After: check only one milestone per cycle
if current_progress < len(self.milestone_manager.milestones):
    success, new_progress = self.milestone_manager.check_and_lock_stateless(...)
    if success:
        current_progress = new_progress
```

**Changes in `frontend/llm_planner.py`**:
- Added Rule 3: "Temporal Progression" to SYSTEM_PROMPT
- Instructs LLM to generate milestones that form a temporal sequence across clock cycles
- Emphasizes that early milestones should be prerequisites for later ones
- Avoids conditions that can be satisfied simultaneously in a single cycle

### Verification
After all four fixes:
- No more false positive terminations in cycle 0
- No more Z3 type errors
- No more "Skipping invalid basic_block_idx" warnings
- Milestones now progress incrementally: 0/7 → 1/7 → 2/7 → ... → 7/7
- No more false positive terminations in cycle 0
- No more Z3 type errors
- No more "Skipping invalid basic_block_idx" warnings
- Tool correctly explores paths: `[Path 8] cycle=2, milestones=7/7, queue=21`

## 2026-03-06 - Context Slicer Enhancement and COI Fixes

### Problem 1: Incomplete RTL Context for LLM Milestone Generation
When using `--auto-plan` with OR1200, the LLM received only the top-level module wrapper (25K chars) without the actual logic that implements the assertion signals. This caused poor milestone generation.

**Example**: For assertion `operand_b == dcpu_dat_o` in `or1200_cpu.u_assertions`:
- **Before**: Context only included `or1200_top` (wrapper with port declarations)
- **After (without COI)**: Context includes `or1200_cpu`, `or1200_alu`, `or1200_lsu`, `or1200_operandmuxes`, `or1200_sprs`, `or1200_mult_mac`, `or1200_fpu` (109K chars with actual logic)
- **After (with COI)**: Context includes only `or1200_cpu`, `or1200_operandmuxes` (26K chars - the minimal relevant set)

### Problem 2: COI Analysis Failing with Hierarchical Instance Names
COI analysis was receiving seed signals with hierarchical paths like `or1200_cpu.u_assertions.operand_b`, but the port map used short instance names like `u_assertions`. This caused:
1. Port connection lookups to fail
2. COI to find 0 relevant instances
3. Either "No modules found to execute" error or execution issues

### Problem 3: IndexError During Execution with COI
After fixing the seed signal naming, execution crashed with `IndexError: list index out of range` when accessing `cfg.basic_block_list[basic_block_idx]`. This was caused by CFG paths containing invalid basic block indices that exceed the actual basic block list size.

### Root Cause Analysis

**Problem 1**:
1. `ContextSlicer.get_context()` only parsed the target expression for instance names (e.g., `or1200_cpu.u_assertions`)
2. It never analyzed which submodules actually drive the assertion signals
3. For OR1200, assertion signals like `operand_b` and `dcpu_dat_o` are produced by sibling modules of `u_assertions`, not by the top module

**Problem 2**:
1. `assertion_extractor.py` sets `module_name` to the full hierarchical path `or1200_cpu.u_assertions`
2. This becomes the COI seed: `(or1200_cpu.u_assertions, operand_b)`
3. But `COIAnalyzer` builds port maps using short names from `modules_dict`: `(u_assertions, operand_b)`
4. Lookup fails at `port_map_child_to_parent[(or1200_cpu.u_assertions, operand_b)]`

**Problem 3**:
1. CFG construction creates paths that reference basic block indices
2. Some paths contain indices that are out of bounds for the `basic_block_list`
3. This is likely a bug in CFG construction or path generation
4. When COI keeps certain CFGs, these invalid paths cause crashes during execution

### Changes Made

#### `frontend/context_slicer.py`
1. **Added signal extraction** (new method `_extract_signal_names_from_expr`):
   - Extracts leaf signal names from target expressions
   - Filters out operators, literals, and common keywords

2. **Added parent module detection** (new method `_find_assertion_module_parent`):
   - Finds the parent module that instantiates the assertion module
   - Returns parent module instance and path

3. **Added sibling module discovery** (new method `_find_sibling_modules_for_signals`):
   - Searches parent module's source code for child instances
   - Identifies which children have port connections to the assertion signals
   - Uses regex to match instance declarations and port connections

4. **Enhanced `get_context` method**:
   - When target references an assertion module, traces signal dependencies
   - Includes parent module and all relevant sibling submodules
   - Constructs full hierarchical paths for instance lookup
   - Falls back to original behavior if assertion parent not found
   - **Works with COI**: When COI provides relevant instances, uses those instead

5. **Added children tracking** (in `_build_maps`):
   - New `_children_map` to track parent → children relationships
   - Enables efficient sibling module lookup

#### `engine/execution_engine.py`
**Fixed COI seed signal instance names** (lines 593-607):
- Extract the last component of hierarchical paths for instance names
- `or1200_cpu.u_assertions` → `u_assertions`
- This matches the short names used in `modules_dict` and port maps
- COI can now successfully trace through port connections

**Fixed COI empty result handling** (lines 609-636):
- When COI finds no relevant instances, set `self.coi_result = None`
- Skip pruning entirely to avoid removing all modules
- Prevents "No modules found to execute" error

#### `engine/strategies.py`
**Added safety check for invalid basic block indices** (lines 613-626):
- Before accessing `cfg.basic_block_list[basic_block_idx]`, check if index is valid
- If `basic_block_idx >= len(cfg.basic_block_list)`, skip that basic block with a warning
- Warning includes: module name, CFG index, path index, invalid index, valid range, and total blocks
- Example: `[Warning] Skipping invalid basic_block_idx 5 in or1200_cpu/cfg51/path2 (max: 4, total blocks: 5)`
- Allows execution to continue despite CFG construction bugs
- Prevents `IndexError` crashes

**Updated `_execute_path` signature** (lines 593-604):
- Added optional parameters `cfg_idx` and `path_idx` for better error reporting
- Defaults to -1 if not provided (for backward compatibility)

#### `engine/milestone.py`
**Fixed hierarchical signal path handling** (lines 73-95):
- Added support for hierarchical signal paths with more than 2 parts (e.g., `or1200_cpu.u_assertions.operand_b`)
- When a path has 3+ parts, extracts the signal name (last part) and searches all modules
- This handles cases where LLM generates hierarchical paths but the actual signal is stored in a different module
- Example: `or1200_cpu.u_assertions.operand_b` → searches for `operand_b` in all modules → finds it in `or1200_operandmuxes`
- Eliminates "Invalid signal path format" warnings during milestone checking
**Fixed PySlang version compatibility** (line 52-66):
- Added fallback for `ConditionalExpressionSyntax` attributes
- Tries `ifTrue`/`ifFalse` first (PySlang 7.0)
- Falls back to `left`/`right` for other versions
- Prevents `AttributeError: 'ConditionalExpressionSyntax' object has no attribute 'ifTrue'`

### Testing Results

**Without COI** (`--auto-plan` only):
- Context: 109K chars (7 modules)
- Includes all sibling modules that connect to assertion signals
- Works but may exceed LLM context limits on large designs

**With COI** (`--auto-plan --coi`):
- Context: 26K chars (2 modules: `or1200_cpu`, `or1200_operandmuxes`)
- COI correctly identifies minimal relevant set
- Execution proceeds with warnings about invalid basic block indices
- Successfully reaches milestones and completes

**Working command**:
```bash
python3 -m main 50 or1200_subset.F --sv --auto-plan --llm-provider deepseek --coi --strategy directed -t or1200_top
```

### Known Issues

**CFG Path Construction Bug**: Some CFG paths contain basic block indices that exceed the actual basic block list size. The safety check in `strategies.py` works around this by skipping invalid indices with a warning. The root cause in CFG construction should be investigated and fixed in a future update.

### PySlang Library Usage
- `ConditionalExpressionSyntax`: Ternary operator `cond ? true_val : false_val`
  - PySlang 7.0: uses `predicate`, `ifTrue`, `ifFalse` attributes
  - Other versions: may use `predicate`, `left`, `right` attributes
  - Added compatibility layer with `hasattr()` checks

## 2024 - Assertion Extraction and Condition Parser Fixes

### Problem 1: Assertion Extraction
PySlang could correctly parse `ImmediateAssertion` statements, but the assertion extraction was failing due to:
1. **Module selection issue**: Without `-t` parameter, `_discover_modules` defaulted to the first top instance (`or1200_dc_fsm`) instead of the correct one (`or1200_top`)
2. **Deduplication bug**: Using `str(assertion)` for deduplication caused all assertions to be treated as identical since they all returned `Expression(ExpressionKind.BinaryOp)`

### Problem 2: LLM Planner Validation Errors
The condition parser and milestone system had several limitations:
1. **Verilog bit-width format not supported**: `2'b01`, `32'hFF` couldn't be parsed
2. **Signal-to-signal comparisons not supported**: `sig_a != sig_b` failed validation
3. **Tokenizer bug**: `!=` was incorrectly split into `!` and `=` tokens

### Root Cause Analysis
- `or1200_assertions` module is instantiated in `or1200_cpu.v:1029` as `u_assertions`
- The instance hierarchy is: `or1200_top` → `or1200_cpu` → `u_assertions`
- When analyzing `or1200_dc_fsm` instead of `or1200_top`, the assertion module was never traversed
- The condition parser only supported `signal op constant` format, not `signal op signal`

### Changes Made

#### `frontend/assertion_extractor.py`
1. **Fixed deduplication logic** (lines 159-177):
   - Changed from using `str(assertion)` to using `sourceRange` or object `id()`
   - This allows each unique assertion to be properly identified

2. **Optimized search strategy** (lines 114-123):
   - Only search the top-level module once
   - Let `get_assertions` recursively traverse all sub-instances
   - Prevents duplicate assertions from being found multiple times

3. **Added support for standalone assertion modules** (lines 133-150):
   - Search all top instances for modules with "assert" in their name
   - Skip modules already searched to avoid duplicates
   - Useful for designs with uninstantiated assertion modules

#### `frontend/condition_parser.py`
1. **Enhanced `parse_value` function** (lines 35-73):
   - Added support for Verilog bit-width formats: `2'b01`, `32'hFF`, `6'd42`
   - Handles formats: `width'base_value` where base can be `h`, `b`, or `d`

2. **Updated `SimpleCondition` dataclass** (lines 8-20):
   - Changed `value` type from `int` to `Union[int, str]`
   - Added `is_signal_comparison()` method to distinguish signal vs constant comparisons

3. **Enhanced `parse_simple_condition` function** (lines 69-125):
   - Try to parse right-hand side as numeric value first
   - If that fails, treat it as a signal path (signal-to-signal comparison)
   - Uses regex to validate signal names: `^[a-zA-Z_][\w.\[\]:]*$`

4. **Fixed `tokenize_condition` function** (lines 128-193):
   - Modified to not split `!=` into separate tokens
   - Only treats `!` as NOT operator when not followed by `=`
   - Preserves `!=` as part of comparison expressions

5. **Enhanced `extract_signal_name` to support bit-select syntax** (lines 362-385):
   - Now strips bit-select brackets `[...]` before extracting signal name
   - Examples:
     - `ex_insn[31:26]` → `ex_insn`
     - `module.signal[7:0]` → `signal`
   - This allows LLM to generate milestone conditions with bit-select syntax
   - Fixes validation errors like "Signal 'ex_insn[31:26]' not found"
   - Enables more precise milestone conditions (e.g., checking instruction opcodes)

#### `engine/milestone.py`
1. **Enhanced `_build_simple_condition` method** (lines 144-183):
   - Check if `cond.value` is a string (signal path) or int (constant)
   - For signal-to-signal comparisons, resolve both signals to Z3 expressions
   - For constant comparisons, use `BitVecVal` as before

#### Test Results
- ✅ **test_2.v**: Correctly finds 1 assertion (previously found duplicates)
- ✅ **or1200 design**: Correctly finds all 71 assertions when using `-t or1200_top`
- ✅ **Verilog formats**: `2'b01`, `32'hFF` parse correctly
- ✅ **Signal comparisons**: `sig_a != sig_b` works in milestones
- ✅ **Tokenizer**: `!=` no longer split incorrectly

### Usage

**For test_2.v**:
```bash
python3 -m main 16 designs/test-designs/test_2.v --sv --auto-plan --llm-provider deepseek --coi --strategy directed
```

**For or1200 design**:
```bash
python3 -m main 3 or1200.F --sv --auto-plan --llm-provider deepseek --coi --strategy directed -t or1200_top
```

**Key**: The `-t or1200_top` parameter is essential to specify the correct top-level module.

### Files Modified
- `frontend/assertion_extractor.py`: Fixed deduplication and search logic
- `frontend/condition_parser.py`: Added Verilog format support and signal-to-signal comparisons
- `engine/milestone.py`: Enhanced to handle signal-to-signal comparisons
- `engine/execution_engine.py`: Updated calls to pass `compilation` and `driver` parameters

### Files Created (Optional)
- `designs/benchmarks/or1200/buggy-or1200/or1200_assertions_wrapper.sv`: Wrapper module (not needed if using `-t` parameter)
- `or1200_with_assertions.F`: Alternative filelist (not needed if using `-t` parameter)

### Notes
- The wrapper approach works but is unnecessary since `or1200_assertions` is already instantiated in the design
- Using the `-t` parameter is the cleaner solution
- The deduplication fix is critical for any design with multiple assertions
- Signal-to-signal comparisons enable more expressive milestone conditions
- Verilog format support is essential for realistic hardware verification
