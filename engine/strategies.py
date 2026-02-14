"""Exploration strategies for symbolic execution.

This module implements the Strategy Pattern to decouple search algorithms
from the execution mechanism.
"""

from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, Dict, List, Any, Optional, Tuple
from itertools import product
from copy import deepcopy
import heapq
import time

from z3 import Solver

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
        num_cycles: int
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

'''
class BlindSearchStrategy(ExplorationStrategy):
    """
    Blind search strategy using Cartesian product of all paths.

    This replicates the original behavior: pre-compute all path combinations
    and iterate through them exhaustively.
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
        num_cycles: int
    ) -> None:
        """Execute blind exhaustive search."""

        
        # old version
        # Build mapped_paths: module_name -> cfg_idx -> paths
        mapped_paths = {}
        for name in manager.names_list:
            mapped_paths[name] = {}

        for module_name, cfg_list in cfgs_by_module.items():
            for i, cfg in enumerate(cfg_list):
                mapped_paths[module_name][i] = cfg.paths

        # Build total_paths using Cartesian product
        single_paths_by_module = {}
        total_paths_by_module = {}
        for module_name in cfgs_by_module:
            print(f"Module {module_name} has {len(cfgs_by_module[module_name])} always blocks")
            single_paths_by_module[module_name] = product(*mapped_paths[module_name].values())
            total_paths_by_module[module_name] = list(tuple(product(
                product(*mapped_paths[module_name].values()),
                repeat=int(num_cycles)
            )))

        if not total_paths_by_module:
            total_paths = []
        else:
            keys = list(total_paths_by_module.keys())
            values = []
            for key in keys:
                module_paths = total_paths_by_module[key]
                if not module_paths:
                    module_paths = [tuple(() for _ in range(int(num_cycles)))]
                values.append(module_paths)

            total_paths = []
            for path_combo in product(*values):
                total_paths.append({k: list(p) for k, p in zip(keys, path_combo)})

        # Reset branch tracking
        manager.branch_count = 0
        manager.branch_points_seen = set()

        # Main exploration loop
        for i in range(len(total_paths)):
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

            print(f"Executing path {i+1} / {len(total_paths)}")
            engine.check_state(manager, state)

            curr_path = total_paths[i]
            modules_seen = 0
            for module_name in curr_path:
                manager.curr_module = manager.names_list[modules_seen]
                manager.cycle = 0
                for complete_single_cycle_path in curr_path[module_name]:
                    if manager.cycle > 0:
                        state.apply_pending_nba()

                    for cfg_idx, cfg_path in enumerate(complete_single_cycle_path):
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
                                direction = directions[k]
                                k += 1
                                basic_block = cfgs_by_module[module_name][cfg_idx].basic_block_list[basic_block_idx]
                                print(f"visiting basic_block: {[str(s)[:50] if s else 'None' for s in basic_block]}")
                                for stmt in basic_block:
                                    visitor.visit_stmt(manager, state, stmt, modules_dict, direction)

                    manager.cycle += 1
                modules_seen += 1

            manager.cycle = 0
            engine.done = True
            print(f"Checking path {i+1} / {len(total_paths)}")
            engine.check_state(manager, state)
            engine.done = False

            manager.curr_level = 0
            for module_name in manager.instances_seen:
                manager.instances_seen[module_name] = 0
                manager.instances_loc[module_name] = ""

            if engine.debug:
                print("------------------------")

            if manager.assertion_violation:
                self._handle_assertion_violation(engine, manager, state)
                return

            state.pc.reset()
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
'''
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
        num_cycles: int
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
            print(f"Checking path {manager.path_count + 1}")
            engine.check_state(manager, state)
            engine.done = False

            manager.curr_level = 0
            for module_name in manager.instances_seen:
                manager.instances_seen[module_name] = 0
                manager.instances_loc[module_name] = ""

            if engine.debug:
                print("------------------------")

            if manager.assertion_violation:
                self._handle_assertion_violation(engine, manager, state)
                return

            state.pc.reset()
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

    def __init__(self, milestone_manager: 'MilestoneManager', max_cycles: int = 100, max_paths: int = 1000):
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
        num_cycles: int
    ) -> None:
        """Execute milestone-directed search with priority queue."""

        print(f"[DirectedStrategy] Starting milestone-directed search")
        print(f"[DirectedStrategy] Milestones: {self.milestone_manager.milestones}")
        num_cycles_int = int(num_cycles)
        print(f"[DirectedStrategy] Max cycles: {min(self.max_cycles, num_cycles_int)}")

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
            if self.paths_explored % 100 == 0:
                print(f"[DirectedStrategy] Explored {self.paths_explored} paths, queue size: {len(worklist)}")

            # Execute one cycle for all modules
            result = self._execute_cycle(
                engine, visitor, modules_dict, cfgs_by_module,
                manager, item, worklist
            )

            if result == "VIOLATION":
                print(f"[DirectedStrategy] Assertion violation found!")
                self._handle_assertion_violation(engine, manager, item.state)
                return

            if result == "ALL_MILESTONES":
                print(f"[DirectedStrategy] All milestones reached!")
                print(f"[DirectedStrategy] Final state: {item.state.store}")
                return

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
        """Initialize symbolic state for all modules."""
        for module_name in manager.names_list:
            manager.curr_module = module_name
            visitor.symbolic_store.clear()
            visitor.visited.clear()
            visitor.dfs(modules_dict[module_name])
            for var_name in visitor.symbolic_store:
                if var_name not in state.store[module_name]:
                    state.store[module_name][var_name] = init_symbol()

        # Process declarations and combinational logic
        for module_name in manager.names_list:
            if module_name in cfgs_by_module:
                for c in cfgs_by_module[module_name]:
                    for node in c.decls:
                        visitor.dfs(node)
                    for node in c.comb:
                        visitor.dfs(node)

    def _clone_state(self, state: SymbolicState) -> SymbolicState:
        """
        Create a deep copy of the symbolic state.

        Z3 Solvers cannot be deep-copied, so we create a new solver
        and copy assertions.
        """
        new_state = SymbolicState()
        new_state.store = deepcopy(state.store)
        new_state.pending_nba = deepcopy(state.pending_nba)

        # Copy Z3 solver assertions
        new_state.pc = Solver()
        for assertion in state.pc.assertions():
            new_state.pc.add(assertion)

        return new_state

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
        """
        Execute one clock cycle for all modules.

        Returns:
            "VIOLATION" if assertion violated
            "ALL_MILESTONES" if all milestones reached
            None otherwise
        """
        state = item.state
        cycle = item.cycle

        # Apply pending non-blocking assignments from previous cycle
        if cycle > 0:
            state.apply_pending_nba()

        # Execute all modules for this cycle
        for module_name in manager.names_list:
            manager.curr_module = module_name
            manager.cycle = cycle

            if module_name not in cfgs_by_module:
                continue

            # Execute each CFG (always block) in the module
            for cfg_idx, cfg in enumerate(cfgs_by_module[module_name]):
                # For directed search, we explore all paths through the CFG
                # by creating child states at branch points
                result = self._execute_cfg_step_by_step(
                    engine, visitor, modules_dict, cfg, cfg_idx,
                    module_name, manager, state, worklist, item
                )

                if result == "VIOLATION":
                    return "VIOLATION"

        # After all modules executed, check milestones
        if self.milestone_manager.check_milestone(state, state.pc):
            if self.milestone_manager.all_milestones_reached():
                return "ALL_MILESTONES"

        # Check for assertion violations
        if manager.assertion_violation:
            return "VIOLATION"

        # Create work item for next cycle
        next_cycle = cycle + 1
        if next_cycle < self.max_cycles:
            new_score = self.milestone_manager.compute_score(next_cycle)
            new_item = WorkItem(
                score=new_score,
                cycle=next_cycle,
                milestones_completed=len(self.milestone_manager.milestones) - self.milestone_manager.milestones_remaining(),
                state=self._clone_state(state),
                execution_context=item.execution_context.copy()
            )
            heapq.heappush(worklist, new_item)

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
        state: SymbolicState,
        worklist: List[WorkItem],
        parent_item: WorkItem
    ) -> Optional[str]:
        """
        Execute a CFG step by step, branching at conditionals.

        For simplicity in this initial implementation, we execute all paths
        through the CFG but create separate states for each branch.
        """
        # Get all paths through this CFG
        paths = cfg.paths

        if not paths:
            return None

        # For the first path, execute directly on current state
        # For additional paths, clone state and add to worklist
        for path_idx, cfg_path in enumerate(paths):
            if path_idx == 0:
                # Execute on current state
                result = self._execute_path(
                    engine, visitor, modules_dict, cfg, cfg_path,
                    module_name, manager, state
                )
                if result == "VIOLATION":
                    return "VIOLATION"
            else:
                # Clone state and add to worklist for later exploration
                cloned_state = self._clone_state(state)
                new_score = self.milestone_manager.compute_score(parent_item.cycle)
                new_item = WorkItem(
                    score=new_score + path_idx,  # Slight penalty for alternative paths
                    cycle=parent_item.cycle,
                    milestones_completed=parent_item.milestones_completed,
                    state=cloned_state,
                    execution_context={
                        'pending_path': (module_name, cfg_idx, cfg_path),
                        **parent_item.execution_context
                    }
                )
                heapq.heappush(worklist, new_item)

        return None

    def _execute_path(
        self,
        engine: 'ExecutionEngine',
        visitor: Any,
        modules_dict: Dict[str, Any],
        cfg: Any,
        cfg_path: List[int],
        module_name: str,
        manager: ExecutionManager,
        state: SymbolicState
    ) -> Optional[str]:
        """Execute a single path through a CFG."""
        directions = cfg.compute_direction(cfg_path)

        k = 0
        for basic_block_idx in cfg_path:
            if basic_block_idx < 0:
                # Skip dummy nodes
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
                print(f"    z3_condition: {va.get('z3_condition', 'N/A')}")
                print(f"    path condition: {va.get('path condition', 'N/A')}")
                print(f"    kind: {va.get('kind', 'N/A')}")

        counterexample = {}
        symbols_to_values = {}

        if engine.solve_pc(state.pc):
            solved_model = state.pc.model()
            decls = solved_model.decls()
            for item in decls:
                symbols_to_values[item.name()] = solved_model[item]

            for module in state.store:
                for signal in state.store[module]:
                    for symbol in symbols_to_values:
                        if state.store[module][signal] == symbol:
                            counterexample[signal] = symbols_to_values[symbol]

            print(f"Counterexample: {counterexample}")
        else:
            print("UNSAT - no counterexample found")
