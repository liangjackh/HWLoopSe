# Project Specification: Modular Symbolic Execution Engine (Strategy Pattern)

## 1. Context & Objective
**Current State:** The `ExecutionEngine` currently hardcodes a specific search logic (Cartesian product) mixed with execution primitives.
**Goal:** Refactor the codebase to support **pluggable exploration strategies**. We need to switch dynamically between:
1.  **Blind Search:** The existing logic (for regression testing/small designs).
2.  **Directed Search:** The new LLM-guided, Milestone-based logic (for deep verification).

## 2. Architecture: The Strategy Pattern

We will decouple the "Search Algorithm" from the "Execution Mechanism".

### A. New Module: `engine/strategies.py`
Define an abstract base class and concrete implementations.

#### 1. `class ExplorationStrategy (ABC)`
* **Abstract Method:** `run(self, engine: ExecutionEngine, manager: ExecutionManager, state: SymbolicState, num_cycles: int)`
* **Role:** Defines the contract for any search algorithm.

#### 2. `class BlindSearchStrategy(ExplorationStrategy)`
* **Logic:** Move the *existing* loops (including `itertools.product`) from `execution_engine.py` into this class.
* **Behavior:** Replicates the current legacy behavior exactly.

#### 3. `class MilestoneDirectedStrategy(ExplorationStrategy)`
* **Initialization:** Accepts a `MilestoneManager` instance.
* **Logic:** Implements the **Priority Queue** loop described in previous specs.
    * Uses `heapq` for the worklist.
    * Scores paths based on depth + milestone completion.
    * Calls `engine.check_pc_SAT` and `milestone_manager.check_milestone`.

### B. Refactored `ExecutionEngine` (`engine/execution_engine.py`)
* **Change:** Remove the giant `while` loops and `product` logic from `execute_sv`.
* **New Logic:**
    * Method `set_strategy(self, strategy: ExplorationStrategy)`.
    * Method `execute_sv(...)` should now essentially prepare the initial state and then call `self.strategy.run(self, ...)` to hand over control.
* **Utility Preservation:** Keep helper methods like `check_pc_SAT`, `check_state`, and Z3 integration helper methods in `ExecutionEngine` so strategies can call them.

### C. `engine/milestone.py` (The Planner)
* (Same as before) Implement `Milestone` and `MilestoneManager`.
* Add logic to parse hierarchical signals (e.g., "test_1.out") into Z3 variables.

## 3. Implementation Roadmap

### Step 1: Infrastructure
1.  Create `engine/milestone.py`.
2.  Create `engine/strategies.py` with the `ExplorationStrategy` interface.

### Step 2: Migration (Blind Strategy)
1.  Extract the current execution loop logic from `ExecutionEngine.execute_sv`.
2.  Wrap it into `BlindSearchStrategy.run`.
3.  Ensure `ExecutionEngine` passes `self` to the strategy so the strategy can call `engine.check_pc_SAT`.

### Step 3: Implementation (Directed Strategy)
1.  Implement `MilestoneDirectedStrategy` in `engine/strategies.py`.
2.  Implement the priority queue loop:
    * `queue = [(score, state)]`
    * `while queue: pop -> process_block -> push children`
    * Check milestones at block boundaries.

### Step 4: Integration
1.  Modify `main.py` to accept a generic argument (e.g., `--strategy=directed` or `--strategy=blind`).
2.  Based on the arg, instantiate the correct strategy class.
3.  Pass the strategy to `engine.set_strategy()`.
4.  For `directed` mode, initialize `MilestoneManager` with the hardcoded waypoints for `test_2.v`.

## 5. Technical Implementation Details (Clarifications)

To ensure robustness, please adhere to these specific implementation decisions:

### 1. Milestone Definitions (for `test_2.v`)
Hardcode these specific milestones in `main.py` when initializing the directed strategy:
* **M0 (Reset)**: `test_1.out == 0`
* **M1 (Step)**: `test_1.out == 2`
* **M2 (Target)**: `test_1.out > 3` (Note: This targets the assertion failure).

### 2. Priority Scoring Formula
Use a **Min-Heap** for the priority queue. The score should be calculated as:
* `Score = (Milestones_Remaining * 1000) + Clock_Cycle`
* *Rationale*: Paths that have passed more milestones (fewer remaining) get a massive priority boost (lower score). Within the same milestone stage, younger paths (lower clock cycle) are explored first to find the shortest path to the next milestone.

### 3. `MilestoneManager.check_milestone`
* **Input**: `(state: SymbolicState, solver: z3.Solver)`
* **Logic**:
    1.  Get the condition for `current_milestone_index`.
    2.  `solver.push()`
    3.  `solver.add(condition)`
    4.  `result = solver.check()`
    5.  `solver.pop()`
    6.  If `result == z3.sat`: increment `current_milestone_index` and return `True`.
    7.  Else: return `False`.
* **Return**: Boolean.

### 4. Hierarchical Signal Parsing
* Input string: `"test_1.out"`
* Logic: Split by `.` -> `["test_1", "out"]`.
* Lookup: `state.store["test_1"]["out"]`.
* *Constraint*: Do not support wildcards yet. Assume exact hierarchical paths.

### 5. State Cloning (Deepcopy vs Z3)
When branching, you need to clone `SymbolicState`:
* Use `copy.deepcopy` for the `state.store` (dictionary of variables).
* **For Z3 Solvers**: `z3.Solver` objects are not deep-copyable.
    * *Action*: Create a new `z3.Solver()` and copy assertions: `new_solver.add(old_solver.assertions())`.

### 6. Termination Condition
The `MilestoneDirectedStrategy` loop stops when:
1.  **Success**: The final milestone is reached (return `SAT` / `Violation Found`).
2.  **Failure**: The priority queue is empty (return `UNSAT`).
3.  **Timeout**: Max clock cycles reached (configured in main).

## 6. Development Prompt for Claude
* "Refactor `execution_engine.py` to use the Strategy Pattern. Move the current logic into `BlindSearchStrategy` in a new file `engine/strategies.py`."
* "Implement `MilestoneDirectedStrategy` using the specific scoring formula and state cloning logic defined in Section 5."
* "Make `ExecutionEngine` a clean context provider that exposes methods like `check_pc_SAT` to the strategies."
* "Update `main.py` to allow switching strategies via a variable or flag, and inject the hardcoded milestones for `test_2.v`."