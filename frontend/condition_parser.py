"""Parse condition strings into components for Milestone creation."""

import re
from typing import Tuple, Optional


def parse_condition(condition: str) -> Tuple[str, str, int]:
    """
    Parse a condition string into (signal_path, operator, value).

    Examples:
        "rst == 1" -> ("rst", "==", 1)
        "test_1.out > 3" -> ("test_1.out", ">", 3)
        "u_fifo.cnt >= 10" -> ("u_fifo.cnt", ">=", 10)
        "overflow != 0" -> ("overflow", "!=", 0)

    Args:
        condition: A string like "signal_name op value"

    Returns:
        Tuple of (signal_path, operator, value)

    Raises:
        ValueError: If the condition cannot be parsed
    """
    # Supported operators (order matters - check longer ones first)
    operators = ['==', '!=', '>=', '<=', '>', '<']

    condition = condition.strip()

    for op in operators:
        if op in condition:
            parts = condition.split(op)
            if len(parts) == 2:
                signal_path = parts[0].strip()
                value_str = parts[1].strip()

                # Parse value (support hex, binary, decimal)
                try:
                    if value_str.startswith("0x") or value_str.startswith("0X"):
                        value = int(value_str, 16)
                    elif value_str.startswith("0b") or value_str.startswith("0B"):
                        value = int(value_str, 2)
                    elif value_str.startswith("'h"):
                        # Verilog hex format
                        value = int(value_str[2:], 16)
                    elif value_str.startswith("'b"):
                        # Verilog binary format
                        value = int(value_str[2:], 2)
                    else:
                        value = int(value_str)
                except ValueError:
                    raise ValueError(f"Cannot parse value '{value_str}' in condition: {condition}")

                return (signal_path, op, value)

    raise ValueError(f"Cannot parse condition: {condition}. Expected format: 'signal op value'")


def extract_signal_name(signal_path: str) -> str:
    """
    Extract the base signal name from a hierarchical path.

    Examples:
        "test_1.out" -> "out"
        "u_cpu.u_alu.result" -> "result"
        "rst" -> "rst"

    Args:
        signal_path: A potentially hierarchical signal path

    Returns:
        The base signal name (last component)
    """
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
