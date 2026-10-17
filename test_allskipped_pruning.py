"""Regression test for the AllSkipped implicit stutter-cycle bug.

Before this fix, `_DirectedSearchBase._execute_cycle` (engine/strategies.py)
special-cased the non-forked ("preferred-path") WorkItem when every CFG's
every path was abandoned for infeasibility this cycle: forked items got
pruned (`return None`), but the preferred-path item fell through to
`_execute_cycle_tail`, which unconditionally advances to `cycle + 1` and
enqueues a new WorkItem — even though no clocked transition actually
happened. This silently produced a cycle with no RTL semantics: the cycle
counter advanced, but registers never updated, and that cycle's already-
minted primary-input symbol (refreshed at the top of `_execute_cycle` before
the abandon was detected) was orphaned, skewing later cycle-stamped symbol
numbering (see docs/analysis_0724_additional_findings.md, section 4).

The fix removes the special case: "all CFGs abandoned" is pruned uniformly
regardless of whether the WorkItem is forked, since every alternative
direction at every prior branch point is already a separate queued WorkItem
by the time lazy forking reaches this point.

This test drives `_execute_cycle` directly (bypassing the full
`execute_sv` pipeline) the same way test_value_predictor.py and
test_cfg_leaf_threading.py build minimal CFG/state/manager objects, so the
"every path abandoned" condition can be forced deterministically instead of
relying on an end-to-end fixture where cross-cycle path-condition
accumulation makes it hard to script reliably.
"""
import pyslang as ps
import z3

from engine.cfg import CFG
from engine.execution_manager import ExecutionManager
from engine.symbolic_state import SymbolicState
from engine.strategies import MilestoneDirectedStrategy, WorkItem
from engine.milestone import MilestoneManager
from helpers.slang_helpers import SymbolicDFS
from helpers.rvalue_to_z3 import parse_expr_to_Z3


CONTRADICTION_SRC = """
module tiny_contradiction(
  input CLK,
  output reg [7:0] r
);
  always @(posedge CLK) begin
    if (r == 8'd1) r <= 10;
    else r <= 20;
  end
endmodule
"""


def _build_strategy_and_cfg(r_value):
    """Build a MilestoneDirectedStrategy plus a single-always-block CFG for
    `tiny_contradiction`, with `r` concretely fixed to *r_value*.

    Fixing `r` to a concrete value makes exactly one of the two branch
    guards (`r == 1`) satisfiable and the other trivially false, so we can
    force "every path abandoned" (r_value != 1, both directions abandon:
    `r==1` is UNSAT and its negation on the other path is a no-op that
    still requires the *other* path's own guard to hold — see the two path
    directions below) or "one path succeeds" (r_value == 1) on demand.
    """
    tree = ps.SyntaxTree.fromText(CONTRADICTION_SRC)
    comp = ps.Compilation()
    comp.addSyntaxTree(tree)
    root = comp.getRoot()
    top = root.topInstances[0]

    manager = ExecutionManager()
    manager.sv = True
    manager.curr_module = "tiny_contradiction"
    manager.names_list = ["tiny_contradiction"]
    state = SymbolicState()
    state.store["tiny_contradiction"] = {
        "r": z3.BitVecVal(r_value, 8),
        "CLK": z3.BitVecVal(0, 1),
    }

    probe = CFG()
    probe.get_always_sv(manager, state, top)
    ab = probe.always_blocks[0]
    ab_body = getattr(ab, "statement", getattr(ab, "members", ab))
    cfg = CFG()
    cfg.module_name = "tiny_contradiction"
    cfg.basic_blocks_sv(manager, state, ab_body)
    cfg.partition()
    cfg.build_cfg(manager, state)
    cfg.comb = probe.comb

    cfgs_by_module = {"tiny_contradiction": [cfg]}
    modules_dict = {"tiny_contradiction": top}

    visitor = SymbolicDFS(1)
    visitor.expr_to_z3 = lambda m, s, e: parse_expr_to_Z3(e, s, m)

    strategy = MilestoneDirectedStrategy(MilestoneManager([]))
    strategy._comb_by_module = {}
    strategy._wire_groups = []
    strategy._primary_input_flags = []
    strategy._wire_group_widths = []
    strategy._primary_input_ports = {}
    strategy._sorted_comb_by_module = strategy._topo_sort_comb(cfgs_by_module, manager)
    strategy._sorted_comb_modules = [
        n for n in manager.names_list if strategy._sorted_comb_by_module.get(n)
    ]
    strategy._comb_downstream = strategy._build_comb_downstream_map(manager)
    strategy._comb_node_reads = {}
    strategy._comb_input_snapshot = {}
    strategy._comb_mod_cache_eligible = set()
    strategy._comb_mod_cache = {}

    return strategy, visitor, modules_dict, cfgs_by_module, manager, state


def test_preferred_path_item_prunes_when_all_cfgs_abandoned():
    """r fixed to 5 makes path 0's guard (`r == 1`) UNSAT — the sole CFG's
    chosen (preferred, non-forked) path is abandoned. Before the fix this
    silently advanced to cycle 2 via `_execute_cycle_tail`; now it must
    prune, returning (None, ...) with nothing pushed to the worklist.
    """
    strategy, visitor, modules_dict, cfgs_by_module, manager, state = (
        _build_strategy_and_cfg(r_value=5)
    )
    item = WorkItem(
        score=0, cycle=1, milestones_completed=0, state=state,
        execution_context={
            'remaining_cfgs': [
                {'module': 'tiny_contradiction', 'cfg_idx': 0, 'path_idx': 0}
            ]
        },
    )
    worklist = []
    result = strategy._execute_cycle(
        None, visitor, modules_dict, cfgs_by_module, manager, item, worklist
    )
    assert result == (None, 0), (
        f"expected the item to be pruned as (None, 0), got {result}"
    )
    assert len(worklist) == 0, (
        f"expected no new WorkItem to be enqueued (no implicit cycle "
        f"advance), got {len(worklist)} queued"
    )


def test_forked_item_still_prunes_when_all_cfgs_abandoned():
    """Same scenario but with `forked=True` — must prune identically,
    confirming the fix didn't just rename the forked-item behavior but
    genuinely unified both cases.
    """
    strategy, visitor, modules_dict, cfgs_by_module, manager, state = (
        _build_strategy_and_cfg(r_value=5)
    )
    item = WorkItem(
        score=0, cycle=1, milestones_completed=0, state=state,
        execution_context={
            'remaining_cfgs': [
                {'module': 'tiny_contradiction', 'cfg_idx': 0, 'path_idx': 0,
                 'forked': True}
            ]
        },
    )
    worklist = []
    result = strategy._execute_cycle(
        None, visitor, modules_dict, cfgs_by_module, manager, item, worklist
    )
    assert result == (None, 0), f"expected pruning, got {result}"
    assert len(worklist) == 0, f"expected empty worklist, got {len(worklist)}"


def test_feasible_path_still_executes_and_advances():
    """Sanity check: when the chosen path IS feasible (r=5, else-branch
    `r != 1` holds), the cycle must still execute normally — the fix must
    not have broken the ordinary, non-abandoned case.
    """
    strategy, visitor, modules_dict, cfgs_by_module, manager, state = (
        _build_strategy_and_cfg(r_value=5)
    )
    item = WorkItem(
        score=0, cycle=1, milestones_completed=0, state=state,
        execution_context={
            'remaining_cfgs': [
                # path_idx=1 is the else-branch (direction [0, 0]); its
                # guard `r != 1` is satisfied by r=5, so it executes.
                {'module': 'tiny_contradiction', 'cfg_idx': 0, 'path_idx': 1}
            ]
        },
    )
    worklist = []
    result = strategy._execute_cycle(
        None, visitor, modules_dict, cfgs_by_module, manager, item, worklist
    )
    assert result[0] == 'ALL_MILESTONES', (
        f"expected ALL_MILESTONES (empty milestone list is trivially "
        f"satisfied once a cycle executes), got {result}"
    )


if __name__ == "__main__":
    test_preferred_path_item_prunes_when_all_cfgs_abandoned()
    print("PASS: preferred-path item prunes when all CFGs abandoned")
    test_forked_item_still_prunes_when_all_cfgs_abandoned()
    print("PASS: forked item still prunes when all CFGs abandoned")
    test_feasible_path_still_executes_and_advances()
    print("PASS: feasible path still executes normally")
    print("\nAll AllSkipped-pruning tests passed.")
