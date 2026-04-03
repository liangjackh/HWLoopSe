# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

LoopSE is an LLM-guided symbolic execution engine for SystemVerilog designs. It uses PySlang for parsing SystemVerilog AST, an LLM (OpenAI/Anthropic/DeepSeek) for macroscopic milestone planning, and Z3 for constraint solving to verify paths dynamically.

## Core Architectural Paradigm: "LLM Proposes, BMC Disposes"

We are currently refactoring the engine to solve the **LLM Hallucination & Temporal Path Explosion** problem. The target architecture works as follows:

1. **LLM Proposes (Macro-Navigation)**: The LLM analyzes the RTL and outputs a sequence of `Milestones`. For each milestone, it MUST provide:
   - `condition`: The boolean RTL constraint (e.g., `fifo_cnt == 4`).
   - `expected_cycles` ($k$): The LLM's estimated clock cycles required to reach this state from the previous one.
2. **BMC Disposes (Micro-Verification)**: The Z3/Symbolic execution engine treats the LLM's milestone as a target. It sets a maximum unroll bound $m$ (where $m = k + \text{margin}$, e.g., $m = k + 5$).
   - If **SAT** within $m$ cycles: The milestone is reached. The engine locks the path and proceeds to the next milestone.
   - If **Timeout / UNSAT** within $m$ cycles: The LLM hallucinated, or the granularity is too large. The engine rejects the milestone and triggers a **Dynamic Granularity Fallback** (asking the LLM to refine the path).

## Implementation Roadmap (Current Focus)

When I ask you to implement the "LLM Dynamic Depth" feature, please follow these steps modifying the corresponding files:

### 1. Update LLM Planner (`frontend/llm_planner.py`)
- Modify `SYSTEM_PROMPT`: Update the JSON format requirements to include an `"expected_cycles": <int>` field for each milestone.
- Add explicit instructions prompting the LLM to carefully calculate the sequential cycles based on pipeline stages, counters, or state machines.

### 2. Update Milestone Data Structure (`engine/milestone.py`)
- Update the `Milestone` class `__init__` to accept and store `expected_cycles` (defaulting to a safe fallback if missing).
- Ensure `MilestoneManager` correctly loads this new field from `milestones.json`.

### 3. Update Directed Strategy (`engine/strategies.py` / `engine/execution_engine.py`)
- When attempting to reach `Milestone[i]`, read `Milestone[i].expected_cycles` ($k$).
- Calculate the local verification bound $m = k + \text{margin}$.
- Implement the early-exit / UNSAT detection: if the engine's current exploration depth from the last milestone exceeds $m$, abort this path branch immediately to prevent state explosion.

## PySlang Implementation Details
- The code uses `pyslang` for AST traversal (`engine/execution_manager.py`, `helpers/slang_helpers.py`).
- Expressions are converted to Z3 using `parse_expr_to_Z3` located in `helpers/rvalue_to_z3.py`.
- Always verify both `ifTrue`/`ifFalse` and `statements`/`elseClause` when traversing conditionals due to PySlang version differences (supports both v7 and v9).

## Claude Code Guidelines

1. **Project Context**: This is an advanced hardware verification project. Precision in SystemVerilog semantics and Z3 SMT logic is strictly required.
2. **Logging Protocol**: 
   - Whenever I type "Log it" or "记录", you must:
   - Summarize the current task/bug fix.
   - Append it to `CHANGELOG.md` with a timestamp.
   - Use the format: `[Date] [Category] Summary`.
   - You MUST also explicitly summarize how you utilized or modified the `pyslang` library during the task.
