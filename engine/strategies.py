"""Exploration strategies for symbolic execution.

This module implements the Strategy Pattern to decouple search algorithms
from the execution mechanism.
"""

from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, Dict, List, Any, Optional, Tuple, Union
from itertools import product
from copy import deepcopy
import heapq
import time

from z3 import Solver, sat

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
            print(f"\n--- [Path {self.paths_explored}] Popped: score={item.score}, cycle={item.cycle}, milestones={item.milestones_completed}/{len(self.milestone_manager.milestones)}, queue={len(worklist)}")

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

            if result == "ALL_MILESTONES":
                print(f"[Path {self.paths_explored}] cycle={item.cycle}, result=ALL_MILESTONES, milestones={len(self.milestone_manager.milestones)}/{len(self.milestone_manager.milestones)}")
                print(f"[DirectedStrategy] All milestones reached!")
                print(f"[DirectedStrategy] Final state: {item.state.store}")
                return

            # Path ended without violation or milestone completion
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

# engine/strategies.py (截取 MilestoneDirectedStrategy 的修改部分)
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
        """执行一个完整的时钟周期"""
        cycle = item.cycle

        if cycle > 0:
            item.state.apply_pending_nba()

        # 1. 局部状态列表：保存本周期内的所有平行宇宙（最初只有一个）
        active_states = [item.state]

        for module_name in manager.names_list:
            manager.curr_module = module_name
            manager.cycle = cycle

            if module_name not in cfgs_by_module:
                continue

            for cfg_idx, cfg in enumerate(cfgs_by_module[module_name]):
                # Skip initial blocks after cycle 0
                if cycle > 0 and getattr(cfg, 'is_initial', False):
                    continue
                next_active_states = []
                for state in active_states:
                    # 分支裂变：传入1个状态，可能返回1个或多个存活状态
                    result = self._execute_cfg_step_by_step(
                        engine, visitor, modules_dict, cfg, cfg_idx,
                        module_name, manager, state
                    )
                    if result == "VIOLATION":
                        return "VIOLATION"
                    # 将该 CFG 分支出的所有有效状态收集起来
                    next_active_states.extend(result)
                active_states = next_active_states

        # 2. 周期结束：处理所有存活的平行宇宙，检查里程碑，然后推入全局队列
        for state in active_states:
            current_progress = item.milestones_completed
            
            # 连续检查并固化里程碑 (注意这里换成了无状态方法，下文会解释)
            while current_progress < len(self.milestone_manager.milestones):
                success, new_progress = self.milestone_manager.check_and_lock_stateless(state, current_progress)
                if success:
                    current_progress = new_progress
                else:
                    break

            if current_progress >= len(self.milestone_manager.milestones):
                return "ALL_MILESTONES"

            # 3. 检查断言违例
            if manager.assertion_violation:
                return "VIOLATION"

            # 4. 生成下一周期的任务并入队
            if state.pc.check() == sat:
                next_cycle = cycle + 1
                if next_cycle < self.max_cycles:
                    new_score = self.milestone_manager.compute_score_stateless(current_progress, next_cycle)
                    new_item = WorkItem(
                        score=new_score,
                        cycle=next_cycle,
                        milestones_completed=current_progress,
                        state=state,
                        execution_context=item.execution_context.copy()
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

        if len(paths) > 1:
            print(f"  [Branch] {module_name}/cfg{cfg_idx}: {len(paths)} paths")
            clean_base_state = self._clone_state(state)

        for path_idx, cfg_path in enumerate(paths):
            if path_idx == 0:
                curr_state = state
            else:
                curr_state = self._clone_state(clean_base_state)

            result = self._execute_path(
                engine, visitor, modules_dict, cfg, cfg_path,
                module_name, manager, curr_state
            )

            if result == "VIOLATION":
                return "VIOLATION"

            # Early Pruning
            if curr_state.pc.check() == sat:
                valid_states.append(curr_state)
            else:
                print(f"  [Pruned] {module_name}/cfg{cfg_idx}/path{path_idx}: UNSAT")

        if len(paths) > 1:
            print(f"  [Branch] {module_name}/cfg{cfg_idx}: {len(valid_states)}/{len(paths)} survived")

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
