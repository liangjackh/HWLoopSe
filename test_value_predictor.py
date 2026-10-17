"""Unit tests for the multi-cycle value predictor (thesis §4.2).

Validates that ValuePredictor.classify_branches resolves branch directions
correctly given a controlled symbolic state, using a real PySlang-parsed
design so the dependency analyzer and expression evaluator run end-to-end.
"""
import z3

from engine.symbolic_state import SymbolicState
from engine.execution_manager import ExecutionManager
from engine.value_predictor import ValuePredictor, FORCED_TRUE, FORCED_FALSE, FREE
from frontend.dep_analyzer import DependencyAnalyzer


FSM_SRC = """
module fsm(
    input logic clk,
    input logic rst_n,
    input logic go,
    output logic [1:0] state
);
    logic [1:0] state_reg;
    logic [1:0] next_state;

    always_comb begin
        next_state = state_reg;
        if (state_reg == 2'd0) begin
            if (go) next_state = 2'd1;
        end else if (state_reg == 2'd1) begin
            next_state = 2'd2;
        end else begin
            next_state = 2'd0;
        end
    end

    assign state = state_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_reg <= 2'd0;
        else
            state_reg <= next_state;
    end
endmodule
"""


def _build_cfgs(src):
    """Parse *src* and build CFGs the same way the engine does."""
    import pyslang as ps
    from engine.cfg import CFG

    tree = ps.SyntaxTree.fromText(src)
    comp = ps.Compilation()
    comp.addSyntaxTree(tree)
    root = comp.getRoot()

    manager = ExecutionManager()
    state = SymbolicState()

    cfgs_by_module = {}
    comb_by_module = {}
    modules_dict = {}
    instance = "fsm"
    manager.curr_module = instance
    manager.names_list = []

    for member in root.topInstances:
        # Mirror the engine's CFG build sequence (execution_engine.execute_sv).
        probe = CFG()
        probe.get_always_sv(manager, state, member)

        cfg_list = []
        for ab in probe.always_blocks:
            ab_body = getattr(ab, "statement", getattr(ab, "members", ab))
            c = CFG()
            c.module_name = instance
            if hasattr(ab, 'kind') and str(ab.kind) == 'SyntaxKind.InitialBlock':
                c.is_initial = True
            c.basic_blocks_sv(manager, state, ab_body)
            c.partition()
            c.build_cfg(manager, state)
            c.comb = probe.comb
            cfg_list.append(c)

        cfgs_by_module[instance] = cfg_list
        comb_by_module[instance] = probe.comb
        modules_dict[instance] = member
        manager.names_list.append(instance)
        state.store.setdefault(instance, {})

    return cfgs_by_module, comb_by_module, modules_dict, manager


def _make_state(state_reg_val):
    """A symbolic state with state_reg fixed to a concrete 2-bit value."""
    s = SymbolicState()
    s.store["fsm"] = {
        "clk": z3.BitVecVal(0, 1),
        "rst_n": z3.BitVecVal(1, 1),
        "go": z3.BitVec("go_c1", 1),      # symbolic primary input
        "state_reg": z3.BitVecVal(state_reg_val, 2),
        "next_state": z3.BitVecVal(0, 2),
        "state": z3.BitVecVal(0, 2),
    }
    return s


def test_predictor_resolves_state_branches():
    cfgs, comb, mods, manager = _build_cfgs(FSM_SRC)
    dep = DependencyAnalyzer(cfgs, comb_by_module=comb, modules_dict=mods).analyze()
    assert len(dep.all_branches) >= 2, "expected multiple branches"

    predictor = ValuePredictor(dep, manager)

    # With state_reg == 0: the "state_reg == 0" guard must be forced true,
    # and "state_reg == 1" must be forced false.
    s0 = _make_state(0)
    verdicts0 = predictor.classify_branches(s0, cycle=1)

    by_reads = {}
    for br_id, v in verdicts0.items():
        br = dep.nodes_by_id[br_id]
        # only capture guards that read state_reg (skip go / rst_n)
        if br.reads == {"state_reg"}:
            by_reads[br_id] = (br, v)

    # There should be at least one forced_true and one forced_false among
    # the state_reg-dependent guards when state_reg == 0.
    verds = [v for (_, v) in by_reads.values()]
    assert FORCED_TRUE in verds, f"expected a forced_true guard, got {verds}"
    assert FORCED_FALSE in verds, f"expected a forced_false guard, got {verds}"

    # The `if (go)` branch reads the symbolic input `go` and must be FREE.
    go_branches = [v for br_id, v in verdicts0.items()
                   if dep.nodes_by_id[br_id].reads == {"go"}]
    assert go_branches, "expected a branch reading `go`"
    assert all(v == FREE for v in go_branches), \
        f"go-gated branch should be free, got {go_branches}"

    print("PASS: predictor resolves state_reg branches and keeps go-gated branch free")


def test_predictor_flips_with_state():
    cfgs, comb, mods, manager = _build_cfgs(FSM_SRC)
    dep = DependencyAnalyzer(cfgs, comb_by_module=comb, modules_dict=mods).analyze()
    predictor = ValuePredictor(dep, manager)

    # Identify a guard that reads state_reg and is forced_true at state_reg==0.
    s0 = _make_state(0)
    v0 = predictor.classify_branches(s0, cycle=1)
    target = None
    for br_id, v in v0.items():
        if dep.nodes_by_id[br_id].reads == {"state_reg"} and v == FORCED_TRUE:
            target = br_id
            break
    assert target is not None, "no forced_true state_reg guard at state_reg==0"

    # At state_reg==1 the same guard (state_reg==0) must no longer be forced true.
    s1 = _make_state(1)
    v1 = predictor.classify_branches(s1, cycle=1)
    assert v1.get(target) != FORCED_TRUE, \
        "guard should change resolution when state_reg changes"

    print("PASS: predictor verdict flips when register value changes")


def test_value_predict_strategy_selection():
    """value_predict without milestones selects the value-predict directed strategy."""
    from engine.config import EngineConfig
    from engine.strategy_factory import StrategyFactory
    from engine.strategies import ValuePredictDirectedStrategy, BlindSearchStrategy

    # value_predict on, no milestone file, no auto-plan, default (blind) strategy
    cfg = EngineConfig(num_cycles=4, value_predict=True, strategy="blind")
    strat = StrategyFactory.create(cfg)
    assert isinstance(strat, ValuePredictDirectedStrategy), \
        "value_predict without milestones should use the value-predict directed strategy"
    assert not hasattr(strat, 'milestone_manager'), \
        "value-predict strategy must not carry milestone-directed state"
    assert strat.enable_value_prediction is True

    # value_predict off, no milestone: unchanged -> blind
    cfg_off = EngineConfig(num_cycles=4, value_predict=False, strategy="blind")
    strat_off = StrategyFactory.create(cfg_off)
    assert isinstance(strat_off, BlindSearchStrategy), \
        "without value_predict, blind strategy must be unchanged"

    # value_predict on WITH milestone file: not value-predict-only (directed path
    # builds its own MilestoneDirectedStrategy downstream; factory must not
    # force the value-predict strategy)
    cfg_ms = EngineConfig(num_cycles=4, value_predict=True, strategy="blind",
                          milestone_file="milestones.json")
    strat_ms = StrategyFactory.create(cfg_ms)
    assert isinstance(strat_ms, BlindSearchStrategy), \
        "with a milestone file, factory keeps default; strategy is rebuilt later"

    print("PASS: value-predict strategy selection is correct")


def test_symbol_legend_mapping():
    """Violation legend maps free Z3 symbols back to module.signal names."""
    import z3
    from helpers.utils import build_symbol_to_signals, collect_z3_symbols

    class _FakeState:
        store = {
            "vp_fsm": {
                "RST": z3.BitVec("uxMFYVkKVKrpOB4c", 1),   # random init symbol
                "in_a": z3.BitVec("in_a_c2", 8),           # refreshed cycle input
            }
        }

    state = _FakeState()
    mapping = build_symbol_to_signals(state)
    assert mapping.get("uxMFYVkKVKrpOB4c") == ["vp_fsm.RST"]
    assert mapping.get("in_a_c2") == ["vp_fsm.in_a"]

    rst = z3.BitVec("uxMFYVkKVKrpOB4c", 1)
    ina = z3.BitVec("in_a_c2", 8)
    unknown = z3.BitVec("nosuchsym", 4)
    syms = collect_z3_symbols([z3.Not(rst == 0), ina == 5, unknown == 1])
    assert syms == {"uxMFYVkKVKrpOB4c", "in_a_c2", "nosuchsym"}

    # Unmatched symbol must not appear in the reverse map (printed as unmapped).
    assert "nosuchsym" not in mapping

    print("PASS: symbol legend maps symbols back to signals")


if __name__ == "__main__":
    test_predictor_resolves_state_branches()
    test_predictor_flips_with_state()
    test_value_predict_strategy_selection()
    test_symbol_legend_mapping()
    print("\nAll value predictor tests passed.")
