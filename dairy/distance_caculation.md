# Project Context: MileSE (Hardware Symbolic Execution Engine)

This project is a milestone-driven directed symbolic execution engine for RTL verification, using Python, `pyslang`, and `Z3`. The engine uses an A* priority queue to explore the state space. 

Currently, the A* scoring function is primarily macro-heuristic: `Score = cycle + (Remaining_Milestones * 1000)`.
**The Problem**: If the distance between two milestones is large (e.g., 50 clock cycles), the `Remaining_Milestones` does not change. The A* score ties, and the engine degenerates into Breadth-First Search (BFS), leading to a $O(2^N)$ state explosion (Temporal Path Explosion).

## Objective

Your task is to implement the **Microscopic Data-Flow Distance ($D$)** calculation and integrate it into the A* `Score` computation. This will provide a microscopic gradient to break ties during long milestone gaps.

The new scoring formula should be:
`Score = cycle + (Remaining_Milestones * 1000) + Data_Flow_Distance(state, next_milestone)`

---

## Actionable Tasks

### Task 1: Create a Distance Calculation Function
Create a helper function (e.g., `compute_dataflow_distance(state, next_milestone_condition)`) that calculates the numerical distance between the current state's variables and the target milestone's conditions.

**Implementation Logic for Z3 ASTs:**
1. **Target Extraction**: Extract the LHS (variable) and RHS (target constant) from the Z3 condition of the `next_milestone`. (Assume basic equality `LHS == RHS` or inequality for now).
2. **Current State Evaluation**: Retrieve the Z3 expression for the LHS variable in the current `state`.
3. **Concretization (Crucial)**: Since the current variable might be a symbolic expression (containing unconstrained inputs):
   - First, try `z3.simplify(current_expr)`. If it reduces to a concrete Z3 constant (e.g., `z3.BitVecNumRef`), extract its integer value using `.as_long()`.
   - **Fallback (Model Probing)**: If it is still symbolic, temporarily call `state.pc.check()` and use `state.pc.model()` to evaluate the expression to a concrete integer: `model.eval(current_expr, model_completion=True).as_long()`.
4. **Distance Math**:
   - If it's a data-flow variable (e.g., counter): `D = abs(current_val - target_val)`.
   - If it's a boolean/control signal (1 bit): `D = 10` if `current_val != target_val` else `0` (apply a small penalty for wrong control flow).

### Task 2: Integrate into A* Scoring
Locate the priority queue scoring logic (likely in `strategies.py` or the `WorkItem` creation).
1. Identify the *next* milestone the state is currently trying to reach (`milestones[current_progress]`).
2. Call your `compute_dataflow_distance` function to get $D$.
3. Add $D$ to the final score before pushing the state into the `heapq`.

---

## Coding Constraints & Guidelines

* **Z3 Safety**: When using `solver.check()` or `solver.model()` to probe values, ensure you do not permanently alter the path constraints. 
* **Performance**: Model probing (`solver.check()`) can be expensive. Try `z3.simplify()` first. Only invoke the solver if `simplify` fails to yield a concrete number.
* **Error Handling**: If the AST cannot be parsed into LHS/RHS, or if the distance cannot be computed, safely return a default distance of `0` so the engine falls back to standard A* rather than crashing.
* **Logging**: Add a debug-level log (e.g., `[Data-Flow Fitness] Distance to M[i] is D`) so we can observe the micro-gradient guiding the search.

Please analyze the current scoring and state evaluation code, and implement this data-flow distance heuristic.