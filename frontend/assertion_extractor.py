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
    # Only traverse from the top-level module since get_assertions
    # already recurses into sub-instances. Traversing all modules
    # would find the same assertion multiple times.
    manager.assertions = []
    top_module = modules[0]
    manager.get_assertions(manager, top_module.body)

    if not manager.assertions:
        print("[assertion_extractor] No assertions found in design")
        return targets

    # Assertions are now tuples of (condition, instance_path)
    # Deduplicate by (string representation, instance_path)
    seen_assertions = set()
    unique_assertions = []
    for assertion, instance_path in manager.assertions:
        key = (str(assertion), instance_path)
        if key not in seen_assertions:
            seen_assertions.add(key)
            unique_assertions.append((assertion, instance_path))

    manager.assertions = unique_assertions
    print(f"[assertion_extractor] Found {len(manager.assertions)} unique assertion(s) (after deduplication):")
    for assertion, instance_path in manager.assertions:
        print(f"[assertion_extractor]   {assertion} in '{instance_path or 'top'}'")

    # Convert each assertion to a verification target
    for idx, (assertion, instance_path) in enumerate(manager.assertions):
        # Get the assertion condition as a string
        assertion_str = str(assertion)

        # Try to extract the condition expression
        condition_str = assertion_str

        if hasattr(assertion, 'syntax'):
            condition_str = str(assertion.syntax)

        print(f"[assertion_extractor] Processing assertion {idx}: {condition_str}")

        # Negate the condition to find violations
        negated = negate_condition(condition_str)

        # Use the instance path tracked during get_assertions
        if instance_path:
            instance_name = instance_path
        else:
            # Assertion is in the top-level module
            from helpers.slang_helpers import get_module_name
            instance_name = get_module_name(modules[0])

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
