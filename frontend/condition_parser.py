"""Parse condition strings into components for Milestone creation."""

import re
from typing import Tuple, Optional, List, Union, Dict, Any
from dataclasses import dataclass


@dataclass
class SimpleCondition:
    """A simple condition: signal op value or signal op signal"""
    signal_path: str
    operator: str
    value: Union[int, str]  # int for constant, str for signal path

    def __repr__(self):
        return f"{self.signal_path} {self.operator} {self.value}"

    def is_signal_comparison(self) -> bool:
        """Check if this is a signal-to-signal comparison."""
        return isinstance(self.value, str)


@dataclass
class CompoundCondition:
    """A compound condition with AND/OR/NOT"""
    op: str  # "&&", "||", "!"
    operands: List[Union['SimpleCondition', 'CompoundCondition']]

    def __repr__(self):
        if self.op == "!":
            return f"!({self.operands[0]})"
        return f" {self.op} ".join(f"({o})" for o in self.operands)


# Type alias for any condition
Condition = Union[SimpleCondition, CompoundCondition]


def parse_value(value_str: str) -> int:
    """
    Parse a value string into an integer.

    Supports:
    - decimal: 42
    - hex: 0x2A, 'h2A, 32'h2A
    - binary: 0b101010, 'b101010, 6'b101010
    """
    value_str = value_str.strip()

    if value_str.startswith("0x") or value_str.startswith("0X"):
        return int(value_str, 16)
    elif value_str.startswith("0b") or value_str.startswith("0B"):
        return int(value_str, 2)
    elif value_str.startswith("'h"):
        # Verilog hex format without width: 'h2A
        return int(value_str[2:], 16)
    elif value_str.startswith("'b"):
        # Verilog binary format without width: 'b101010
        return int(value_str[2:], 2)
    elif "'" in value_str:
        # Verilog format with width: 32'h2A or 6'b101010
        parts = value_str.split("'", 1)
        if len(parts) == 2:
            # width = parts[0]  # Not used, but available if needed
            format_and_value = parts[1]
            if format_and_value.startswith('h'):
                return int(format_and_value[1:], 16)
            elif format_and_value.startswith('b'):
                return int(format_and_value[1:], 2)
            elif format_and_value.startswith('d'):
                return int(format_and_value[1:], 10)
            else:
                # Default to decimal if no format specifier
                return int(format_and_value, 10)

    # Default: try to parse as decimal
    return int(value_str)


def parse_simple_condition(condition: str) -> SimpleCondition:
    """
    Parse a simple condition string into a SimpleCondition.

    Examples:
        "rst == 1" -> SimpleCondition("rst", "==", 1)
        "test_1.out > 3" -> SimpleCondition("test_1.out", ">", 3)
        "sig_a != sig_b" -> SimpleCondition("sig_a", "!=", "sig_b")

    Args:
        condition: A string like "signal_name op value" or "signal_name op signal_name"

    Returns:
        SimpleCondition object

    Raises:
        ValueError: If the condition cannot be parsed
    """
    # Supported operators (order matters - check longer ones first)
    operators = ['==', '!=', '>=', '<=', '>', '<']

    condition = condition.strip()

    for op in operators:
        if op in condition:
            parts = condition.split(op, 1)  # Split only on first occurrence
            if len(parts) == 2:
                signal_path = parts[0].strip()
                value_str = parts[1].strip()

                # Try to parse as a numeric value first
                try:
                    value = parse_value(value_str)
                    return SimpleCondition(signal_path, op, value)
                except (ValueError, AttributeError):
                    # If parsing as value fails, treat it as a signal path
                    # This handles signal-to-signal comparisons
                    # Check if it looks like a signal (contains letters, dots, underscores, brackets)
                    if re.match(r'^[a-zA-Z_][\w.\[\]:]*$', value_str):
                        return SimpleCondition(signal_path, op, value_str)
                    else:
                        raise ValueError(f"Cannot parse value '{value_str}' in condition: {condition}")

    raise ValueError(f"Cannot parse simple condition: {condition}. Expected format: 'signal op value' or 'signal op signal'")


def tokenize_condition(condition: str) -> List[str]:
    """
    Tokenize a condition string into tokens.

    Handles: &&, ||, !, (, ), and simple conditions
    Note: != is part of a comparison operator, not a NOT token
    """
    tokens = []
    i = 0
    condition = condition.strip()

    while i < len(condition):
        # Skip whitespace
        if condition[i].isspace():
            i += 1
            continue

        # Check for &&
        if condition[i:i+2] == '&&':
            tokens.append('&&')
            i += 2
            continue

        # Check for ||
        if condition[i:i+2] == '||':
            tokens.append('||')
            i += 2
            continue

        # Check for ! (but not !=)
        if condition[i] == '!' and (i + 1 >= len(condition) or condition[i+1] != '='):
            tokens.append('!')
            i += 1
            continue

        # Check for parentheses
        if condition[i] == '(':
            tokens.append('(')
            i += 1
            continue

        if condition[i] == ')':
            tokens.append(')')
            i += 1
            continue

        # Otherwise, read until we hit &&, ||, !, (, or )
        # But be careful not to break on != (which is part of a comparison)
        j = i
        while j < len(condition):
            # Check for logical operators
            if condition[j:j+2] in ('&&', '||'):
                break
            # Check for ! but not !=
            if condition[j] == '!' and (j + 1 >= len(condition) or condition[j+1] != '='):
                break
            # Check for parentheses
            if condition[j] in '()':
                break
            j += 1

        token = condition[i:j].strip()
        if token:
            tokens.append(token)
        i = j

    return tokens


def parse_compound_condition(condition: str) -> Condition:
    """
    Parse a potentially compound condition string.

    Supports:
        - Simple: "rst == 1"
        - AND: "rst == 0 && out == 0"
        - OR: "state == 1 || state == 2"
        - NOT: "!overflow"
        - Nested: "(a == 1 && b == 2) || c == 3"

    Args:
        condition: A condition string

    Returns:
        SimpleCondition or CompoundCondition

    Raises:
        ValueError: If the condition cannot be parsed
    """
    tokens = tokenize_condition(condition)

    if not tokens:
        raise ValueError(f"Empty condition: {condition}")

    # If no compound operators, parse as simple
    if '&&' not in tokens and '||' not in tokens and '!' not in tokens and '(' not in tokens:
        return parse_simple_condition(condition)

    # Parse with precedence: ! > && > ||
    result, remaining = parse_or_expr(tokens)

    if remaining:
        raise ValueError(f"Unexpected tokens remaining: {remaining}")

    return result


def parse_or_expr(tokens: List[str]) -> Tuple[Condition, List[str]]:
    """Parse OR expression (lowest precedence)"""
    left, tokens = parse_and_expr(tokens)

    operands = [left]
    while tokens and tokens[0] == '||':
        tokens = tokens[1:]  # consume ||
        right, tokens = parse_and_expr(tokens)
        operands.append(right)

    if len(operands) == 1:
        return operands[0], tokens
    return CompoundCondition('||', operands), tokens


def parse_and_expr(tokens: List[str]) -> Tuple[Condition, List[str]]:
    """Parse AND expression (higher precedence than OR)"""
    left, tokens = parse_unary_expr(tokens)

    operands = [left]
    while tokens and tokens[0] == '&&':
        tokens = tokens[1:]  # consume &&
        right, tokens = parse_unary_expr(tokens)
        operands.append(right)

    if len(operands) == 1:
        return operands[0], tokens
    return CompoundCondition('&&', operands), tokens


def parse_unary_expr(tokens: List[str]) -> Tuple[Condition, List[str]]:
    """Parse unary expression (NOT, highest precedence)"""
    if tokens and tokens[0] == '!':
        tokens = tokens[1:]  # consume !
        operand, tokens = parse_primary_expr(tokens)
        return CompoundCondition('!', [operand]), tokens

    return parse_primary_expr(tokens)


def parse_primary_expr(tokens: List[str]) -> Tuple[Condition, List[str]]:
    """Parse primary expression (parenthesized or simple condition)"""
    if not tokens:
        raise ValueError("Unexpected end of expression")

    if tokens[0] == '(':
        tokens = tokens[1:]  # consume (
        expr, tokens = parse_or_expr(tokens)
        if not tokens or tokens[0] != ')':
            raise ValueError("Missing closing parenthesis")
        tokens = tokens[1:]  # consume )
        return expr, tokens

    # Simple condition - the token should be something like "rst == 1"
    return parse_simple_condition(tokens[0]), tokens[1:]


def parse_condition(condition: str) -> Tuple[str, str, int]:
    """
    Parse a simple condition string into (signal_path, operator, value).

    This is the legacy interface for backward compatibility.
    For compound conditions, use parse_compound_condition().

    Examples:
        "rst == 1" -> ("rst", "==", 1)
        "test_1.out > 3" -> ("test_1.out", ">", 3)

    Args:
        condition: A string like "signal_name op value"

    Returns:
        Tuple of (signal_path, operator, value)

    Raises:
        ValueError: If the condition cannot be parsed as a simple condition
    """
    result = parse_simple_condition(condition)
    return (result.signal_path, result.operator, result.value)


def get_all_signals(condition: Condition) -> List[str]:
    """
    Extract all signal names from a condition (simple or compound).

    Args:
        condition: A SimpleCondition or CompoundCondition

    Returns:
        List of signal paths
    """
    if isinstance(condition, SimpleCondition):
        return [condition.signal_path]
    elif isinstance(condition, CompoundCondition):
        signals = []
        for operand in condition.operands:
            signals.extend(get_all_signals(operand))
        return signals
    else:
        return []


def condition_to_dict(condition: Condition) -> Dict[str, Any]:
    """
    Convert a condition to a dictionary representation.

    Args:
        condition: A SimpleCondition or CompoundCondition

    Returns:
        Dictionary representation
    """
    if isinstance(condition, SimpleCondition):
        return {
            "type": "simple",
            "signal": condition.signal_path,
            "operator": condition.operator,
            "value": condition.value
        }
    elif isinstance(condition, CompoundCondition):
        return {
            "type": "compound",
            "op": condition.op,
            "operands": [condition_to_dict(op) for op in condition.operands]
        }
    else:
        raise ValueError(f"Unknown condition type: {type(condition)}")


def extract_signal_name(signal_path: str) -> str:
    """
    Extract the base signal name from a hierarchical path.

    Examples:
        "test_1.out" -> "out"
        "u_cpu.u_alu.result" -> "result"
        "rst" -> "rst"
        "ex_insn[31:26]" -> "ex_insn"
        "module.signal[7:0]" -> "signal"

    Args:
        signal_path: A potentially hierarchical signal path with optional bit-select

    Returns:
        The base signal name (last component, without bit-select)
    """
    # First, strip any bit-select syntax [...]
    if '[' in signal_path:
        signal_path = signal_path.split('[')[0]

    # Then extract the last component if hierarchical
    if '.' in signal_path:
        return signal_path.split('.')[-1]
    return signal_path


def extract_instance_path(signal_path: str) -> Optional[str]:
    """
    Extract the instance path from a hierarchical signal path.

    Examples:
        "test_1.out" -> "test_1"
        "u_cpu.u_alu.result" -> "u_cpu.u_alu"
        "rst" -> None

    Args:
        signal_path: A potentially hierarchical signal path

    Returns:
        The instance path (everything except the last component), or None if no hierarchy
    """
    if '.' in signal_path:
        parts = signal_path.rsplit('.', 1)
        return parts[0]
    return None
