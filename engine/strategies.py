"""Exploration strategies for symbolic execution.

This module implements the Strategy Pattern to decouple search algorithms
from the execution mechanism.
"""

from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, Dict, List, Any, Optional, Tuple, Union
from itertools import product
import heapq
import time
import logging

from z3 import Solver, sat, BitVec, is_bv, is_bv_value

from .symbolic_state import SymbolicState
from .execution_manager import ExecutionManager
from helpers.utils import init_symbol
from helpers.slang_helpers import init_state

if TYPE_CHECKING:
    from .execution_engine import ExecutionEngine
    from .milestone import MilestoneManager


class ExplorationStrategy(ABC):
    """Abstract base class for exploration strategies."""

    @abstractmethod
    def run(
        self,
        engine: 'ExecutionEngine',
        visitor: Any,
        modules: List[Any],
        modules_dict: Dict[str, Any],
        cfgs_by_module: Dict[str, List[Any]],
        manager: ExecutionManager,
        state: SymbolicState,
        num_cycles: int,
        comb_by_module: Optional[Dict[str, List[Any]]] = None,
        wire_groups: Optional[List[Any]] = None,
        primary_input_flags: Optional[List[bool]] = None
    ) -> None:
        """
        Execute the exploration strategy.

        Args:
            engine: The execution engine (provides utility methods)
            visitor: The AST visitor for statement execution
            modules: List of module instances
            modules_dict: Dictionary mapping instance names to module objects
            cfgs_by_module: Dictionary mapping instance names to CFG lists
            manager: Execution manager tracking state
            state: Initial symbolic state
            num_cycles: Number of clock cycles to explore
        """
        pass



class BlindSearchStrategy(ExplorationStrategy):
    """
    Blind search strategy using Cartesian product of all paths.

    This strategy uses a generator-based approach to avoid memory explosion
    when dealing with a large number of paths (e.g., in complex RTL designs).
    It explores all possible combinations of paths across modules and cycles.
    """

    def run(
        self,
        engine: 'ExecutionEngine',
        visitor: Any,
        modules: List[Any],
        modules_dict: Dict[str, Any],
        cfgs_by_module: Dict[str, List[Any]],
        manager: ExecutionManager,
        state: SymbolicState,
        num_cycles: int,
        comb_by_module: Optional[Dict[str, List[Any]]] = None,
        wire_groups: Optional[List[Any]] = None,
        primary_input_flags: Optional[List[bool]] = None
    ) -> None:
        """Execute blind exhaustive search with memory optimization."""

        # Build mapped_paths: module_name -> cfg_idx -> paths
        mapped_paths = {}
        for name in manager.names_list:
            mapped_paths[name] = {}

        for module_name, cfg_list in cfgs_by_module.items():
            for i, cfg in enumerate(cfg_list):
                mapped_paths[module_name][i] = cfg.paths

        keys = list(cfgs_by_module.keys())
        
        # 1. Flatten all decision points to build the generator
        all_decision_lists = []
        decision_map = []  # Maps each decision to (cycle, module_name, cfg_idx)
        
        for cycle in range(int(num_cycles)):
            for module_name in keys:
                for cfg_idx, paths in enumerate(mapped_paths[module_name].values()):
                    # Provide a fallback if a CFG has no paths
                    path_list_to_add = paths if paths else [[]]
                    all_decision_lists.append(path_list_to_add)
                    decision_map.append((cycle, module_name, cfg_idx))
                    
        # 2. Build the super-generator (extremely low memory footprint)
        total_paths_generator = product(*all_decision_lists)

        # Reset branch tracking and path count
        manager.branch_count = 0
        manager.branch_points_seen = set()
        manager.path_count = 0

        print("[BlindSearchStrategy] Starting exhaustive search via generator...")

        # 3. Main exploration loop directly consuming the generator
        for path_tuple in total_paths_generator:
            # Reconstruct the curr_path dictionary structure expected by the engine
            curr_path = {k: [ [] for _ in range(int(num_cycles)) ] for k in keys}
            for val, (cycle, module_name, cfg_idx) in zip(path_tuple, decision_map):
                curr_path[module_name][cycle].append(val)
                
            manager.prev_store = state.store
            # Use the first module for init_state
            first_module = modules[0] if modules else None
            if first_module:
                init_state(state, manager.prev_store, first_module, visitor)

            # Initialize inputs with symbols for all submodules
            for module_name in manager.names_list:
                manager.curr_module = module_name
                visitor.symbolic_store.clear()
                visitor.visited.clear()
                visitor.dfs(modules_dict[module_name])
                for var_name in visitor.symbolic_store:
                    if var_name not in state.store[module_name]:
                        state.store[module_name][var_name] = init_symbol()

            # Process declarations and combinational logic
            for c in cfgs_by_module[manager.curr_module]:
                for node in c.decls:
                    visitor.dfs(node)
                for node in c.comb:
                    visitor.dfs(node)

            manager.curr_module = manager.names_list[0]

            print(f"Executing path {manager.path_count + 1} (Total paths unknown due to generator)")
            engine.check_state(manager, state)

            modules_seen = 0
            for module_name in curr_path:
                manager.curr_module = manager.names_list[modules_seen]
                manager.cycle = 0
                for complete_single_cycle_path in curr_path[module_name]:
                    if manager.cycle > 0:
                        state.apply_pending_nba()

                    for cfg_idx, cfg_path in enumerate(complete_single_cycle_path):
                        # Handle empty paths generated as fallbacks
                        if not cfg_path:
                            continue
                        # Skip initial blocks after cycle 0
                        if manager.cycle > 0 and getattr(cfgs_by_module[module_name][cfg_idx], 'is_initial', False):
                            continue
                        directions = cfgs_by_module[module_name][cfg_idx].compute_direction(cfg_path)
                        if engine.debug:
                            print(f"DEBUG: cfg_path={cfg_path}, directions={directions}")
                            print(f"DEBUG: basic_block_list has {len(cfgs_by_module[module_name][cfg_idx].basic_block_list)} blocks")

                        k = 0
                        for basic_block_idx in cfg_path:
                            if basic_block_idx < 0:
                                print("Skipping dummy node in path")
                                continue
                            else:
                                direction = directions[k] if k < len(directions) else 0
                                k += 1
                                basic_block = cfgs_by_module[module_name][cfg_idx].basic_block_list[basic_block_idx]
                                print(f"visiting basic_block: {[str(s)[:50] if s else 'None' for s in basic_block]}")
                                for stmt in basic_block:
                                    visitor.visit_stmt(manager, state, stmt, modules_dict, direction)

                    manager.cycle += 1
                modules_seen += 1

            manager.cycle = 0
            engine.done = True
            engine.check_state(manager, state)
            engine.done = False

            manager.curr_level = 0
            for module_name in manager.instances_seen:
                manager.instances_seen[module_name] = 0
                manager.instances_loc[module_name] = ""

            if manager.assertion_violation:
                print(f"[Path {manager.path_count + 1}] cycles={int(num_cycles)}, result=VIOLATION")
                self._handle_assertion_violation(engine, manager, state)
                return

            # Path completed without violation
            pc_result = "SAT" if state.pc.check() == sat else "UNSAT"
            print(f"[Path {manager.path_count + 1}] cycles={int(num_cycles)}, result={pc_result}")

            if engine.debug:
                print("------------------------")

            state.pc.reset()
            state.pc_constraint_set.clear()
            for module in manager.dependencies:
                module = {}

            manager.ignore = False
            manager.abandon = False
            manager.reg_writes.clear()
            for name in manager.names_list:
                state.store[name] = {}
            manager.path_count += 1

        print(f"Branch points explored: {manager.branch_count}")
        print(f"Paths explored: {manager.path_count}")

    def _handle_assertion_violation(
        self,
        engine: 'ExecutionEngine',
        manager: ExecutionManager,
        state: SymbolicState
    ) -> None:
        """Handle assertion violation: print details and generate counterexample."""
        print("Assertion violation")
        if hasattr(manager, 'violated_assertions') and manager.violated_assertions:
            print("Violated assertion details:")
            for va in manager.violated_assertions:
                print(f"  - condition: {va.get('condition', 'N/A')}")
                print(f"    z3_condition: {va.get('z3_condition', 'N/A')}")
                print(f"    path condition: {va.get('path condition', 'N/A')}")
                print(f"    kind: {va.get('kind', 'N/A')}")

        counterexample = {}
        symbols_to_values = {}
        solver_start = time.process_time()

        if engine.solve_pc(state.pc):
            solver_end = time.process_time()
            manager.solver_time += solver_end - solver_start
            solved_model = state.pc.model()
            decls = solved_model.decls()
            for item in decls:
                symbols_to_values[item.name()] = solved_model[item]

            for module in state.store:
                for signal in state.store[module]:
                    for symbol in symbols_to_values:
                        if state.store[module][signal] == symbol:
                            counterexample[signal] = symbols_to_values[symbol]

            print(counterexample)
        else:
            print("UNSAT")
            

class WorkItem:
    """
    Work item for the priority queue in directed search.

    Contains all information needed to resume execution from a specific point.
    """

    def __init__(
        self,
        score: int,
        cycle: int,
        milestones_completed: int,
        state: SymbolicState,
        execution_context: Dict[str, Any],
        cycle_at_last_milestone: int = 0
    ):
        """
        Initialize a work item.

        Args:
            score: Priority score (lower = higher priority)
            cycle: Current clock cycle
            milestones_completed: Number of milestones reached
            state: Deep-copied symbolic state
            execution_context: Dict containing:
                - module_positions: {module_name: (cfg_idx, bb_idx, direction_idx)}
                - pending_modules: List of modules not yet executed this cycle
            cycle_at_last_milestone: Clock cycle at which the last milestone was reached
        """
        self.score = score
        self.cycle = cycle
        self.milestones_completed = milestones_completed
        self.state = state
        self.execution_context = execution_context
        self.cycle_at_last_milestone = cycle_at_last_milestone
        self.id = id(self)  # Unique ID for tie-breaking

    def __lt__(self, other: 'WorkItem') -> bool:
        """Compare by score, then by ID for deterministic ordering."""
        if self.score != other.score:
            return self.score < other.score
        return self.id < other.id


class MilestoneDirectedStrategy(ExplorationStrategy):
    """
    Milestone-directed search strategy using priority queue.

    This strategy performs step-by-step execution, creating child states
    at branch points and prioritizing paths that make progress toward milestones.
    """

    def __init__(self, milestone_manager: 'MilestoneManager', max_cycles: int = 100, max_paths: int = 500000, bmc_margin: int = 5,
                 enable_eager_target_eval: bool = True, enable_sliding_window: bool = True):
        """
        Initialize the directed strategy.

        Args:
            milestone_manager: Manager for milestone checking
            max_cycles: Maximum clock cycles before timeout
            max_paths: Maximum number of paths to explore before giving up
            bmc_margin: Extra cycles added to each milestone's expected_cycles
                        to form the BMC verification bound (default: 5)
            enable_eager_target_eval: Enable eager final-milestone pre-check
            enable_sliding_window: Enable sliding-window lookahead milestone skip
        """
        self.milestone_manager = milestone_manager
        self.max_cycles = max_cycles
        self.max_paths = max_paths
        self.bmc_margin = bmc_margin
        self.enable_eager_target_eval = enable_eager_target_eval
        self.enable_sliding_window = enable_sliding_window
        self.paths_explored = 0
        # Suppression tracking: deferred violation and stagnation detection
        self._deferred_violation = None   # (assertions, state)
        self._deferred_at_milestone = -1  # milestone progress when violation was saved
        self._deferred_at_cycle = -1      # cycle when violation was saved
        self._stagnation_counter = 0      # paths explored without milestone progress

    def run(
        self,
        engine: 'ExecutionEngine',
        visitor: Any,
        modules: List[Any],
        modules_dict: Dict[str, Any],
        cfgs_by_module: Dict[str, List[Any]],
        manager: ExecutionManager,
        state: SymbolicState,
        num_cycles: int,
        comb_by_module: Optional[Dict[str, List[Any]]] = None,
        wire_groups: Optional[List[Any]] = None,
        primary_input_flags: Optional[List[bool]] = None,
        wire_group_widths: Optional[List[int]] = None
    ) -> None:
        """Execute milestone-directed search with priority queue."""

        print(f"[DirectedStrategy] Starting milestone-directed search")
        print(f"[DirectedStrategy] Milestones: {self.milestone_manager.milestones}")
        num_cycles_int = int(num_cycles)
        print(f"[DirectedStrategy] Max cycles: {min(self.max_cycles, num_cycles_int)}, BMC margin: {self.bmc_margin}")

        # Store comb_by_module and wire_groups for use in _execute_cycle
        self._comb_by_module = comb_by_module or {}
        self._wire_groups = wire_groups or []
        self._primary_input_flags = primary_input_flags or []
        self._wire_group_widths = wire_group_widths or []
        self._active_instances = set(manager.names_list)

        # Build topologically sorted comb nodes (single-pass instead of 2-pass fixedpoint)
        self._sorted_comb_by_module = self._topo_sort_comb(cfgs_by_module, manager)

        # Precompute ordered list of modules that actually have comb nodes,
        # preserving names_list order. This avoids iterating all 600+ modules
        # on every _evaluate_comb_topo call when most have no comb nodes.
        self._sorted_comb_modules = [
            name for name in manager.names_list
            if self._sorted_comb_by_module.get(name)
        ]

        # Build cross-module comb dependency map: given a module whose signals
        # just changed (e.g. after CFG execution), which OTHER modules have
        # comb nodes that may need re-evaluation?  Uses wire_groups to find
        # inter-module signal connections.
        self._comb_downstream = self._build_comb_downstream_map(manager)

        # Precompute the read-set for each comb node so we can skip nodes
        # whose inputs haven't changed (input-change detection).
        self._comb_node_reads = {}  # (module_name, node_idx) -> frozenset of signal names
        for module_name, nodes in self._sorted_comb_by_module.items():
            for idx, node in enumerate(nodes):
                _writes, _reads = self._extract_comb_node_signals(node)
                self._comb_node_reads[(module_name, idx)] = frozenset(_reads)
        # Cache of id(store_value) for each (module, signal) at last comb eval
        self._comb_input_snapshot = {}

        # --- Module-level comb caching ---
        # For modules with many comb nodes (like alu_ff_i with 282 nodes),
        # per-node input-change detection still evaluates all nodes on first
        # pass. Module-level caching skips the ENTIRE module when its
        # store hasn't changed since the last evaluation.
        #
        # We fingerprint the full store (all signal id()s) before/after eval.
        # If the pre-eval fingerprint matches the cached one, all comb outputs
        # are unchanged and we can skip.
        _MOD_CACHE_THRESHOLD = 20   # only cache modules with >= this many nodes
        self._comb_mod_cache_eligible = set()  # module names eligible for caching
        for module_name, nodes in self._sorted_comb_by_module.items():
            if len(nodes) >= _MOD_CACHE_THRESHOLD:
                self._comb_mod_cache_eligible.add(module_name)
                if len(nodes) >= 50:
                    print(f"  [ModCache] {module_name}: {len(nodes)} nodes — eligible for module-level caching", flush=True)
        # Runtime cache: module_name -> (pre_fp, {sig: value})
        # pre_fp = fingerprint of store BEFORE eval (i.e., inputs that drive comb)
        self._comb_mod_cache = {}

        # Reset milestone progress
        self.milestone_manager.reset()
        manager.branch_count = 0
        manager.branch_points_seen = set()

        # Initialize state for all modules
        self._initialize_state(visitor, modules_dict, cfgs_by_module, manager, state)

        # Create initial work item
        initial_context = {
            'module_positions': {name: (0, 0, 0) for name in manager.names_list},
            'pending_modules': list(manager.names_list),
            'current_module_idx': 0
        }

        initial_score = self.milestone_manager.compute_score(0)
        initial_item = WorkItem(
            score=initial_score,
            cycle=0,
            milestones_completed=0,
            state=self._clone_state(state),
            execution_context=initial_context
        )

        # Priority queue (min-heap)
        worklist: List[WorkItem] = []
        heapq.heappush(worklist, initial_item)

        max_cycles_to_run = min(self.max_cycles, int(num_cycles))

        while worklist:
            item = heapq.heappop(worklist)

            # Check path limit
            if self.paths_explored >= self.max_paths:
                print(f"[DirectedStrategy] Path limit reached ({self.max_paths} paths)")
                print(f"[DirectedStrategy] Consider increasing max_paths or simplifying the design")
                break

            # Check timeout
            if item.cycle >= max_cycles_to_run:
                print(f"[DirectedStrategy] Timeout: reached max cycles ({max_cycles_to_run})")
                continue

            # BMC bound check: prune paths that exceed the local verification
            # bound for the current milestone (expected_cycles + margin).
            target_idx = item.milestones_completed
            if target_idx < len(self.milestone_manager.milestones):
                target_milestone = self.milestone_manager.milestones[target_idx]
                k = target_milestone.expected_cycles
                m = k + self.bmc_margin
                local_depth = item.cycle - item.cycle_at_last_milestone
                if local_depth > m:
                    print(
                        f"  [BMC Prune] cycle={item.cycle}, local_depth={local_depth} > "
                        f"bound m={m} (k={k}+margin={self.bmc_margin}) for "
                        f"milestone[{target_idx}] '{target_milestone.description}' — soft pruning"
                    )
                    continue

            # Tier-2 stagnation release: if a deferred violation exists and either
            # (a) its milestone is close enough to the end, or (b) the search has
            # been stuck at the same milestone for too many paths, release it now.
            if self._deferred_violation is not None:
                _total = len(self.milestone_manager.milestones)
                _release = False
                _reason = ""
                if self._deferred_at_milestone >= _total - 2:
                    _release = True
                    _reason = f"milestone {self._deferred_at_milestone}/{_total} >= total-2"
                elif self._stagnation_counter >= 100:
                    _release = True
                    _reason = f"stagnation {self._stagnation_counter} paths without milestone progress"
                if _release:
                    print(f"[DirectedStrategy] Releasing deferred violation ({_reason})")
                    deferred_va, deferred_state = self._deferred_violation
                    manager.violated_assertions = deferred_va
                    self._handle_assertion_violation(engine, manager, deferred_state)
                    return

            self.paths_explored += 1
            print(f"\n--- [Path {self.paths_explored}] Popped: score={item.score}, cycle={item.cycle}, milestones={item.milestones_completed}/{len(self.milestone_manager.milestones)}, queue={len(worklist)}")

            # Reset manager flags for this work item
            manager.ignore = False
            manager.abandon = False
            manager.assertion_violation = False
            if hasattr(manager, 'violated_assertions'):
                manager.violated_assertions = []

            # Execute one cycle for all modules
            result, current_progress = self._execute_cycle(
                engine, visitor, modules_dict, cfgs_by_module,
                manager, item, worklist
            )

            if result == "VIOLATION":
                print(f"[Path {self.paths_explored}] cycle={item.cycle}, result=VIOLATION, milestones={current_progress}/{len(self.milestone_manager.milestones)}")
                print(f"[DirectedStrategy] Assertion violation found!")
                # Restore deferred violation record if the current manager state was cleared
                # (happens when a deferred violation is reported via sliding window).
                if not (hasattr(manager, 'violated_assertions') and manager.violated_assertions):
                    deferred = getattr(self, '_deferred_violation', None)
                    if deferred is not None:
                        saved_violations, _ = deferred
                        manager.violated_assertions = saved_violations
                self._handle_assertion_violation(engine, manager, item.state)
                return

            if result == "ALL_MILESTONES":
                print(f"[Path {self.paths_explored}] cycle={item.cycle}, result=ALL_MILESTONES")
                print(f"[DirectedStrategy] All milestones reached — reporting violation!")
                # Use item.state (full multi-cycle path condition) for counterexample.
                # The deferred violation record has stale _c0 symbols; the current
                # item.state accumulates constraints from ALL cycles (_c0.._cN).
                deferred = getattr(self, '_deferred_violation', None)
                if deferred is not None:
                    saved_violations, _ = deferred
                    manager.violated_assertions = saved_violations
                self._handle_assertion_violation(engine, manager, item.state)
                return

            # Path ended without violation
            if result is None:
                print(f"[Path {self.paths_explored}] cycle={item.cycle}, result=CONTINUE, milestones={current_progress}/{len(self.milestone_manager.milestones)}")
            elif result == "TIMEOUT":
                print(f"[Path {self.paths_explored}] cycle={item.cycle}, result=TIMEOUT, milestones={current_progress}/{len(self.milestone_manager.milestones)}")

        # Tier-3 fallback: if the worklist is exhausted (or path limit hit) and a
        # deferred violation was saved, report it as the best available result.
        if self._deferred_violation is not None:
            _total = len(self.milestone_manager.milestones)
            print(
                f"[DirectedStrategy] Search exhausted — reporting best deferred violation "
                f"(milestone {self._deferred_at_milestone}/{_total}, cycle {self._deferred_at_cycle})"
            )
            deferred_va, deferred_state = self._deferred_violation
            manager.violated_assertions = deferred_va
            self._handle_assertion_violation(engine, manager, deferred_state)
            return

        print(f"[DirectedStrategy] Search exhausted (UNSAT)")
        print(f"[DirectedStrategy] Paths explored: {self.paths_explored}")
        print(f"[DirectedStrategy] Branch points: {manager.branch_count}")
        # Report which milestone the search stalled on
        stalled_idx = self.milestone_manager.current_milestone_index
        if stalled_idx < len(self.milestone_manager.milestones):
            stalled = self.milestone_manager.milestones[stalled_idx]
            print(
                f"[DirectedStrategy] WARNING: Queue exhausted before reaching "
                f"milestone[{stalled_idx}] '{stalled.description}' "
                f"(condition: {stalled.condition_str}, expected_cycles: {stalled.expected_cycles}). "
                f"This milestone may be hallucinated or its granularity too coarse."
            )

    def _initialize_state(
        self,
        visitor: Any,
        modules_dict: Dict[str, Any],
        cfgs_by_module: Dict[str, List[Any]],
        manager: ExecutionManager,
        state: SymbolicState
    ) -> None:
        """Initialize symbolic state for all modules.

        Registers (Variable symbols) are initialized to BitVecVal(0, 32) per
        Verilog semantics.  Input ports and nets get fresh symbolic values so
        the solver can explore all possible input combinations.
        """
        import pyslang as ps
        from z3 import BitVecVal

        for module_name in manager.names_list:
            manager.curr_module = module_name
            visitor.symbolic_store.clear()
            visitor.visited.clear()
            visitor.dfs(modules_dict[module_name])
            for var_name, sym in visitor.symbolic_store.items():
                if var_name not in state.store[module_name]:
                    # Parameters get their actual constant value; everything
                    # else starts at 0 (Verilog default for regs).
                    if (hasattr(sym, 'kind') and
                            sym.kind == ps.SymbolKind.Parameter and
                            hasattr(sym, 'value') and sym.value is not None):
                        try:
                            int_val = sym.value.convertToInt()
                            state.store[module_name][var_name] = BitVecVal(int_val, 32)
                        except Exception:
                            state.store[module_name][var_name] = BitVecVal(0, 32)
                    else:
                        state.store[module_name][var_name] = BitVecVal(0, 32)

        # Process declarations using visitor.dfs (these are Symbol/Syntax nodes)
        for module_name in manager.names_list:
            manager.curr_module = module_name
            if module_name in cfgs_by_module:
                for c in cfgs_by_module[module_name]:
                    for node in c.decls:
                        visitor.dfs(node)

        # Populate parameters from submodule instances that are NOT in modules_dict.
        # e.g. div_i (riscv_alu_div) is inside a generate block inside alu_i and is
        # never a top-level module entry, so its parameters (C_LOG_WIDTH, C_WIDTH) are
        # not stored.  Recursively walk each module's symbol body—descending into
        # GenerateBlock/GenerateBlockArray—and for every InstanceSymbol found, store
        # its parameters keyed by the *instance name* so that hierarchical milestone
        # paths like "...alu_i.div_i.C_LOG_WIDTH" resolve via parts[-2] = "div_i".
        def _collect_submodule_params(sym_body):
            """Yield (inst_name, param_name, BitVecVal) for every nested instance."""
            try:
                for child in sym_body:
                    kind = getattr(child, 'kind', None)
                    if kind == ps.SymbolKind.Instance:
                        child_body = getattr(child, 'body', None)
                        if child_body is None:
                            continue
                        inst_name = getattr(child, 'name', None)
                        if inst_name is None:
                            continue
                        try:
                            for param in child_body:
                                if getattr(param, 'kind', None) != ps.SymbolKind.Parameter:
                                    continue
                                pname = param.name
                                cv = getattr(param, 'value', None)
                                if cv is None:
                                    continue
                                try:
                                    int_val = cv.convertToInt()
                                    yield (inst_name, pname, BitVecVal(int_val, 32))
                                except Exception:
                                    pass
                        except TypeError:
                            pass
                        # Also recurse into the child's body for deeper nesting
                        yield from _collect_submodule_params(child_body)
                    elif kind in (ps.SymbolKind.GenerateBlock, ps.SymbolKind.GenerateBlockArray):
                        # Descend into generate blocks to find instances inside them
                        yield from _collect_submodule_params(child)
            except TypeError:
                pass

        for module_name, module_sym in modules_dict.items():
            body = getattr(module_sym, 'body', module_sym)
            for inst_name, pname, bv in _collect_submodule_params(body):
                # Store under the instance name (e.g. "div_i") so that paths
                # like "...div_i.C_LOG_WIDTH" resolve via parts[-2] lookup.
                if inst_name not in state.store:
                    state.store[inst_name] = {}
                if pname not in state.store[inst_name]:
                    state.store[inst_name][pname] = bv

        # Unify port symbols so connected signals share the same value
        self._unify_port_symbols(state, cycle=0)

        # Evaluate combinational logic to fixed-point (Sylvia-style)
        logging.debug("Initializing state: evaluating combinational logic to fixed-point...")
        self._evaluate_comb_topo(visitor, manager, state)

    def _clone_state(self, state: SymbolicState) -> SymbolicState:
        """Create an efficient shallow clone of the symbolic state."""
        return state.clone()

    def _preferred_path_idx(self, cfg, cycle: int) -> int:
        """Choose the preferred default path for a CFG at a given cycle.

        For cycle 0: use path 0 (typically the reset path).
        For cycle > 0: prefer a non-reset path. When multiple non-reset
        paths exist (e.g., shift vs no-shift), alternate among them by
        cycle number to ensure diverse constraint combinations are explored
        as the main (un-penalized) path.

        This avoids both the cascade forking problem (always picking reset)
        and the single-path bias problem (always picking the same non-reset
        path, causing all work items to accumulate the same data-path
        constraints).
        """
        if cycle == 0 or len(cfg.paths) <= 1:
            return 0

        first_dirs = []
        for path in cfg.paths:
            directions = cfg.compute_direction(path)
            first_dirs.append(directions[0] if directions else None)

        dir_1_count = sum(1 for d in first_dirs if d == 1)
        dir_0_count = sum(1 for d in first_dirs if d == 0)

        # If exactly 1 path takes the true branch at the first conditional,
        # it's likely the single reset path (e.g. always_ff with if(rst_n)).
        # Prefer a non-reset path (direction[0]==0) for cycle > 0.
        # EXCEPTION: if the CFG has many direction=1 paths (i.e., the first
        # branch is a case statement with the first arm being sequential),
        # rotate across ALL paths rather than only preferring direction=0 paths,
        # so that the IDLE arm sub-paths are also explored eagerly.
        if dir_1_count == 1 and dir_0_count >= 1:
            non_reset_indices = [i for i, d in enumerate(first_dirs) if d == 0]
            # Alternate among non-reset paths by cycle to create diverse
            # constraint combinations across cycles
            return non_reset_indices[(cycle - 1) % len(non_reset_indices)]

        # Multiple direction=1 paths (e.g. case statement with first arm sequential)
        # or mixed: rotate across ALL paths so every arm gets a turn.
        return (cycle - 1) % len(cfg.paths)

    def _propagate_ports(self, state: SymbolicState, module_name: str = None):
        """Propagate values through wire equivalence groups.

        If module_name is given, propagate FROM that module's signals TO other
        members of each group. Otherwise propagate all groups (pick any source
        from an active instance — i.e., not pruned by COI).
        """
        if not self._wire_groups:
            return

        active = getattr(self, '_active_instances', None)

        for group in self._wire_groups:
            if module_name is not None:
                # Find this module's signal in the group as the source
                source_value = None
                for inst, sig in group:
                    if inst == module_name and inst in state.store and sig in state.store[inst]:
                        source_value = state.store[inst][sig]
                        break
                if source_value is None:
                    continue  # This module has no signal in this group
            else:
                # No specific source module — pick any active member that has a value
                source_value = None
                for inst, sig in group:
                    if active and inst not in active:
                        continue  # Skip COI-pruned instances
                    if inst in state.store and sig in state.store[inst]:
                        source_value = state.store[inst][sig]
                        break
                if source_value is None:
                    continue

            # Propagate to all other members
            for inst, sig in group:
                if inst in state.store:
                    state.store[inst][sig] = source_value

    def _unify_port_symbols(self, state: SymbolicState, cycle: int = 0):
        """Assign a fresh shared Z3 BitVec to all signals in each wire group.

        Uses cycle number in the symbol name so that primary inputs get
        independent symbols at each clock cycle, allowing the solver to
        explore different input values per cycle (e.g. rst_n=0 at cycle 0,
        rst_n=1 at cycle 1).
        """
        if not self._wire_groups:
            return

        for i, group in enumerate(self._wire_groups):
            # Pick a representative name for the group
            rep_inst, rep_sig = next(iter(group))
            sym_name = f"{rep_sig}_c{cycle}"
            width = self._wire_group_widths[i] if i < len(self._wire_group_widths) else 32
            shared_bv = BitVec(sym_name, width)

            # Assign to all members
            for inst, sig in group:
                if inst in state.store:
                    state.store[inst][sig] = shared_bv

    def _refresh_primary_inputs(self, state: SymbolicState, cycle: int):
        """Assign fresh Z3 BitVec symbols to primary input wire groups for this cycle.

        Only primary inputs (top-level input ports like rst_n, top_in) get
        refreshed. Internal wires (out_a, out_b, etc.) keep their computed values.
        """
        if not self._wire_groups or not self._primary_input_flags:
            return

        for i, group in enumerate(self._wire_groups):
            if i >= len(self._primary_input_flags) or not self._primary_input_flags[i]:
                continue  # Not a primary input group

            rep_inst, rep_sig = next(iter(group))
            sym_name = f"{rep_sig}_c{cycle}"
            width = self._wire_group_widths[i] if i < len(self._wire_group_widths) else 32
            shared_bv = BitVec(sym_name, width)

            for inst, sig in group:
                if inst in state.store:
                    state.store[inst][sig] = shared_bv

    def _topo_sort_comb(self, cfgs_by_module, manager) -> Dict[str, List[Any]]:
        """Topologically sort combinational logic nodes per module.

        Uses write/read dependency analysis: if node A writes signal X and
        node B reads signal X, then A must be evaluated before B.

        Returns sorted_comb_by_module with nodes in dependency order.
        Falls back to original order if a cycle is detected.
        """
        import networkx as nx

        sorted_comb = {}
        for module_name in manager.names_list:
            nodes = self._comb_by_module.get(module_name, [])
            if len(nodes) <= 1:
                sorted_comb[module_name] = list(nodes)
                continue

            # Build write->node and read sets per node
            node_writes = {}   # node_idx -> set of written signal names
            node_reads = {}    # node_idx -> set of read signal names
            signal_writer = {} # signal_name -> node_idx that writes it

            for idx, node in enumerate(nodes):
                writes, reads = self._extract_comb_node_signals(node)
                node_writes[idx] = writes
                node_reads[idx] = reads
                for sig in writes:
                    signal_writer[sig] = idx

            # Build dependency DAG: edge from writer to reader
            G = nx.DiGraph()
            G.add_nodes_from(range(len(nodes)))
            for idx in range(len(nodes)):
                for sig in node_reads[idx]:
                    writer_idx = signal_writer.get(sig)
                    if writer_idx is not None and writer_idx != idx:
                        G.add_edge(writer_idx, idx)

            try:
                order = list(nx.topological_sort(G))
                sorted_comb[module_name] = [nodes[i] for i in order]
                logging.debug(f"  [TopoSort] {module_name}: {len(nodes)} nodes sorted")
            except nx.NetworkXUnfeasible:
                print(f"[TopoSort] Warning: cycle detected in {module_name}, using original order")
                sorted_comb[module_name] = list(nodes)

        return sorted_comb

    def _extract_comb_node_signals(self, node):
        """Extract (writes, reads) signal name sets from a comb node."""
        import pyslang as ps
        writes = set()
        reads = set()

        if node is None:
            return writes, reads

        cname = node.__class__.__name__
        # Unwrap symbol wrappers
        if cname in ('ContinuousAssignSymbol', 'NetSymbol'):
            syntax = getattr(node, 'syntax', None)
            if syntax is not None:
                node = syntax
                cname = node.__class__.__name__

        if cname == 'ContinuousAssignSyntax':
            assigns = getattr(node, 'assigns', None)
            if assigns:
                for assign in assigns:
                    lhs = getattr(assign, 'left', None)
                    rhs = getattr(assign, 'right', None)
                    if lhs:
                        name = self._get_signal_name(lhs)
                        if name:
                            writes.add(name)
                    if rhs:
                        self._collect_read_names(rhs, reads)

        elif cname in ('NetDeclarationSyntax', 'DataDeclarationSyntax'):
            declarators = getattr(node, 'declarators', None)
            if declarators:
                for decl in declarators:
                    name_node = getattr(decl, 'name', None)
                    init = getattr(decl, 'initializer', None)
                    if name_node:
                        name = getattr(name_node, 'valueText', str(name_node))
                        writes.add(name)
                    if init:
                        init_expr = getattr(init, 'expr', getattr(init, 'expression', init))
                        self._collect_read_names(init_expr, reads)

        return writes, reads

    @staticmethod
    def _get_signal_name(node):
        """Extract signal name from an LHS syntax node."""
        if hasattr(node, 'identifier'):
            ident = node.identifier
            return getattr(ident, 'valueText', getattr(ident, 'value', str(ident)))
        if hasattr(node, 'valueText'):
            return node.valueText
        return None

    @staticmethod
    def _collect_read_names(node, reads):
        """Recursively collect signal names read by an expression node."""
        if node is None:
            return
        cname = node.__class__.__name__
        if cname == 'IdentifierNameSyntax':
            if hasattr(node, 'identifier'):
                name = getattr(node.identifier, 'valueText', getattr(node.identifier, 'value', None))
                if name:
                    reads.add(name)
            return
        if cname == 'IdentifierSelectNameSyntax':
            if hasattr(node, 'identifier'):
                name = getattr(node.identifier, 'valueText', getattr(node.identifier, 'value', None))
                if name:
                    reads.add(name)
            return
        # Recurse into children
        for attr in ('left', 'right', 'operand', 'expression', 'expr'):
            child = getattr(node, attr, None)
            if child is not None:
                MilestoneDirectedStrategy._collect_read_names(child, reads)
        # Handle lists (e.g., concatenation operands)
        for attr in ('expressions', 'operands', 'items', 'assigns'):
            children = getattr(node, attr, None)
            if children is not None and hasattr(children, '__iter__'):
                for child in children:
                    MilestoneDirectedStrategy._collect_read_names(child, reads)

    def _mod_store_fingerprint(self, module_name, state):
        """Fast fingerprint of a module's store using id() of values."""
        mod_store = state.store.get(module_name)
        if mod_store is None:
            return None
        # Use frozenset of (key, id(value)) for order-independent comparison
        return frozenset((k, id(v)) for k, v in mod_store.items())

    def _try_mod_cache(self, module_name, state):
        """Try to use module-level comb cache.

        Fingerprints the entire store for this module. If it matches the
        fingerprint captured after the last evaluation, all comb inputs are
        unchanged so outputs are also unchanged — skip evaluation.
        """
        if module_name not in self._comb_mod_cache_eligible:
            return False
        fp = self._mod_store_fingerprint(module_name, state)
        if fp is None:
            return False
        cached_fp = self._comb_mod_cache.get(module_name)
        return cached_fp is not None and cached_fp == fp

    def _update_mod_cache(self, module_name, state):
        """Store module-level comb cache after evaluating all nodes."""
        if module_name not in self._comb_mod_cache_eligible:
            return
        fp = self._mod_store_fingerprint(module_name, state)
        if fp is not None:
            self._comb_mod_cache[module_name] = fp

    def _evaluate_comb_topo(
        self,
        visitor: Any,
        manager: ExecutionManager,
        state: SymbolicState
    ):
        """Single-pass combinational evaluation in topological order.

        Two levels of caching:
        1. Module-level: for modules with many comb nodes (>= threshold),
           fingerprint external inputs. On cache hit, restore outputs without
           evaluating any nodes.  Eliminates alu_ff_i's 282 evaluations.
        2. Node-level: for remaining modules, per-node input-change detection.
        """
        import time as _t
        _t0 = _t.time()
        _n_eval = 0
        _n_skip = 0
        _n_mod_hit = 0
        snapshot = getattr(self, '_comb_input_snapshot', {})
        node_reads = getattr(self, '_comb_node_reads', {})
        _mod_times = {}

        for module_name in getattr(self, '_sorted_comb_modules', manager.names_list):
            manager.curr_module = module_name
            _mt0 = _t.time()
            _mod_n = 0

            # Module-level cache check
            if self._try_mod_cache(module_name, state):
                nodes = self._sorted_comb_by_module.get(module_name, [])
                _n_skip += len(nodes)
                _n_mod_hit += 1
                _mod_times[module_name] = (_t.time() - _mt0, 0)
                continue

            mod_store = state.store.get(module_name, {})
            for idx, node in enumerate(self._sorted_comb_by_module.get(module_name, [])):
                # Check if any input has changed
                reads = node_reads.get((module_name, idx))
                if reads is not None and len(reads) > 0:
                    cache_key = (module_name, idx)
                    # Build current input fingerprint (tuple of id()s)
                    current_fp = tuple(id(mod_store.get(sig)) for sig in reads)
                    prev_fp = snapshot.get(cache_key)
                    if prev_fp is not None and current_fp == prev_fp:
                        _n_skip += 1
                        continue
                    # Evaluate and update snapshot
                    visitor.evaluate_comb(manager, state, node)
                    _n_eval += 1
                    _mod_n += 1
                    # Refresh mod_store reference (evaluate_comb may have updated it)
                    mod_store = state.store.get(module_name, {})
                    snapshot[cache_key] = tuple(id(mod_store.get(sig)) for sig in reads)
                else:
                    visitor.evaluate_comb(manager, state, node)
                    _n_eval += 1
                    _mod_n += 1

            # Update module-level cache after evaluation
            self._update_mod_cache(module_name, state)
            _mod_times[module_name] = (_t.time() - _mt0, _mod_n)

        self._comb_input_snapshot = snapshot
        _t1 = _t.time()
        self._propagate_ports(state)
        _t2 = _t.time()
        if _t2 - _t0 > 0.3:
            print(f"    [comb_topo] eval={_n_eval} skip={_n_skip} mod_hit={_n_mod_hit} in {_t1-_t0:.3f}s, propagate in {_t2-_t1:.3f}s, modules={len(getattr(self, '_sorted_comb_modules', []))}", flush=True)
            # Log top-3 slowest modules
            _sorted_mods = sorted(_mod_times.items(), key=lambda x: -x[1][0])[:3]
            for _mname, (_mtime, _mn) in _sorted_mods:
                if _mtime > 0.1:
                    print(f"      [{_mname}] {_mn} nodes in {_mtime:.3f}s ({_mtime/_mn*1000:.1f}ms/node)", flush=True)

    def _build_comb_downstream_map(self, manager) -> dict:
        """Build a map: module_name -> set of downstream module names.

        When a CFG in module M executes, we need to re-evaluate comb nodes
        in M itself plus any module connected to M via wire groups.  This
        precomputes that relationship so the per-CFG comb evaluation only
        touches the relevant modules instead of all 836 nodes.
        """
        # Map every (instance, signal) -> set of modules that share a wire group
        sig_to_peers = {}  # (inst, sig) -> set of peer instance names
        for group in self._wire_groups:
            group_instances = {inst for inst, _sig in group}
            for inst, sig in group:
                sig_to_peers[(inst, sig)] = group_instances

        # For each module M, find all modules that could be affected when M's
        # signals change: (a) modules that share wire groups with M, and
        # (b) modules whose comb nodes read signals propagated from M.
        downstream = {}  # module_name -> set of downstream module names
        all_modules = set(manager.names_list)
        for mod in all_modules:
            peers = set()
            # Find all modules connected to mod via wire groups
            for (inst, sig), group_insts in sig_to_peers.items():
                if inst == mod:
                    peers.update(group_insts)
            # Only keep peers that actually have comb nodes to evaluate
            peers_with_comb = {
                p for p in peers
                if p != mod and self._sorted_comb_by_module.get(p)
            }
            downstream[mod] = peers_with_comb

        _total_downstream = sum(len(v) for v in downstream.values())
        _mods_with_downstream = sum(1 for v in downstream.values() if v)
        print(f"  [CombDeps] Built downstream map: {_mods_with_downstream} modules have downstream comb deps, avg={_total_downstream/max(len(downstream),1):.1f}", flush=True)
        return downstream

    def _evaluate_comb_for_module(
        self,
        visitor: Any,
        manager: ExecutionManager,
        state: SymbolicState,
        source_module: str
    ):
        """Targeted comb evaluation after a CFG in source_module executes.

        Instead of re-evaluating all comb nodes, only evaluates:
        1. Comb nodes in source_module itself (its comb assigns may read
           registers just written by the CFG)
        2. Comb nodes in modules directly connected via wire groups
           (port propagation carries updated values to these modules)

        Uses module-level caching to skip modules whose external inputs
        haven't changed (e.g. alu_ff_i with 282 nodes).
        """
        import time as _t
        _t0 = _t.time()
        _n_eval = 0
        _n_skip = 0
        _n_mod_hit = 0
        saved_module = manager.curr_module
        snapshot = getattr(self, '_comb_input_snapshot', {})
        node_reads = getattr(self, '_comb_node_reads', {})

        def _eval_nodes(mod):
            nonlocal _n_eval, _n_skip, _n_mod_hit
            nodes = self._sorted_comb_by_module.get(mod, [])
            if not nodes:
                return
            manager.curr_module = mod

            # Module-level cache check
            if self._try_mod_cache(mod, state):
                _n_skip += len(nodes)
                _n_mod_hit += 1
                return

            mod_store = state.store.get(mod, {})
            for idx, node in enumerate(nodes):
                reads = node_reads.get((mod, idx))
                if reads is not None and len(reads) > 0:
                    cache_key = (mod, idx)
                    current_fp = tuple(id(mod_store.get(sig)) for sig in reads)
                    prev_fp = snapshot.get(cache_key)
                    if prev_fp is not None and current_fp == prev_fp:
                        _n_skip += 1
                        continue
                    visitor.evaluate_comb(manager, state, node)
                    _n_eval += 1
                    mod_store = state.store.get(mod, {})
                    snapshot[cache_key] = tuple(id(mod_store.get(sig)) for sig in reads)
                else:
                    visitor.evaluate_comb(manager, state, node)
                    _n_eval += 1

            # Update module-level cache after evaluation
            self._update_mod_cache(mod, state)

        # 1. Re-evaluate comb nodes in the source module
        _eval_nodes(source_module)

        # 2. Propagate source module's ports to connected modules
        self._propagate_ports(state, source_module)

        # 3. Re-evaluate comb nodes in downstream modules
        downstream = self._comb_downstream.get(source_module, set())
        for mod in downstream:
            _eval_nodes(mod)
            # Propagate this module too (cascading)
            self._propagate_ports(state, mod)

        manager.curr_module = saved_module
        self._comb_input_snapshot = snapshot
        _t1 = _t.time()
        if _t1 - _t0 > 0.3:
            print(f"    [comb_targeted] {source_module}: eval={_n_eval} skip={_n_skip} mod_hit={_n_mod_hit} ({1+len(downstream)} modules) in {_t1-_t0:.3f}s", flush=True)

# engine/strategies.py (截取 MilestoneDirectedStrategy 的修改部分)
    def _evaluate_comb_fixedpoint(
        self,
        visitor: Any,
        manager: ExecutionManager,
        state: SymbolicState,
        max_iterations: int = 2
    ) -> int:
        """Evaluate combinational logic to a stable state (Sylvia-style).

        Combinational logic forms a DAG. Two passes suffice:
        - Pass 1: evaluate all comb nodes, establishing initial values.
        - Pass 2: re-evaluate so that nodes depending on other comb outputs
                  pick up the values computed in pass 1.

        Returns the number of iterations executed.
        """
        for iteration in range(max_iterations):
            for module_name in manager.names_list:
                manager.curr_module = module_name
                for node in self._comb_by_module.get(module_name, []):
                    visitor.evaluate_comb(manager, state, node)
            self._propagate_ports(state)

        logging.debug(f"  [Comb] Evaluated {max_iterations} pass(es)")
        return max_iterations

    def _execute_cycle(
        self,
        engine: 'ExecutionEngine',
        visitor: Any,
        modules_dict: Dict[str, Any],
        cfgs_by_module: Dict[str, List[Any]],
        manager: ExecutionManager,
        item: WorkItem,
        worklist: List[WorkItem]
    ) -> tuple:
        """Execute one clock cycle (Sylvia-style: lazy fork at branch points).

        Returns (result_str, current_progress) where result_str is one of
        "VIOLATION", "ALL_MILESTONES", "TIMEOUT", or None.

        Executes CFGs sequentially on a single state. When a branching CFG is
        encountered, we execute one path and push the remaining paths as new
        WorkItems into the worklist (with a snapshot of the state *before* the
        branch). This avoids both:
        - Exponential intra-cycle state explosion (old approach)
        - Generating useless Cartesian products upfront (previous fix)

        The path to execute is chosen from execution_context['remaining_cfgs'],
        which tracks which CFGs still need to be executed and which path to take.
        """
        cycle = item.cycle

        # Clear comb input snapshot — each work item has its own state object,
        # so id()-based fingerprints from a previous work item are meaningless.
        self._comb_input_snapshot = {}
        self._comb_mod_cache = {}

        # Step 1: Apply NBA and refresh inputs (if cycle > 0)
        if cycle > 0:
            item.state.apply_pending_nba()
            self._refresh_primary_inputs(item.state, cycle)
            self._evaluate_comb_topo(visitor, manager, item.state)

        # Step 2: Build CFG list if not already in context
        remaining_cfgs = item.execution_context.get('remaining_cfgs', None)
        if remaining_cfgs is None:
            remaining_cfgs = []
            print(f"  [CFG Build] Building CFG list for cycle {cycle}...", flush=True)
            for module_name in manager.names_list:
                if module_name not in cfgs_by_module:
                    continue
                for cfg_idx, cfg in enumerate(cfgs_by_module[module_name]):
                    if cycle > 0 and getattr(cfg, 'is_initial', False):
                        continue
                    print(f"    [CFG Build] {module_name}/cfg{cfg_idx}: accessing paths...", flush=True)
                    paths = cfg.paths
                    if not paths:
                        print(f"    [CFG Build] {module_name}/cfg{cfg_idx}: 0 paths, skipping", flush=True)
                        continue
                    print(f"    [CFG Build] {module_name}/cfg{cfg_idx}: {len(paths)} paths", flush=True)
                    remaining_cfgs.append({
                        'module': module_name,
                        'cfg_idx': cfg_idx,
                        'path_idx': self._preferred_path_idx(cfg, cycle),
                    })
            # Print CFG summary
            print(f"  [CFG Summary] {len(remaining_cfgs)} CFGs to execute in cycle {cycle}:", flush=True)
            _total_paths = 0
            for _rc in remaining_cfgs:
                _cfg = cfgs_by_module[_rc['module']][_rc['cfg_idx']]
                _total_paths += len(_cfg.paths)
                print(f"    {_rc['module']}/cfg{_rc['cfg_idx']}: {len(_cfg.paths)} paths, preferred={_rc['path_idx']}", flush=True)
            print(f"  [CFG Summary] Total paths across all CFGs: {_total_paths}", flush=True)
            if _total_paths > 1000:
                print(f"  [Warning] Large path count ({_total_paths}) may cause slow execution due to lazy forking", flush=True)
        # Step 3: Execute CFGs sequentially, lazy-fork at branches
        state = item.state
        total_milestones = len(self.milestone_manager.milestones)
        import time as _time

        # Track if any CFG actually executes (not skipped/abandoned)
        any_cfg_executed = False

        for i, cfg_entry in enumerate(remaining_cfgs):
            _cfg_t0 = _time.time()
            module_name = cfg_entry['module']
            cfg_idx = cfg_entry['cfg_idx']
            chosen_path_idx = cfg_entry['path_idx']

            manager.curr_module = module_name
            manager.cycle = cycle

            cfg = cfgs_by_module[module_name][cfg_idx]

            # Clamp path index
            if chosen_path_idx >= len(cfg.paths):
                chosen_path_idx = 0

            # Execute the chosen path
            cfg_path = cfg.paths[chosen_path_idx]
            manager.ignore = False
            manager.abandon = False

            # Snapshot store & pending_nba so we can rollback on abandon
            # Also snapshot for lazy fork (if path succeeds, we'll fork from here)
            pre_cfg_store = {mod: sigs.copy() for mod, sigs in state.store.items()}
            pre_cfg_nba = {mod: sigs.copy() for mod, sigs in state.pending_nba.items()}

            print(f"  [Run] {module_name}/cfg{cfg_idx}/path{chosen_path_idx} ({len(cfg_path)} blocks)...", flush=True)
            _exec_t0 = _time.time()
            result = self._execute_path(
                engine, visitor, modules_dict, cfg, cfg_path,
                module_name, manager, state, cfg_idx, chosen_path_idx
            )
            _exec_elapsed = _time.time() - _exec_t0
            _cfg_elapsed = _time.time() - _cfg_t0
            print(f"  [Exec] {module_name}/cfg{cfg_idx}/path{chosen_path_idx}: exec={_exec_elapsed:.3f}s, total={_cfg_elapsed:.3f}s, result={result}", flush=True)

            # Per-CFG timeout: if execution took too long, treat as abandoned
            _cfg_timeout = 30.0
            if _exec_elapsed > _cfg_timeout:
                print(f"  [Timeout] {module_name}/cfg{cfg_idx}/path{chosen_path_idx}: execution took {_exec_elapsed:.1f}s (> {_cfg_timeout}s) — marking as abandoned")
                manager.abandon = True
                result = None

            if result == "VIOLATION":
                # Suppress violations until we're one step away from the final milestone.
                # Earlier violations are spurious — unconstrained inputs trivially satisfy
                # the negated assertion before the design has been steered through reset.
                # Exception: if the violation is unconditional (path condition has no free
                # variables), report immediately regardless of milestone progress.
                if item.milestones_completed >= total_milestones - 1:
                    return "VIOLATION", item.milestones_completed
                else:
                    # Check if violation is unconditional (no symbolic constraints)
                    _is_unconditional = False
                    _pc_assertions = list(state.pc.assertions())
                    if len(_pc_assertions) == 0:
                        _is_unconditional = True
                    else:
                        from z3 import Solver as _Solver, sat as _sat
                        _s = _Solver()
                        for _a in _pc_assertions:
                            _s.add(_a)
                        if _s.check() == _sat and len(_s.model().decls()) == 0:
                            _is_unconditional = True
                    if _is_unconditional and cycle > 0:
                        # Only report unconditional violations after cycle 0.
                        # At cycle 0, signals are free Z3 vars (no reset constraints),
                        # so ANY assertion is trivially violable — always spurious.
                        print(f"  [Unconditional] assertion violation fires with no path constraints — reporting immediately")
                        return "VIOLATION", item.milestones_completed
                    print(f"  [Suppressed] assertion violation at cycle {cycle}, milestones={item.milestones_completed}/{total_milestones} — deferring until near final milestone")
                    # Save the violation with the highest milestone progress seen so far.
                    # This ensures the most "trusted" violation is reported if released later.
                    _cur_ms = item.milestones_completed
                    if _cur_ms >= self._deferred_at_milestone and hasattr(manager, 'violated_assertions') and manager.violated_assertions:
                        self._deferred_violation = (list(manager.violated_assertions), self._clone_state(state))
                        self._deferred_at_milestone = _cur_ms
                        self._deferred_at_cycle = cycle
                    manager.assertion_violation = False
                    if hasattr(manager, 'violated_assertions'):
                        manager.violated_assertions = []

            if manager.abandon or manager.ignore:
                # Restore state to pre-CFG snapshot and skip this CFG.
                # This is safe because _try_add_constraint uses push/pop
                # and does NOT permanently add UNSAT constraints.
                state.store = pre_cfg_store
                state.pending_nba = pre_cfg_nba
                print(f"  [Skip] {module_name}/cfg{cfg_idx}/path{chosen_path_idx}: abandoned/ignore, rolling back and continuing")
                manager.abandon = False
                manager.ignore = False
                continue

            # Mark that at least one CFG executed successfully
            any_cfg_executed = True

            # Lazy fork: if this CFG has multiple paths and we're taking the preferred path
            # (i.e., not already a forked work item for a specific path),
            # push siblings for the other paths. IMPORTANT: Only fork AFTER the chosen
            # path succeeds (not abandoned). This prevents forking alternatives when the
            # chosen path is UNSAT, which would cause exponential queue growth.
            if len(cfg.paths) > 1 and cfg_entry.get('forked', False) is False:
                _fork_t0 = _time.time()
                # Use the pre-CFG snapshot as the fork base (before this CFG executed)
                pre_branch_state = self._clone_state(state)
                pre_branch_state.store = {mod: sigs.copy() for mod, sigs in pre_cfg_store.items()}
                pre_branch_state.pending_nba = {mod: sigs.copy() for mod, sigs in pre_cfg_nba.items()}

                # Cap fork alternatives for large CFGs (e.g. 43-path JTAG) to
                # prevent exponential queue growth. CFGs with many paths are
                # typically structural fabric (demux/mux/fan-in) whose specific
                # routing choice doesn't affect whether a security violation occurs.
                _MAX_FORK_ALTS = 4
                _n_alts_total = len(cfg.paths) - 1
                _n_alts = min(_n_alts_total, _MAX_FORK_ALTS)
                _alt_count = 0
                for alt_path_idx in range(len(cfg.paths)):
                    if alt_path_idx == chosen_path_idx:
                        continue
                    if _alt_count >= _MAX_FORK_ALTS:
                        break
                    # Build remaining CFGs for the alternative: same list from
                    # this point onward, but with this CFG using alt_path_idx
                    alt_remaining = []
                    alt_remaining.append({
                        'module': module_name,
                        'cfg_idx': cfg_idx,
                        'path_idx': alt_path_idx,
                        'forked': True,  # mark so we don't re-fork
                    })
                    for j in range(i + 1, len(remaining_cfgs)):
                        alt_remaining.append(dict(remaining_cfgs[j]))
                    alt_ctx = {'remaining_cfgs': alt_remaining}
                    alt_item = WorkItem(
                        score=item.score + 1,
                        cycle=cycle,
                        milestones_completed=item.milestones_completed,
                        state=self._clone_state(pre_branch_state),
                        execution_context=alt_ctx,
                        cycle_at_last_milestone=item.cycle_at_last_milestone
                    )
                    heapq.heappush(worklist, alt_item)
                    _alt_count += 1
                if _n_alts_total > _MAX_FORK_ALTS:
                    print(f"  [Fork] {module_name}/cfg{cfg_idx}: {_n_alts}/{_n_alts_total} alternatives forked (capped) in {_time.time()-_fork_t0:.3f}s, queue={len(worklist)}", flush=True)
                else:
                    print(f"  [Fork] {module_name}/cfg{cfg_idx}: {_n_alts} alternatives forked in {_time.time()-_fork_t0:.3f}s, queue={len(worklist)}", flush=True)

            # Propagate this module's output ports and re-evaluate only
            # downstream comb nodes (targeted, not all 836 nodes).
            _comb_t0 = _time.time()
            self._evaluate_comb_for_module(visitor, manager, state, module_name)
            _comb_elapsed = _time.time() - _comb_t0
            if _comb_elapsed > 0.1:
                print(f"  [Slow] {module_name}/cfg{cfg_idx}: targeted_comb={_comb_elapsed:.3f}s", flush=True)

        # If all CFGs were skipped/abandoned, only continue if this is the preferred-path
        # item (not a forked alternative). Forked items that hit UNSAT should die here —
        # their siblings will cover the other paths. The preferred-path item should advance
        # so the work item isn't lost when the preferred path is UNSAT at this cycle.
        if not any_cfg_executed:
            is_forked_item = any(rc.get('forked', False) for rc in remaining_cfgs)
            if is_forked_item:
                print(f"  [AllSkipped] cycle {cycle}: forked item, all CFGs abandoned — pruning path")
                return None, item.milestones_completed
            print(f"  [AllSkipped] cycle {cycle}: preferred-path item, all CFGs abandoned — continuing to next cycle")

        # Step 4: Re-evaluate comb after sequential logic
        self._evaluate_comb_topo(visitor, manager, state)

        # Step 5: Check SAT
        if state.pc.check() != sat:
            print(f"  [Pruned] cycle {cycle}: UNSAT after execution")
            return None, item.milestones_completed

        # Step 6: Milestone/violation handling
        current_progress = item.milestones_completed
        total_milestones = len(self.milestone_manager.milestones)

        if manager.assertion_violation:
            # If the path condition has no constraints, the violation is unconditional
            # (fires for any input regardless of reset/milestones) — report immediately.
            pc_assertions = list(state.pc.assertions())
            is_unconditional = len(pc_assertions) == 0
            if not is_unconditional and current_progress == 0:
                from z3 import Solver as _Solver, sat as _sat
                _s = _Solver()
                for _a in pc_assertions:
                    _s.add(_a)
                _chk = _s.check()
                _ndecls = len(_s.model().decls()) if _chk == _sat else -1
                is_unconditional = (_chk == _sat and _ndecls == 0)
            if current_progress > 0 or is_unconditional:
                if is_unconditional:
                    print(f"  [Unconditional] assertion violation fires with no path constraints — reporting immediately")
                return "VIOLATION", current_progress
            else:
                print(f"  [Suppressed] assertion violation at cycle {cycle} before any milestone reached — likely spurious")
                manager.assertion_violation = False
                if hasattr(manager, 'violated_assertions'):
                    manager.violated_assertions = []

        if current_progress >= total_milestones - 1 and self.enable_eager_target_eval and self.milestone_manager.check_final_milestone(state):
            print(
                f"  [Preemption] Final milestone SAT after reset progress "
                f"{current_progress}/{total_milestones}; reporting VIOLATION"
            )
            return "VIOLATION", current_progress

        if self.enable_sliding_window:
            current_progress, skipped_idx = self.milestone_manager.advance_with_sliding_window(
                state,
                current_progress,
                window_size=1,
            )
            if skipped_idx is not None:
                print(f"  [Sliding Window] Skipped hallucinated milestone {skipped_idx} -> advanced to {current_progress}")
        else:
            skipped_idx = None
            _, current_progress = self.milestone_manager.check_and_lock_stateless(state, current_progress)

        # Update stagnation counter: reset if milestone advanced, increment otherwise
        if current_progress > item.milestones_completed:
            self._stagnation_counter = 0
        else:
            self._stagnation_counter += 1

        if current_progress >= total_milestones:
            return "ALL_MILESTONES", current_progress

        # If a violation was deferred earlier this cycle and the sliding window
        # has now advanced us to the penultimate milestone, report it immediately.
        if (current_progress >= total_milestones - 1
                and getattr(self, '_deferred_violation', None) is not None):
            print(f"  [Deferred Violation] Sliding window reached milestone {current_progress}/{total_milestones} — reporting deferred violation")
            return "VIOLATION", current_progress

        # Step 7: Enqueue next cycle
        # Update cycle_at_last_milestone if milestones advanced this cycle
        if current_progress > item.milestones_completed:
            new_cycle_at_last_milestone = cycle
        else:
            new_cycle_at_last_milestone = item.cycle_at_last_milestone

        next_cycle = cycle + 1
        if next_cycle < self.max_cycles:
            new_score = self.milestone_manager.compute_score_stateless(current_progress, next_cycle, state)
            new_item = WorkItem(
                score=new_score,
                cycle=next_cycle,
                milestones_completed=current_progress,
                state=state,
                execution_context={'remaining_cfgs': None},  # fresh at next cycle
                cycle_at_last_milestone=new_cycle_at_last_milestone
            )
            heapq.heappush(worklist, new_item)
            print(f"  [Enqueue] score={new_score}, next_cycle={next_cycle}, milestones={current_progress}/{len(self.milestone_manager.milestones)}")
        else:
            print(f"  [MaxCycle] cycle {next_cycle} >= limit {self.max_cycles}, not enqueued")

        return None, current_progress

    def _execute_cfg_step_by_step(
        self,
        engine: 'ExecutionEngine',
        visitor: Any,
        modules_dict: Dict[str, Any],
        cfg: Any,
        cfg_idx: int,
        module_name: str,
        manager: ExecutionManager,
        state: SymbolicState
    ) -> Union[List[SymbolicState], str]:
        """粗粒度分支处理：返回所有存活的子状态列表"""
        paths = cfg.paths
        if not paths:
            return [state]

        valid_states = []

        # Always save a clean copy before executing any paths
        clean_base_state = self._clone_state(state)

        if len(paths) > 1:
            print(f"  [Branch] {module_name}/cfg{cfg_idx}: {len(paths)} paths")

        for path_idx, cfg_path in enumerate(paths):
            # Reset abandon/ignore flags for each new path
            manager.ignore = False
            manager.abandon = False

            if path_idx == 0:
                curr_state = state
            else:
                curr_state = self._clone_state(clean_base_state)

            result = self._execute_path(
                engine, visitor, modules_dict, cfg, cfg_path,
                module_name, manager, curr_state, cfg_idx, path_idx
            )

            if result == "VIOLATION":
                return "VIOLATION"

            # Early Pruning: skip abandoned paths and UNSAT states
            if manager.abandon or manager.ignore:
                print(f"  [Pruned] {module_name}/cfg{cfg_idx}/path{path_idx}: abandoned/ignore")
                continue
            if curr_state.pc.check() == sat:
                valid_states.append(curr_state)
            else:
                print(f"  [Pruned] {module_name}/cfg{cfg_idx}/path{path_idx}: UNSAT")

        if len(paths) > 1:
            print(f"  [Branch] {module_name}/cfg{cfg_idx}: {len(valid_states)}/{len(paths)} survived")

        # If all paths were abandoned/UNSAT, preserve the original state
        # so execution can continue to the next module/cycle.
        # This handles cases like assertion guards that are false at cycle 0.
        if not valid_states:
            if len(paths) > 1:
                valid_states = [clean_base_state]
            else:
                valid_states = [state]

        return valid_states
    




    def _execute_path(
        self,
        engine: 'ExecutionEngine',
        visitor: Any,
        modules_dict: Dict[str, Any],
        cfg: Any,
        cfg_path: List[int],
        module_name: str,
        manager: ExecutionManager,
        state: SymbolicState,
        cfg_idx: int = -1,
        path_idx: int = -1
    ) -> Optional[str]:
        """Execute a single path through a CFG."""
        directions = cfg.compute_direction(cfg_path)

        k = 0
        for basic_block_idx in cfg_path:
            if basic_block_idx < 0:
                # Skip dummy nodes
                continue

            # Safety check: ensure basic_block_idx is valid
            if basic_block_idx >= len(cfg.basic_block_list):
                cfg_info = f"{module_name}/cfg{cfg_idx}/path{path_idx}" if cfg_idx >= 0 else module_name
                print(f"[Warning] Skipping invalid basic_block_idx {basic_block_idx} in {cfg_info} (max: {len(cfg.basic_block_list)-1}, total blocks: {len(cfg.basic_block_list)})")
                continue

            direction = directions[k] if k < len(directions) else 0
            k += 1

            basic_block = cfg.basic_block_list[basic_block_idx]

            for stmt in basic_block:
                visitor.visit_stmt(manager, state, stmt, modules_dict, direction)

                # Check for assertion violation after each statement
                if manager.assertion_violation:
                    return "VIOLATION"

        return None

    def _handle_assertion_violation(
        self,
        engine: 'ExecutionEngine',
        manager: ExecutionManager,
        state: SymbolicState
    ) -> None:
        """Handle assertion violation with cycle-by-cycle counterexample trace."""
        import re
        from z3 import Solver, sat as z3_sat

        print("Assertion violation detected!")

        # Collect assertion signal names from violated_assertions conditions
        # so we can prioritize them in the reverse map below.
        _assertion_signals: set = set()
        if hasattr(manager, 'violated_assertions') and manager.violated_assertions:
            for _va in manager.violated_assertions:
                _cond_str = _va.get('condition', '')
                # Extract bare identifiers from the condition string
                for _tok in re.findall(r'[a-zA-Z_][a-zA-Z0-9_]*', _cond_str):
                    _assertion_signals.add(_tok)

        # Build reverse map: z3_var_base -> assertion signal name (used for display).
        # Priority: (1) signal appears in assertion condition, (2) longer name.
        _cycle_re_rev = re.compile(r'^(.+)_c(\d+)$')
        _z3base_to_sig: Dict[str, str] = {}
        for _mod, _sigs in state.store.items():
            for _sig_name, _z3_val in _sigs.items():
                try:
                    if hasattr(_z3_val, 'decl') and _z3_val.num_args() == 0:
                        _z3_full = _z3_val.decl().name()
                        _m2 = _cycle_re_rev.match(_z3_full)
                        _z3_base = _m2.group(1) if _m2 else _z3_full
                        _existing = _z3base_to_sig.get(_z3_base, '')
                        _new_in_assert = _sig_name in _assertion_signals
                        _old_in_assert = _existing in _assertion_signals
                        # Prefer assertion signal names; break ties by length
                        if (_new_in_assert and not _old_in_assert) or \
                           (_new_in_assert == _old_in_assert and len(_sig_name) > len(_existing)):
                            _z3base_to_sig[_z3_base] = _sig_name
                except Exception:
                    pass

        if hasattr(manager, 'violated_assertions') and manager.violated_assertions:
            print("Violated assertion details:")
            for va in manager.violated_assertions:
                print(f"  - condition: {va.get('condition', 'N/A')}")
                z3_cond = va.get('z3_condition')
                if z3_cond is not None:
                    try:
                        z3_str = z3_cond.sexpr() if hasattr(z3_cond, 'sexpr') else str(z3_cond)
                        # Replace underlying Z3 var names with assertion signal names.
                        # Sort by descending key length so longer names are replaced first,
                        # preventing short names (e.g. "o") from matching inside longer
                        # ones (e.g. "FC_DATA_gnt_o").
                        for _z3b, _sn in sorted(_z3base_to_sig.items(), key=lambda kv: -len(kv[0])):
                            # Match base_cN pattern (cycle-stamped variables).
                            # Use negative lookbehind to avoid matching inside longer names.
                            z3_str = re.sub(
                                r'(?<![A-Za-z0-9_])' + re.escape(_z3b) + r'(_c\d+)',
                                _sn + r'\1', z3_str)
                            # Also replace bare (non-cycle-stamped) occurrences
                            z3_str = re.sub(
                                r'(?<![A-Za-z0-9_])' + re.escape(_z3b) + r'(?![A-Za-z0-9_])',
                                _sn, z3_str)
                        if len(z3_str) > 200:
                            z3_str = z3_str[:200] + "... (truncated)"
                        print(f"    z3_condition: {z3_str}")
                    except Exception as e:
                        print(f"    z3_condition: (error: {e})")
                print(f"    kind: {va.get('kind', 'N/A')}")

        # Solve the CURRENT path condition (accumulated over all cycles) to get
        # the full multi-cycle model with _c0, _c1, ..., _cN stamped symbols.
        # Also add the negated assertion condition (the violation witness) so that
        # unconstrained signals like FC_DATA_gnt_o get concrete values that actually
        # satisfy the violation (e.g. gnt_o=1), not arbitrary solver defaults.
        ce_solver = Solver()
        for assertion in state.pc.assertions():
            ce_solver.add(assertion)
        # Add violation witness constraints from all violated assertions
        if hasattr(manager, 'violated_assertions') and manager.violated_assertions:
            from z3 import Not as z3_Not
            for _va in manager.violated_assertions:
                _z3_cond = _va.get('z3_condition')
                if _z3_cond is not None:
                    ce_solver.add(z3_Not(_z3_cond))
        if ce_solver.check() != z3_sat:
            print("\n(path condition UNSAT — cannot derive counterexample)")
            return

        model = ce_solver.model()
        decls = model.decls()
        if not decls:
            # Path condition has no symbolic constraints — the assertion fires for any
            # input. Try to get a concrete witness by adding the z3_condition itself.
            if hasattr(manager, 'violated_assertions') and manager.violated_assertions:
                va = manager.violated_assertions[-1]
                z3_cond = va.get('z3_condition')
                if z3_cond is not None:
                    from z3 import Not as z3_Not
                    witness_solver = Solver()
                    witness_solver.add(z3_Not(z3_cond))
                    if witness_solver.check() == z3_sat:
                        model = witness_solver.model()
                        decls = model.decls()
            if not decls:
                print("\nCounterexample: violation is unconditional (no free variables).")
                return

        # Build symbol-name -> concrete value mapping
        sym_vals = {d.name(): model[d] for d in decls}

        # Parse _cN suffix: symbol name format is "<signal>_c<cycle>"
        cycle_re = re.compile(r'^(.+)_c(\d+)$')

        # Group by cycle number; use assertion signal names where available
        # Reuse _z3base_to_sig (built above with assertion-priority logic)
        by_cycle: Dict[int, Dict[str, Any]] = {}
        ungrouped: Dict[str, Any] = {}
        for sym_name, val in sym_vals.items():
            m = cycle_re.match(sym_name)
            if m:
                sig, cyc = m.group(1), int(m.group(2))
                display = _z3base_to_sig.get(sig, sig)
                by_cycle.setdefault(cyc, {})[display] = val
            else:
                display = _z3base_to_sig.get(sym_name, sym_name)
                ungrouped[display] = val

        # Supplement by_cycle with assertion signals that are in state.store but
        # were not assigned by the solver (unconstrained free variables or derived
        # expressions like Extract from concat-assign).
        # model.eval(..., model_completion=True) evaluates any Z3 expression.
        #
        # Search both the current state.store (has _cN symbols for the latest cycle)
        # and the deferred violation's saved state (has _c0 symbols for cycle 0).
        # This covers the case where a deferred violation fires at cycle N but the
        # assertion signal is a derived expression (e.g. Extract from concat-assign)
        # that only appears in the model via its free variables.
        if _assertion_signals and by_cycle:
            import z3 as _z3
            _deferred = getattr(self, '_deferred_violation', None)
            _stores_to_search = [state.store]
            if _deferred is not None:
                _stores_to_search.append(_deferred[1].store)
            for _search_store in _stores_to_search:
                for _mod, _sigs in _search_store.items():
                    for _sig_name, _z3_val in _sigs.items():
                        if _sig_name not in _assertion_signals:
                            continue
                        try:
                            # Determine the cycle from the Z3 variable name.
                            # For free vars: decl().name() gives e.g. "FC_DATA_gnt_o_c1"
                            # For compound exprs (Extract etc.): walk free variables.
                            _cyc = None
                            if hasattr(_z3_val, 'decl') and _z3_val.num_args() == 0:
                                _z3_name = _z3_val.decl().name()
                                _m = cycle_re.match(_z3_name)
                                if _m:
                                    _cyc = int(_m.group(2))
                            else:
                                _free = _z3.z3util.get_vars(_z3_val)
                                for _fv in _free:
                                    _m = cycle_re.match(_fv.decl().name())
                                    if _m:
                                        _cyc = int(_m.group(2))
                                        break
                            if _cyc is None or _cyc not in by_cycle:
                                continue
                            _display = _sig_name
                            _eval_val = model.eval(_z3_val, model_completion=True)
                            # Add to the found cycle and all later cycles that lack this signal.
                            # Combinational signals may retain an earlier cycle stamp (_c0)
                            # even in later cycles, so propagate the value forward.
                            for _target_cyc in sorted(by_cycle.keys()):
                                if _target_cyc >= _cyc and _display not in by_cycle[_target_cyc]:
                                    by_cycle[_target_cyc][_display] = _eval_val
                        except Exception:
                            pass

        def _fmt_val(v) -> str:
            """Format a Z3 model value as hex (with decimal in parentheses).

            For BitVec values we show 0x<hex> (decimal).
            For Bool values we show True/False.
            Anything else falls back to str().
            """
            try:
                import z3 as _z3
                if isinstance(v, _z3.BitVecNumRef):
                    int_val = v.as_long()
                    size = v.size()
                    hex_digits = (size + 3) // 4
                    return f"0x{int_val:0{hex_digits}X}  ({int_val})"
                if isinstance(v, _z3.BoolRef):
                    return str(v)
            except Exception:
                pass
            return str(v)

        if by_cycle:
            print("\nCounterexample trace (cycle-by-cycle):")
            for cyc in sorted(by_cycle.keys()):
                print(f"  Cycle {cyc}:")
                for sig in sorted(by_cycle[cyc].keys()):
                    print(f"    {sig} = {_fmt_val(by_cycle[cyc][sig])}")
        if ungrouped:
            print("\nOther model values:")
            for sym, val in sorted(ungrouped.items()):
                print(f"  {sym} = {_fmt_val(val)}")
