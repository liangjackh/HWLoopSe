"""Multi-cycle register value predictor (thesis §4.2, Algorithm 5).

Given a design's static dependency analysis (see frontend/dep_analyzer.py) and
the symbolic state at the end of cycle *t* (whose ``pending_nba`` queue holds
the register updates that take effect at *t+1*), this module predicts the
branch conditions that will be evaluated at cycle *t+1* — WITHOUT running a
full symbolic execution of the next cycle.

Core idea (Algorithm 5, updateMem):
    1. Build a scratch store = current store with ``pending_nba`` applied, so
       registers already hold their *t+1* values.
    2. For each branch, walk its CycDSet in topological order and recompute the
       combinational (blocking) nodes it depends on — these now evaluate over
       *t+1* register values (idempotent, so a shared scratch is safe).
    3. Evaluate the branch's condition over the scratch store → the symbolic
       predicate that will guard that branch at *t+1*.

We deliberately do NOT replay NBA nodes during the walk: applying
``pending_nba`` once already advanced every assigned register to its *t+1*
value, and replaying an NBA (whose RHS reads a just-recomputed comb signal)
would incorrectly compute the *t+2* value. This is the semantically correct
reading of "updateMem" for a synchronous design and keeps combinational
re-evaluation idempotent across branches.

The predictor is intentionally CONSERVATIVE: any branch whose condition cannot
be evaluated (unsupported form, evaluation error) is simply omitted. Downstream
consumers treat a predicted constraint as a *necessary* condition and always
retain a normally-executed WorkItem as a completeness backstop, so omissions
only cost pruning opportunities — never soundness.
"""

from typing import Dict, Optional, Tuple, Any

import z3

from helpers.rvalue_to_z3 import parse_expr_to_Z3, solve_pc
from helpers.slang_helpers import coerce_to_bool


# Per-branch resolution verdict under the current path condition.
FORCED_TRUE = 'forced_true'      # pc ⇒ cond   (branch must take the true edge)
FORCED_FALSE = 'forced_false'    # pc ⇒ ¬cond  (branch must take the false edge)
FREE = 'free'                    # both directions feasible


class ValuePredictor:
    """Predicts next-cycle branch conditions from static dependency sets."""

    def __init__(self, dep_result, manager, parse_fn=parse_expr_to_Z3,
                 refresh_inputs_fn=None):
        """
        Args:
            dep_result: DepAnalysisResult from DependencyAnalyzer.analyze()
            manager: ExecutionManager (used for curr_module context during eval)
            parse_fn: expression→Z3 converter (injectable for testing)
            refresh_inputs_fn: optional callable(scratch_state, cycle) that
                assigns fresh per-cycle symbols to primary inputs on the scratch
                store — mirrors the executor's cycle-start input refresh so that
                input-gated branches are correctly seen as free rather than
                being resolved against stale previous-cycle input values.
        """
        self.dep = dep_result
        self.manager = manager
        self._parse = parse_fn
        self._refresh_inputs = refresh_inputs_fn

    # ------------------------------------------------------------------
    # Scratch store construction
    # ------------------------------------------------------------------

    def _build_scratch_state(self, state, cycle: int):
        """Clone *state* and apply its pending NBA queue (advance to t+1).

        Returns a cloned SymbolicState whose store holds next-cycle register
        values. The clone's path condition is carried over so the caller can
        reuse it for feasibility checks.
        """
        scratch = state.clone()
        # Apply the non-blocking queue in place: registers advance to t+1.
        for module_name, updates in state.pending_nba.items():
            if module_name not in scratch.store:
                scratch.store[module_name] = {}
            for var_name, value in updates.items():
                scratch.store[module_name][var_name] = value
        # The scratch's own pending queue is now consumed.
        scratch.pending_nba = {}
        # Refresh primary inputs to fresh t+1 symbols so input-gated branches
        # are not spuriously resolved against stale previous-cycle input values.
        if self._refresh_inputs is not None:
            try:
                self._refresh_inputs(scratch, cycle)
            except Exception:
                pass
        return scratch

    def _eval_on(self, ast_node, scratch, instance):
        """Evaluate an expression node over the scratch store for *instance*."""
        saved = getattr(self.manager, 'curr_module', None)
        try:
            self.manager.curr_module = instance
            return self._parse(ast_node, scratch, self.manager)
        finally:
            self.manager.curr_module = saved

    def _update_mem(self, node, scratch):
        """updateMem(node.lhs): recompute a blocking/comb node over scratch.

        Evaluates the node's RHS and writes the result to the LHS signal in the
        scratch store, mirroring the executor's blocking-assignment semantics.
        """
        if not node.lhs:
            return
        rhs = getattr(node.ast, 'right', None)
        if rhs is None:
            # Declarator/continuous form stored the RHS directly as node.ast
            rhs = node.ast
        try:
            val = self._eval_on(rhs, scratch, node.instance)
        except Exception:
            return
        if val is None:
            return
        scratch.store.setdefault(node.instance, {})[node.lhs] = val

    # ------------------------------------------------------------------
    # Branch condition prediction
    # ------------------------------------------------------------------

    def predict_branch_conditions(self, state, cycle: int) -> Dict[int, Any]:
        """Predict the t+1 guard expression for every analyzable branch.

        Returns a dict branch_node_id -> Z3 boolean expression. Branches whose
        condition cannot be evaluated are omitted.
        """
        scratch = self._build_scratch_state(state, cycle)
        conditions: Dict[int, Any] = {}

        for br in self.dep.all_branches:
            cyc = self.dep.cyc_dsets.get(br.node_id, [])
            # Replay the combinational cone (skip NBA nodes — already applied).
            for nid in cyc:
                node = self.dep.nodes_by_id[nid]
                if nid == br.node_id:
                    continue
                if node.kind == 'blocking':
                    self._update_mem(node, scratch)

            cond = self._eval_branch_condition(br, scratch)
            if cond is not None:
                conditions[br.node_id] = cond

        return conditions

    def _eval_branch_condition(self, br, scratch):
        """Evaluate a branch node's guard to a Z3 boolean, or None if unsupported."""
        cond_ast = br.cond_ast
        if cond_ast is None:
            return None

        # Case statements / case-arm markers require match semantics against
        # each arm's labels; predicting the exact arm constraint is deferred.
        # We conservatively skip them (omission is safe — see module docstring).
        if br.ast.__class__.__name__ == 'CaseArmMarker':
            return None

        try:
            cond_z3 = self._eval_on(cond_ast, scratch, br.instance)
        except Exception:
            return None
        if cond_z3 is None:
            return None
        try:
            return coerce_to_bool(cond_z3)
        except Exception:
            return None

    # ------------------------------------------------------------------
    # Resolution under the current path condition
    # ------------------------------------------------------------------

    def classify_branches(self, state, cycle: int) -> Dict[int, str]:
        """Classify each predicted branch as FORCED_TRUE / FORCED_FALSE / FREE.

        A branch is *forced* when the current path condition already implies its
        predicted guard (or its negation) — meaning only one direction is
        feasible at t+1 and the other can be pruned.
        """
        conditions = self.predict_branch_conditions(state, cycle)
        verdicts: Dict[int, str] = {}
        import os
        _dbg = os.environ.get('VP_DEBUG')
        for br_id, cond in conditions.items():
            v = self._resolve(state, cond)
            verdicts[br_id] = v
            if _dbg:
                br = self.dep.nodes_by_id[br_id]
                try:
                    cond_s = z3.simplify(cond).sexpr()
                except Exception:
                    cond_s = str(cond)
                print(f"    [VP] br#{br_id}({br.instance},reads={sorted(br.reads)}) "
                      f"=> {v}  cond={cond_s[:120]}", flush=True)
        return verdicts

    def classify_branches_by_location(self, state, cycle: int) -> Dict[tuple, str]:
        """Like classify_branches but keyed by (instance, src_offset).

        This key matches the executor's branch identification scheme, so the
        path-selection logic can look up a predicted verdict for the branch it
        is about to take. Branches without a usable source offset are omitted.
        """
        verdicts = self.classify_branches(state, cycle)
        by_loc: Dict[tuple, str] = {}
        for br_id, v in verdicts.items():
            br = self.dep.nodes_by_id[br_id]
            if br.src_offset is None:
                continue
            by_loc[(br.instance, br.src_offset)] = v
        return by_loc

    def _resolve(self, state, cond) -> str:
        """Return FORCED_TRUE / FORCED_FALSE / FREE for *cond* under state.pc."""
        # pc ∧ ¬cond UNSAT  ⇒  pc implies cond  ⇒  forced true
        state.pc.push()
        state.pc.add(z3.Not(cond))
        true_infeasible = not solve_pc(state.pc)
        state.pc.pop()
        if true_infeasible:
            return FORCED_TRUE

        # pc ∧ cond UNSAT  ⇒  pc implies ¬cond  ⇒  forced false
        state.pc.push()
        state.pc.add(cond)
        false_only = not solve_pc(state.pc)
        state.pc.pop()
        if false_only:
            return FORCED_FALSE

        return FREE

    # ------------------------------------------------------------------
    # Algorithm 5: next-cycle path constraint for a chosen set of directions
    # ------------------------------------------------------------------

    def predict_next_pc(self, state, cycle: int,
                        directions: Optional[Dict[int, bool]] = None
                        ) -> Tuple[Optional[Any], Dict[int, Any]]:
        """Build pc_{t+1} as a conjunction of predicted branch guards.

        Args:
            directions: optional branch_node_id -> bool. When provided, each
                branch contributes ``cond`` if True else ``¬cond``. When omitted,
                every predicted guard is conjoined as-is (Algorithm 5 literal
                form), useful only as a feasibility artifact.

        Returns:
            (pc_next, conditions) where pc_next is a Z3 boolean (or None if no
            branch could be predicted) and conditions is the raw guard map.
        """
        conditions = self.predict_branch_conditions(state, cycle)
        if not conditions:
            return None, conditions

        terms = []
        for br_id, cond in conditions.items():
            if directions is not None:
                take = directions.get(br_id)
                if take is None:
                    continue
                terms.append(cond if take else z3.Not(cond))
            else:
                terms.append(cond)

        if not terms:
            return None, conditions
        pc_next = terms[0] if len(terms) == 1 else z3.And(*terms)
        return pc_next, conditions
