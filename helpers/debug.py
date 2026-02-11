"""Centralized debug logging utility."""

# Global debug flag - set via main.py --debug/-B flag
DEBUG_ENABLED = False


def set_debug(enabled: bool):
    """Enable or disable debug output."""
    global DEBUG_ENABLED
    DEBUG_ENABLED = enabled


def debug_print(tag: str, message: str):
    """Print debug message if debug mode is enabled.

    Args:
        tag: Debug tag (e.g., "build_cfg", "rvalue_to_z3")
        message: Debug message to print
    """
    if DEBUG_ENABLED:
        print(f"[DEBUG {tag}] {message}")
