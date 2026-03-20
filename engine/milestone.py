"""Milestone management for directed symbolic execution."""

import re
from typing import List, Optional, Tuple, Any, Union
from z3 import Solver, sat, ExprRef, BitVecVal, ULE, ULT, UGE, UGT, And, Or, Not, Extract, ZeroExt, is_bv
from .symbolic_state import SymbolicState, smt_stats
from frontend.condition_parser import (
    parse_compound_condition, SimpleCondition, CompoundCondition, Condition
)


class Milestone:
    """Represents a single milestone condition (simple or compound)."""

    def __init__(self, description: str, condition_str: str):
        """
        Initialize a milestone.

        Args:
            description: Human-readable description (e.g., "Reset state")
            condition_str: Condition string (e.g., "RST == 1" or "RST == 0 && out == 0")
        """
        self.description = description
        self.condition_str = condition_str
        # Parse the condition
        self.condition = parse_compound_condition(condition_str)

    def __repr__(self):
        return f"Milestone({self.description}: {self.condition_str})"


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
            # Hierarchical path like "or1200_cpu.u_assertions.operand_b"
            # Try to find the signal by searching in all modules
            var_name = parts[-1]  # Last part is the signal name
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

        milestone = self.milestones[current_progress]
        condition = self.build_z3_condition(milestone, state)
        if condition is None:
            return False, current_progress

        solver = state.pc

        # Speculative check only — no locking
        solver.push()
        solver.add(condition)
        result = solver.check()
        solver.pop()

        if result == sat:
            print(f"  [Milestone] Step {current_progress} REACHED: {milestone.description}")
            return True, current_progress + 1

        return False, current_progress

    def compute_score_stateless(self, current_progress: int, cycle: int) -> int:
        """无状态的评分计算"""
        remaining = len(self.milestones) - current_progress
        return (remaining * 1000) + cycle
