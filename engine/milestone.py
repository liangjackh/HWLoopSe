"""Milestone management for directed symbolic execution."""

from typing import List, Optional, Tuple, Any, Union
from z3 import Solver, sat, ExprRef, BitVecVal, ULE, ULT, UGE, UGT, And, Or, Not
from .symbolic_state import SymbolicState
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

        Args:
            signal_path: Hierarchical path like "test_1.out" or just "out"
            state: Current symbolic state

        Returns:
            The symbolic value from state.store, or None if not found
        """
        parts = signal_path.split(".")

        if len(parts) == 2:
            module_name, var_name = parts
        elif len(parts) == 1:
            # Non-hierarchical signal - search in all modules
            var_name = parts[0]
            for module_name, module_store in state.store.items():
                if var_name in module_store:
                    return module_store[var_name]
            print(f"[MilestoneManager] Variable not found: {var_name}")
            return None
        elif len(parts) > 2:
            # Hierarchical path like "or1200_cpu.u_assertions.operand_b"
            # Try to find the signal by searching in all modules
            var_name = parts[-1]  # Last part is the signal name
            for module_name, module_store in state.store.items():
                if var_name in module_store:
                    return module_store[var_name]
            print(f"[MilestoneManager] Variable not found in any module: {var_name} (from path: {signal_path})")
            return None
        else:
            print(f"[MilestoneManager] Invalid signal path format: {signal_path}")
            return None

        if module_name not in state.store:
            print(f"[MilestoneManager] Module not found: {module_name}")
            return None

        if var_name not in state.store[module_name]:
            print(f"[MilestoneManager] Variable not found: {var_name} in {module_name}")
            return None

        return state.store[module_name][var_name]

    def _get_signal_z3_value(self, signal_path: str, state: SymbolicState) -> Optional[ExprRef]:
        """
        Get the Z3 value for a signal.

        Args:
            signal_path: Signal path
            state: Current symbolic state

        Returns:
            Z3 expression for the signal value
        """
        from helpers.rvalue_to_z3 import parse_infix_expr_to_z3
        from z3 import BitVec, BitVecVal

        signal_value = self.parse_hierarchical_signal(signal_path, state)
        if signal_value is None:
            return None

        # Already a Z3 expression — return as-is
        if not isinstance(signal_value, str):
            return signal_value

        # It's a string — try to convert to Z3
        original_str = signal_value
        parts = signal_path.split(".")
        if len(parts) == 2:
            module_name = parts[0]
        else:
            module_name = None
            for mod_name, module_store in state.store.items():
                if signal_path in module_store:
                    module_name = mod_name
                    break

        z3_val = None
        if module_name:
            z3_val = parse_infix_expr_to_z3(original_str, state.store.get(module_name, {}), None)

        if z3_val is not None:
            return z3_val

        # Fallback: treat the string as a free Z3 BitVec variable.
        # This handles random symbol names for unconstrained inputs (e.g., "QguHPd8pyYDSPKqE" for RST).
        return BitVec(original_str, 32)

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
            # Signal-to-signal comparison
            target = self._get_signal_z3_value(cond.value, state)
            if target is None:
                print(f"[MilestoneManager] Cannot resolve signal: {cond.value}")
                return None
        else:
            # Constant value comparison
            target = BitVecVal(cond.value, 32)

        op = cond.operator
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
        result = solver.check()
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
