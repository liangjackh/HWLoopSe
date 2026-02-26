# Main execution engine that orchestrates symbolic execution of SystemVerilog designs

import z3
from z3 import Solver, Int, BitVec, Context, BitVecSort, ExprRef, BitVecRef, If, BitVecVal, And
from .execution_manager import ExecutionManager
from .symbolic_state import SymbolicState
from .cfg import CFG
import re
import os
import json
from optparse import OptionParser
from typing import Optional, List, Tuple, TYPE_CHECKING
import random, string
import time
import gc
from itertools import product
import logging
from helpers.utils import to_binary, init_symbol
import sys
import time
from copy import deepcopy
import pyslang as ps
from helpers.slang_helpers import get_module_name, init_state

if TYPE_CHECKING:
    from .strategies import ExplorationStrategy
    from .config import EngineConfig

# Tuple of PySlang AST node types that represent conditional/loop statements
CONDITIONALS = (
    ps.ConditionalStatementSyntax,
    ps.CaseStatementSyntax,
    ps.ForeachLoopStatementSyntax,
    ps.ForLoopStatementSyntax,
    ps.LoopStatementSyntax,
    ps.DoWhileStatementSyntax
)


class ExecutionEngine:
    """Drives the entire symbolic execution process.

    This class is the main orchestrator that handles:
    - Design compilation (PySlang)
    - Visitor setup (SymbolicDFS, SlangSymbolVisitor)
    - Strategy selection and execution
    - Auto-plan milestone generation (optional)
    """

    module_depth: int = 0  # Tracks current module nesting depth during execution
    debug: bool = False  # Boolean flag to enable debug output
    done: bool = False  # Boolean flag indicating if execution is complete
    cache = None  # Optional Redis cache for Z3 solver results TODO
    strategy: Optional['ExplorationStrategy'] = None  # Pluggable exploration strategy

    # Auto-plan configuration
    auto_plan_enabled: bool = False  # Enable LLM-based milestone generation
    llm_api_key: Optional[str] = None  # API key for LLM provider
    llm_provider: str = "auto"  # LLM provider: openai, anthropic, deepseek, or auto
    llm_mock: bool = False  # Use mock LLM responses for testing
    llm_base_url: Optional[str] = None  # Custom base URL for LLM API

    # COI configuration
    coi_enabled: bool = False  # Enable Cone of Influence pruning
    coi_result = None  # Stores COIResult after analysis

    # Internal state set by _compile_design
    _driver = None
    _compilation = None
    _visitor = None
    _symbol_visitor = None

    def __init__(self):
        """Initialize the execution engine."""
        self.module_depth = 0
        self.debug = False
        self.done = False
        self.cache = None
        self.strategy = None
        self.auto_plan_enabled = False
        self.llm_api_key = None
        self.llm_provider = "auto"
        self.llm_mock = False
        self.llm_base_url = None
        self._driver = None
        self._compilation = None
        self._visitor = None
        self._symbol_visitor = None
        self.coi_enabled = False
        self.coi_result = None

    def _compile_design(self, file_path: str, config: "EngineConfig") -> Tuple[any, any, List]:
        """Compile the design using PySlang.

        Args:
            file_path: Path to the Verilog/SystemVerilog file or .F filelist
            config: Engine configuration

        Returns:
            Tuple of (driver, compilation, modules)

        Raises:
            SystemExit: If compilation fails with errors
        """
        driver = ps.Driver()
        driver.addStandardArgs()

        # Set include paths
        for inc_path in config.include_paths:
            driver.sourceLoader.addSearchDirectories(inc_path)

        # Check file exists
        if not os.path.exists(file_path):
            print(f"[Error] File not found: {file_path}")
            sys.exit(1)

        # Load source files
        if file_path.endswith('.F') or file_path.endswith('.f'):
            driver.processCommandFiles(file_path, True, False)
        else:
            driver.sourceLoader.addFiles(file_path)

        driver.processOptions()
        driver.parseAllSources()

        # Create Compilation
        compilation = driver.createCompilation()

        # Get diagnostics
        diags = compilation.getAllDiagnostics()
        diag_engine = ps.DiagnosticEngine(driver.sourceManager)
        client = ps.TextDiagnosticClient()
        diag_engine.addClient(client)

        for d in diags:
            diag_engine.issue(d)

        report = client.getString()
        has_errors = any(d.isError() for d in diags)

        if report:
            print("\n" + "=" * 40)
            print("COMPILATION DIAGNOSTICS:")
            print("=" * 40)
            print(report)
            print("=" * 40 + "\n")

        if has_errors:
            print("[Fatal] Compilation failed with errors. See above.")
            sys.exit(1)

        # Discover modules
        modules = self._discover_modules(compilation, config.top_module)

        if not modules:
            print("[Error] No modules found in the design!")
            sys.exit(1)

        print(f"[Info] Found {len(modules)} top-level module instance(s):")
        for mod in modules:
            print(f"  - {mod.name}")

        self._driver = driver
        self._compilation = compilation
        return driver, compilation, modules

    def _discover_modules(self, compilation, top_module: Optional[str]) -> List:
        """Discover modules from compilation.

        Args:
            compilation: PySlang compilation object
            top_module: Name of top module to analyze (None = auto-detect)

        Returns:
            List of module instances
        """
        modules = list(compilation.getRoot().topInstances)

        def collect_all_instances(symbol, collected):
            """Recursively collect all module instances including nested ones."""
            if symbol.kind == ps.SymbolKind.Instance:
                collected.append(symbol)
                for child in symbol.body:
                    collect_all_instances(child, collected)

        # If user specified a top module, find and use only that module
        selected_module = None
        if top_module:
            # First check top instances
            for module in modules:
                if module.name == top_module or \
                   (hasattr(module.body, 'definition') and module.body.definition.name == top_module):
                    selected_module = module
                    break

            # If not found in top instances, search nested instances
            if not selected_module:
                for module in modules:
                    for child in module.body:
                        if child.kind == ps.SymbolKind.Instance:
                            if child.name == top_module or \
                               (hasattr(child.body, 'definition') and child.body.definition.name == top_module):
                                selected_module = child
                                break
                    if selected_module:
                        break

            if not selected_module:
                print(f"[Error] Specified top module '{top_module}' not found")
                print(f"Available modules: {[m.name for m in modules]}")
                sys.exit(1)
        else:
            selected_module = modules[0] if modules else None

        # Collect all instances from selected module
        all_instances = []
        if selected_module:
            collect_all_instances(selected_module, all_instances)
            return all_instances

        # Fallback: search syntax trees for definitions
        if not modules:
            print("No top instances found, searching syntax trees for definitions...")
            syntax_trees = compilation.getSyntaxTrees()
            for tree in syntax_trees:
                for member in tree.root.members:
                    if hasattr(member, 'kind') and 'ModuleDeclaration' in str(member.kind):
                        modules.append(member)

        return modules

    def _setup_visitors(self, num_cycles: int):
        """Set up the AST visitors for symbolic execution.

        Args:
            num_cycles: Number of clock cycles to simulate

        Returns:
            Tuple of (symbolic_visitor, symbol_visitor)
        """
        from helpers.slang_helpers import SymbolicDFS, SlangSymbolVisitor
        from helpers.rvalue_to_z3 import parse_expr_to_Z3

        symbolic_visitor = SymbolicDFS(num_cycles)
        # Bind the Z3 parser helper
        symbolic_visitor.expr_to_z3 = lambda m, s, e: parse_expr_to_Z3(e, s, m)

        symbol_visitor = SlangSymbolVisitor()

        self._visitor = symbolic_visitor
        self._symbol_visitor = symbol_visitor
        return symbolic_visitor, symbol_visitor

    def _configure_from_config(self, config: "EngineConfig") -> None:
        """Configure engine from EngineConfig.

        Args:
            config: Engine configuration
        """
        self.debug = config.debug
        self.auto_plan_enabled = config.auto_plan
        self.llm_api_key = config.llm_api_key
        self.llm_provider = config.llm_provider
        self.llm_mock = config.llm_mock
        self.llm_base_url = config.llm_base_url

        if config.debug:
            from helpers.debug import set_debug
            set_debug(True)

        if config.use_cache:
            import redis
            self.cache = redis.Redis(host='localhost', port=6379, db=0)

        if config.auto_plan:
            print(f"[ExecutionEngine] Auto-plan enabled (provider={config.llm_provider}, mock={config.llm_mock})")

        if config.coi:
            self.coi_enabled = True
            print("[ExecutionEngine] Cone of Influence (COI) pruning enabled")

    def run(self, file_path: str, config: "EngineConfig") -> None:
        """Main entry point for symbolic execution.

        This is the clean public API that orchestrates:
        1. Design compilation
        2. Visitor setup
        3. Strategy creation
        4. Execution

        Args:
            file_path: Path to the Verilog/SystemVerilog file or .F filelist
            config: Engine configuration
        """
        start_time = time.process_time()

        # Configure engine from config
        self._configure_from_config(config)

        # Step 1: Compile design
        driver, compilation, modules = self._compile_design(file_path, config)

        # Step 2: Setup visitors
        visitor, symbol_visitor = self._setup_visitors(config.num_cycles)

        # Step 3: Create strategy
        from .strategy_factory import StrategyFactory
        strategy = StrategyFactory.create(config)
        self.set_strategy(strategy)
        print(f"[ExecutionEngine] Using {config.strategy} search strategy")

        explore_time = time.process_time()
        # Step 4: Execute
        self.execute_sv(visitor, modules, None, config.num_cycles, driver, compilation)

        end_time = time.process_time()
        print(f"Execution time {end_time - explore_time}")
        print(f"Frontend time {explore_time - start_time}")
        print(f"Total time {end_time - start_time}")

    def set_strategy(self, strategy: 'ExplorationStrategy') -> None:
        """Set the exploration strategy to use."""
        self.strategy = strategy
        print(f"[ExecutionEngine] Strategy set to: {strategy.__class__.__name__}")

    def check_pc_SAT(self, s: Solver, constraint: ExprRef) -> bool:
        """Check if pc is satisfiable before taking path."""
        # the push adds a backtracking point if unsat
        s.push()
        s.add(constraint)
        result = s.check()
        if str(result) == "sat":
            return True
        else:
            s.pop()
            return False

    def check_dup(self, m: ExecutionManager) -> bool:
        """Checks if the current path is a duplicate/worth exploring."""
        for i in range(len(m.path_code)):
            if m.path_code[i] == "1" and i in m.completed:
                return True
        return False

    def solve_pc(self, s: Solver) -> bool:
        """Solves path condition using Z3"""
        result = str(s.check())
        if str(result) == "sat":
            model = s.model()
            return True
        else:
            return False

    def seen_all_cases(self, m: ExecutionManager, bit_index: int, nested_ifs: int) -> bool:
        """Checks if we've seen all the cases for this index in the bit string.
        We know there are no more nested conditionals within the block, just want to check 
        that we have seen the path where this bit was turned on but the thing to the left of it
        could vary."""
        # first check if things less than me have been added.
        # so index 29 shouldnt be completed before 30
        for i in range(bit_index + 1, 32):
            if not i in m.completed:
                return False
        count = 0
        seen = m.seen
        for path in seen[m.curr_module]:
            if path[bit_index] == '1':
                count += 1
        if count >  2 * nested_ifs:
            return True
        return False

    def module_count_sv(self, m: ExecutionManager, items) -> None:
        """Traverse a top level SystemVerilog module (pyslang AST) and count instances.

        This implementation uses duck-typing and classname checks so it is robust
        across pyslang node variants. It attempts to find instantiation nodes
        and increment m.instance_count[module_name].
        """
        if items is None:
            return

        # If it's a plain list/tuple of nodes, recurse over each element
        if isinstance(items, (list, tuple)):
            for it in items:
                self.module_count_sv(m, it)
            return

        # Normalize access: many pyslang nodes wrap a single statement under .statement
        # e.g., ProceduralBlockSyntax -> .statement; handle that first.
        cname = items.__class__.__name__ if hasattr(items, '__class__') else ''
        print(f"Visiting node type: {cname}")
        if cname == "ProceduralBlockSyntax" and hasattr(items, 'statement'):
            self.module_count_sv(m, items.statement)
            return

        # If the node exposes an `instances` collection (common for instantiation lists),
        # traverse it first so nested instance lists are handled.
        if hasattr(items, 'instances'):
            self.module_count_sv(m, items.instances)

        # Heuristic: if the class name suggests an instantiation/instance, try to extract module name
        lower_name = cname.lower()
        if 'instance' in lower_name or 'instantiat' in lower_name or 'moduleinst' in lower_name:
            # Try a set of common attribute names that may hold the referenced module name/object
            mod_name = None
            for attr in ('module', 'module_name', 'moduleName', 'module_identifier',
                         'moduleReference', 'module_ref', 'moduleIdentifier', 'moduleType',
                         'type'):
                if hasattr(items, attr):
                    val = getattr(items, attr)
                    if val is None:
                        continue
                    if isinstance(val, str):
                        mod_name = val
                    else:
                        # attempt to extract a name from an identifier node
                        mod_name = getattr(val, 'name', None) or getattr(val, 'identifier', None) or str(val)
                    break

            # If we couldn't find a direct attribute, some pyslang instantiation nodes
            # keep the module reference under a nested template like `.module` or `.moduleName`
            if not mod_name:
                # inspect all attributes for something that looks like a module identifier
                for a in dir(items):
                    if 'module' in a.lower() or 'instance' in a.lower():
                        val = getattr(items, a)
                        if isinstance(val, str):
                            mod_name = val
                            break
                        if hasattr(val, 'name'):
                            mod_name = getattr(val, 'name')
                            break

            if mod_name:
                m.instance_count[mod_name] = m.instance_count.get(mod_name, 0) + 1

            # If the instantiation node also contains nested children, traverse them
            for child_attr in ('items', 'statements', 'statement', 'instances', 'children', 'body'):
                if hasattr(items, child_attr):
                    self.module_count_sv(m, getattr(items, child_attr))
            return

        # Otherwise, descend into common container attributes to find nested instantiations
        for attr in ('items', 'statements', 'body', 'statement', 'declarationList', 'declarations'):
            if hasattr(items, attr):
                child = getattr(items, attr)
                if child is not None:
                    self.module_count_sv(m, child)



    def populate_child_paths(self, manager: ExecutionManager) -> None:
        """Populates child path codes based on number of paths."""
        for child in manager.child_num_paths:
            manager.child_path_codes[child] = []
            if manager.piece_wise:
                manager.child_path_codes[child] = []
                for i in manager.child_range:
                    manager.child_path_codes[child].append(to_binary(i))
            else:
                for i in range(manager.child_num_paths[child]):
                    manager.child_path_codes[child].append(to_binary(i))

    def populate_seen_mod(self, manager: ExecutionManager) -> None:
        """Populates child path codes but in a format to keep track of corresponding states that we've seen."""
        for child in manager.child_num_paths:
            manager.seen_mod[child] = {}
            if manager.piece_wise:
                for i in manager.child_range:
                    manager.seen_mod[child][(to_binary(i))] = {}
            else:
                for i in range(manager.child_num_paths[child]):
                    manager.seen_mod[child][(to_binary(i))] = {}

    def execute_sv(self, visitor, modules, manager: Optional[ExecutionManager], num_cycles: int,
                   driver=None, compilation=None) -> None:
        """Main entry point for PySlang execution
        Drives symbolic execution for SystemVerilog designs.

        Args:
            visitor: SymbolicDFS visitor for traversing AST
            modules: List of module instances
            manager: ExecutionManager (or None to create new)
            num_cycles: Number of clock cycles to execute
            driver: PySlang driver (needed for auto-plan context slicing)
            compilation: PySlang compilation (needed for auto-plan context slicing)
        """
        gc.collect()
        print(f"Executing for {num_cycles} clock cycles")
        self.module_depth += 1
        state: SymbolicState = SymbolicState()
        if manager is None:
            manager: ExecutionManager = ExecutionManager()
            manager.cache = self.cache
            manager.sv = True
            modules_dict = {}
            # CFGs keyed by module definition name (shared across instances)
            cfgs_by_definition = {}
            # CFGs keyed by instance name (references to cfgs_by_definition)
            cfgs_by_module = {}

            # Step 1: Group instances by their module definition name
            # definition_name -> list of (instance_name, instance_symbol)
            definitions_to_instances = {}
            for module in modules:
                instance_name = get_module_name(module)  # actual instance name
                definition_name = module.definition.name  # module definition name
                print("-----------------------------------")
                print(f"Processing instance: {instance_name}, definition: {definition_name}")

                modules_dict[instance_name] = module # instance_dict in fact

                if definition_name not in definitions_to_instances:
                    definitions_to_instances[definition_name] = []
                definitions_to_instances[definition_name].append((instance_name, module))

            # Step 2: Build CFGs once per module definition
            for definition_name, instances in definitions_to_instances.items():
                print(f"Building CFGs for module definition: {definition_name} ({len(instances)} instance(s))")

                # Use the first instance to build CFGs (all instances of same definition have same structure)
                _, representative_module = instances[0]

                # Discover always blocks
                probe = CFG()
                probe.get_always_sv(manager, state, representative_module)

                cfgs_by_definition[definition_name] = []
                for ab in probe.always_blocks:
                    ab_body = getattr(ab, "statement", getattr(ab, "members", ab))
                    c = CFG()
                    c.module_name = definition_name
                    # Tag initial blocks so they only execute on cycle 0
                    if hasattr(ab, 'kind') and str(ab.kind) == 'SyntaxKind.InitialBlock':
                        c.is_initial = True
                    c.basic_blocks_sv(manager, state, ab_body)
                    c.partition()
                    c.build_cfg(manager, state)
                    cfgs_by_definition[definition_name].append(c)

                print(f"  Built {len(cfgs_by_definition[definition_name])} CFG(s) for {definition_name}")

            # Step 3: Create per-instance state and reference shared CFGs
            for definition_name, instances in definitions_to_instances.items():
                # Track instance count per definition
                manager.instance_count[definition_name] = len(instances)
                if len(instances) > 1:
                    manager.instances_seen[definition_name] = 0
                    manager.instances_loc[definition_name] = ""

                for instance_name, module in instances:
                    print(f"Setting up instance: {instance_name} (definition: {definition_name})")
                    manager.names_list.append(instance_name)
                    manager.seen_mod[instance_name] = {}

                    # Reference shared CFGs from definition
                    cfgs_by_module[instance_name] = cfgs_by_definition[definition_name]

                    # Per-instance state
                    state.store[instance_name] = {}
                    manager.dependencies[instance_name] = {}
                    manager.intermodule_dependencies[instance_name] = {}
                    manager.cond_assigns[instance_name] = {}

            print(f"[sum] manager.names_list: {manager.names_list}")
            total_paths = 1
            for x in manager.child_num_paths.values():
                total_paths *= x

            # have do do things piece wise
            manager.debug = self.debug


            if len(modules) > 1:
                self.populate_seen_mod(manager)
                #manager.opt_1 = True
            else:
                manager.opt_1 = False
            manager.modules = modules_dict


        # Step 3.5: COI pruning (if enabled)
        if self.coi_enabled:
            print("[ExecutionEngine] Running Cone of Influence analysis...")
            if driver is None or compilation is None:
                print("[ExecutionEngine] Warning: COI requires driver and compilation objects, skipping")
            else:
                from frontend.assertion_extractor import extract_verification_targets, extract_signals_from_condition
                from frontend.coi_analyzer import COIAnalyzer

                # Extract seed signals from assertions
                coi_targets = extract_verification_targets(modules, manager)
                seed_signals = []
                if coi_targets:
                    for target in coi_targets:
                        # Extract signal names from the assertion condition
                        signals = extract_signals_from_condition(target.assertion_source)
                        for sig in signals:
                            if sig.isdigit() or sig in ('if', 'else', 'begin', 'end'):
                                continue
                            seed_signals.append((target.module_name, sig))

                if seed_signals:
                    analyzer = COIAnalyzer(modules_dict, cfgs_by_module, modules)
                    coi_result = analyzer.analyze(seed_signals)
                    self.coi_result = coi_result

                    # Filter cfgs_by_module: remove non-relevant instances entirely,
                    # prune non-relevant CFGs within relevant instances
                    for instance_name in list(cfgs_by_module.keys()):
                        if instance_name not in coi_result.relevant_instances:
                            del cfgs_by_module[instance_name]
                            print(f"[COI] Pruned all CFGs for instance: {instance_name}")
                        else:
                            # Only keep relevant CFGs within this instance
                            for cfg_idx, cfg in enumerate(cfgs_by_module[instance_name]):
                                if (instance_name, cfg_idx) not in coi_result.relevant_cfgs:
                                    cfg.paths = []
                                    print(f"[COI] Pruned CFG {cfg_idx} for instance: {instance_name}")

                    # Filter names_list to only relevant instances
                    original_names = list(manager.names_list)
                    manager.names_list = [n for n in manager.names_list if n in coi_result.relevant_instances]
                    pruned = set(original_names) - set(manager.names_list)
                    if pruned:
                        print(f"[COI] Removed instances from exploration: {pruned}")
                    print(f"[COI] Remaining instances: {manager.names_list}")
                else:
                    print("[ExecutionEngine] No seed signals found for COI, skipping pruning")

        # Step 4: Auto-plan milestone generation (if enabled)
        if self.auto_plan_enabled:
            print("[ExecutionEngine] Auto-plan mode enabled")

            # Check if driver and compilation are available
            if driver is None or compilation is None:
                print("[ExecutionEngine] Warning: Auto-plan requires driver and compilation objects")
                print("[ExecutionEngine] Falling back to blind strategy")
            else:
                from frontend.assertion_extractor import extract_verification_targets
                from frontend.context_slicer import ContextSlicer
                from frontend.llm_planner import LLMPlanner
                from engine.milestone import Milestone, MilestoneManager
                from engine.strategies import MilestoneDirectedStrategy

                # 4.1: Extract verification targets from assertions
                targets = extract_verification_targets(modules, manager)

                if not targets:
                    print("[ExecutionEngine] No assertions found in design, using blind strategy")
                else:
                    print(f"[ExecutionEngine] Found {len(targets)} verification target(s) from assertions")

                    # 4.2: For each target, generate milestones
                    all_milestones = []
                    for target in targets:
                        print(f"[ExecutionEngine] Planning for: {target.description}")

                        # Extract RTL context
                        slicer = ContextSlicer(driver, compilation, modules)
                        context = slicer.get_context(target.target_expr, coi_result=self.coi_result)
                        print(f"[ExecutionEngine] Extracted {len(context)} chars of RTL context")

                        # Get valid signal names (reuse SymbolicDFS)
                        all_signals = set()
                        for module in modules:
                            visitor.symbolic_store.clear()
                            visitor.visited.clear()
                            visitor.dfs(module)
                            all_signals.update(visitor.symbolic_store.keys())
                        all_signals = list(all_signals)
                        print(f"[ExecutionEngine] Found {len(all_signals)} signals")

                        # Generate milestones using LLM
                        planner = LLMPlanner(
                            api_key=self.llm_api_key,
                            provider=self.llm_provider,
                            mock=self.llm_mock,
                            base_url=self.llm_base_url
                        )
                        milestone_dicts = planner.generate_plan(context, target.target_expr, all_signals, num_cycles=int(num_cycles))
                        print(f"[ExecutionEngine] Generated {len(milestone_dicts)} milestones for this target")

                        # Convert to Milestone objects
                        for m in milestone_dicts:
                            try:
                                milestone = Milestone(m['description'], m['condition'])
                                all_milestones.append(milestone)
                                print(f"[ExecutionEngine]   Step {m['step']}: {m['description']} ({m['condition']})")
                            except ValueError as e:
                                print(f"[ExecutionEngine] Warning: Skipping invalid milestone: {e}")

                    # 4.3: Create directed strategy with milestones
                    if all_milestones:
                        milestone_manager = MilestoneManager(all_milestones)
                        print(f"[ExecutionEngine] Generated {len(all_milestones)} milestone(s)")

                        # Write milestones to file
                        milestone_output = {
                            "target": target.description,
                            "target_expr": target.target_expr,
                            "milestones": [
                                {
                                    "step": i,
                                    "description": m.description,
                                    "condition": m.condition_str
                                }
                                for i, m in enumerate(all_milestones)
                            ]
                        }
                        milestone_file = "milestones.json"
                        with open(milestone_file, "w") as f:
                            json.dump(milestone_output, f, indent=2)
                        print(f"[ExecutionEngine] Milestones written to {milestone_file}")

                        # If strategy is already MilestoneDirectedStrategy, update its milestones
                        if self.strategy is not None and hasattr(self.strategy, 'milestone_manager'):
                            self.strategy.milestone_manager = milestone_manager
                            print(f"[ExecutionEngine] Updated directed strategy with {len(all_milestones)} milestones")
                        else:
                            # Create a new directed strategy with milestones
                            self.strategy = MilestoneDirectedStrategy(milestone_manager, max_cycles=int(num_cycles))
                            print(f"[ExecutionEngine] Created directed strategy with {len(all_milestones)} milestones")
                    else:
                        print("[ExecutionEngine] No valid milestones generated, using blind strategy")

        # Delegate exploration to the strategy

        
        time.sleep(20)  # brief pause before starting exploration
        print("Starting exploration...")
        print(f"Branch points explored: {manager.branch_count}")

        if self.debug:
            manager.debug = True

        manager.seen = {}

        if not manager.names_list:
            print("[Error] No modules found to execute. Please check if the input file contains valid modules.")
            return

        for name in manager.names_list:
            manager.seen[name] = []

        manager.curr_module = manager.names_list[0]

        # Use strategy if set, otherwise fall back to BlindSearchStrategy
        if self.strategy is None:
            from .strategies import BlindSearchStrategy
            self.strategy = BlindSearchStrategy()
            print("[ExecutionEngine] No strategy set, using BlindSearchStrategy")

        # Run the exploration strategy
        self.strategy.run(
            engine=self,
            visitor=visitor,
            modules=modules,
            modules_dict=modules_dict,
            cfgs_by_module=cfgs_by_module,
            manager=manager,
            state=state,
            num_cycles=num_cycles
        )

        self.module_depth -= 1

    def check_state(self, manager, state):
        """Checks the status of the execution and displays the state."""
        if self.done and manager.debug and not manager.is_child and not manager.init_run_flag and not manager.ignore and not manager.abandon:
            print(f"[cond1]Cycle {manager.cycle} final state:")
            print(state.store)
    
            print(f"[cond1]Cycle {manager.cycle} final path condition:")
            print(state.pc.assertions())
        elif self.done and not manager.is_child and manager.assertion_violation and not manager.ignore and not manager.abandon:
            print(f"[cond2]Cycle {manager.cycle} initial state:")
            print(manager.initial_store)

            print(f"[cond2]Cycle {manager.cycle} final state:")
            print(state.store)

            print(f"[cond2]Cycle {manager.cycle} final path condition:")
            print(state.pc.assertions())

            # Print violated assertions (constraints are stored here since solver uses push/pop)
            if hasattr(manager, 'violated_assertions') and manager.violated_assertions:
                print(f"[cond2]Violated assertions:")
                for va in manager.violated_assertions:
                    print(f"  - condition: {va.get('condition', 'N/A')}")
                    print(f"    z3_condition: {va.get('z3_condition', 'N/A')}")
                    print(f"    path condition: {va.get('path condition', 'N/A')}")
                    print(f"    kind: {va.get('kind', 'N/A')}")
        elif manager.debug and not manager.is_child and not manager.init_run_flag and not manager.ignore:
            print("[cond3]Initial state:")
            print(state.store)
                
