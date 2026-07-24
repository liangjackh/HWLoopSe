"""Static dependency analyzer for multi-cycle value-prediction (thesis §4.1/§4.2).

Given the CFGs of a design, this module classifies every relevant AST node as
one of:

    - 'branch'   : a conditional / case predicate that adds a path constraint
    - 'nba'      : a non-blocking assignment  (reg <= rhs)  — carries a value
                   across a clock boundary
    - 'blocking' : a blocking / continuous assignment (x = rhs, assign x = rhs)
                   — combinational, visible within the same cycle

From this classification it computes three dependency structures used by the
value predictor:

    NonBlockingBDSets : branch_id -> {nba_id, ...}
        The NBA nodes whose written registers influence this branch's
        condition at the *next* cycle (either nested under the branch, or
        feeding the branch condition through combinational logic).

    BlockingDepSets   : nba_id -> {blocking_id, ...}
        The blocking/combinational nodes the NBA's RHS transitively depends on
        within the current cycle (its combinational cone, stopping at register
        and primary-input boundaries).

    CycDSets          : branch_id -> [node_id, ...]   (Algorithm 4)
        For each branch, the union of BlockingDepSet(nba) over all
        nba in NonBlockingBDSet(branch), topologically ordered
        (write-before-read) and with the branch node appended so the predictor
        can evaluate the guard after its cone.

The analyzer reuses COIAnalyzer's syntax-level signal extraction so the read/
write sets stay consistent with the rest of the frontend.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Set, Tuple, Any, Optional
from collections import deque

import pyslang as ps

from frontend.coi_analyzer import COIAnalyzer
from helpers.utils import topo_sort_nodes


@dataclass
class DepNode:
    """A single classified node in the dependency graph."""
    node_id: int
    kind: str                       # 'branch' | 'nba' | 'blocking'
    instance: str
    cfg_idx: int                    # -1 for a continuous-assign (comb) node
    lhs: Optional[str]              # written signal (None for branch)
    reads: Set[str] = field(default_factory=set)
    ast: Any = None                 # PySlang node — reused for runtime evaluation
    cond_ast: Any = None            # branch condition expression node (branch only)
    src_offset: Any = None          # source byte offset of a branch (for path matching)


@dataclass
class DepAnalysisResult:
    """Output of DependencyAnalyzer.analyze()."""
    all_branches: List[DepNode] = field(default_factory=list)
    nonblocking_bd: Dict[int, Set[int]] = field(default_factory=dict)   # branch_id -> nba ids
    blocking_dep: Dict[int, Set[int]] = field(default_factory=dict)     # nba_id -> blocking ids
    cyc_dsets: Dict[int, List[int]] = field(default_factory=dict)       # branch_id -> ordered ids
    nodes_by_id: Dict[int, DepNode] = field(default_factory=dict)


class DependencyAnalyzer:
    """Builds DepAnalysisResult from a design's CFGs.

    Args:
        cfgs_by_module: instance_name -> list of CFG objects
        comb_by_module: instance_name -> list of comb syntax nodes
        modules_dict:   instance_name -> InstanceSymbol (unused for now, kept
                        for API symmetry with COIAnalyzer / future port work)
        coi_analyzer:   optional pre-built COIAnalyzer to reuse extraction
                        helpers and port maps; a fresh one is built if omitted.
    """

    def __init__(self, cfgs_by_module: Dict[str, list],
                 comb_by_module: Optional[Dict[str, list]] = None,
                 modules_dict: Optional[Dict[str, Any]] = None,
                 modules: Optional[list] = None,
                 coi_analyzer: Optional[COIAnalyzer] = None):
        self.cfgs_by_module = cfgs_by_module
        self.comb_by_module = comb_by_module or {}
        self.modules_dict = modules_dict or {}

        # Reuse COIAnalyzer purely for its stateless syntax helpers
        # (_collect_read_signals, _get_signal_name_syntax) and port maps.
        if coi_analyzer is not None:
            self._coi = coi_analyzer
        else:
            self._coi = COIAnalyzer(self.modules_dict, cfgs_by_module,
                                    modules or [], self.comb_by_module)

        self._next_id = 0
        self.nodes_by_id: Dict[int, DepNode] = {}
        self.all_branches: List[DepNode] = []
        self.all_nba: List[DepNode] = []
        self.all_blocking: List[DepNode] = []

        # (instance, signal) -> [node_id, ...] writers, split by kind
        self._nba_writer: Dict[Tuple[str, str], List[int]] = {}
        self._blocking_writer: Dict[Tuple[str, str], List[int]] = {}

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def analyze(self) -> DepAnalysisResult:
        """Run the full static analysis and return a DepAnalysisResult."""
        self._classify_all_nodes()
        self._build_writer_index()
        blocking_dep = self._compute_blocking_dep_sets()
        nonblocking_bd = self._compute_nonblocking_bd_sets()
        cyc_dsets = self._compute_cyc_dsets(nonblocking_bd, blocking_dep)

        import os
        if os.environ.get('DEP_DEBUG'):
            self._debug_dump(nonblocking_bd, blocking_dep, cyc_dsets)

        return DepAnalysisResult(
            all_branches=self.all_branches,
            nonblocking_bd=nonblocking_bd,
            blocking_dep=blocking_dep,
            cyc_dsets=cyc_dsets,
            nodes_by_id=self.nodes_by_id,
        )

    def _debug_dump(self, nonblocking_bd, blocking_dep, cyc_dsets):
        """Print the full dependency analysis (enabled via DEP_DEBUG env var)."""
        def desc(nid):
            n = self.nodes_by_id[nid]
            return f"#{nid}({n.kind},{n.instance}.{n.lhs},reads={sorted(n.reads)})"
        print("===== DepAnalyzer DEBUG =====")
        print(f"nba writers: {[(k, v) for k, v in self._nba_writer.items()]}")
        print(f"blocking writers: {[(k, v) for k, v in self._blocking_writer.items()]}")
        for br in self.all_branches:
            print(f"BRANCH {desc(br.node_id)}")
            print(f"  NonBlockingBD: {[desc(i) for i in nonblocking_bd.get(br.node_id, [])]}")
            print(f"  CycDSet: {[desc(i) for i in cyc_dsets.get(br.node_id, [])]}")
        for nba in self.all_nba:
            print(f"NBA {desc(nba.node_id)} BlockingDep: {[desc(i) for i in blocking_dep.get(nba.node_id, [])]}")
        print("=============================")

    # ------------------------------------------------------------------
    # Node id allocation
    # ------------------------------------------------------------------

    def _new_node(self, kind: str, instance: str, cfg_idx: int,
                  lhs: Optional[str], reads: Set[str], ast: Any,
                  cond_ast: Any = None) -> DepNode:
        src_offset = self._source_offset(ast) if kind == 'branch' else None
        node = DepNode(node_id=self._next_id, kind=kind, instance=instance,
                       cfg_idx=cfg_idx, lhs=lhs, reads=reads, ast=ast,
                       cond_ast=cond_ast, src_offset=src_offset)
        self.nodes_by_id[self._next_id] = node
        self._next_id += 1
        if kind == 'branch':
            self.all_branches.append(node)
        elif kind == 'nba':
            self.all_nba.append(node)
        elif kind == 'blocking':
            self.all_blocking.append(node)
        return node

    @staticmethod
    def _source_offset(node):
        """Best-effort source byte offset for a statement node.

        Matches the executor's branch_id scheme (slang_helpers Conditional
        handler), so predicted verdicts can be aligned to executed branches.
        Returns an int offset, a string fallback, or None.
        """
        syn = getattr(node, 'syntax', None) or node
        try:
            sr = syn.sourceRange()
            start = sr.start
            off = getattr(start, 'offset', None)
            return off if off is not None else str(start)
        except Exception:
            try:
                sr = getattr(node, 'sourceRange', None)
                if sr is not None:
                    start = getattr(sr, 'start', None)
                    off = getattr(start, 'offset', None) if start else None
                    return off if off is not None else str(sr)
            except Exception:
                pass
        return None

    # ------------------------------------------------------------------
    # 1. Classify every AST node into branch / nba / blocking
    # ------------------------------------------------------------------

    def _classify_all_nodes(self):
        """Walk all CFGs and comb lists, creating a DepNode per relevant node."""
        for instance, cfg_list in self.cfgs_by_module.items():
            for cfg_idx, cfg in enumerate(cfg_list):
                for block in cfg.basic_block_list:
                    for stmt in block:
                        self._classify_stmt(stmt, instance, cfg_idx)

            # Continuous assigns (comb) are shared across a definition's CFGs;
            # take them from the first CFG's comb list.
            if cfg_list:
                for comb_node in cfg_list[0].comb:
                    self._classify_comb(comb_node, instance)

        # Instances with zero always blocks (pure comb wrappers)
        for instance, comb_nodes in self.comb_by_module.items():
            if instance not in self.cfgs_by_module or not self.cfgs_by_module[instance]:
                for comb_node in comb_nodes:
                    self._classify_comb(comb_node, instance)

    def _classify_stmt(self, stmt, instance: str, cfg_idx: int):
        """Classify a single flattened basic-block statement."""
        if stmt is None:
            return

        # Case-arm markers are branch points (thesis treats case arms as branches)
        cname = stmt.__class__.__name__
        if cname == 'CaseArmMarker':
            reads: Set[str] = set()
            case_expr = getattr(stmt, 'case_expr', None)
            if case_expr is not None:
                self._coi._collect_read_signals(case_expr, reads)
            for arm in getattr(stmt, 'arm_exprs', []) or []:
                self._coi._collect_read_signals(arm, reads)
            self._new_node('branch', instance, cfg_idx, None, reads,
                           ast=stmt, cond_ast=case_expr)
            return

        # Conditional statement -> branch node
        if isinstance(stmt, ps.ConditionalStatementSyntax):
            reads = set()
            # Reuse the executor's condition extraction for consistency
            from helpers.slang_helpers import extract_branch_condition
            cond_expr = extract_branch_condition(stmt)
            if cond_expr is not None:
                self._coi._collect_read_signals(cond_expr, reads)
            self._new_node('branch', instance, cfg_idx, None, reads,
                           ast=stmt, cond_ast=cond_expr)
            return

        # Case statement predicate -> branch node (arms handled via markers)
        if isinstance(stmt, ps.CaseStatementSyntax):
            reads = set()
            case_expr = getattr(stmt, 'expr', getattr(stmt, 'expression', None))
            if case_expr is not None:
                self._coi._collect_read_signals(case_expr, reads)
            self._new_node('branch', instance, cfg_idx, None, reads,
                           ast=stmt, cond_ast=case_expr)
            return

        # Assignment (blocking / nonblocking) inside an expression statement
        if isinstance(stmt, ps.ExpressionStatementSyntax):
            expr = getattr(stmt, 'expression', getattr(stmt, 'expr', None))
            self._classify_assignment(expr, instance, cfg_idx)
            return

        # Bare assignment expression node. Blocking / nonblocking assignments
        # surface as BinaryExpressionSyntax whose SyntaxKind is
        # (Nonblocking)AssignmentExpression — the class name is NOT "Assignment".
        self._classify_assignment(stmt, instance, cfg_idx)

    @staticmethod
    def _assignment_kind(expr):
        """Return 'nba', 'blocking', or None for an assignment expression node.

        Blocking and nonblocking assignments both parse as BinaryExpressionSyntax;
        the distinguishing information is in the SyntaxKind (.kind), not the
        Python class name.
        """
        kind = getattr(expr, 'kind', None)
        kind_name = str(kind)
        if 'NonblockingAssignment' in kind_name:
            return 'nba'
        if 'Assignment' in kind_name:
            return 'blocking'
        # Semantic (elaborated) forms carry the info in the class name
        cname = expr.__class__.__name__
        if 'NonblockingAssignment' in cname:
            return 'nba'
        if 'Assignment' in cname:
            return 'blocking'
        return None

    def _classify_assignment(self, expr, instance: str, cfg_idx: int):
        """Create an nba or blocking DepNode for an assignment expression."""
        if expr is None:
            return
        kind = self._assignment_kind(expr)
        if kind is None:
            return

        lhs = getattr(expr, 'left', None)
        rhs = getattr(expr, 'right', None)
        lhs_name = self._coi._get_signal_name_syntax(lhs) if lhs is not None else None
        reads: Set[str] = set()
        if rhs is not None:
            self._coi._collect_read_signals(rhs, reads)

        self._new_node(kind, instance, cfg_idx, lhs_name, reads, ast=expr)

    def _classify_comb(self, comb_node, instance: str):
        """Classify a continuous-assign / wire-init node as blocking (cfg_idx=-1)."""
        if comb_node is None:
            return

        # Reuse COIAnalyzer's per-signal comb extraction to obtain lhs->reads.
        # comb_writes[instance] is populated during COIAnalyzer construction.
        comb_map = self._coi.comb_writes.get(instance, {})

        assigns = getattr(comb_node, 'assigns', None)
        handled = False
        if assigns is not None and hasattr(assigns, '__iter__'):
            for a in assigns:
                lhs = getattr(a, 'left', None)
                rhs = getattr(a, 'right', None)
                lhs_name = self._coi._get_signal_name_syntax(lhs) if lhs is not None else None
                reads: Set[str] = set()
                if rhs is not None:
                    self._coi._collect_read_signals(rhs, reads)
                self._new_node('blocking', instance, -1, lhs_name, reads, ast=a)
                handled = True

        if handled:
            return

        # Declarator form: wire x = expr;  (NetDeclarationSyntax)
        declarators = getattr(comb_node, 'declarators', None)
        if declarators is not None:
            for decl in declarators:
                name_node = getattr(decl, 'name', None)
                init = getattr(decl, 'initializer', None)
                if name_node is None or init is None:
                    continue
                lhs_name = getattr(name_node, 'valueText', str(name_node))
                # initializer wraps the expression (EqualsValueClauseSyntax)
                init_expr = getattr(init, 'expr', getattr(init, 'expression', init))
                reads = set()
                self._coi._collect_read_signals(init_expr, reads)
                self._new_node('blocking', instance, -1, lhs_name, reads, ast=init_expr)
            return

        # BinaryExpressionSyntax form (e.g. from ContinuousAssignSymbol.syntax)
        lhs = getattr(comb_node, 'left', None)
        rhs = getattr(comb_node, 'right', None)
        if lhs is not None and rhs is not None:
            lhs_name = self._coi._get_signal_name_syntax(lhs)
            reads = set()
            self._coi._collect_read_signals(rhs, reads)
            self._new_node('blocking', instance, -1, lhs_name, reads, ast=comb_node)

    # ------------------------------------------------------------------
    # 2. Writer index
    # ------------------------------------------------------------------

    def _build_writer_index(self):
        """Index nodes by the (instance, signal) they write, split by kind."""
        for node in self.all_nba:
            if node.lhs:
                self._nba_writer.setdefault((node.instance, node.lhs), []).append(node.node_id)
        for node in self.all_blocking:
            if node.lhs:
                self._blocking_writer.setdefault((node.instance, node.lhs), []).append(node.node_id)

    # ------------------------------------------------------------------
    # 3. BlockingDepSets: nba_id -> combinational cone (blocking nodes)
    # ------------------------------------------------------------------

    def _compute_blocking_dep_sets(self) -> Dict[int, Set[int]]:
        """For each NBA node, the blocking/comb nodes its RHS depends on.

        Backward BFS from the NBA's read signals through blocking/comb writers.
        Stops at register boundaries (signals written by NBAs — those are
        previous-cycle store values) and primary inputs (no writer).
        """
        blocking_dep: Dict[int, Set[int]] = {}

        for nba in self.all_nba:
            deps: Set[int] = set()
            seen_sigs: Set[Tuple[str, str]] = set()
            worklist = deque((nba.instance, sig) for sig in nba.reads)

            while worklist:
                inst, sig = worklist.popleft()
                if (inst, sig) in seen_sigs:
                    continue
                seen_sigs.add((inst, sig))

                # Follow blocking/comb writers of this signal within the cycle.
                for writer_id in self._blocking_writer.get((inst, sig), []):
                    if writer_id in deps:
                        continue
                    deps.add(writer_id)
                    writer = self.nodes_by_id[writer_id]
                    for r in writer.reads:
                        if (writer.instance, r) not in seen_sigs:
                            worklist.append((writer.instance, r))

                # Cross-module: trace this signal through port connections so a
                # comb cone spanning a hierarchy is captured. Skip clk/reset.
                if not self._coi._is_global_infra(sig):
                    self._enqueue_port_neighbors(inst, sig, seen_sigs, worklist)

                # NOTE: we deliberately do NOT chase NBA writers of `sig`.
                # A signal written by an NBA is a register — its value comes
                # from the previous cycle's store, not this cycle's cone.

            blocking_dep[nba.node_id] = deps

        return blocking_dep

    def _enqueue_port_neighbors(self, inst, sig, seen_sigs, worklist):
        """Push cross-module port-connected signals onto the BFS worklist."""
        p2c = getattr(self._coi, 'port_map_parent_to_child', {})
        c2p = getattr(self._coi, 'port_map_child_to_parent', {})
        if (inst, sig) in c2p:
            parent = c2p[(inst, sig)]
            if parent not in seen_sigs:
                worklist.append(parent)
        for child in p2c.get((inst, sig), []):
            if child not in seen_sigs:
                worklist.append(child)

    # ------------------------------------------------------------------
    # 4. NonBlockingBDSets: branch_id -> influencing NBA nodes
    # ------------------------------------------------------------------

    def _compute_nonblocking_bd_sets(self) -> Dict[int, Set[int]]:
        """For each branch, the NBA nodes whose registers feed its condition.

        A branch reads a set of signals. For each read signal that is a
        register (has an NBA writer), that NBA directly influences the branch
        at the next cycle. We also chase combinational writers of the read
        signals so registers feeding the branch *through* comb logic are found.
        """
        nonblocking_bd: Dict[int, Set[int]] = {}

        for br in self.all_branches:
            nbas: Set[int] = set()
            seen_sigs: Set[Tuple[str, str]] = set()
            worklist = deque((br.instance, sig) for sig in br.reads)

            while worklist:
                inst, sig = worklist.popleft()
                if (inst, sig) in seen_sigs:
                    continue
                seen_sigs.add((inst, sig))

                # Register writers of this signal directly influence the branch.
                for nba_id in self._nba_writer.get((inst, sig), []):
                    nbas.add(nba_id)

                # Chase combinational writers to reach registers behind comb logic.
                for writer_id in self._blocking_writer.get((inst, sig), []):
                    writer = self.nodes_by_id[writer_id]
                    for r in writer.reads:
                        if (writer.instance, r) not in seen_sigs:
                            worklist.append((writer.instance, r))

                if not self._coi._is_global_infra(sig):
                    self._enqueue_port_neighbors(inst, sig, seen_sigs, worklist)

            nonblocking_bd[br.node_id] = nbas

        return nonblocking_bd

    # ------------------------------------------------------------------
    # 5. CycDSets (Algorithm 4)
    # ------------------------------------------------------------------

    def _compute_cyc_dsets(self, nonblocking_bd: Dict[int, Set[int]],
                           blocking_dep: Dict[int, Set[int]]) -> Dict[int, List[int]]:
        """Algorithm 4: per branch, union of BlockingDepSet over its NBAs.

        The result is topologically ordered (write-before-read) so the value
        predictor can evaluate nodes in dependency order. The branch node
        itself is appended last so its guard is evaluated after its cone.
        """
        cyc_dsets: Dict[int, List[int]] = {}

        for br in self.all_branches:
            node_set: Set[int] = set()
            for nba_id in nonblocking_bd.get(br.node_id, ()):  # noqa: E501
                node_set |= blocking_dep.get(nba_id, set())
                # Include the NBA nodes themselves — the predictor must apply
                # the register update (updateMem) before evaluating the guard.
                node_set.add(nba_id)

            ordered = topo_sort_nodes(
                node_set,
                writes_of=lambda nid: ({self.nodes_by_id[nid].lhs}
                                       if self.nodes_by_id[nid].lhs else set()),
                reads_of=lambda nid: self.nodes_by_id[nid].reads,
            )
            ordered.append(br.node_id)
            cyc_dsets[br.node_id] = ordered

        return cyc_dsets
