# Project Context: MileSE (Hardware Symbolic Execution Engine)

This project is a directed symbolic execution engine for RTL (Register Transfer Level) hardware verification, written in Python using `pyslang` and `Z3`. 
The engine uses an A* priority queue to navigate the temporal state space, guided by LLM-generated milestones.

Currently, the engine strictly requires states to match milestones serially (e.g., M0 -> M1 -> M2 -> M3). However, due to "LLM Hallucinations" (LLMs generating physically impossible states) and "Granularity Misalignment" (LLM semantic steps not matching hardware clock cycles), strict serial matching often causes the engine to get stuck, leading to state explosion or timeouts.

## Objective

Your task is to implement two architectural fault-tolerance mechanisms in the engine's core execution loop (likely located in `strategies.py`, specifically within the `_execute_cycle` method or equivalent milestone evaluation logic). These mechanisms will decouple the strict temporal dependency from the LLM's heuristic hints.

---

## Task 1: Implement "Eager Target Evaluation" (Global Assertion Override)

**Theory**: The LLM might generate overly verbose intermediate milestones (e.g., M1 to M10), but the actual hardware might trigger the final Bug/Assertion violation at cycle 3. We must not wait for all milestones to complete.

**Implementation Steps**:
1. At the end of every clock cycle execution (after states are cloned and updated, but before or right after they are pushed back to the priority queue), inject a global check.
2. For every active state in the current cycle, extract the **Final Target Condition** (i.e., the last milestone, which represents the assertion violation).
3. Evaluate this final target condition using the Z3 solver (`state.pc.push()`, add condition, `check()`, `state.pc.pop()`).
4. **Action**: If Z3 returns `sat`, immediately halt the search, report `VIOLATION` (Assertion Violation Found), and dump the counterexample. Completely bypass any remaining `Remaining_Milestones`.
5. **Constraint**: This check should only occur if the system has at least passed the initial reset phase (e.g., `milestones_completed > 0`).

---

## Task 2: Implement "Sliding Window Lookahead"

**Theory**: If the hardware skips a step (e.g., $0 \rightarrow 2 \rightarrow 4$) but the LLM milestone expects `out == 1`, the engine will deadlock. We must allow the engine to "skip" hallucinated or skipped milestones locally.

**Implementation Steps**:
1. Locate the `while` loop or logic where the engine checks if a `state` satisfies the current milestone `M[i]`.
2. Introduce a configuration variable `SLIDING_WINDOW_SIZE = 1` (allowing the engine to look ahead 1 extra milestone).
3. Modify the matching logic: Instead of only checking `current_progress`, attempt to match milestones in the range `[current_progress, min(current_progress + SLIDING_WINDOW_SIZE, total_milestones - 1)]`.
4. **Order of Evaluation**: It is recommended to evaluate from the furthest allowed lookahead back to the current progress (greedy advancement).
5. **Action**: If a state satisfies `M[i+1]` but failed `M[i]`, update the state's `milestones_completed` directly to `i+2` (since it completed `i+1`).
6. **Constraint**: **NEVER** allow skipping `Milestone 0` (System Reset). The sliding window should only be active when `current_progress > 0`. Add a debug print (e.g., `[Sliding Window] Skipped hallucinated milestone...`) when a jump occurs.

---

## Coding Constraints & Guidelines

* **Preserve A* Logic**: Do not modify the existing `Score` computation or priority queue structure (`heapq`). These mechanisms only modify *when* a state reaches the target or *how* its `milestones_completed` counter is updated.
* **Z3 State Safety**: Always use `state.pc.push()` and `state.pc.pop()` when doing speculative evaluations (like Eager Target Evaluation or Sliding Window checks) to avoid permanently polluting the path constraints with unmet conditions.
* **Logging**: Add clear `[Preemption]` and `[Sliding Window]` tags in the `logging` or `print` statements so we can trace when the fault-tolerance mechanisms are triggered in the logs.

## Verification
this two task should be finished within 100 paths.
1. python3 -m main 7 designs/test-designs/test_2.v --sv --milestone-file milestones/test_2.json --coi --strategy directed
2. python3 -m main 6 designs/test-designs/sub-test/sub.F --sv --milestone-file milestones/sub-test.json --coi --strategy directed


Please analyze the current `strategies.py` and propose the code modifications.