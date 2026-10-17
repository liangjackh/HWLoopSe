"""Regression tests for CFG leaf-threading (engine/cfg.py).

Guards against the false-positive class of bug where basic_blocks_sv used
curr_idx - 1 (or a branch node's own index) as a stand-in for "the real
predecessor/successor in this statement list". That heuristic breaks
whenever a sibling statement is itself a multi-arm conditional/case, letting
paths (a) jump between mutually exclusive branches of an enclosing if/else,
or (b) skip a whole if-elif chain without committing to any of its arms, or
(c) miss a trailing statement (like an assert) that should be reachable from
every branch. See docs/analysis_0724_additional_findings.md for the full
root-cause writeup on designs/test-designs/test_vp_fsm.v.
"""
import pyslang as ps

from engine.cfg import CFG
from engine.execution_manager import ExecutionManager
from engine.symbolic_state import SymbolicState


def _build_cfg_list(src, instance_name="x"):
    """Parse *src* and build the list of CFG objects for its first instance."""
    tree = ps.SyntaxTree.fromText(src)
    comp = ps.Compilation()
    comp.addSyntaxTree(tree)
    root = comp.getRoot()
    top = root.topInstances[0]

    manager = ExecutionManager()
    manager.sv = True
    state = SymbolicState()

    probe = CFG()
    probe.get_always_sv(manager, state, top)

    cfg_list = []
    for ab in probe.always_blocks:
        ab_body = getattr(ab, "statement", getattr(ab, "members", ab))
        c = CFG()
        c.module_name = instance_name
        c.basic_blocks_sv(manager, state, ab_body)
        c.partition()
        c.build_cfg(manager, state)
        cfg_list.append(c)
    return cfg_list


VP_FSM_SRC = """
module vp_fsm (
  input  CLK,
  input  RST,
  output reg [2:0] state,
  output reg       at_three
);
  always @(posedge CLK) begin
    if (RST) begin
      state    <= 0;
      at_three <= 0;
    end else begin
      if (state == 3'd0)      state <= 3'd1;
      else if (state == 3'd1) state <= 3'd2;
      else if (state == 3'd2) state <= 3'd3;
      else                    state <= 3'd0;

      if (state == 3'd3) at_three <= 1;
      else               at_three <= 0;
    end
    assert (at_three == 0);
  end
endmodule
"""


def _find_node_idx(cfg, predicate, class_name=None):
    """Return the first all_nodes index whose str() matches predicate, or None.

    str() on a syntax node renders its *entire* subtree, so a substring match
    against a container node (e.g. the whole `if (RST) begin...end` statement)
    can spuriously match text that actually belongs to a nested leaf. Passing
    class_name restricts the search to nodes of that exact PySlang syntax
    kind, so callers can target a specific leaf statement unambiguously.
    """
    for idx, node in enumerate(cfg.all_nodes):
        if node is None:
            continue
        if class_name is not None and node.__class__.__name__ != class_name:
            continue
        if predicate(str(node)):
            return idx
    return None


def test_vp_fsm_rst_branch_does_not_leak_into_else_branch():
    """The RST=1 branch must never flow into the else-branch's state logic.

    Bug A wired the RST-then body's last statement directly into the
    else-branch's if-elif chain head via a curr_idx - 1 heuristic. After the
    fix, the RST-then body's leaves may only feed into the trailing assert
    (the always-block's next real sibling), never into the else-branch.
    """
    cfg_list = _build_cfg_list(VP_FSM_SRC)
    always_ff = cfg_list[-1]

    rst_then_leaf = _find_node_idx(
        always_ff, lambda s: s.strip() == "at_three <= 0;", class_name="ExpressionStatementSyntax"
    )
    assert rst_then_leaf is not None, "could not locate RST-then body leaf node"

    else_if_head = _find_node_idx(
        always_ff,
        lambda s: "3'd0)" in s and "RST" not in s,
        class_name="ConditionalStatementSyntax",
    )
    assert else_if_head is not None, "could not locate else-branch if-elif head node"

    illegal_edges = [e for e in always_ff.edgelist if e == (rst_then_leaf, else_if_head)]
    assert not illegal_edges, (
        f"RST-then branch illegally wired into else-branch logic: {illegal_edges}"
    )


def test_vp_fsm_all_state_arms_reach_second_conditional():
    """Every arm of the 4-way state if-elif chain must reach the second,
    independent `if (state == 3'd3)` conditional — not just whichever arm
    happened to be processed last (Bug B: sibling conditionals were wired
    head-to-head instead of leaf-to-head).
    """
    cfg_list = _build_cfg_list(VP_FSM_SRC)
    always_ff = cfg_list[-1]

    # str() on a syntax node renders its whole subtree, so a plain substring
    # search would also match the outer if(RST) node (which contains this
    # text nested inside its else-branch). Anchor on the node's own leading
    # text via strip().startswith() to get the exact node, not an ancestor.
    second_if_head = _find_node_idx(
        always_ff,
        lambda s: s.strip().startswith("if (state == 3'd3)"),
        class_name="ConditionalStatementSyntax",
    )
    assert second_if_head is not None

    # Each of the 4 arms in the state if-elif chain ends with `state <= 3'dN;`
    # — a BinaryExpressionSyntax node immediately followed by its terminating
    # `;` Token, which is the actual leaf node in all_nodes/edgelist.
    arm_binexpr_predicates = [
        lambda s: "3'd1" in s and "state <=" in s,
        lambda s: "3'd2" in s and "state <=" in s,
        lambda s: "3'd3" in s and "state <=" in s,
        lambda s: "3'd0" in s and "state <=" in s,
    ]
    arm_leaves = []
    for p in arm_binexpr_predicates:
        binexpr_idx = _find_node_idx(always_ff, p, class_name="BinaryExpressionSyntax")
        assert binexpr_idx is not None, f"missing arm BinaryExpressionSyntax for {p}"
        token_idx = binexpr_idx + 1
        assert always_ff.all_nodes[token_idx].__class__.__name__ == "Token", (
            f"expected terminating Token right after arm binexpr at {binexpr_idx}"
        )
        arm_leaves.append(token_idx)

    incoming = {e[0] for e in always_ff.edgelist if e[1] == second_if_head}
    for leaf in arm_leaves:
        assert leaf in incoming, (
            f"state-arm leaf {leaf} has no edge into the second conditional "
            f"(incoming edges: {incoming})"
        )


def test_vp_fsm_assert_reachable_from_every_path():
    """The trailing assert must be reachable from every top-level path,
    including the `at_three <= 1` arm (Bug: that arm previously had zero
    outgoing edges and connected straight to the dummy exit, silently
    skipping the assert on that path — a false-negative risk).
    """
    cfg_list = _build_cfg_list(VP_FSM_SRC)
    always_ff = cfg_list[-1]

    assert_block_idx = None
    for bidx, block in enumerate(always_ff.basic_block_list):
        if any(n is not None and "assert" in str(n) for n in block):
            assert_block_idx = bidx
            break
    assert assert_block_idx is not None, "could not locate assert's basic block"

    for path in always_ff.paths:
        assert assert_block_idx in path, f"path {path} never reaches the assert block"


NESTED_IFS_SRC = """
module test_nested_ifs (
  input CLK,
  input RST,
  input [1:0] sel,
  output reg [31:0] out
);
  always @(posedge CLK) begin
    if (RST) begin
      out <= 0;
    end
    else begin
      if (sel == 0) begin
        out <= 1;
      end
      if (sel == 1) begin
        out <= 2;
      end
      if (sel == 2) begin
        out <= 3;
      end
    end
  end
endmodule
"""


def test_nested_ifs_full_combination_coverage():
    """Three independent sibling `if`s each with only a then-branch (implicit
    empty else) must yield all 2^3 = 8 combinations reachable via the
    else-branch, plus the RST=1 path — 9 total. Before the fix, Bug B's
    head-to-head wiring meant some combinations were unreachable (only 7
    paths existed).
    """
    cfg_list = _build_cfg_list(NESTED_IFS_SRC)
    always_ff = cfg_list[-1]
    assert len(always_ff.paths) == 9, (
        f"expected 9 paths (1 RST + 8 sel combinations), got {len(always_ff.paths)}: "
        f"{always_ff.paths}"
    )


if __name__ == "__main__":
    test_vp_fsm_rst_branch_does_not_leak_into_else_branch()
    print("PASS: RST branch does not leak into else-branch")
    test_vp_fsm_all_state_arms_reach_second_conditional()
    print("PASS: all state arms reach the second conditional")
    test_vp_fsm_assert_reachable_from_every_path()
    print("PASS: assert reachable from every path")
    test_nested_ifs_full_combination_coverage()
    print("PASS: nested ifs full combination coverage")
    print("\nAll CFG leaf-threading tests passed.")
