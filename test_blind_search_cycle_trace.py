"""Regression tests for per-cycle primary-input refresh in BlindSearchStrategy.

Before this fix, BlindSearchStrategy (the default strategy used when no
--strategy/--value_predict flag is given) minted exactly one Z3 symbol per
primary input for an entire multi-cycle run, so a counterexample looked like
a flat `{'RST': 0}` with no indication of which cycle mattered. The directed/
value-predict strategies, by contrast, mint a fresh `<sig>_cN` symbol every
cycle (see `refresh_primary_inputs` in engine/strategies.py) and format
violations with a per-cycle trace (`format_assertion_violation`).

These tests run the real CLI entry point (`python3 -m main`) as a subprocess
against tiny fixture designs and check the printed counterexample for the
`<sig>_cN` symbol naming convention and the "Counterexample trace
(cycle-by-cycle)" section — the same thing a user reading log.txt would look
for. Subprocess is used (rather than importing main.py's internals) because
main() has no return value and writes results only to stdout.
"""
import os
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))


def _run_main(num_cycles, verilog_src):
    """Write *verilog_src* to a temp file and run `python3 -m main <n> <f> --sv`.

    Returns the combined stdout+stderr text.
    """
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".v", delete=False, dir=REPO_ROOT
    ) as f:
        f.write(verilog_src)
        path = f.name
    try:
        result = subprocess.run(
            [sys.executable, "-m", "main", str(num_cycles), path, "--sv"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=60,
        )
        return result.stdout + result.stderr
    finally:
        os.unlink(path)


SINGLE_CYCLE_VIOLATION_SRC = """
module tiny_viol(
  input CLK,
  input A,
  output reg r
);
  initial r = 0;
  always @(posedge CLK) begin
    r <= A;
    assert (A == 0);
  end
endmodule
"""

MULTI_CYCLE_PER_CYCLE_INPUT_SRC = """
module tiny_viol_percycle(
  input CLK,
  input A,
  output reg [2:0] cnt
);
  initial cnt = 0;
  always @(posedge CLK) begin
    if (A) cnt <= cnt + 1;
    assert (cnt < 3);
  end
endmodule
"""

NON_ASSERTION_REGISTER_SRC = """
module tiny_broadened(
  input CLK,
  input A,
  output reg [3:0] acc,
  output reg flag
);
  initial acc = 0;
  initial flag = 0;
  always @(posedge CLK) begin
    flag <= (acc == 4'd3);
    acc <= acc + A;
    assert (flag == 0);
  end
endmodule
"""


def test_primary_input_symbol_is_cycle_stamped():
    """The violating input's Z3 symbol name must carry a _c<N> cycle suffix.

    Before the fix, BlindSearchStrategy reused one un-stamped symbol for the
    whole run (e.g. a random 16-char string from init_symbol()), so no cycle
    information was ever visible in the counterexample.
    """
    output = _run_main(1, SINGLE_CYCLE_VIOLATION_SRC)
    assert "Assertion violation" in output, f"expected a violation, got:\n{output}"
    assert re.search(r"\bA_c0\b", output), (
        f"expected the primary input 'A' to appear as a cycle-stamped Z3 symbol "
        f"'A_c0', got:\n{output}"
    )


def test_counterexample_trace_is_grouped_by_cycle():
    """A multi-cycle violation must print a 'Cycle N:' line per cycle, each
    with the input value that actually applied that cycle — not one flat,
    ungrouped dict for the whole run.
    """
    output = _run_main(4, MULTI_CYCLE_PER_CYCLE_INPUT_SRC)
    assert "Assertion violation" in output, f"expected a violation, got:\n{output}"
    assert "Counterexample trace (cycle-by-cycle):" in output, (
        f"expected a cycle-by-cycle trace section, got:\n{output}"
    )
    for cycle in range(4):
        assert re.search(rf"Cycle {cycle}:\s*\n\s*A = ", output), (
            f"expected a 'Cycle {cycle}:' line with A's value, got:\n{output}"
        )


def test_counterexample_includes_non_assertion_registers():
    """The trace must surface registers the violated assertion never
    textually mentions (here: `acc`, which only appears via `assert (flag ==
    0)` — `flag`'s guard condition, `acc == 4'd3`, is evaluated inside the
    always block, not inside the assertion text itself).

    Before this fix, `format_assertion_violation` only back-filled signals
    matched against `_assertion_signals` (identifiers regex-parsed out of
    the violated assertion's condition string), so `acc` never appeared even
    though it's the register driving the violation.
    """
    output = _run_main(5, NON_ASSERTION_REGISTER_SRC)
    assert "Assertion violation" in output, f"expected a violation, got:\n{output}"
    assert re.search(r"\bacc = ", output), (
        f"expected the non-assertion register 'acc' to appear in the "
        f"counterexample trace, got:\n{output}"
    )


if __name__ == "__main__":
    test_primary_input_symbol_is_cycle_stamped()
    print("PASS: primary input symbol is cycle-stamped")
    test_counterexample_trace_is_grouped_by_cycle()
    print("PASS: counterexample trace is grouped by cycle")
    test_counterexample_includes_non_assertion_registers()
    print("PASS: counterexample includes non-assertion registers")
    print("\nAll blind-search cycle-trace tests passed.")
