"""Regression test for SMT query double-counting in solve_pc.

Before this fix, `helpers/rvalue_to_z3.py::solve_pc(s)` wrapped its solver
check in `smt_stats.timed_check(s)`. Every real call site passes a
`_LazyPC` (engine/symbolic_state.py) as `s`, whose own `check()` method
already calls `smt_stats.timed_check(self._build_solver())` internally.
Since `_LazyPC` duck-types `.assertions()`/`.check()`, the outer
`timed_check(lazy_pc)` call re-entered `_LazyPC.check()`, triggering the
already-instrumented inner check — so one logical SAT/UNSAT check
incremented `smt_stats.query_count` by 2 and printed two
`[Z3-QUERY #N]`/`[Z3-RESULT #N]` pairs instead of one (see
docs/analysis_0724_additional_findings.md, section 5).

The fix makes `solve_pc` call `s.check()` directly, letting `_LazyPC.check()`
be the sole place that increments the counter.
"""
import contextlib
import io

import z3

from engine.symbolic_state import SymbolicState, smt_stats
from helpers.rvalue_to_z3 import solve_pc


def test_solve_pc_counts_once():
    """A single solve_pc() call on a trivially SAT path condition must
    increment smt_stats.query_count by exactly 1 and print exactly one
    Z3-QUERY/Z3-RESULT pair — not two.
    """
    state = SymbolicState()
    state.pc.add(z3.BitVec("x", 8) == 3)  # trivially SAT

    before = smt_stats.query_count
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        result = solve_pc(state.pc)
    after = smt_stats.query_count

    assert result is True, f"expected SAT, got {result}"
    assert after - before == 1, (
        f"expected query_count to increase by exactly 1, got {after - before}"
    )
    out = buf.getvalue()
    assert out.count("[Z3-QUERY #") == 1, (
        f"expected exactly one [Z3-QUERY #...] line, got:\n{out}"
    )
    assert out.count("[Z3-RESULT #") == 1, (
        f"expected exactly one [Z3-RESULT #...] line, got:\n{out}"
    )


def test_solve_pc_returns_false_on_unsat():
    """Sanity check: the UNSAT path must still return False and count once."""
    state = SymbolicState()
    x = z3.BitVec("y", 8)
    state.pc.add(x == 3)
    state.pc.add(x == 4)  # contradiction

    before = smt_stats.query_count
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        result = solve_pc(state.pc)
    after = smt_stats.query_count

    assert result is False, f"expected UNSAT, got {result}"
    assert after - before == 1, (
        f"expected query_count to increase by exactly 1, got {after - before}"
    )


if __name__ == "__main__":
    test_solve_pc_counts_once()
    print("PASS: solve_pc increments query_count by exactly 1 (SAT case)")
    test_solve_pc_returns_false_on_unsat()
    print("PASS: solve_pc increments query_count by exactly 1 (UNSAT case)")
    print("\nAll solve_pc single-count tests passed.")
