"""Extract verification targets from SystemVerilog assertions."""

from typing import List, Dict, Optional
from dataclasses import dataclass
import re


@dataclass
class VerificationTarget:
    """Represents a verification target extracted from an assertion."""
    target_expr: str  # e.g., "test_1.out > 2"
    assertion_source: str  # Original assertion condition
    module_name: str  # Module instance name
    description: str  # Human-readable description


def negate_condition(condition_str: str) -> str:
    """
    Negate an assertion condition to find violations.

    Examples:
        "out <= 2" -> "out > 2"
        "out == 0" -> "out != 0"
        "flag != 1" -> "flag == 1"
        "cnt < 10" -> "cnt >= 10"

    Args:
        condition_str: Original assertion condition as string

    Returns:
        Negated condition string
    """
    condition_str = condition_str.strip()

    # Map operators to their negations
    negation_map = {
        '<=': '>',
        '>=': '<',
        '<': '>=',
        '>': '<=',
        '==': '!=',
        '!=': '=='
    }

    # Try to find and replace operator
    for op, neg_op in negation_map.items():
        if op in condition_str:
            # Split on the operator
            parts = condition_str.split(op)
            if len(parts) == 2:
                return f"{parts[0].strip()} {neg_op} {parts[1].strip()}"

    # If we can't parse it, just wrap in NOT
    return f"!({condition_str})"


def resolve_signal_path(signal_name: str, module_instance_name: str) -> str:
    """
    Convert local signal reference to hierarchical path.

    Args:
        signal_name: Local signal name (e.g., "out")
        module_instance_name: Instance name (e.g., "test_1")

    Returns:
        Hierarchical path (e.g., "test_1.out")
    """
    # If already hierarchical, return as-is
    if '.' in signal_name:
        return signal_name

    # Otherwise, prepend instance name
    return f"{module_instance_name}.{signal_name}"


def extract_signals_from_condition(condition_str: str) -> List[str]:
    """
    Extract signal names from a condition string.

    Args:
        condition_str: Condition like "out <= 2" or "a + b > c"

    Returns:
        List of signal names found
    """
    # Remove operators and numbers to find identifiers
    # This is a simple heuristic - may need refinement
    tokens = re.findall(r'[a-zA-Z_][a-zA-Z0-9_]*', condition_str)
    return tokens


def extract_verification_targets(modules, manager) -> List[VerificationTarget]:
    """
    Extract all assertions from modules and convert to verification targets.

    Args:
        modules: List of PySlang module symbols
        manager: ExecutionManager instance

    Returns:
        List of VerificationTarget objects
    """
    targets = []

    # First, collect all assertions using the existing method
    manager.assertions = []

    for module in modules:
        manager.get_assertions(manager, module.body)

    if not manager.assertions:
        print("[assertion_extractor] No assertions found in design")
        return targets

    print(f"[assertion_extractor] Found {len(manager.assertions)} assertion(s)")

    # Convert each assertion to a verification target
    for idx, assertion in enumerate(manager.assertions):
        # Get the assertion condition as a string
        assertion_str = str(assertion)

        # Try to extract the condition expression
        # PySlang assertions have different formats, try to handle them
        condition_str = assertion_str

        # For simple cases like "out <= 2", extract the condition
        # This is a heuristic - may need refinement based on actual PySlang output
        if hasattr(assertion, 'syntax'):
            condition_str = str(assertion.syntax)

        print(f"[assertion_extractor] Processing assertion {idx}: {condition_str}")

        # Negate the condition to find violations
        negated = negate_condition(condition_str)

        # Determine which module this assertion belongs to
        # For now, assume single module or use first module
        # TODO: Improve module detection by tracking assertion location
        if len(modules) == 1:
            module_instance = modules[0]
            from helpers.slang_helpers import get_module_name
            instance_name = get_module_name(module_instance)
        else:
            # For multi-module designs, try to infer from assertion context
            # Default to first module for now
            from helpers.slang_helpers import get_module_name
            instance_name = get_module_name(modules[0])
            print(f"[assertion_extractor] Warning: Multi-module design, assuming assertion in {instance_name}")

        # Extract signal names and resolve paths
        signals = extract_signals_from_condition(condition_str)

        # Build target expression with hierarchical paths
        target_expr = negated
        for signal in signals:
            # Skip numeric literals and keywords
            if signal.isdigit() or signal in ['if', 'else', 'begin', 'end']:
                continue

            # Resolve to hierarchical path
            hierarchical = resolve_signal_path(signal, instance_name)

            # Replace in target expression
            # Use word boundaries to avoid partial replacements
            target_expr = re.sub(r'\b' + signal + r'\b', hierarchical, target_expr)

        # Create verification target
        target = VerificationTarget(
            target_expr=target_expr,
            assertion_source=condition_str,
            module_name=instance_name,
            description=f"Violate assertion '{condition_str}' in {instance_name}"
        )

        targets.append(target)
        print(f"[assertion_extractor] Created target: {target.description}")
        print(f"[assertion_extractor]   Expression: {target.target_expr}")

    return targets
