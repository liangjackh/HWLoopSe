# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

LoopSE is a symbolic execution engine for SystemVerilog designs. It uses PySlang for parsing SystemVerilog AST and Z3 for constraint solving to explore execution paths through hardware designs.

## Running the Tool

Basic usage:
```bash
python3 -m main <num_cycles> <verilog_file>.v [options]
```

Key options:
- `--sv`: Enable SystemVerilog parser (required for SystemVerilog files)
- `--use_cache`: Enable Redis-based query caching for Z3 solver results
- `--explore_time <seconds>`: Set timeout for exploration
- `-B` or `--debug`: Enable debug mode with verbose output

Example:
```bash
python3 -m main 1 designs/example.v --sv --explore_time 3600
```

Scripts in `scripts/` directory provide common execution patterns:
- `explore_nocache.sh`: Run exploration without caching
- `explore_cache.sh`: Run exploration with Redis caching
- `assertion_check.sh`: Check for assertion violations

## Architecture

### Core Components

**ExecutionEngine** (`engine/execution_engine.py`):
- Main orchestrator for symbolic execution
- `execute_sv()`: Entry point for SystemVerilog execution
- Manages multi-cycle and multi-module path exploration
- Handles path condition satisfiability checking with Z3
- Generates counterexamples when assertion violations are found

**CFG** (`engine/cfg.py`):
- Converts PySlang AST into Control Flow Graph structure
- `get_always_sv()`: Extracts always blocks from modules
- `basic_blocks_sv()`: Partitions statements into basic blocks
- `build_cfg()`: Constructs NetworkX digraph and computes all paths
- Uses NetworkX to enumerate all simple paths through the CFG

**ExecutionManager** (`engine/execution_manager.py`):
- Tracks execution state across modules and cycles
- Manages module instances, dependencies, and path tracking
- Handles branch counting and path completion tracking

**SymbolicState** (`engine/symbolic_state.py`):
- Maintains symbolic store (variable → Z3 expression mapping)
- Manages Z3 path condition solver

### Helper Modules

**slang_helpers.py**:
- `SymbolicDFS`: Main visitor for PySlang symbols that updates symbolic state
- `SlangSymbolVisitor`: Post-processor that counts branch points and paths
- `visit_stmt()`: Handles conditional statements, loops, and case statements
- `expr_to_z3`: Delegate method for converting PySlang expressions to Z3 (implemented in `rvalue_to_z3.py`)

**rvalue_to_z3.py**:
- `parse_expr_to_Z3()`: Converts PySlang expressions to Z3 constraints
- Handles binary/unary operations, concatenations, bit selections

**rvalue_parser.py**:
- Tokenizes and parses Verilog expressions
- Provides fallback parsing when PySlang AST traversal is insufficient

## Key Execution Flow

1. **Parse**: PySlang driver parses SystemVerilog files into AST
2. **Module Discovery**: Identify modules and count instances
3. **CFG Construction**: For each always block, build CFG and enumerate paths
4. **Path Enumeration**: Generate Cartesian product of paths across:
   - Multiple always blocks within a module
   - Multiple clock cycles
   - Multiple module instances
5. **Symbolic Execution**: For each path combination:
   - Initialize symbolic state with fresh symbols
   - Execute declarations and combinational logic
   - Walk through basic blocks following path directions
   - Update path condition at each branch
   - Check satisfiability with Z3
6. **Assertion Checking**: If assertion violation detected, generate counterexample

## PySlang Version Compatibility

The code supports both PySlang 7.0.0 and 9.x versions. Key differences:
- Line 136 in `main.py`: Use `driver.runFullCompilation()` for 9.x, `driver.reportCompilation()` for 7.0
- Conditional statements: 7.0 uses `conditions[0].expr`, syntax varies between versions
- Always check for both `ifTrue`/`ifFalse` and `statement`/`elseClause` attributes

## Multi-Module Handling

When multiple module instances exist:
- Each instance gets unique name: `{module_name}_{instance_number}`
- Separate symbolic stores maintained per instance
- Dependencies tracked both intra-module and inter-module
- Path exploration considers all instance combinations

## Caching

Optional Redis caching (`--use_cache`):
- Caches Z3 solver results keyed by constraint string
- Significantly speeds up repeated constraint checks
- Requires Redis server running on localhost:6379

## Important Implementation Details

- **Path explosion mitigation**: Uses generators for single-cycle paths to avoid OOM
- **Direction tracking**: CFG paths include direction bits (1=then, 0=else) for conditionals
- **Dummy nodes**: CFG uses -1 (start) and -2 (end) as dummy entry/exit nodes
- **Cycle tracking**: `manager.cycle` tracks current clock cycle during multi-cycle execution
- **Branch tracking**: `manager.branch_count` counts explored branch points

# Claude Code Guidelines

1. **Project Context**: This is a hardware verification project.
2. **Logging Protocol**: 
   - Whenever I type "Log it" or "记录", you must:
   - Summarize the current task/bug fix.
   - Append it to `CHANGELOG.md` with a timestamp.
   - Use the format: `[Date] [Category] Summary`.
   - You should also summarize how you use the pyslang library.
