# NBA (Non-Blocking Assignment) Timing Analysis

## Overview
The symbolic execution engine handles non-blocking assignments (NBA) across multiple clock cycles. This document traces the complete flow of NBA handling from assignment to application.

## Key Components

### 1. SymbolicState (engine/symbolic_state.py)
**Lines 11-39: NBA Storage and Application**

```python
def __init__(self):
    self.pc = Solver()
    self.assertion_counter = 0
    self.clock_cycle = 0
    self.store = {}
    self.pending_nba = {}  # Dictionary: {module_name: {var_name: value}}
    self.cond = False
    self.pc_constraint_set = set()

def apply_pending_nba(self):
    """Apply pending non-blocking assignments to the store.
    This should be called at the beginning of each new cycle."""
    if self.pending_nba:
        logging.debug(f"[NBA] Applying {sum(len(updates) for updates in self.pending_nba.values())} pending NBA(s)")
    for module_name, updates in self.pending_nba.items():
        if module_name not in self.store:
            self.store[module_name] = {}
        for var_name, value in updates.items():
            logging.debug(f"[NBA]   {module_name}.{var_name} <= {value}")
            self.store[module_name][var_name] = value
    # Clear pending assignments after applying
    self.pending_nba = {}

def add_pending_nba(self, module_name: str, var_name: str, value):
    """Add a non-blocking assignment to the pending queue."""
    if module_name not in self.pending_nba:
        self.pending_nba[module_name] = {}
    self.pending_nba[module_name][var_name] = value
    logging.debug(f"[NBA] Queued NBA: {module_name}.{var_name} <= {value}")
```

**Key Points:**
- `pending_nba` is a nested dictionary: `{module_name: {var_name: z3_value}}`
- `apply_pending_nba()` moves all pending assignments into the main store
- After applying, `pending_nba` is cleared
- `add_pending_nba()` queues assignments for later application

### 2. NBA Assignment Handling (helpers/slang_helpers.py)
**Lines 778-833: NonblockingAssignmentExpression Processing**

```python
elif kind == ps.SyntaxKind.NonblockingAssignmentExpression:
    # Get LHS variable name (handle array element selects)
    lhs_var = None
    lhs = expr.left
    # ... (complex LHS parsing for array indices, etc.)
    
    if lhs_var is not None:
        # Convert RHS to Z3 expression and use pending NBA queue
        try:
            rhs_z3 = self.expr_to_z3(m, s, expr.right)
        except Exception:
            # Fall back to string-based representation
            rhs_str = conjunction_with_pointers(expr.right, s, m)
            rhs_z3 = substitute_symbols(rhs_str, s.store[m.curr_module])
        s.add_pending_nba(m.curr_module, lhs_var, rhs_z3)
```

**Key Points:**
- NBA expressions are identified by `ps.SyntaxKind.NonblockingAssignmentExpression`
- RHS is converted to Z3 expression
- Assignment is queued via `add_pending_nba()`, NOT immediately applied to store
- Blocking assignments (line 768-776) directly update `s.store[m.curr_module][lhs_var]`

### 3. Cycle Execution Flow

#### BlindSearchStrategy (engine/strategies.py, lines 71-226)
**Lines 158-188: Cycle Loop**

```python
manager.cycle = 0
for complete_single_cycle_path in curr_path[module_name]:
    if manager.cycle > 0:
        state.apply_pending_nba()  # Apply NBA at START of cycle > 0
    
    for cfg_idx, cfg_path in enumerate(complete_single_cycle_path):
        # Skip initial blocks after cycle 0
        if manager.cycle > 0 and getattr(cfgs_by_module[module_name][cfg_idx], 'is_initial', False):
            continue
        
        # Execute CFG path
        for stmt in basic_block:
            visitor.visit_stmt(manager, state, stmt, modules_dict, direction)
    
    manager.cycle += 1
```

**Timing:**
- Cycle 0: No NBA application (initial state)
- Cycle 1+: `apply_pending_nba()` called BEFORE executing any statements
- Statements execute and may queue new NBAs
- Cycle increments at END of loop

#### MilestoneDirectedStrategy (engine/strategies.py, lines 308-750)
**Lines 625-631: Cycle Execution**

```python
cycle = item.cycle

# Step 1: Apply NBA and refresh inputs (if cycle > 0)
if cycle > 0:
    item.state.apply_pending_nba()
    self._refresh_primary_inputs(item.state, cycle)
    self._evaluate_comb_fixedpoint(visitor, manager, item.state)
```

**Timing:**
- Same pattern: NBA applied at START of cycle > 0
- After NBA application, primary inputs are refreshed with fresh symbols
- Combinational logic is re-evaluated to fixed-point

**Lines 735-745: Next Cycle Enqueuing**

```python
next_cycle = cycle + 1
if next_cycle < self.max_cycles:
    new_item = WorkItem(
        score=new_score,
        cycle=next_cycle,
        milestones_completed=current_progress,
        state=state,  # State passed directly (with pending_nba intact)
        execution_context={'remaining_cfgs': None}
    )
    heapq.heappush(worklist, new_item)
```

**Key Point:**
- State is passed directly to next cycle (NOT cloned)
- `pending_nba` from current cycle is preserved for next cycle
- When next cycle pops from worklist, `apply_pending_nba()` is called

### 4. State Cloning (engine/strategies.py, lines 478-497)

```python
def _clone_state(self, state: SymbolicState) -> SymbolicState:
    """Create a deep copy of the symbolic state."""
    new_state = SymbolicState()
    new_state.store = deepcopy(state.store)
    new_state.pending_nba = deepcopy(state.pending_nba)  # NBA also cloned
    
    # Copy Z3 solver assertions
    new_state.pc = Solver()
    for assertion in state.pc.assertions():
        new_state.pc.add(assertion)
    
    new_state.pc_constraint_set = set(state.pc_constraint_set)
    return new_state
```

**Key Point:**
- When state is cloned (for branch exploration), `pending_nba` is also deep-copied
- Each branch gets its own copy of pending assignments

## Execution Timeline Example

### Cycle 0 (Initial)
1. State initialized with `pending_nba = {}`
2. Statements execute:
   - Blocking assignments: `a <= 5` → `store['mod']['a'] = 5`
   - Non-blocking assignments: `b <= 10` → `pending_nba['mod']['b'] = 10`
3. End of cycle 0: `pending_nba = {'mod': {'b': 10}}`

### Cycle 1 (Start)
1. `apply_pending_nba()` called:
   - `store['mod']['b'] = 10` (from pending)
   - `pending_nba = {}` (cleared)
2. Statements execute:
   - Read `b` → gets value 10 (from previous cycle's NBA)
   - New NBA: `c <= 20` → `pending_nba['mod']['c'] = 20`
3. End of cycle 1: `pending_nba = {'mod': {'c': 20}}`

### Cycle 2 (Start)
1. `apply_pending_nba()` called:
   - `store['mod']['c'] = 20` (from pending)
   - `pending_nba = {}` (cleared)
2. Statements execute...

## Critical Timing Points

### When NBA is Applied
- **Location:** Start of each cycle > 0
- **Function:** `SymbolicState.apply_pending_nba()`
- **Strategies:** Both BlindSearchStrategy and MilestoneDirectedStrategy

### When NBA is Queued
- **Location:** During statement execution in `visit_expr()`
- **Function:** `SymbolicState.add_pending_nba()`
- **Trigger:** NonblockingAssignmentExpression encountered

### State Transitions
1. **Cycle N execution:** NBAs queued in `pending_nba`
2. **Cycle N → N+1 transition:** State passed to next WorkItem
3. **Cycle N+1 start:** `apply_pending_nba()` moves pending to store

## Potential Timing Issues

### Issue 1: NBA Application Timing
**Location:** strategies.py, line 161 (BlindSearchStrategy) and line 629 (MilestoneDirectedStrategy)

```python
if manager.cycle > 0:
    state.apply_pending_nba()
```

**Concern:** NBA is applied BEFORE any statements execute in the cycle. This means:
- Values written via NBA in cycle N are visible in cycle N+1
- This is correct Verilog semantics (NBA updates take effect at end of cycle)

### Issue 2: State Passing Between Cycles
**Location:** strategies.py, line 742 (MilestoneDirectedStrategy)

```python
state=state,  # Direct reference, not cloned
```

**Concern:** State is passed by reference to next cycle. If state is modified after enqueuing, it affects the next cycle. However, this appears intentional since:
- The state is modified during execution
- Pending NBAs are preserved for next cycle
- This is the expected behavior

### Issue 3: Initial Block Skipping
**Location:** strategies.py, lines 168 and 641

```python
if manager.cycle > 0 and getattr(cfgs_by_module[module_name][cfg_idx], 'is_initial', False):
    continue
```

**Concern:** Initial blocks are skipped after cycle 0. This is correct, but ensures:
- Initial blocks only execute once at cycle 0
- Any NBAs from initial blocks are applied starting at cycle 1

### Issue 4: Primary Input Refresh
**Location:** strategies.py, line 630 (MilestoneDirectedStrategy only)

```python
if cycle > 0:
    item.state.apply_pending_nba()
    self._refresh_primary_inputs(item.state, cycle)  # Fresh symbols per cycle
    self._evaluate_comb_fixedpoint(visitor, manager, item.state)
```

**Concern:** Primary inputs get fresh symbols each cycle (e.g., `rst_n_c0`, `rst_n_c1`). This allows:
- Different input values per cycle
- Solver to explore different reset sequences
- But BlindSearchStrategy doesn't do this refresh!

## Key Differences Between Strategies

### BlindSearchStrategy
- Applies NBA at cycle start
- Does NOT refresh primary inputs
- Does NOT re-evaluate combinational logic
- Simpler but may miss some behaviors

### MilestoneDirectedStrategy
- Applies NBA at cycle start
- Refreshes primary inputs with fresh symbols
- Re-evaluates combinational logic to fixed-point
- More sophisticated state management

## Summary

**NBA Timing is Correct:**
1. NBAs are queued during execution (not immediately applied)
2. Applied at START of next cycle (before any statements)
3. This matches Verilog semantics where NBA updates take effect at end of cycle

**Potential Bug Areas:**
1. BlindSearchStrategy doesn't refresh primary inputs between cycles
2. State passing by reference could cause issues if not carefully managed
3. Combinational logic re-evaluation only in MilestoneDirectedStrategy

**Critical Code Paths:**
- `SymbolicState.add_pending_nba()` - queues NBA
- `SymbolicState.apply_pending_nba()` - applies NBA at cycle start
- `BlindSearchStrategy.run()` line 161 - cycle loop with NBA application
- `MilestoneDirectedStrategy._execute_cycle()` line 629 - cycle execution with NBA

## Deep Dive: NBA Timing Bug Analysis

### Critical Finding: Cycle 0 NBA Application

**Location:** `engine/symbolic_state.py` line 20-32

The `apply_pending_nba()` method is called at the START of each cycle > 0:

```python
if manager.cycle > 0:
    state.apply_pending_nba()
```

**This means:**
- Cycle 0: NBAs are queued but NOT applied
- Cycle 1: NBAs from cycle 0 are applied BEFORE cycle 1 statements execute
- Cycle 2: NBAs from cycle 1 are applied BEFORE cycle 2 statements execute

**Verilog Semantics Check:**
In Verilog, non-blocking assignments follow this timing:
```verilog
always @(posedge clk) begin
    a <= b;  // Scheduled for end of cycle
end
```

At the END of the cycle, `a` gets the value of `b`. At the START of the NEXT cycle, `a` has the new value.

**Current Implementation:** ✓ CORRECT
- NBA queued during cycle N execution
- Applied at START of cycle N+1
- Matches Verilog semantics

### Critical Finding: Cycle 0 Initialization

**Location:** `engine/strategies.py` lines 449-476 (MilestoneDirectedStrategy._initialize_state)

```python
for module_name in manager.names_list:
    manager.curr_module = module_name
    visitor.symbolic_store.clear()
    visitor.visited.clear()
    visitor.dfs(modules_dict[module_name])
    for var_name, sym in visitor.symbolic_store.items():
        if var_name not in state.store[module_name]:
            # Initialize everything to 0 (Verilog default for regs).
            state.store[module_name][var_name] = BitVecVal(0, 32)
```

**Issue:** All registers initialized to 0 at cycle 0. But what about:
1. Initial blocks that execute at cycle 0?
2. NBAs from initial blocks?

**Trace:**
1. State initialized with all regs = 0
2. Cycle 0 executes (including initial blocks)
3. Initial blocks may queue NBAs
4. Cycle 1 starts: `apply_pending_nba()` applies those NBAs
5. Cycle 1 statements execute with updated values

**This is CORRECT** - initial blocks execute at cycle 0, their NBAs apply at cycle 1.

### Critical Finding: State Passing Between Cycles

**Location:** `engine/strategies.py` lines 735-745 (MilestoneDirectedStrategy._execute_cycle)

```python
next_cycle = cycle + 1
if next_cycle < self.max_cycles:
    new_item = WorkItem(
        score=new_score,
        cycle=next_cycle,
        milestones_completed=current_progress,
        state=state,  # <-- DIRECT REFERENCE, NOT CLONED
        execution_context={'remaining_cfgs': None}
    )
    heapq.heappush(worklist, new_item)
```

**Potential Issue:** State is passed by reference, not cloned. This means:
- If state is modified after enqueuing, it affects the next cycle
- But the state IS modified during execution (NBAs are queued)
- This is actually CORRECT because we want pending NBAs to carry forward

**However, there's a subtle issue:**

When multiple paths branch at cycle N, they all get cloned states:
```python
alt_item = WorkItem(
    ...
    state=self._clone_state(pre_branch_state),  # <-- CLONED
    ...
)
```

But when transitioning to the next cycle, the state is NOT cloned:
```python
state=state,  # <-- NOT CLONED
```

**This means:**
- Branch 1 at cycle N: state1 with pending_nba1
- Branch 2 at cycle N: state2 with pending_nba2 (cloned from state1)
- Both enqueue to cycle N+1 with their respective states
- At cycle N+1, each branch gets its own pending_nba

**This is CORRECT** - each branch path maintains its own state.

### Critical Finding: BlindSearchStrategy vs MilestoneDirectedStrategy

**BlindSearchStrategy (lines 71-226):**
```python
manager.cycle = 0
for complete_single_cycle_path in curr_path[module_name]:
    if manager.cycle > 0:
        state.apply_pending_nba()
    
    # Execute CFG paths
    
    manager.cycle += 1
```

**Issues:**
1. Does NOT refresh primary inputs between cycles
2. Does NOT re-evaluate combinational logic
3. Primary inputs keep their initial symbolic values across all cycles

**Example Problem:**
```verilog
always @(posedge clk) begin
    if (rst_n == 1'b0) begin
        counter <= 0;
    end else begin
        counter <= counter + 1;
    end
end
```

In BlindSearchStrategy:
- Cycle 0: `rst_n` = fresh symbol (e.g., `rst_n_0`)
- Cycle 1: `rst_n` = SAME symbol `rst_n_0` (not refreshed!)
- Cycle 2: `rst_n` = SAME symbol `rst_n_0`

This means the solver sees `rst_n` as constant across all cycles, which is WRONG.

**MilestoneDirectedStrategy (lines 625-631):**
```python
if cycle > 0:
    item.state.apply_pending_nba()
    self._refresh_primary_inputs(item.state, cycle)  # Fresh symbols!
    self._evaluate_comb_fixedpoint(visitor, manager, item.state)
```

**Correct behavior:**
- Cycle 0: `rst_n` = `rst_n_c0`
- Cycle 1: `rst_n` = `rst_n_c1` (fresh symbol)
- Cycle 2: `rst_n` = `rst_n_c2` (fresh symbol)

This allows the solver to explore different reset sequences.

### CRITICAL BUG FOUND: BlindSearchStrategy Primary Input Handling

**File:** `engine/strategies.py` lines 71-226

**Problem:** BlindSearchStrategy does NOT refresh primary inputs between cycles.

**Impact:**
- Primary inputs are treated as constants across all cycles
- Reset signals cannot change between cycles
- Enable signals cannot change between cycles
- Any design that relies on changing inputs will be incorrectly analyzed

**Example Failure Case:**
```verilog
always @(posedge clk) begin
    if (rst_n == 1'b0) begin
        state <= IDLE;
    end else if (enable == 1'b1) begin
        state <= ACTIVE;
    end
end

always @(posedge clk) begin
    if (state == ACTIVE) begin
        counter <= counter + 1;
    end
end

assert property (counter < 10);
```

**What should happen:**
- Cycle 0: `rst_n=0, enable=0` → state=IDLE, counter=0
- Cycle 1: `rst_n=1, enable=0` → state=IDLE, counter=0
- Cycle 2: `rst_n=1, enable=1` → state=ACTIVE, counter=1
- Cycle 3: `rst_n=1, enable=1` → state=ACTIVE, counter=2
- ...
- Cycle 11: counter=10 → ASSERTION FAILS

**What BlindSearchStrategy does:**
- Cycle 0: `rst_n=X, enable=Y` (fresh symbols)
- Cycle 1: `rst_n=X, enable=Y` (SAME symbols!)
- Cycle 2: `rst_n=X, enable=Y` (SAME symbols!)
- ...
- The solver sees `rst_n` and `enable` as constants
- Cannot explore the scenario where reset is released

### Secondary Issue: Combinational Logic Re-evaluation

**Location:** `engine/strategies.py` line 631 (MilestoneDirectedStrategy only)

```python
self._evaluate_comb_fixedpoint(visitor, manager, item.state)
```

**BlindSearchStrategy:** Does NOT re-evaluate combinational logic between cycles

**Issue:** If combinational logic depends on registers that were updated via NBA:
```verilog
always @(*) begin
    output = register + 1;
end

always @(posedge clk) begin
    register <= input;
end
```

**Cycle 0:**
- `register` = 0 (initial)
- `output` = 1 (combinational)
- `register` <= `input` (NBA queued)

**Cycle 1 (BlindSearchStrategy):**
- `apply_pending_nba()` → `register` = `input`
- Statements execute
- But `output` is NOT re-evaluated!
- `output` still = 1 (stale value)

**Cycle 1 (MilestoneDirectedStrategy):**
- `apply_pending_nba()` → `register` = `input`
- `_refresh_primary_inputs()` → fresh input symbols
- `_evaluate_comb_fixedpoint()` → `output` = `input` + 1 (correct!)
- Statements execute

### Tertiary Issue: State Store Clearing

**Location:** `engine/strategies.py` lines 221-222 (BlindSearchStrategy)

```python
for name in manager.names_list:
    state.store[name] = {}
```

**Issue:** After each path completes, the store is cleared. But what about `pending_nba`?

**Check:** Looking at the code, `pending_nba` is NOT explicitly cleared. This means:
- Path 1 completes with `pending_nba = {'mod': {'a': 5}}`
- Store is cleared: `state.store['mod'] = {}`
- But `pending_nba` is NOT cleared!
- Path 2 starts with stale `pending_nba`

**This is a BUG!** The `pending_nba` should also be cleared.

**Correct code should be:**
```python
for name in manager.names_list:
    state.store[name] = {}
state.pending_nba = {}  # <-- MISSING!
```

### Quaternary Issue: State Initialization Between Paths

**Location:** `engine/strategies.py` lines 127-141 (BlindSearchStrategy)

```python
manager.prev_store = state.store
# Use the first module for init_state
first_module = modules[0] if modules else None
if first_module:
    init_state(state, manager.prev_store, first_module, visitor)

# Initialize inputs with symbols for all submodules
for module_name in manager.names_list:
    manager.curr_module = module_name
    visitor.symbolic_store.clear()
    visitor.visited.clear()
    visitor.dfs(modules_dict[module_name])
    for var_name in visitor.symbolic_store:
        if var_name not in state.store[module_name]:
            state.store[module_name][var_name] = init_symbol()
```

**Issue:** `init_symbol()` is called for each path, but it generates the SAME symbol names!

**Example:**
- Path 1: `rst_n` = `BitVec('rst_n', 32)`
- Path 2: `rst_n` = `BitVec('rst_n', 32)` (SAME NAME!)

This means the Z3 solver sees them as the same variable, not independent symbols.

**This is a BUG!** Each path should get unique symbol names.

**Correct code should be:**
```python
for var_name in visitor.symbolic_store:
    if var_name not in state.store[module_name]:
        # Generate unique symbol per path
        unique_name = f"{var_name}_path{manager.path_count}"
        state.store[module_name][var_name] = BitVec(unique_name, 32)
```

## Summary of Bugs Found

### Bug 1: BlindSearchStrategy - No Primary Input Refresh (CRITICAL)
- **File:** `engine/strategies.py` lines 71-226
- **Issue:** Primary inputs not refreshed between cycles
- **Impact:** Cannot explore different input sequences
- **Severity:** CRITICAL - breaks multi-cycle analysis

### Bug 2: BlindSearchStrategy - Stale pending_nba Between Paths (HIGH)
- **File:** `engine/strategies.py` lines 221-222
- **Issue:** `pending_nba` not cleared between paths
- **Impact:** NBAs from previous path leak into next path
- **Severity:** HIGH - causes incorrect state propagation

### Bug 3: BlindSearchStrategy - No Combinational Re-evaluation (MEDIUM)
- **File:** `engine/strategies.py` lines 71-226
- **Issue:** Combinational logic not re-evaluated after NBA application
- **Impact:** Stale combinational outputs
- **Severity:** MEDIUM - affects designs with comb logic depending on regs

### Bug 4: BlindSearchStrategy - Duplicate Symbol Names (HIGH)
- **File:** `engine/strategies.py` lines 140-141
- **Issue:** Each path gets same symbol names
- **Impact:** Z3 solver treats them as same variable
- **Severity:** HIGH - breaks path independence

## Recommended Fixes

### Fix 1: Add Primary Input Refresh to BlindSearchStrategy
```python
# After apply_pending_nba()
if manager.cycle > 0:
    state.apply_pending_nba()
    # Refresh primary inputs with fresh symbols
    for module_name in manager.names_list:
        for var_name in state.store[module_name]:
            if is_primary_input(var_name):
                state.store[module_name][var_name] = BitVec(f"{var_name}_c{manager.cycle}", 32)
```

### Fix 2: Clear pending_nba Between Paths
```python
for name in manager.names_list:
    state.store[name] = {}
state.pending_nba = {}  # ADD THIS LINE
```

### Fix 3: Add Combinational Re-evaluation
```python
if manager.cycle > 0:
    state.apply_pending_nba()
    # Re-evaluate combinational logic
    for module_name in manager.names_list:
        manager.curr_module = module_name
        for node in comb_by_module.get(module_name, []):
            visitor.evaluate_comb(manager, state, node)
```

### Fix 4: Use Unique Symbol Names Per Path
```python
for var_name in visitor.symbolic_store:
    if var_name not in state.store[module_name]:
        unique_name = f"{var_name}_path{manager.path_count}"
        state.store[module_name][var_name] = BitVec(unique_name, 32)
```

