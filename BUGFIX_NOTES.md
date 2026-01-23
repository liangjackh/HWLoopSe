# Bug Fix Documentation - PySlang 9.x Compatibility

**Date:** 2026-01-23
**Issue:** Branch points explored showing 0, always blocks not being detected

---

## Problem Summary

When running the symbolic execution tool on Verilog designs, the tool reported:
- "Module has 0 always blocks" even when always blocks existed in the design
- "Branch points explored: 0" when conditional statements were present
- Only 1 path explored instead of multiple paths

This issue affected both simple test designs (test_2.v) and complex designs (non-pipelined-microprocessor.v).

---

## Root Cause Analysis

### Issue 1: InstanceSymbol Not Handled

**Location:** `engine/cfg.py`, function `get_always_sv()`

**Problem:**
- PySlang 9.x returns `InstanceSymbol` objects from `compilation.getRoot().topInstances`
- The `get_always_sv()` function only handled `DefinitionSymbol` and syntax nodes
- When an `InstanceSymbol` was passed, it fell through to generic iteration logic
- The `syntax` attribute of `InstanceSymbol` is `None`, so no always blocks were found

**Evidence:**
```python
# Debug output showed:
Module type: <class 'pyslang.InstanceSymbol'>
Has syntax: True
Syntax type: <class 'NoneType'>  # <- The problem!
```

### Issue 2: Submodules Not Traversed

**Location:** `engine/cfg.py`, function `get_always_sv()`

**Problem:**
- The tool only processed top-level modules from `topInstances`
- Child module instances (submodules) were not recursively traversed
- For hierarchical designs like non-pipelined-microprocessor.v, always blocks in submodules (memory, pc, etc.) were never discovered

**Evidence:**
```
Top instances:
  main
    Child: M (type: memory)      # <- Has always block, not processed
    Child: PC (type: pc)          # <- Has always block, not processed
    [... other children ...]
```

### Issue 3: Verilog Syntax Issues

**Location:** `designs/test-designs/non-pipelined-microprocessor.v`

**Problem:**
- Module names were on separate lines from the `module` keyword
- PySlang parser couldn't handle this formatting
- Caused compilation errors preventing any analysis

**Example:**
```verilog
module
memory( clk, opcode, ... );  # Parser error: expected identifier
```

### Issue 4: If Statements Without Else Clauses Not Creating Paths

**Location:** `engine/cfg.py`, function `_process_conditional_sv()`

**Problem:**
- When an `if` statement had no `else` clause, the CFG construction returned early
- Only the "true" branch was represented in the CFG
- The "false" path (where condition is false and body is skipped) was not created
- This resulted in fewer paths being explored than expected

**Example:**
```verilog
always @(posedge clk) begin
  if (opcode != JMP) begin
    // do something
  end
  // No else clause - false path was missing!
end
```

**Evidence:**
- Memory module's always block has `if (opcode != JMP)` without else
- Before fix: Only 1 path through memory's always block
- Expected: 2 paths (opcode != JMP true/false)

---

## Changes Made

### Change 1: Add InstanceSymbol Handling

**File:** `engine/cfg.py`
**Lines:** 113-127

**Before:**
```python
def get_always_sv(self, m: ExecutionManager, s: SymbolicState, ast):
    """Extracts always blocks from PySlang AST"""
    if (ast != None and isinstance(ast, ps.DefinitionSymbol)):
        self.get_always_sv(m, s, ast.syntax)
        return
    # ... rest of function
```

**After:**
```python
def get_always_sv(self, m: ExecutionManager, s: SymbolicState, ast):
    """Extracts always blocks from PySlang AST"""
    # Handle InstanceSymbol (from topInstances or child instances)
    if ast is not None and ast.__class__.__name__ == "InstanceSymbol":
        # Iterate over the body to find ProceduralBlockSymbol and child instances
        if hasattr(ast, 'body'):
            for item in ast.body:
                if item.__class__.__name__ == "ProceduralBlockSymbol":
                    # Get the syntax node from the symbol
                    if hasattr(item, 'syntax') and item.syntax is not None:
                        self.always_blocks.append(item.syntax)
                elif item.__class__.__name__ == "InstanceSymbol":
                    # Recursively process child instances (submodules)
                    self.get_always_sv(m, s, item)
        return
    # ... rest of function
```

**Why:**
- `InstanceSymbol` has a `body` attribute that is iterable
- The body contains `ProceduralBlockSymbol` objects representing always/initial blocks
- Each `ProceduralBlockSymbol` has a `syntax` attribute with the actual AST node
- Recursive traversal of child `InstanceSymbol` objects enables hierarchical module analysis

### Change 2: Fix Verilog Module Declarations

**File:** `designs/test-designs/non-pipelined-microprocessor.v`
**Lines:** Multiple locations (72, 163, 206, 218, 229, 240, 251, 265)

**Changes:**
- Moved module names to same line as `module` keyword
- Renamed `program` module to `program_rom` (avoid keyword conflict)
- Updated module instantiation in main module

**Examples:**
```verilog
# Before:
module
memory( clk, opcode, ... );

# After:
module memory( clk, opcode, ... );
```

**Why:**
- PySlang parser expects module name on same line as `module` keyword
- This is standard Verilog formatting
- Prevents compilation errors

### Change 3: Add Skip Path for If Statements Without Else

**File:** `engine/cfg.py`
**Lines:** 217-261
**Function:** `_process_conditional_sv()`

**Before:**
```python
def _process_conditional_sv(self, m: ExecutionManager, s: SymbolicState, parent_idx: int, node) -> None:
    # ... process then branch ...
    self.edgelist.append((parent_idx, then_start_idx))

    if else_body is None:
        return  # <- Early return, no false path created!

    # ... process else branch ...
```

**After:**
```python
def _process_conditional_sv(self, m: ExecutionManager, s: SymbolicState, parent_idx: int, node) -> None:
    # ... process then branch ...
    self.edgelist.append((parent_idx, then_start_idx))

    if else_body is None:
        # No else clause: create a "skip" path (condition false -> fall through)
        # This represents the path where the if condition is false and body is skipped
        skip_idx = self.curr_idx
        self.partition_points.add(self.curr_idx)
        self.all_nodes.append(None)  # Dummy node for the skip path
        self.curr_idx += 1
        self.edgelist.append((parent_idx, skip_idx))
        return

    # ... process else branch ...
```

**Why:**
- An `if` statement without `else` has two execution paths:
  1. Condition is true → execute the body
  2. Condition is false → skip the body (fall through)
- The original code only created path #1
- The fix creates a dummy node representing the "skip" path for path #2
- This allows the CFG to properly enumerate both paths through the conditional

---

## Results and Effects

### Test Case 1: test_2.v (Simple Design)

**Before Fix 1 (InstanceSymbol handling):**
```
Module place_holder has 0 always blocks
Branch points explored: 0
Paths explored: 1
```

**After Fix 1:**
```
Module place_holder has 1 always blocks
Branch points explored: 2
Paths explored: 2
Module place_holder paths: [(([-1, 0, 1, -2],),), (([-1, 0, 2, -2],),)]
```

**After Fix 3 (if without else):**
```
Module place_holder has 1 always blocks
Branch points explored: 8
Paths explored: 4
```

**Impact:**
- ✅ Always block correctly detected (Fix 1)
- ✅ Both branches of if-else statement explored (Fix 1)
- ✅ Submodule (place_holder_2) always block also detected (Fix 1)
- ✅ If statements without else now create skip paths (Fix 3)
- ✅ Path count increased from 2 to 4 (2 modules × 2 paths each)

### Test Case 2: non-pipelined-microprocessor.v (Complex Hierarchical Design)

**Before Fix 1:**
```
[Fatal] Compilation failed with errors
```

**After Fix 2 (Verilog syntax):**
```
Compilation succeeds with warnings
```

**After Fix 1 (InstanceSymbol + submodules):**
```
Module main has 12 always blocks
Branch points explored: 4
Paths explored: 2
```

**After Fix 3 (if without else):**
```
Module main has 12 always blocks
Branch points explored: 8
Paths explored: 4
Module main paths: [
  ([-1,0,-2], ..., [-1,0,1,-2], ..., [-1,0,1,-2], ...),  # memory:true, pc:true
  ([-1,0,-2], ..., [-1,0,1,-2], ..., [-1,0,2,-2], ...),  # memory:true, pc:false
  ([-1,0,-2], ..., [-1,0,2,-2], ..., [-1,0,1,-2], ...),  # memory:false, pc:true
  ([-1,0,-2], ..., [-1,0,2,-2], ..., [-1,0,2,-2], ...)   # memory:false, pc:false
]
```

**Impact:**
- ✅ Compilation succeeds (Fix 2)
- ✅ All procedural blocks discovered across module hierarchy (Fix 1):
  - 1 initial block in main (assertion)
  - 8 initial blocks in memory (m0-m7 initialization)
  - 1 always block in memory (register write logic with conditionals)
  - 1 initial block in pc (progCntr initialization)
  - 1 always block in pc (program counter update with if-else)
- ✅ Branch points doubled from 4 to 8 (Fix 3)
- ✅ Paths doubled from 2 to 4 (Fix 3)
- ✅ Memory module's `if (opcode != JMP)` now creates both true/false paths
- ✅ PC module's `if ((opcode == JMP) && (operand1 == 0))` creates both paths

**Path Breakdown:**
- Memory module: 2 paths (opcode != JMP: true/false)
- PC module: 2 paths (condition: true/false)
- Total: 2 × 2 = 4 paths

**Note on Sequential If Statements:**
The memory module has 8 nested `if (writeLoc == X)` statements without else clauses. Theoretically, these should create 2^8 = 256 paths (each can be true/false independently). However, the current CFG construction treats sequential if statements as part of a single path, not as independent branches. This is a known limitation documented in the "Future Considerations" section.

---

## Technical Details

### PySlang Symbol vs Syntax Hierarchy

**Symbol Objects (Semantic):**
- `InstanceSymbol`: Represents a module instance
- `ProceduralBlockSymbol`: Represents always/initial blocks
- `VariableSymbol`, `NetSymbol`, etc.

**Syntax Objects (AST):**
- `ModuleDeclarationSyntax`: Module definition
- `ProceduralBlockSyntax`: Always/initial block AST
- `ConditionalStatementSyntax`: If-else statements

**Key Insight:**
- PySlang 9.x `topInstances` returns Symbol objects, not Syntax objects
- Symbol objects have a `syntax` attribute to access AST, but for `InstanceSymbol` this is `None`
- Must iterate over `InstanceSymbol.body` to find `ProceduralBlockSymbol` objects
- Each `ProceduralBlockSymbol.syntax` provides the actual AST node

### CFG Path Notation

The path notation `[-1, 0, 1, -2]` represents:
- `-1`: Dummy start node
- `0`: First basic block
- `1` or `2`: Branch direction (1=then, 2=else)
- `-2`: Dummy end node

Example from test_2.v:
- Path `[-1, 0, 1, -2]`: Start → Block 0 → Then branch → End (RST=true)
- Path `[-1, 0, 2, -2]`: Start → Block 0 → Else branch → End (RST=false)

---

## Compatibility Notes

This fix ensures compatibility with PySlang 9.x while maintaining the existing symbolic execution logic. The changes are minimal and focused on the AST traversal layer, not the core execution engine.

**Tested with:**
- PySlang 9.x
- Python 3.x
- Test designs: test_2.v, non-pipelined-microprocessor.v

---

## Future Considerations

1. **Initial vs Always Blocks:** Currently both are treated as procedural blocks. Consider filtering to only process `always` blocks for symbolic execution, as `initial` blocks execute once at simulation start.

2. **Module Hierarchy Tracking:** The current implementation flattens all always blocks under the top module name. Consider preserving module hierarchy in the output for better traceability.

3. **Performance:** Recursive traversal of large hierarchies could be optimized with memoization or iterative approaches.

4. **Error Handling:** Add validation to ensure `ProceduralBlockSymbol.syntax` is not None before appending to always_blocks list.

5. **Sequential If Statements Without Else:** The current CFG construction treats sequential `if` statements without `else` clauses as part of a single path, not as independent branches. For example:
   ```verilog
   if (a) begin x = 1; end
   if (b) begin y = 2; end
   if (c) begin z = 3; end
   ```
   This should theoretically create 2^3 = 8 paths (each if can be true or false independently), but the current implementation treats them as sequential statements within a single path. This is a fundamental limitation of the current CFG construction approach and would require significant refactoring to address properly. The fix for "if without else" creates a skip path for the entire block, but doesn't enumerate all combinations of nested sequential ifs.

---

## Summary of Improvements

### Progression of Fixes

**Initial State:**
- Branch points explored: 0
- Paths explored: 1
- Always blocks found: 0

**After Fix 1 (InstanceSymbol + Submodule Traversal):**
- Branch points explored: 4
- Paths explored: 2
- Always blocks found: 12
- **Improvement:** Can now find always blocks in PySlang 9.x and traverse module hierarchy

**After Fix 2 (Verilog Syntax):**
- Compilation errors resolved
- **Improvement:** Can now parse non-pipelined-microprocessor.v

**After Fix 3 (If Without Else):**
- Branch points explored: 8 (2× increase)
- Paths explored: 4 (2× increase)
- Always blocks found: 12 (unchanged)
- **Improvement:** If statements without else clauses now create both true/false paths

### Key Metrics

| Metric | Before All Fixes | After All Fixes | Improvement |
|--------|-----------------|-----------------|-------------|
| Always blocks detected | 0 | 12 | ∞ |
| Branch points explored | 0 | 8 | ∞ |
| Paths explored | 1 | 4 | 4× |
| Compilation success | ❌ | ✅ | Fixed |

### What Works Now

1. ✅ PySlang 9.x compatibility
2. ✅ Hierarchical module traversal
3. ✅ Always block detection in submodules
4. ✅ If-else statements create proper branches
5. ✅ If statements without else create skip paths
6. ✅ Multiple execution paths explored

### Known Limitations

1. ⚠️ Sequential if statements without else don't create exponential paths
2. ⚠️ Initial blocks are treated the same as always blocks
3. ⚠️ Module hierarchy is flattened in output

