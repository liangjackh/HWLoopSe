好的，这是为你准备的 **架构重构指导文档 (`claude_refactor.md`)**。

这份文档不仅告诉 Claude “做什么”，还详细规定了“怎么做”，特别是如何把 `main.py` 里的胶水代码安全地移动到 `ExecutionEngine` 内部。

请将以下内容保存为 `claude_refactor.md` 发送给 Claude。

---

# Refactoring Specification: Modular Architecture for Symbolic Execution Engine

## 1. Objective

**Goal:** Decouple `main.py` from the internal assembly logic of the execution engine.
**Current Problem:** `main.py` currently handles too many low-level tasks: `pyslang` compilation, visitor initialization, lambda binding for Z3, and strategy selection.
**Target Architecture:**

* **`main.py`**: Lightweight entry point (Parse args -> Init Engine -> Run).
* **`ExecutionEngine`**: The "Context" that manages the toolchain (Compilation, Visitor Setup, State Init).
* **`StrategyFactory`**: A new helper to centralize strategy creation logic.

## 2. Architecture Changes

### A. Create `engine/strategy_factory.py` (New File)

Encapsulate the `if/else` logic for choosing strategies.

**Requirements:**

* Define a class `StrategyFactory`.
* Static method `create(strategy_name: str, options: object) -> ExplorationStrategy`.
* **Logic:**
* If `name == "directed"`: Instantiate `MilestoneDirectedStrategy`. (Initialize `MilestoneManager` with empty list or auto-plan logic if needed).
* If `name == "lookahead"`: Instantiate `LookaheadStrategy` (for Paper A).
* Default: Instantiate `BlindSearchStrategy`.



### B. Refactor `engine/execution_engine.py`

Transform this class from a "Passive Runner" to an "Active Orchestrator".

**1. Add method `_compile_design(self, file_path: str)`:**

* Move the `pyslang` compilation logic here (currently in `main.py`).
* **Logic:**
* `driver = ps.Driver()`
* `driver.addStandardArgs()`
* `driver.addSource(file_path)`
* `compilation = driver.createCompilation()`
* Check diagnostics (errors). If failed, `sys.exit(1)`.
* Extract `modules` (top-level instances).
* **Return:** `(compilation, modules, driver)`



**2. Add method `_setup_visitors(self, num_cycles)`:**

* Move the visitor initialization logic here.
* **Logic:**
* Instantiate `SymbolicDFS(num_cycles)`.
* **Crucial:** Bind the Z3 parser helper: `visitor.expr_to_z3 = lambda ...` (Copy this logic from `main.py`).
* Instantiate `SlangSymbolVisitor`.
* **Return:** `(visitor, symbol_visitor)`



**3. Update `execute_sv` -> Rename to `run`:**

* **Signature:** `def run(self, file_path: str, strategy: ExplorationStrategy, num_cycles: int)`
* **Workflow:**
1. `self._compile_design(file_path)`
2. `self._setup_visitors(num_cycles)`
3. `initial_state = self.setup_initial_state(modules)`
4. `strategy.run(self, visitor, modules, ..., initial_state)`



### C. Clean up `main.py`

Drastically reduce code size.

**New Flow:**

1. Parse arguments (`optparse`).
2. `engine = ExecutionEngine(debug=options.debug)`
3. `strategy = StrategyFactory.create(options.strategy, options)`
4. `engine.run(args[0], strategy, int(options.cycles))`

## 3. Detailed Implementation Steps for Claude

### Step 1: Extract the Factory

Create `engine/strategy_factory.py`. Ensure it imports the strategies from `engine.strategies`.

### Step 2: Empower the Engine

Modify `engine/execution_engine.py`.

* **Import dependencies:** You will need to move imports like `pyslang`, `SymbolicDFS`, `SlangSymbolVisitor`, `parse_expr_to_Z3` from `main.py` to `execution_engine.py`.
* **Encapsulation:** Ensure `_compile_design` handles the error printing (compilation diagnostics) that was previously in main.

### Step 3: Minimalist Main

Rewrite `main.py`. It should strictly be for CLI interaction.

## 4. Constraint Checklist

* **Do NOT break pyslang:** The way `driver` and `compilation` are created is correct in the old `main.py`, preserve that logic exactly, just move it.
* **Lambda Scope:** When moving `visitor.expr_to_z3 = lambda ...`, make sure `parse_expr_to_Z3` is imported and available in `execution_engine.py`.
* **Strategy Interface:** Ensure the `strategy.run()` call in `ExecutionEngine` matches the signature defined in your `strategies.py` ABC.

---

### 5. Development Prompt (Copy this to Claude)

> "Refactor the project architecture to separate concerns between `main.py` and `ExecutionEngine`.
> 1. **Create `engine/strategy_factory.py**`: Implement a factory pattern to select and instantiate strategies (`Blind`, `Directed`, `Lookahead`) based on input strings.
> 2. **Refactor `ExecutionEngine**`: Move the low-level setup logic (PySlang compilation, Visitor instantiation, Z3 lambda binding) from `main.py` into private methods within `ExecutionEngine` (e.g., `_compile_design`, `_setup_visitors`). Expose a clean `run(file_path, strategy)` method.
> 3. **Simplify `main.py**`: It should only parse arguments, create the Engine and Factory, and call `engine.run()`.
> 
> 
> Follow the detailed instructions in the 'Refactoring Specification' above. Ensure all `pyslang` dependencies are correctly moved."