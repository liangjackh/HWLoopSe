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

from z3 import Solver, sat, BitVec

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
        execution_context: Dict[str, Any]
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
        """
        self.score = score
        self.cycle = cycle
        self.milestones_completed = milestones_completed
        self.state = state
        self.execution_context = execution_context
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

    def __init__(self, milestone_manager: 'MilestoneManager', max_cycles: int = 100, max_paths: int = 500000):
        """
        Initialize the directed strategy.

        Args:
            milestone_manager: Manager for milestone checking
            max_cycles: Maximum clock cycles before timeout
            max_paths: Maximum number of paths to explore before giving up
        """
        self.milestone_manager = milestone_manager
        self.max_cycles = max_cycles
        self.max_paths = max_paths
        self.paths_explored = 0

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
        """Execute milestone-directed search with priority queue."""

        print(f"[DirectedStrategy] Starting milestone-directed search")
        print(f"[DirectedStrategy] Milestones: {self.milestone_manager.milestones}")
        num_cycles_int = int(num_cycles)
        print(f"[DirectedStrategy] Max cycles: {min(self.max_cycles, num_cycles_int)}")

        # Store comb_by_module and wire_groups for use in _execute_cycle
        self._comb_by_module = comb_by_module or {}
        self._wire_groups = wire_groups or []
        self._primary_input_flags = primary_input_flags or []
        self._active_instances = set(manager.names_list)

        # Build topologically sorted comb nodes (single-pass instead of 2-pass fixedpoint)
        self._sorted_comb_by_module = self._topo_sort_comb(cfgs_by_module, manager)

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

            self.paths_explored += 1
            print(f"\n--- [Path {self.paths_explored}] Popped: score={item.score}, cycle={item.cycle}, milestones={item.milestones_completed}/{len(self.milestone_manager.milestones)}, queue={len(worklist)}")

            # Reset manager flags for this work item
            manager.ignore = False
            manager.abandon = False
            manager.assertion_violation = False
            if hasattr(manager, 'violated_assertions'):
                manager.violated_assertions = []

            # Execute one cycle for all modules
            result = self._execute_cycle(
                engine, visitor, modules_dict, cfgs_by_module,
                manager, item, worklist
            )

            if result == "VIOLATION":
                print(f"[Path {self.paths_explored}] cycle={item.cycle}, result=VIOLATION, milestones={item.milestones_completed}/{len(self.milestone_manager.milestones)}")
                print(f"[DirectedStrategy] Assertion violation found!")
                self._handle_assertion_violation(engine, manager, item.state)
                return

            # Path ended without violation
            if result is None:
                print(f"[Path {self.paths_explored}] cycle={item.cycle}, result=CONTINUE, milestones={item.milestones_completed}/{len(self.milestone_manager.milestones)}")
            elif result == "TIMEOUT":
                print(f"[Path {self.paths_explored}] cycle={item.cycle}, result=TIMEOUT, milestones={item.milestones_completed}/{len(self.milestone_manager.milestones)}")

        print(f"[DirectedStrategy] Search exhausted (UNSAT)")
        print(f"[DirectedStrategy] Paths explored: {self.paths_explored}")
        print(f"[DirectedStrategy] Branch points: {manager.branch_count}")

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
                    # Initialize everything to 0 (Verilog default for regs).
                    # Port propagation + _unify_port_symbols will later assign
                    # shared fresh symbols to signals connected through ports,
                    # so primary inputs end up symbolic while internal signals
                    # start at a well-defined value.
                    state.store[module_name][var_name] = BitVecVal(0, 32)

        # Process declarations using visitor.dfs (these are Symbol/Syntax nodes)
        for module_name in manager.names_list:
            manager.curr_module = module_name
            if module_name in cfgs_by_module:
                for c in cfgs_by_module[module_name]:
                    for node in c.decls:
                        visitor.dfs(node)

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
        # it's likely the single reset path (no further branching inside reset).
        # Prefer a non-reset path (direction[0]==0) for cycle > 0.
        if dir_1_count == 1 and dir_0_count >= 1:
            non_reset_indices = [i for i, d in enumerate(first_dirs) if d == 0]
            # Alternate among non-reset paths by cycle to create diverse
            # constraint combinations across cycles
            return non_reset_indices[(cycle - 1) % len(non_reset_indices)]

        return 0

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

        for group in self._wire_groups:
            # Pick a representative name for the group
            rep_inst, rep_sig = next(iter(group))
            sym_name = f"{rep_sig}_c{cycle}"
            shared_bv = BitVec(sym_name, 32)

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
            shared_bv = BitVec(sym_name, 32)

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

    def _evaluate_comb_topo(
        self,
        visitor: Any,
        manager: ExecutionManager,
        state: SymbolicState
    ):
        """Single-pass combinational evaluation in topological order."""
        for module_name in manager.names_list:
            manager.curr_module = module_name
            for node in self._sorted_comb_by_module.get(module_name, []):
                visitor.evaluate_comb(manager, state, node)
        self._propagate_ports(state)

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
    ) -> Optional[str]:
        """Execute one clock cycle (Sylvia-style: lazy fork at branch points).

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

        # Step 1: Apply NBA and refresh inputs (if cycle > 0)
        if cycle > 0:
            item.state.apply_pending_nba()
            self._refresh_primary_inputs(item.state, cycle)
            self._evaluate_comb_topo(visitor, manager, item.state)

        # Step 2: Build CFG list if not already in context
        remaining_cfgs = item.execution_context.get('remaining_cfgs', None)
        if remaining_cfgs is None:
            remaining_cfgs = []
            for module_name in manager.names_list:
                if module_name not in cfgs_by_module:
                    continue
                for cfg_idx, cfg in enumerate(cfgs_by_module[module_name]):
                    if cycle > 0 and getattr(cfg, 'is_initial', False):
                        continue
                    paths = cfg.paths
                    if not paths:
                        continue
                    remaining_cfgs.append({
                        'module': module_name,
                        'cfg_idx': cfg_idx,
                        'path_idx': self._preferred_path_idx(cfg, cycle),
                    })

        # Step 3: Execute CFGs sequentially, lazy-fork at branches
        state = item.state
        for i, cfg_entry in enumerate(remaining_cfgs):
            module_name = cfg_entry['module']
            cfg_idx = cfg_entry['cfg_idx']
            chosen_path_idx = cfg_entry['path_idx']

            manager.curr_module = module_name
            manager.cycle = cycle

            cfg = cfgs_by_module[module_name][cfg_idx]

            # Clamp path index
            if chosen_path_idx >= len(cfg.paths):
                chosen_path_idx = 0

            # Lazy fork: if this CFG has multiple paths and we're taking path 0
            # (i.e., not already a forked work item for a specific path),
            # push siblings for the other paths.
            if len(cfg.paths) > 1 and cfg_entry.get('forked', False) is False:
                pre_branch_state = self._clone_state(state)
                for alt_path_idx in range(len(cfg.paths)):
                    if alt_path_idx == chosen_path_idx:
                        continue
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
                        execution_context=alt_ctx
                    )
                    heapq.heappush(worklist, alt_item)

            # Execute the chosen path
            cfg_path = cfg.paths[chosen_path_idx]
            manager.ignore = False
            manager.abandon = False

            # Snapshot store & pending_nba so we can rollback on abandon
            pre_cfg_store = {mod: sigs.copy() for mod, sigs in state.store.items()}
            pre_cfg_nba = {mod: sigs.copy() for mod, sigs in state.pending_nba.items()}

            result = self._execute_path(
                engine, visitor, modules_dict, cfg, cfg_path,
                module_name, manager, state, cfg_idx, chosen_path_idx
            )

            if result == "VIOLATION":
                return "VIOLATION"

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

        # Step 4: Re-evaluate comb after sequential logic
        self._evaluate_comb_topo(visitor, manager, state)

        # Step 5: Check SAT
        if state.pc.check() != sat:
            print(f"  [Pruned] cycle {cycle}: UNSAT after execution")
            return None

        # Step 6: Check milestones
        current_progress = item.milestones_completed
        while current_progress < len(self.milestone_manager.milestones):
            success, new_progress = self.milestone_manager.check_and_lock_stateless(state, current_progress)
            if success:
                current_progress = new_progress
            else:
                break

        if manager.assertion_violation:
            return "VIOLATION"

        # Step 7: Enqueue next cycle
        next_cycle = cycle + 1
        if next_cycle < self.max_cycles:
            new_score = self.milestone_manager.compute_score_stateless(current_progress, next_cycle)
            new_item = WorkItem(
                score=new_score,
                cycle=next_cycle,
                milestones_completed=current_progress,
                state=state,
                execution_context={'remaining_cfgs': None}  # fresh at next cycle
            )
            heapq.heappush(worklist, new_item)
            print(f"  [Enqueue] score={new_score}, next_cycle={next_cycle}, milestones={current_progress}/{len(self.milestone_manager.milestones)}")
        else:
            print(f"  [MaxCycle] cycle {next_cycle} >= limit {self.max_cycles}, not enqueued")

        return None

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
        """Handle assertion violation."""
        print("Assertion violation detected!")
        if hasattr(manager, 'violated_assertions') and manager.violated_assertions:
            print("Violated assertion details:")
            for va in manager.violated_assertions:
                print(f"  - condition: {va.get('condition', 'N/A')}")

                # Better z3_condition display
                z3_cond = va.get('z3_condition')
                if z3_cond is not None:
                    try:
                        if hasattr(z3_cond, 'sexpr'):
                            z3_str = z3_cond.sexpr()
                            if len(z3_str) > 200:
                                print(f"    z3_condition: {z3_str[:200]}... (truncated)")
                            else:
                                print(f"    z3_condition: {z3_str}")
                        else:
                            print(f"    z3_condition: {z3_cond}")
                    except Exception as e:
                        print(f"    z3_condition: (error displaying: {e})")
                else:
                    print(f"    z3_condition: N/A")

                print(f"    kind: {va.get('kind', 'N/A')}")

        # Extract counterexample from the stored model
        counterexample = {}

        if hasattr(manager, 'violated_assertions') and manager.violated_assertions:
            for va in manager.violated_assertions:
                model = va.get('model')

                if model is not None:
                    # Get all declarations from the model
                    decls = model.decls()

                    if decls:
                        print(f"\nCounterexample (input values):")

                        # Build a mapping of symbol names to values
                        symbols_to_values = {}
                        for item in decls:
                            symbols_to_values[item.name()] = model[item]

                        # Match signals to their symbolic values
                        for module in state.store:
                            for signal in state.store[module]:
                                signal_expr = state.store[module][signal]
                                # signal_expr is a string like "RST_0" or "CLK_1"
                                if isinstance(signal_expr, str):
                                    # Check if this exact symbol exists in the model
                                    if signal_expr in symbols_to_values:
                                        counterexample[f"{module}.{signal}"] = symbols_to_values[signal_expr]

                        # Print counterexample
                        if counterexample:
                            for sig, val in counterexample.items():
                                print(f"  {sig} = {val}")
                        else:
                            print("  (no matching signals found in store)")

                        # Also print all symbols for debugging
                        print(f"\nAll symbols in model:")
                        for sym, val in symbols_to_values.items():
                            print(f"  {sym} = {val}")
                    else:
                        # Model has no free variables - all values are concrete
                        print(f"\nCounterexample:")
                        print(f"  The assertion violation occurs with concrete values.")
                        print(f"  This means the design has a bug that always triggers,")
                        print(f"  not dependent on specific input values.")
                        print(f"\n  Path condition constraints:")
                        path_cond = va.get('path condition', [])
                        if path_cond:
                            for i, constraint in enumerate(path_cond):
                                # Try to get a better representation
                                constraint_str = str(constraint)
                                if len(constraint_str) > 100:
                                    # Try sexpr if available
                                    if hasattr(constraint, 'sexpr'):
                                        constraint_str = constraint.sexpr()
                                        if len(constraint_str) > 150:
                                            constraint_str = constraint_str[:150] + "... (truncated)"
                                    else:
                                        constraint_str = constraint_str[:100] + "... (truncated)"
                                print(f"    [{i}] {constraint_str}")
                        else:
                            print(f"    (no path constraints)")

                    break  # Only process first violation
        else:
            print("No violation information available")
