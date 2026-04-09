"""Milestone management for directed symbolic execution."""

import re
import logging
from typing import List, Optional, Tuple, Any, Union
from z3 import Solver, sat, ExprRef, BitVecVal, ULE, ULT, UGE, UGT, And, Or, Not, Extract, ZeroExt, is_bv
from .symbolic_state import SymbolicState, smt_stats
from frontend.condition_parser import (
    parse_compound_condition, SimpleCondition, CompoundCondition, Condition
)


class Milestone:
    """Represents a single milestone condition (simple or compound)."""

    def __init__(self, description: str, condition_str: str, expected_cycles: int = 10):
        """
        Initialize a milestone.

        Args:
            description: Human-readable description (e.g., "Reset state")
            condition_str: Condition string (e.g., "RST == 1" or "RST == 0 && out == 0")
            expected_cycles: LLM-estimated clock cycles to reach this milestone from
                             the previous one. Used as BMC bound (default: 10).
        """
        self.description = description
        self.condition_str = condition_str
        self.expected_cycles = expected_cycles
        # Parse the condition
        self.condition = parse_compound_condition(condition_str)

    def __repr__(self):
        return f"Milestone({self.description}: {self.condition_str}, k={self.expected_cycles})"


class MilestoneManager:
    """Manages milestone checking and progression during directed search."""

    def __init__(self, milestones: List[Milestone]):
        """
        Initialize the milestone manager.

        Args:
            milestones: Ordered list of milestones to achieve
        """
        self.milestones = milestones
        self.current_milestone_index = 0

    def reset(self):
        """Reset milestone progress to the beginning."""
        self.current_milestone_index = 0

    def all_milestones_reached(self) -> bool:
        """Check if all milestones have been reached."""
        return self.current_milestone_index >= len(self.milestones)

    def milestones_remaining(self) -> int:
        """Return the number of milestones not yet reached."""
        return len(self.milestones) - self.current_milestone_index

    def current_milestone(self) -> Optional[Milestone]:
        """Get the current milestone to achieve, or None if all done."""
        if self.all_milestones_reached():
            return None
        return self.milestones[self.current_milestone_index]

    def parse_hierarchical_signal(self, signal_path: str, state: SymbolicState) -> Optional[Any]:
        """
        Parse a hierarchical signal path and look up its value in the state.
        Handles bit-slice notation like "signal[31:26]" or "module.signal[5]".

        Args:
            signal_path: Hierarchical path like "test_1.out[7:0]" or just "out"
            state: Current symbolic state

        Returns:
            The symbolic value from state.store, or None if not found
        """
        # Extract bit-slice notation if present
        bit_slice_match = re.match(r'^(.+)\[(\d+)(?::(\d+))?\]$', signal_path)
        if bit_slice_match:
            base_path = bit_slice_match.group(1)
            # We'll handle the bit extraction in _get_signal_z3_value
            signal_path = base_path

        parts = signal_path.split(".")

        if len(parts) == 2:
            module_name, var_name = parts
        elif len(parts) == 1:
            # Non-hierarchical signal - search in all modules
            var_name = parts[0]
            for module_name, module_store in state.store.items():
                if var_name in module_store:
                    return module_store[var_name]
            self._debug_dump_store(state, var_name, signal_path)
            return None
        elif len(parts) > 2:
            # Hierarchical path like "riscv_core.ex_stage_i.alu_i.div_i.C_LOG_WIDTH"
            var_name = parts[-1]
            # First try the immediate parent instance name (parts[-2]) — this handles
            # submodule parameters stored as state.store['div_i']['C_LOG_WIDTH'].
            parent_inst = parts[-2]
            if parent_inst in state.store and var_name in state.store[parent_inst]:
                return state.store[parent_inst][var_name]
            # Fall back to searching all modules
            for module_name, module_store in state.store.items():
                if var_name in module_store:
                    return module_store[var_name]
            self._debug_dump_store(state, var_name, signal_path)
            return None
        else:
            print(f"[MilestoneManager] Invalid signal path format: {signal_path}")
            return None

        if module_name not in state.store:
            # Module not found - fall back to searching all modules
            for mod_name, module_store in state.store.items():
                if var_name in module_store:
                    print(f"[MilestoneManager] Module '{module_name}' not found, "
                          f"but found '{var_name}' in '{mod_name}'")
                    return module_store[var_name]
            self._debug_dump_store(state, var_name, signal_path)
            return None

        if var_name not in state.store[module_name]:
            # Variable not in specified module - fall back to searching all modules
            for mod_name, module_store in state.store.items():
                if var_name in module_store:
                    print(f"[MilestoneManager] '{var_name}' not in '{module_name}', "
                          f"but found in '{mod_name}'")
                    return module_store[var_name]
            self._debug_dump_store(state, var_name, signal_path)
            return None

        return state.store[module_name][var_name]

    def _debug_dump_store(self, state: SymbolicState, var_name: str, signal_path: str) -> None:
        """Print debug info when a variable is not found in any module store."""
        print(f"[MilestoneManager] Variable '{var_name}' not found (from path: '{signal_path}')")
        print(f"[MilestoneManager] Available modules: {list(state.store.keys())}")
        for mod_name, module_store in state.store.items():
            vars_list = sorted(module_store.keys())
            print(f"[MilestoneManager]   {mod_name}: {vars_list}")

    def _evaluate_expression(self, expr_str: str, state: SymbolicState, default_width: int = 32) -> Optional[ExprRef]:
        """
        Evaluate an expression string to a Z3 expression.

        Handles:
        - Arithmetic expressions: "(sig + 1)", "(a - b)", "(sig << 1)"
        - Verilog backtick macros: "`THRESHOLD" (looked up in design parameters)
        - Signal paths within expressions are resolved from state.store

        Args:
            expr_str: Expression string
            state: Current symbolic state
            default_width: Default bit width for constants

        Returns:
            Z3 expression, or None if evaluation fails
        """
        import z3 as z3mod
        from z3 import BitVecVal

        expr_str = expr_str.strip()

        # Handle backtick macros
        if expr_str.startswith('`'):
            macro_name = expr_str[1:]
            for module_name, module_store in state.store.items():
                if macro_name in module_store:
                    val = module_store[macro_name]
                    if isinstance(val, int):
                        return BitVecVal(val, default_width)
                    return self._get_signal_z3_value(macro_name, state)
            print(f"[MilestoneManager] Cannot resolve macro: {expr_str}")
            return None

        # Strip outer parens
        if expr_str.startswith('(') and expr_str.endswith(')'):
            # Check balanced parens
            depth = 0
            all_inside = True
            for i, c in enumerate(expr_str):
                if c == '(':
                    depth += 1
                elif c == ')':
                    depth -= 1
                if depth == 0 and i < len(expr_str) - 1:
                    all_inside = False
                    break
            if all_inside:
                expr_str = expr_str[1:-1].strip()

        # Handle unary operators before binary search to avoid infinite recursion.
        # Without this, ~expr falls through to _resolve_operand which calls
        # _get_signal_z3_value which detects ~ as arithmetic and loops back here.
        if expr_str.startswith('~'):
            inner = expr_str[1:].strip()
            operand = self._evaluate_expression(inner, state, default_width)
            if operand is not None:
                return ~operand
            return None
        if expr_str.startswith('!'):
            inner = expr_str[1:].strip()
            operand = self._evaluate_expression(inner, state, default_width)
            if operand is not None:
                from z3 import Not, is_bool
                if is_bool(operand):
                    return Not(operand)
                return operand == BitVecVal(0, operand.size())
            return None

        # Try to find a binary operator at the top level (outside nested parens)
        # Order: lowest precedence first (<<, >>, +, -, *, /)
        operators = [(' << ', 'lshift'), (' >> ', 'rshift'),
                     (' + ', 'add'), (' - ', 'sub'),
                     (' * ', 'mul'), (' / ', 'div'),
                     (' & ', 'band'), (' | ', 'bor'), (' ^ ', 'bxor')]

        for op_str, op_name in operators:
            depth = 0
            for i in range(len(expr_str)):
                if expr_str[i] == '(':
                    depth += 1
                elif expr_str[i] == ')':
                    depth -= 1
                elif depth == 0 and expr_str[i:].startswith(op_str):
                    lhs_str = expr_str[:i].strip()
                    rhs_str = expr_str[i + len(op_str):].strip()

                    lhs = self._resolve_operand(lhs_str, state, default_width)
                    rhs = self._resolve_operand(rhs_str, state, default_width)

                    if lhs is None or rhs is None:
                        continue

                    # Match bit widths before arithmetic
                    lhs, rhs = self._match_widths(lhs, rhs)

                    if op_name == 'add':
                        return lhs + rhs
                    elif op_name == 'sub':
                        return lhs - rhs
                    elif op_name == 'mul':
                        return lhs * rhs
                    elif op_name == 'div':
                        return z3mod.UDiv(lhs, rhs)
                    elif op_name == 'lshift':
                        return lhs << rhs
                    elif op_name == 'rshift':
                        return z3mod.LShR(lhs, rhs)
                    elif op_name == 'band':
                        return lhs & rhs
                    elif op_name == 'bor':
                        return lhs | rhs
                    elif op_name == 'bxor':
                        return lhs ^ rhs

        # No binary operator found — try as a single operand
        return self._resolve_operand(expr_str, state, default_width)

    def _resolve_operand(self, operand: str, state: SymbolicState, default_width: int = 32) -> Optional[ExprRef]:
        """
        Resolve a single operand to a Z3 expression.

        Handles: numeric literals, signal paths, backtick macros, parenthesized sub-expressions.
        """
        from z3 import BitVecVal

        operand = operand.strip()
        if not operand:
            return None

        # Parenthesized sub-expression: recurse
        if operand.startswith('(') and operand.endswith(')'):
            return self._evaluate_expression(operand, state, default_width)

        # Backtick macro
        if operand.startswith('`'):
            return self._evaluate_expression(operand, state, default_width)

        # Try as numeric literal
        try:
            from frontend.condition_parser import parse_value
            val = parse_value(operand)
            return BitVecVal(val, default_width)
        except (ValueError, AttributeError):
            pass

        # Try as signal path (using existing Z3-aware resolution)
        result = self._get_signal_z3_value(operand, state)
        if result is not None:
            return result

        return None

    def _get_signal_z3_value(self, signal_path: str, state: SymbolicState) -> Optional[ExprRef]:
        """
        Get the Z3 value for a signal, handling both array indexing and bit-slice notation.

        Array elements like "in_a_history[0]" are stored in the symbolic store
        with the full key "in_a_history[0]". Bit-slices like "signal[31:26]" use
        Z3 Extract on the base signal. We try array-element lookup first.

        Args:
            signal_path: Signal path (may include array index or bit-slice)
            state: Current symbolic state

        Returns:
            Z3 expression for the signal value
        """
        from helpers.rvalue_to_z3 import parse_infix_expr_to_z3
        from z3 import BitVec, BitVecVal

        # If signal_path is an arithmetic expression (contains operators like &, |, >>, <<, +, -)
        # route it through _evaluate_expression rather than store lookup.
        _ARITH_OPS = re.compile(r'[&|^~+\-]|>>|<<')
        if _ARITH_OPS.search(signal_path):
            logging.debug(f"[_get_signal_z3_value] Routing arithmetic expr to _evaluate_expression: '{signal_path}'")
            return self._evaluate_expression(signal_path, state)

        # Check for bracket notation: signal[n] or signal[n:m]
        bit_slice_match = re.match(r'^(.+)\[(\d+)(?::(\d+))?\]$', signal_path)
        base_path = signal_path
        msb = None
        lsb = None

        if bit_slice_match:
            # First try as array element lookup (e.g., "in_a_history[0]" stored as key)
            # Extract the module.var[index] path and try it as a store key
            full_bracket_path = signal_path  # e.g., "u_assert.in_a_history[0]"
            bracket_base = bit_slice_match.group(1)  # e.g., "u_assert.in_a_history"
            bracket_index = bit_slice_match.group(2)  # e.g., "0"

            # Build the store key with bracket (e.g., "in_a_history[0]")
            bracket_parts = bracket_base.split(".")
            if len(bracket_parts) >= 2:
                module_hint = bracket_parts[0]
                var_with_index = ".".join(bracket_parts[1:]) + f"[{bracket_index}]"
                # Try direct lookup in the hinted module
                if module_hint in state.store and var_with_index in state.store[module_hint]:
                    return self._to_z3_value(state.store[module_hint][var_with_index], var_with_index, module_hint, state)
                # Also try just the last part with bracket
                var_name_with_index = bracket_parts[-1] + f"[{bracket_index}]"
                for mod_name, module_store in state.store.items():
                    if var_name_with_index in module_store:
                        return self._to_z3_value(module_store[var_name_with_index], var_name_with_index, mod_name, state)

            # Try 1-part path: signal_name[index] as store key
            if len(bracket_parts) == 1:
                var_with_index = bracket_parts[0] + f"[{bracket_index}]"
                for mod_name, module_store in state.store.items():
                    if var_with_index in module_store:
                        return self._to_z3_value(module_store[var_with_index], var_with_index, mod_name, state)

            # Array element not found — fall back to bit-slice extraction
            base_path = bit_slice_match.group(1)
            if bit_slice_match.group(3):  # Range like [31:26]
                msb = int(bit_slice_match.group(2))
                lsb = int(bit_slice_match.group(3))
            else:  # Single bit like [5]
                msb = lsb = int(bit_slice_match.group(2))

        signal_value = self.parse_hierarchical_signal(base_path, state)
        if signal_value is None:
            return None

        # Convert to Z3 expression if it's a string
        signal_value = self._to_z3_value(signal_value, base_path, None, state)
        if signal_value is None:
            return None

        # Apply bit extraction if needed
        if msb is not None and lsb is not None:
            return Extract(msb, lsb, signal_value)

        return signal_value

    def _to_z3_value(self, value: Any, path: str, module_hint: Optional[str], state: SymbolicState) -> Optional[ExprRef]:
        """Convert a store value to a Z3 expression if it isn't one already."""
        from helpers.rvalue_to_z3 import parse_infix_expr_to_z3
        from z3 import BitVec, is_bv

        if value is None:
            return None

        # Already a Z3 expression
        if is_bv(value):
            return value

        if isinstance(value, str):
            # Try to find the module for context
            mod_name = module_hint
            if mod_name is None:
                parts = path.split(".")
                if len(parts) == 2:
                    mod_name = parts[0]
                else:
                    for mn, ms in state.store.items():
                        if path in ms:
                            mod_name = mn
                            break

            z3_val = None
            if mod_name:
                z3_val = parse_infix_expr_to_z3(value, state.store.get(mod_name, {}), None)

            if z3_val is not None:
                return z3_val
            else:
                return BitVec(value, 32)

        return None

    @staticmethod
    def _match_widths(a: ExprRef, b: ExprRef) -> tuple:
        """Zero-extend the narrower operand to match the wider one's bit width."""
        a_size = a.size()
        b_size = b.size()
        if a_size < b_size:
            a = ZeroExt(b_size - a_size, a)
        elif b_size < a_size:
            b = ZeroExt(a_size - b_size, b)
        return a, b

    def _build_simple_condition(self, cond: SimpleCondition, state: SymbolicState) -> Optional[ExprRef]:
        """
        Build a Z3 condition for a simple condition.

        Args:
            cond: SimpleCondition object
            state: Current symbolic state

        Returns:
            Z3 expression
        """
        signal_value = self._get_signal_z3_value(cond.signal_path, state)
        if signal_value is None:
            return None

        # Check if value is a signal path (signal-to-signal comparison) or a constant
        if isinstance(cond.value, str):
            # Check if value looks like a simple signal path (no arithmetic operators/parens)
            value_str = cond.value.strip()
            is_simple_path = bool(re.match(r'^[a-zA-Z_][\w.]*$', value_str))

            target = None
            if is_simple_path:
                # Simple signal path - try direct lookup
                target = self._get_signal_z3_value(value_str, state)

            if target is None:
                # Try as an expression (e.g., "(sig + 1)", "`DEFINE", or failed signal path)
                target = self._evaluate_expression(cond.value, state, signal_value.size())
            if target is None:
                print(f"[MilestoneManager] Cannot resolve value: {cond.value}")
                return None
        else:
            # Constant value comparison - match signal's bit width
            target = BitVecVal(cond.value, signal_value.size())

        op = cond.operator

        # Ensure both operands have matching bit widths
        signal_value, target = self._match_widths(signal_value, target)

        if op == "==":
            return signal_value == target
        elif op == "!=":
            return signal_value != target
        elif op == "<":
            return ULT(signal_value, target)
        elif op == "<=":
            return ULE(signal_value, target)
        elif op == ">":
            return UGT(signal_value, target)
        elif op == ">=":
            return UGE(signal_value, target)
        else:
            print(f"[MilestoneManager] Unknown operator: {op}")
            return None

    def build_z3_condition(self, milestone: Milestone, state: SymbolicState) -> Optional[ExprRef]:
        """
        Build a Z3 condition for the given milestone.

        Args:
            milestone: The milestone to build condition for
            state: Current symbolic state

        Returns:
            Z3 expression representing the milestone condition, or None on error
        """
        return self._build_condition_recursive(milestone.condition, state)

    def _build_condition_recursive(self, cond: Condition, state: SymbolicState) -> Optional[ExprRef]:
        """
        Recursively build Z3 condition for simple or compound conditions.

        Args:
            cond: SimpleCondition or CompoundCondition
            state: Current symbolic state

        Returns:
            Z3 expression
        """
        if isinstance(cond, SimpleCondition):
            return self._build_simple_condition(cond, state)
        elif isinstance(cond, CompoundCondition):
            if cond.op == "&&":
                # AND all operands
                z3_operands = []
                for operand in cond.operands:
                    z3_op = self._build_condition_recursive(operand, state)
                    if z3_op is None:
                        return None
                    z3_operands.append(z3_op)
                return And(*z3_operands)
            elif cond.op == "||":
                # OR all operands
                z3_operands = []
                for operand in cond.operands:
                    z3_op = self._build_condition_recursive(operand, state)
                    if z3_op is None:
                        return None
                    z3_operands.append(z3_op)
                return Or(*z3_operands)
            elif cond.op == "!":
                # NOT the single operand
                z3_op = self._build_condition_recursive(cond.operands[0], state)
                if z3_op is None:
                    return None
                return Not(z3_op)
            else:
                print(f"[MilestoneManager] Unknown compound operator: {cond.op}")
                return None
        else:
            print(f"[MilestoneManager] Unknown condition type: {type(cond)}")
            return None

    def check_milestone(self, state: SymbolicState, solver: Solver) -> bool:
        """
        Check if the current milestone is satisfied.

        Uses Z3 solver to check if the milestone condition is satisfiable
        given the current path condition.

        Args:
            state: Current symbolic state
            solver: Z3 solver with current path condition

        Returns:
            True if milestone is reached (and advances to next), False otherwise
        """
        milestone = self.current_milestone()
        if milestone is None:
            return False  # All milestones already reached

        condition = self.build_z3_condition(milestone, state)
        if condition is None:
            print(f"[MilestoneManager] Failed to build condition for {milestone}")
            return False

        # Check satisfiability with push/pop to avoid polluting solver
        solver.push()
        solver.add(condition)
        result = smt_stats.timed_check(solver)
        solver.pop()

        if result == sat:
            print(f"[MilestoneManager] Milestone reached: {milestone}")
            self.current_milestone_index += 1
            return True
        else:
            return False

    def compute_score(self, cycle: int) -> int:
        """
        Compute priority score for the priority queue.

        Score = (Milestones_Remaining * 1000) + Clock_Cycle
        Lower score = higher priority (for min-heap)

        Args:
            cycle: Current clock cycle

        Returns:
            Priority score
        """
        return (self.milestones_remaining() * 1000) + cycle

    def check_and_lock(self, state: SymbolicState) -> bool:
            """
            Observational milestone check (stateful version).

            Checks satisfiability without locking the condition into the solver,
            to avoid permanent conflicts when milestones involve changing inputs.

            Args:
                state: Current symbolic state

            Returns:
                True if milestone is reached (and advances to next), False otherwise
            """
            milestone = self.current_milestone()
            if milestone is None:
                return False

            condition = self.build_z3_condition(milestone, state)
            if condition is None:
                return False

            solver = state.pc

            solver.push()
            solver.add(condition)
            result = solver.check()
            solver.pop()

            if result == sat:
                print(f"  [Milestone] Step {self.current_milestone_index} REACHED: {milestone.description}")
                self.current_milestone_index += 1
                return True

            return False
    
    def check_and_lock_stateless(self, state: SymbolicState, current_progress: int) -> Tuple[bool, int]:
        """
        Observational milestone check for A* directed search.

        Checks if the milestone condition is satisfiable given the current path
        condition, but does NOT lock (add) the condition into the solver.
        Locking caused permanent conflicts when milestones involve input signals
        that the engine keeps as a single symbol across all cycles.

        The priority queue already guides the search — states with more milestones
        reached get lower scores (higher priority).
        """
        if current_progress >= len(self.milestones):
            return False, current_progress

        if self.check_milestone_index(state, current_progress):
            milestone = self.milestones[current_progress]
            print(f"  [Milestone] Step {current_progress} REACHED: {milestone.description}")
            return True, current_progress + 1

        return False, current_progress

    def check_milestone_index(self, state: SymbolicState, milestone_idx: int) -> bool:
        """Speculatively check whether a specific milestone index is satisfiable."""
        if milestone_idx < 0 or milestone_idx >= len(self.milestones):
            return False

        milestone = self.milestones[milestone_idx]
        condition = self.build_z3_condition(milestone, state)
        if condition is None:
            return False

        solver = state.pc
        solver.push()
        solver.add(condition)
        result = solver.check()
        solver.pop()

        return result == sat

    def check_final_milestone(self, state: SymbolicState) -> bool:
        """Speculatively check whether the final milestone is satisfiable."""
        if not self.milestones:
            return False
        return self.check_milestone_index(state, len(self.milestones) - 1)

    def advance_with_sliding_window(
        self,
        state: SymbolicState,
        current_progress: int,
        window_size: int = 1
    ) -> Tuple[int, Optional[int]]:
        """Advance milestone progress with a small lookahead window.

        Also auto-skips milestones whose signals are not in the store
        (build_z3_condition returns None), treating them as hallucinated.

        Returns:
            (new_progress, skipped_idx). skipped_idx is the skipped milestone index
            when lookahead succeeds past the current milestone; otherwise None.
        """
        total = len(self.milestones)
        if current_progress >= total:
            return current_progress, None

        if current_progress == 0:
            success, new_progress = self.check_and_lock_stateless(state, current_progress)
            return (new_progress, None) if success else (current_progress, None)

        # Auto-skip any milestone at current_progress whose condition cannot be
        # built (signal not in store = hallucinated signal name).
        first_skipped = None
        while current_progress < total:
            milestone = self.milestones[current_progress]
            condition = self.build_z3_condition(milestone, state)
            if condition is not None:
                break  # This milestone is evaluable — stop skipping
            if first_skipped is None:
                first_skipped = current_progress
            print(f"  [Auto-skip] Milestone {current_progress} '{milestone.description}' "
                  f"has unresolvable signals — treating as hallucinated")
            current_progress += 1

        if current_progress >= total:
            return current_progress, first_skipped

        last_idx = total - 1
        furthest_idx = min(current_progress + window_size, last_idx)

        for milestone_idx in range(furthest_idx, current_progress - 1, -1):
            if not self.check_milestone_index(state, milestone_idx):
                continue

            milestone = self.milestones[milestone_idx]
            print(f"  [Milestone] Step {milestone_idx} REACHED: {milestone.description}")
            new_progress = milestone_idx + 1
            skipped_idx = first_skipped if first_skipped is not None else (
                current_progress if milestone_idx > current_progress else None
            )
            return new_progress, skipped_idx

        return current_progress, first_skipped

    def compute_dataflow_distance(self, state: SymbolicState, milestone_idx: int) -> int:
        """Compute microscopic data-flow distance from current state to a milestone's condition.

        Walks the (possibly compound) condition tree and sums per-sub-condition distances.
        Returns 0 on any error so the engine falls back to standard A* scoring.
        """
        if milestone_idx < 0 or milestone_idx >= len(self.milestones):
            return 0
        milestone = self.milestones[milestone_idx]
        try:
            return self._distance_recursive(milestone.condition, state)
        except Exception:
            return 0

    def _distance_recursive(self, cond, state: SymbolicState) -> int:
        """Recursively compute distances for compound conditions, respecting logic operators."""
        if isinstance(cond, SimpleCondition):
            return self._distance_simple(cond, state)
        
        elif isinstance(cond, CompoundCondition):
            # 获取操作符，假设存在 operator 属性，如 '&&' 或 '||'
            # (根据你实际的 AST 结构修改这部分属性获取方式)
            op = getattr(cond, 'operator', '&&') 
            
            distances = [self._distance_recursive(operand, state) for operand in cond.operands]
            
            if not distances:
                return 0
                
            if op == '||' or op == 'OR':
                # OR 逻辑：只要有一条路满足即可，取最短距离
                return min(distances)
            else:
                # AND 逻辑 (默认)：所有条件都必须满足，累加距离
                return sum(distances)
                
        return 0

    def _distance_simple(self, cond: 'SimpleCondition', state: SymbolicState) -> int:
        """Compute distance for a single SimpleCondition, respecting relational operators."""
        import z3

        # --- Resolve LHS ---
        lhs_expr = self._get_signal_z3_value(cond.signal_path, state)
        if lhs_expr is None: return 0

        # --- Resolve RHS ---
        if isinstance(cond.value, int):
            target_val = cond.value
        else:
            rhs_expr = self._get_signal_z3_value(cond.value, state)
            if rhs_expr is None: return 0
            target_val = self._concretize(rhs_expr, state)
            if target_val is None: return 0

        # --- Concretize LHS ---
        current_val = self._concretize(lhs_expr, state)
        if current_val is None: return 0

        bit_width = lhs_expr.size() if z3.is_bv(lhs_expr) else 32
        
        # --- Operator-Aware Distance Math ---
        # 假设 SimpleCondition 带有 operator 属性 (如 '==', '!=', '>', '<')
        op = getattr(cond, 'operator', '==')

        if bit_width == 1:
            # 1-bit boolean logic
            if op == '==':
                return 0 if current_val == target_val else 10
            elif op == '!=':
                return 0 if current_val != target_val else 10
            else:
                # For 1-bit, > or < is rare, fallback to strict match
                return 0 if current_val == target_val else 10
        else:
            # Multi-bit logic (Treated as Unsigned by default, which is RTL standard)
            # If you know the specific signal is signed, you can add sign-extension here conditionally.
            
            dist = 0
            if op == '==':
                dist = abs(current_val - target_val)
            elif op == '!=':
                dist = 0 if current_val != target_val else 10
            elif op in ('>', '>='):
                # ReLU: 如果当前值已经大于目标值，距离为 0
                dist = 0 if current_val >= target_val else (target_val - current_val)
            elif op in ('<', '<='):
                # ReLU: 如果当前值已经小于目标值，距离为 0
                dist = 0 if current_val <= target_val else (current_val - target_val)
            else:
                dist = abs(current_val - target_val)
                
            # Cap at 999 so distance never dominates the milestone component (1000).
            return min(dist, 999)

    def _concretize(self, expr, state: SymbolicState):
        """Try to reduce a Z3 expression to a concrete integer.

        1. z3.simplify — free, no solver call.
        2. Model probing via state.pc.check() + model() — expensive, used as fallback.
        Returns None if concretization fails.
        """
        import z3

        # Fast path: simplify
        simplified = z3.simplify(expr)
        if isinstance(simplified, z3.BitVecNumRef):
            return simplified.as_long()

        # Fallback: model probing (push/pop to avoid polluting PC)
        try:
            state.pc.push()
            result = state.pc.check()
            if result == z3.sat:
                model = state.pc.model()
                val = model.eval(expr, model_completion=True)
                if isinstance(val, z3.BitVecNumRef):
                    return val.as_long()
        except Exception:
            pass
        finally:
            state.pc.pop()

        return None

    def compute_score_stateless(self, current_progress: int, cycle: int,
                                state: Optional[SymbolicState] = None) -> int:
        """Score = (remaining * 1000) + cycle + data_flow_distance."""
        remaining = len(self.milestones) - current_progress
        base = (remaining * 10) + cycle

        if state is not None and current_progress < len(self.milestones):
            d = self.compute_dataflow_distance(state, current_progress)
            milestone_desc = self.milestones[current_progress].description
            logging.debug(
                f"[Score] M[{current_progress}]='{milestone_desc}' "
                f"remaining={remaining} cycle={cycle} "
                f"base={base} distance={d} total={base + d}"
            )
            return base + d

        logging.debug(
            f"[Score] no distance (state={'None' if state is None else 'set'}, "
            f"progress={current_progress}/{len(self.milestones)}) "
            f"base={base}"
        )
        return base
