"""Parse condition strings into components for Milestone creation."""

import re
import logging
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


def _find_top_level_comparison(condition: str) -> Optional[Tuple[str, int]]:
    """Find the first comparison operator at the top paren level.

    Returns (operator, index) or None.  Correctly distinguishes:
      ==  !=  >=  <=   (2-char comparison operators)
      >   <            (1-char, but NOT >> or <<)
    """
    depth = 0
    i = 0
    while i < len(condition):
        c = condition[i]
        if c == '(':
            depth += 1
            i += 1
            continue
        elif c == ')':
            depth -= 1
            i += 1
            continue

        if depth != 0:
            i += 1
            continue

        # Check 2-char operators first
        two = condition[i:i+2]
        if two in ('==', '!=', '>=', '<='):
            return (two, i)
        # Check single-char > but not >> or >= (and not the second char of >>)
        if c == '>' and two not in ('>>', '>=') and (i == 0 or condition[i-1] != '>'):
            return ('>', i)
        # Check single-char < but not << or <= (and not the second char of <<)
        if c == '<' and two not in ('<<', '<=') and (i == 0 or condition[i-1] != '<'):
            return ('<', i)

        i += 1
    return None


def parse_simple_condition(condition: str) -> SimpleCondition:
    """
    Parse a simple condition string into a SimpleCondition.

    Examples:
        "rst == 1" -> SimpleCondition("rst", "==", 1)
        "test_1.out > 3" -> SimpleCondition("test_1.out", ">", 3)
        "sig_a != sig_b" -> SimpleCondition("sig_a", "!=", "sig_b")
        "out > `THRESHOLD" -> SimpleCondition("out", ">", "`THRESHOLD")
        "a == (b + 1)" -> SimpleCondition("a", "==", "(b + 1)")
        "((sig & 32'hFF) >> 4) == 2" -> SimpleCondition("((sig & 32'hFF) >> 4)", "==", 2)

    Args:
        condition: A string like "signal_name op value" or "expression op value"

    Returns:
        SimpleCondition object

    Raises:
        ValueError: If the condition cannot be parsed
    """
    condition = condition.strip()

    # Find the comparison operator at the top paren level
    match = _find_top_level_comparison(condition)
    if match is None:
        raise ValueError(
            f"Cannot parse simple condition: {condition}. "
            "Expected format: 'signal op value' or 'signal op signal'"
        )

    op, idx = match
    signal_path = condition[:idx].strip()
    value_str = condition[idx + len(op):].strip()
    logging.debug(f"[ConditionParser] '{condition}' -> LHS='{signal_path}' op='{op}' RHS='{value_str}'")

    if not signal_path or not value_str:
        raise ValueError(
            f"Cannot parse simple condition: {condition}. "
            "Expected format: 'signal op value' or 'signal op signal'"
        )

    # Try to parse RHS as a numeric value first
    try:
        value = parse_value(value_str)
        return SimpleCondition(signal_path, op, value)
    except (ValueError, AttributeError):
        # If parsing as value fails, treat as signal path or expression
        # Accept: signal names, hierarchical paths, backtick macros, arithmetic expressions
        # Includes: +, -, *, /, <<, >>, &, |, ^, ~, parens, backtick, Verilog literals
        if re.match(r'^[`a-zA-Z_(][\w.\[\]:+\-*/<>&|^~ `()\'h]*$', value_str):
            return SimpleCondition(signal_path, op, value_str)
        else:
            raise ValueError(f"Cannot parse value '{value_str}' in condition: {condition}")


def _has_comparison_operator(text: str) -> bool:
    """Check if text contains a comparison operator (==, !=, >=, <=, >, <)."""
    for op in ['==', '!=', '>=', '<=']:
        if op in text:
            return True
    # Check for bare > or < (not part of >= or <=)
    for i, c in enumerate(text):
        if c == '>' and (i + 1 >= len(text) or text[i + 1] != '='):
            return True
        if c == '<' and (i + 1 >= len(text) or text[i + 1] != '='):
            return True
    return False


def _find_matching_paren(text: str, start: int) -> int:
    """Find the index of the closing ')' matching the '(' at `start`.
    Returns -1 if not found."""
    depth = 1
    i = start + 1
    while i < len(text):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def _has_top_level_logical_op(text: str) -> bool:
    """Check if text contains a top-level (outside parens) logical operator (&&, ||)."""
    depth = 0
    i = 0
    while i < len(text):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
        elif depth == 0 and text[i:i+2] in ('&&', '||'):
            return True
        i += 1
    return False


def _is_arithmetic_paren(condition: str, paren_start: int) -> bool:
    """Determine if the '(' at paren_start is arithmetic (part of an expression
    on the LHS or RHS of a comparison) rather than logical grouping.

    Heuristic: find the matching ')'. If the text *after* the closing paren
    (at the same nesting level) contains a comparison operator before any
    logical operator, then this paren group is the LHS of a comparison —
    i.e. arithmetic, not logical.  Also, if the content inside has no
    top-level logical operators AND no top-level comparison operators, it's
    arithmetic (e.g. "(sig & mask)").
    """
    close = _find_matching_paren(condition, paren_start)
    if close == -1:
        return False

    # Check what follows the closing paren (skip whitespace)
    rest = condition[close + 1:].lstrip()

    # If a comparison operator follows, this whole paren group is the LHS
    # of a comparison — definitely arithmetic.
    for op in ('==', '!=', '>=', '<=', '>', '<'):
        if rest.startswith(op):
            return True

    # If a bitwise/shift/arithmetic operator follows (and eventually a
    # comparison), this paren is part of a larger arithmetic expression.
    # E.g. "(sig & mask) >> 30" which later gets "== 2"
    # We scan the rest for a comparison at depth-0.
    # But exclude logical operators && and ||.
    if rest and rest[0] in ('>', '<', '&', '|', '^', '+', '-', '*', '/'):
        if rest[:2] not in ('&&', '||'):
            if _has_comparison_operator(rest):
                return True

    # Check the content inside the parens
    inner = condition[paren_start + 1:close]
    if not _has_top_level_logical_op(inner) and not _has_comparison_operator_top_level(inner):
        # Pure arithmetic inside (e.g. "sig & mask"), not a logical group
        # But only if there's more after it (otherwise it could be wrapping a condition)
        if rest and rest[0] not in (')', ''):
            return True

    return False


def _has_comparison_operator_top_level(text: str) -> bool:
    """Check if text contains a comparison operator at the top paren level."""
    depth = 0
    i = 0
    while i < len(text):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
        elif depth == 0:
            for op in ('==', '!=', '>=', '<='):
                if text[i:i+len(op)] == op:
                    return True
            if text[i] == '>' and (i + 1 >= len(text) or text[i + 1] != '='):
                # Make sure it's not >>
                if i + 1 < len(text) and text[i + 1] == '>':
                    pass  # This is >>, not a comparison
                else:
                    return True
            if text[i] == '<' and (i + 1 >= len(text) or text[i + 1] != '='):
                if i + 1 < len(text) and text[i + 1] == '<':
                    pass  # This is <<, not a comparison
                else:
                    return True
        i += 1
    return False


def tokenize_condition(condition: str) -> List[str]:
    """
    Tokenize a condition string into tokens.

    Handles: &&, ||, !, (, ), and simple conditions.
    Note: != is part of a comparison operator, not a NOT token.
    Parentheses that are part of arithmetic expressions (e.g. on the LHS
    of a comparison like "(sig & mask) == value") are kept as part of the
    simple-condition token, not split into logical grouping.
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

        # Check for (
        if condition[i] == '(':
            # Determine if this is arithmetic (part of a comparison expression)
            # or logical grouping.
            if _is_arithmetic_paren(condition, i):
                # This paren starts an arithmetic expression that is part of
                # a simple condition. Consume the entire simple condition as
                # one token (including balanced parens up to a logical op).
                j = i
                paren_depth = 0
                while j < len(condition):
                    c = condition[j]
                    if c == '(':
                        paren_depth += 1
                    elif c == ')':
                        paren_depth -= 1
                        if paren_depth < 0:
                            break
                    elif paren_depth == 0:
                        if condition[j:j+2] in ('&&', '||'):
                            break
                        # ! but not !=
                        if c == '!' and (j + 1 >= len(condition) or condition[j+1] != '='):
                            break
                    j += 1
                token = condition[i:j].strip()
                if token:
                    tokens.append(token)
                i = j
                continue
            else:
                tokens.append('(')
                i += 1
                continue

        if condition[i] == ')':
            tokens.append(')')
            i += 1
            continue

        # Read a simple condition token, handling balanced parens within it
        # E.g., "a == (b + 1)" should be one token
        j = i
        paren_depth = 0
        while j < len(condition):
            c = condition[j]

            # Track balanced parentheses within the token
            if c == '(' and paren_depth == 0:
                # Check if we've already seen a comparison operator in this token
                token_so_far = condition[i:j].strip()
                if _has_comparison_operator(token_so_far):
                    # This ( is arithmetic grouping in the RHS, include it
                    paren_depth += 1
                    j += 1
                    continue
                else:
                    # Check if this ( starts an arithmetic sub-expression
                    if _is_arithmetic_paren(condition, j):
                        paren_depth += 1
                        j += 1
                        continue
                    else:
                        # This ( is logical grouping, stop here
                        break
            elif c == '(':
                paren_depth += 1
                j += 1
                continue
            elif c == ')' and paren_depth > 0:
                paren_depth -= 1
                j += 1
                continue
            elif c == ')' and paren_depth == 0:
                break

            # Don't break on operators inside balanced parens
            if paren_depth > 0:
                j += 1
                continue

            # Check for logical operators
            if condition[j:j+2] in ('&&', '||'):
                break
            # Check for ! but not !=
            if c == '!' and (j + 1 >= len(condition) or condition[j+1] != '='):
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
    Extract the base signal name from a hierarchical path or expression.

    Examples:
        "test_1.out" -> "out"
        "u_cpu.u_alu.result" -> "result"
        "rst" -> "rst"
        "ex_insn[31:26]" -> "ex_insn"
        "module.signal[7:0]" -> "signal"
        "((ex_insn & 32'hFC000000) >> 26)" -> "ex_insn"
        "(sig + 1)" -> "sig"

    Args:
        signal_path: A potentially hierarchical signal path, bit-select, or arithmetic expression

    Returns:
        The base signal name (first identifier found)
    """
    # Strip outer parens and whitespace
    signal_path = signal_path.strip()
    while signal_path.startswith('(') and signal_path.endswith(')'):
        signal_path = signal_path[1:-1].strip()

    # Extract all identifiers (signal names) from the expression
    # Match: letter/underscore followed by alphanumeric/underscore/dot
    identifiers = re.findall(r'[a-zA-Z_][\w.]*', signal_path)

    if not identifiers:
        return signal_path  # Fallback to original if no identifiers found

    # Return the first identifier (the primary signal)
    first_id = identifiers[0]

    # Strip bit-select syntax if present
    if '[' in first_id:
        first_id = first_id.split('[')[0]

    # Extract last component if hierarchical
    if '.' in first_id:
        return first_id.split('.')[-1]

    return first_id


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
