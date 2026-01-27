# Project Specification: SylQ-SV (Query Caching SystemVerilog Execution)

## 1. Context & Objective
**Target Paper:** "SylQ-SV: Scaling Symbolic Execution of Hardware Designs with Query Caching" (Ryan & Sturton, 2025).
**Core Logic:** Implement a SystemVerilog symbolic execution engine that leverages **SMT Query Caching** to solve the path explosion problem.
**Environment:** Python 3.10+, **pyslang v10.0** (Strict AST Mode), z3-solver, Redis (for caching).

## 2. Architecture Overview
The system consists of three main components:
1.  **Pyslang Adapter:** A robust frontend to parse SystemVerilog using `pyslang` v10.0 AST APIs.
2.  **Query Cache Manager (The "Q" in SylQ-SV):** A module to intercept, normalize, and cache Z3 solver queries to avoid redundant computations across paths.
3.  **Execution Engine:** The symbolic execution loop that uses the cache during path exploration.

## 3. Critical Technical Constraints (Pyslang v10.0)

### A. Strict AST/Syntax Tree Usage
* **NO Symbols:** Do NOT use `compilation.getRoot().topInstances`. This returns Symbol objects which crash the AST-based engine.
* **REQUIREMENT:** Use `compilation.getSyntaxTrees()` and iterate through `tree.root.members` to find `ModuleDeclaration` syntax nodes.

### B. File Loading
* **NO Driver:** Do not use `pyslang.Driver`. Use `ps.SourceManager` -> `ps.SyntaxTree.fromFile` -> `ps.Compilation`.
* **Diagnostics:** Use `ps.DiagnosticEngine` to report syntax errors.

## 4. Implementation Roadmap

### Step 1: Fix `main.py` (Frontend)
**Task:** Ensure the entry point correctly loads modules as Syntax Nodes and initializes the Redis cache.
* **Action:**
    * Rewrite file loading to use `SourceManager` and `SyntaxTree`.
    * Extract `ModuleDeclaration` nodes manually.
    * Initialize `redis.Redis` connection if `--use_cache` is enabled.

### Step 2: Implement Query Caching (`engine/query_cache.py`)
**Task:** Implement the core contribution of the SylQ-SV paper.
* **Concept:** Different execution paths often generate logically identical SMT queries (e.g., checking if `cnt == 0` happens in many states). Caching these results significantly speeds up execution.
* **Action:**
    * Create `class QueryCache`.
    * **Method `normalize(expr_list)`:** (Crucial) Convert Z3 expressions into a canonical string format.
        * *Tip:* Sort constraints to ensure `And(A, B)` hashes the same as `And(B, A)`.
    * **Method `check_cache(constraints)`:**
        * Hash the normalized constraints (SHA-256).
        * Check Redis: If hit -> Return `(SAT/UNSAT)`.
        * If miss -> Return `None`.
    * **Method `add_to_cache(constraints, result)`:** Store the result in Redis.

### Step 3: Integrate Cache into Execution Engine (`engine/execution_engine.py`)
**Task:** Modify the solver interface to use the cache.
* **Action:**
    * Locate `check_pc_SAT(self, s, constraint)`.
    * **Refactor Logic:**
        1.  Get current path constraints + new constraint.
        2.  Call `QueryCache.check_cache()`.
        3.  **Hit:** Use cached result (Skip Z3 call).
        4.  **Miss:** Call `s.check()`.
        5.  **Store:** Save result to `QueryCache`.
    * *Note:* Keep the DFS/Cartesian loop for now, as SylQ-SV focuses on optimizing the *solver time* per step rather than changing the *traversal order* (though Piecewise Composition is a separate topic, Query Caching is our focus here).

### Step 4: Execution Manager Fixes (`engine/execution_manager.py`)
**Task:** Ensure compatibility with Pyslang v10.0 AST nodes.
* **Action:**
    * Verify `count_conditionals` handles `SyntaxNode` types (e.g., `ConditionalStatementSyntax`) correctly.
    * Ensure member access uses `.members` (AST) not `.body` (Symbol).

## 5. Instructions for AI Generation
* **Focus on Caching:** The "Smart" part of this tool is the Cache, not an LLM. Spend effort on making the `normalize` function robust (so that `a + b > 0` and `b + a > 0` are treated as the same cache key).
* **Pyslang Safety:** Always wrap `pyslang` API calls in `try-except` blocks or check `hasattr` because v10.0 API structure is strict.
* **Redis Fallback:** If Redis is unavailable, the code should fallback to a local Python dictionary cache or no cache (print a warning).