# Project Specification: LLM Frontend & AutoPlanner for Symbolic Execution

## 1. Context & Objective
**Goal:** Automate the generation of "Milestones" (Waypoints) for the Directed Symbolic Execution engine.
**Current State:** The backend engine requires a list of milestones (e.g., `cnt == 10`, `overflow == 1`) to guide the search. Currently, these are hardcoded.
**Requirement:** Implement a **Frontend Module** that:
1.  Analyzes a verification target (e.g., `test_1.out > 3`).
2.  Extracts *only* the relevant RTL source code (Context Slicing) to save tokens and focus attention.
3.  Queries an LLM to generate logical milestones.
4.  **Validates** the LLM output (Signal Name Check) to prevent hallucinations.
5.  Outputs a list of `Milestone` objects compatible with the backend.

## 2. Architecture Overview

Create a new directory `frontend/` containing two main classes.

### A. `frontend/context_slicer.py` (The Slicer)
**Role:** Locate the specific module instances related to the verification target and extract their source code using `pyslang`.
**Key Logic:**
* Input: `target_string` (e.g., "u_fifo.cnt > 10") and the `pyslang` Compilation object.
* **Step 1:** Parse `target_string` to find instance names (e.g., `u_fifo`).
* **Step 2:** Traverse the AST (using `pyslang`) to find the *Definition* of the module instantiated as `u_fifo`.
* **Step 3:** Use `source_manager.getRawText(node.sourceRange)` to extract the raw Verilog source code of that module.
* **Step 4:** Always include the `top` module source (for glue logic).
* **Output:** A string containing the combined Verilog code of relevant modules.

### B. `frontend/llm_planner.py` (The Agent)
**Role:** Manage the interaction with the LLM (OpenAI/Anthropic compatible API).
**Key Logic:**
* **Prompt Construction:** Combine the sliced code with a System Prompt instructing the LLM to act as a Verification Engineer.
* **Self-Correction Loop:**
    1.  Get JSON response from LLM.
    2.  **Validation:** Extract signal names from the JSON conditions. Check if these signals actually exist in the `ExecutionEngine`'s `SymbolicState` (or `known_signals` list).
    3.  **Retry:** If a signal is missing (Hallucination), feed the error back to the LLM (e.g., *"Error: Signal 'fifo_count' not found. Did you mean 'fifo_cnt'?"*) and ask for a corrected JSON.
    4.  Repeat up to 3 times.

## 3. Implementation Details

### 3.1 `ContextSlicer` Implementation
* **Class:** `ContextSlicer`
* **Method:** `get_context(self, target_expr: str) -> str`
* **Dependencies:** Needs access to `pyslang.Compilation` or the `modules` list from `main.py`.
* **Granularity:** Extract at the **Module** level. If `u_cpu.u_alu.res` is targeted, extract the code for the `ALU` module and the `CPU` module.

### 3.2 `LLMPlanner` Implementation
* **Class:** `LLMPlanner`
* **Method:** `generate_plan(self, rtl_context: str, target: str, known_signals: list) -> List[dict]`
* **Output Format:** A list of dictionaries, e.g., `[{"step": 1, "description": "Reset", "condition": "rst == 1"}]`.
* **Mocking:** Since we don't have a live API key in the env yet, allow a `mock=True` flag that returns the hardcoded milestones for `test_2.v` for testing purposes.

### 3.3 Main Integration (`main.py`)
Update `main.py` to support CLI arguments for the frontend:
* `--target "condition_string"`: The verification goal (e.g., "test_1.out > 3").
* `--llm-api-key "sk-..."`: API key for the LLM.
* `--auto-plan`: Flag to enable this frontend flow.

**Flow in `main.py`:**
```python
if args.auto_plan:
    # 1. Slice Context
    slicer = ContextSlicer(compilation_data)
    context_code = slicer.get_context(args.target)
    
    # 2. Get Valid Signal Names (for validation)
    # You might need to dry-run the engine or use SlangSymbolVisitor to get all signal names first.
    all_signals = engine.get_all_known_signals() 
    
    # 3. Call Agent
    planner = LLMPlanner(api_key=args.llm_api_key)
    milestone_dicts = planner.generate_plan(context_code, args.target, all_signals)
    
    # 4. Convert to Backend Objects
    milestones = [Milestone(d['description'], d['condition']) for d in milestone_dicts]
    
    # 5. Execute
    strategy = MilestoneDirectedStrategy(milestones)
    engine.set_strategy(strategy)
    engine.execute_sv(...)