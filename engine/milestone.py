"""Milestone management for directed symbolic execution."""

from typing import List, Optional, Tuple, Any
from z3 import Solver, sat, ExprRef, BitVecVal, ULE, ULT, UGE, UGT
from .symbolic_state import SymbolicState


class Milestone:
    """Represents a single milestone condition."""

    def __init__(self, name: str, signal_path: str, operator: str, value: int):
        """
        Initialize a milestone.

        Args:
            name: Human-readable name for the milestone (e.g., "M0 (Reset)")
            signal_path: Hierarchical signal path (e.g., "test_1.out")
            operator: Comparison operator ("==", "!=", "<", "<=", ">", ">=")
            value: Target value to compare against
        """
        self.name = name
        self.signal_path = signal_path
        self.operator = operator
        self.value = value

    def __repr__(self):
        return f"Milestone({self.name}: {self.signal_path} {self.operator} {self.value})"


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
            signal_path: Hierarchical path like "test_1.out"
            state: Current symbolic state

        Returns:
            The symbolic value from state.store, or None if not found
        """
        parts = signal_path.split(".")
        if len(parts) != 2:
            print(f"[MilestoneManager] Invalid signal path format: {signal_path}")
            return None

        module_name, var_name = parts

        if module_name not in state.store:
            print(f"[MilestoneManager] Module not found: {module_name}")
            return None

        if var_name not in state.store[module_name]:
            print(f"[MilestoneManager] Variable not found: {var_name} in {module_name}")
            return None

        return state.store[module_name][var_name]

    def build_z3_condition(self, milestone: Milestone, state: SymbolicState) -> Optional[ExprRef]:
        """
        Build a Z3 condition for the given milestone.

        Args:
            milestone: The milestone to build condition for
            state: Current symbolic state

        Returns:
            Z3 expression representing the milestone condition, or None on error
        """
        from helpers.rvalue_to_z3 import parse_infix_expr_to_z3

        signal_value = self.parse_hierarchical_signal(milestone.signal_path, state)
        if signal_value is None:
            return None

        # Convert signal value to Z3 if it's a string expression
        if isinstance(signal_value, str):
            # Parse the expression string to Z3
            module_name = milestone.signal_path.split(".")[0]
            signal_value = parse_infix_expr_to_z3(signal_value, state.store.get(module_name, {}))

        # Build the comparison
        target = BitVecVal(milestone.value, 32)

        op = milestone.operator
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
