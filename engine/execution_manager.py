"""The main class that controls the flow of execution. Most of the bookkeeping happens here, and 
a lot of this information will probably be useful when working in a specific search strategy."""
# Central coordinator that tracks all execution metadata, paths explored, modules processed, and optimization state.

from __future__ import annotations
from .symbolic_state import SymbolicState
from helpers.utils import init_symbol
from typing import Optional
# import pkg_resources
import pyslang as ps

# Using this as a reference for conditionals:
# https://sv-lang.com/structslang_1_1syntax_1_1_statement_syntax.html
CONDITIONALS = (
    ps.ConditionalStatementSyntax,
    ps.CaseStatementSyntax,
    ps.ForeachLoopStatementSyntax,
    ps.ForLoopStatementSyntax,
    ps.LoopStatementSyntax,
    ps.DoWhileStatementSyntax
)

class ExecutionManager:
    """The ExecutionManager class is responsible for managing the execution of the symbolic execution engine.
    It is responsible for counting the number of paths, merging states, and other bookkeeping tasks."""
    num_paths: int = 1
    curr_level: int = 0
    path_code: str = "0" * 12
    ast_str: str = ""
    abandon: bool = False
    assertion_violation: bool = False
    in_always: bool = False
    modules = {}
    dependencies = {}
    intermodule_dependencies = {}
    updates = {}
    seen = {}
    final = False
    completed = []
    is_child: bool = False
    # Map of module name to path nums for child module
    child_num_paths = {}    
    # Map of module name to path code for child module
    child_path_codes = {}
    paths = []
    config = {}
    names_list = []
    instance_count = {}
    seen_mod = {}
    opt_1: bool = False
    curr_module: str = ""
    piece_wise: bool = False
    child_range: range = None
    always_writes = {}
    curr_always = None
    opt_2: bool = True
    opt_3: bool = False
    assertions = []
    blocks_of_interest = []
    init_run_flag: bool = False
    ignore = False
    branch: bool = False
    cond_assigns = {}
    cond_updates = []
    reg_writes = set()
    path = []
    cycle = 0
    prev_store = {}
    reg_decls = set()
    reg_widths = {}
    curr_case = None
    debug: bool = False
    initial_store = {}
    instances_seen = {}
    instances_loc = {}
    solver_time = 0
    sv = False
    cache = None
    path_count = 0
    branch_count = 0
    branch_points_seen = set()  # Track unique branch points by source location

    def merge_states(self, state: SymbolicState, store, flag, module_name=""):
        """Merges two states. The flag is for when we are just merging a particular module"""
        for key, val in state.store.items():
            if type(val) != dict:
                continue
            else:
                for key2, var in val.items():
                    if var in store.values() and (key2 in self.reg_decls or key2.startswith("clk") or key2.startswith("rst")):
                        prev_symbol = state.store[key][key2]
                        new_symbol = store[key][key2]
                        state.store[key][key2].replace(prev_symbol, new_symbol)
                    else:
                        if flag:
                            state.store[module_name][key2] = store[key][key2]
                        else:
                            state.store[key][key2] = store[key][key2]

    def init_run(self, m: ExecutionManager, module) -> None:
        """Initalize run for a module - accepts both Symbol Objects and Syntax Nodes"""
        m.init_run_flag = True
        print(f"[init_run] initializing module: {module.name}")

        # Handle different module types:
        # - InstanceSymbol: use .body (Symbol Object approach)
        # - DefinitionSymbol: use .syntax.members (Syntax Node approach)
        # - ModuleDeclarationSyntax: use .members directly (Syntax Node approach)
        if isinstance(module, ps.InstanceSymbol):
            # Symbol Object approach: use .body
            module_body = module.body
        elif hasattr(module, 'members'):
            # Syntax Node approach: use .members
            module_body = module.members
        else:
            # Fallback: try to get members or body
            module_body = getattr(module, 'body', getattr(module, 'members', None))

        if module_body is not None:
            self.count_conditionals(m, module_body)
        
        print(f"[init_run] total paths for module {module.name}: {m.num_paths}")
        # these are for the COI opt
        if module_body is not None:
            self.lhs_signals(m, module_body)
            self.get_assertions(m, module_body)
        m.init_run_flag = False

    def count_conditionals(self, m: "ExecutionManager", items):
        """Recursively count all conditional statements in the AST (pyslang version)"""
        stmts = items
        if isinstance(items, ps.BlockStatementSyntax):
            # PySlang uses .items, not .statements for BlockStatementSyntax
            # not reach in test_2.v
            stmts = getattr(items, 'items', getattr(items, 'statements', items))
        # If stmts is iterable, traverse each statement
        if hasattr(stmts, '__iter__'):
            #print(f"[count_conditionals] traversing statements  {stmts.name} in block")
            for item in stmts:
                if type(item) == ps.ProceduralBlockSymbol:
                    #print(f"-   ProceduralBlockSymbol: {str(item.body)}")
                    # Recurse into the body of the procedural block
                    self.count_conditionals(m, item.body)
                elif type(item) == ps.InstanceSymbol:
                    #print(f"-   InstanceSymbol: {item.name}")
                    # Recurse into the instance body to count conditionals in submodules
                    if hasattr(item, 'body'):
                        #print(f"    Recursing into InstanceSymbol body: {item.body}")
                        self.count_conditionals(m, item.body)
                else:
                    #print(f"    -item: {item.name}, type: {type(item)}")
                    self.count_conditionals(m, item)
        elif items is not None:
            # Check for Statement objects first (compiled AST with .kind attribute)
            if hasattr(items, 'kind'):
                kind = items.kind
                # Handle Conditional Statement (compiled AST)
                if kind == ps.StatementKind.Conditional:
                    #print(f"[count_conditionals] found StatementKind.Conditional")
                    m.num_paths *= 2  # Each if-else doubles the paths
                    # Conditional statements have ifTrue and ifFalse attributes
                    if hasattr(items, 'ifTrue'):
                        self.count_conditionals(m, items.ifTrue)
                    if hasattr(items, 'ifFalse') and items.ifFalse is not None:
                        self.count_conditionals(m, items.ifFalse)
                    return
                # Handle Case Statement (compiled AST)
                elif kind == ps.StatementKind.Case:
                    #print(f"[count_conditionals] found StatementKind.Case")
                    # Case statement: multiply by number of cases
                    num_cases = len(items.items) if hasattr(items, 'items') else 2
                    m.num_paths *= num_cases
                    if hasattr(items, 'items'):
                        for case in items.items:
                            if hasattr(case, 'stmt'):
                                self.count_conditionals(m, case.stmt)
                    return
                # Handle Loop Statements (compiled AST)
                elif kind in [ps.StatementKind.ForLoop, ps.StatementKind.WhileLoop,
                             ps.StatementKind.DoWhileLoop, ps.StatementKind.RepeatLoop,
                             ps.StatementKind.ForeverLoop]:
                    #print(f"[count_conditionals] found loop: {kind}")
                    m.num_paths *= 2  # Loops can be entered or not (simplified)
                    if hasattr(items, 'body'):
                        self.count_conditionals(m, items.body)
                    return
                # Handle ForeachLoop if it exists
                elif hasattr(ps.StatementKind, 'ForeachLoop') and kind == ps.StatementKind.ForeachLoop:
                    #print(f"[count_conditionals] found ForeachLoop")
                    m.num_paths *= 2
                    if hasattr(items, 'body'):
                        self.count_conditionals(m, items.body)
                    return
                # Handle Block Statement (compiled AST)
                elif kind == ps.StatementKind.Block:
                    #print(f"[count_conditionals] found StatementKind.Block")
                    if hasattr(items, 'body'):
                        body = items.body
                        # Check if body is iterable (list of statements) or a single statement
                        if hasattr(body, '__iter__') and not isinstance(body, str):
                            for substmt in body:
                                self.count_conditionals(m, substmt)
                        else:
                            # Single statement
                            self.count_conditionals(m, body)
                    return
                # Handle List Statement (compiled AST)
                elif kind == ps.StatementKind.List:
                    #print(f"[count_conditionals] found StatementKind.List")
                    # List statements use 'list' attribute, not 'body'
                    if hasattr(items, 'list'):
                        lst = items.list
                        print(f"[count_conditionals] List content type: {type(lst)}")
                        # Check if list is iterable
                        if hasattr(lst, '__iter__') and not isinstance(lst, str):
                            for substmt in lst:
                                print(f"[count_conditionals] List substmt: {substmt}, kind: {getattr(substmt, 'kind', 'N/A')}")
                                self.count_conditionals(m, substmt)
                        else:
                            # Single statement
                            self.count_conditionals(m, lst)
                    elif hasattr(items, 'body'):
                        # Fallback to body if list doesn't exist
                        body = items.body
                        if hasattr(body, '__iter__') and not isinstance(body, str):
                            for substmt in body:
                                self.count_conditionals(m, substmt)
                        else:
                            self.count_conditionals(m, body)
                    else:
                        print(f"[count_conditionals] List has no list/body attr, dir: {dir(items)}")
                    return
                # Handle Timed Statement (compiled AST)
                elif kind == ps.StatementKind.Timed:
                    print(f"[count_conditionals] found StatementKind.Timed")
                    if hasattr(items, 'stmt'):
                        self.count_conditionals(m, items.stmt)
                    return

            # Check for Syntax objects (uncompiled AST)
            if isinstance(items, ps.ConditionalStatementSyntax):
                print(f"[count_conditionals] found ConditionalStatementSyntax: {items.name}")
                m.num_paths *= 2  # Each if-else doubles the paths
                self.count_conditionals(m, items.ifTrue)
                if items.ifFalse is not None:
                    self.count_conditionals(m, items.ifFalse)
            elif isinstance(items, ps.CaseStatementSyntax):
                print(f"[count_conditionals] found CaseStatementSyntax: {items.name}")
                num_cases = len(items.items) if hasattr(items, 'items') else 2
                m.num_paths *= num_cases
                for case in items.items:
                    # Case items may have .statements or .statement attribute
                    case_body = getattr(case, 'statements', getattr(case, 'statement', None))
                    self.count_conditionals(m, case_body)
            elif isinstance(items, ps.ForLoopStatementSyntax):
                m.num_paths *= 2
                self.count_conditionals(m, items.body)
            elif hasattr(ps, "ForeachLoopStatementSyntax") and isinstance(items, ps.ForeachLoopStatementSyntax):
                m.num_paths *= 2
                self.count_conditionals(m, items.body)
            elif hasattr(ps, "WhileLoopStatementSyntax") and isinstance(items, ps.WhileLoopStatementSyntax):
                m.num_paths *= 2
                self.count_conditionals(m, items.body)
            elif hasattr(ps, "DoWhileLoopStatementSyntax") and isinstance(items, ps.DoWhileLoopStatementSyntax):
                m.num_paths *= 2
                self.count_conditionals(m, items.body)
            elif hasattr(ps, "RepeatLoopStatementSyntax") and isinstance(items, ps.RepeatLoopStatementSyntax):
                m.num_paths *= 2
                self.count_conditionals(m, items.body)
            elif isinstance(items, ps.BlockStatementSyntax):
                print(f"[count_conditionals] found BlockStatementSyntax: {items.name}")
                # PySlang uses .items, not .statements for BlockStatementSyntax
                self.count_conditionals(m, items.items)
            elif hasattr(ps, "AlwaysConstructSyntax") and isinstance(items, ps.AlwaysConstructSyntax):
                self.count_conditionals(m, items.statement)
            elif hasattr(ps, "InitialConstructSyntax") and isinstance(items, ps.InitialConstructSyntax):
                self.count_conditionals(m, items.statement)
            elif hasattr(ps, "CaseItemSyntax") and isinstance(items, ps.CaseItemSyntax):
                # CaseItemSyntax may have .statements or .statement attribute
                case_body = getattr(items, 'statements', getattr(items, 'statement', None))
                self.count_conditionals(m, case_body)

    def lhs_signals(self, m: "ExecutionManager", items) -> None:
        """Take stock of which signals are written to in which always blocks for COI analysis.
        PySlang version - traverses compiled AST to find assignment targets."""
        if items is None:
            return

        # Handle iterable (module body, block body, etc.)
        if hasattr(items, '__iter__') and not isinstance(items, str):
            for item in items:
                if type(item) == ps.ProceduralBlockSymbol:
                    # Track current always block
                    m.curr_always = item
                    m.always_writes[item] = []
                    self.lhs_signals(m, item.body)
                elif type(item) == ps.InstanceSymbol:
                    # Recurse into submodule instances
                    if hasattr(item, 'body'):
                        self.lhs_signals(m, item.body)
                else:
                    self.lhs_signals(m, item)
            return

        # Handle Statement objects (compiled AST)
        if hasattr(items, 'kind'):
            kind = items.kind

            if kind == ps.StatementKind.Block:
                if hasattr(items, 'body'):
                    body = items.body
                    if hasattr(body, '__iter__') and not isinstance(body, str):
                        for substmt in body:
                            self.lhs_signals(m, substmt)
                    else:
                        self.lhs_signals(m, body)

            elif kind == ps.StatementKind.List:
                if hasattr(items, 'list'):
                    for substmt in items.list:
                        self.lhs_signals(m, substmt)

            elif kind == ps.StatementKind.Timed:
                if hasattr(items, 'stmt'):
                    self.lhs_signals(m, items.stmt)

            elif kind == ps.StatementKind.Conditional:
                if hasattr(items, 'ifTrue'):
                    self.lhs_signals(m, items.ifTrue)
                if hasattr(items, 'ifFalse') and items.ifFalse is not None:
                    self.lhs_signals(m, items.ifFalse)

            elif kind == ps.StatementKind.Case:
                if hasattr(items, 'items'):
                    for case in items.items:
                        if hasattr(case, 'stmt'):
                            self.lhs_signals(m, case.stmt)

            elif kind in [ps.StatementKind.ForLoop, ps.StatementKind.WhileLoop,
                         ps.StatementKind.DoWhileLoop, ps.StatementKind.RepeatLoop]:
                if hasattr(items, 'body'):
                    self.lhs_signals(m, items.body)

            elif kind == ps.StatementKind.ExpressionStatement:
                # This is where assignments happen
                if hasattr(items, 'expr'):
                    self._extract_lhs_from_expr(m, items.expr)

    def _extract_lhs_from_expr(self, m: "ExecutionManager", expr) -> None:
        """Extract LHS signal names from assignment expressions."""
        if expr is None or m.curr_always is None:
            return

        # Check expression kind
        if hasattr(expr, 'kind'):
            kind = expr.kind

            # Handle Assignment and NonblockingAssignment
            if kind in [ps.ExpressionKind.Assignment, ps.ExpressionKind.BinaryOp]:
                if hasattr(expr, 'left'):
                    lhs_name = self._get_signal_name(expr.left)
                    if lhs_name and lhs_name not in m.always_writes.get(m.curr_always, []):
                        if m.curr_always in m.always_writes:
                            m.always_writes[m.curr_always].append(lhs_name)

        # Also check syntax kind for syntax nodes
        if hasattr(expr, '__class__'):
            class_name = expr.__class__.__name__
            if 'AssignmentExpression' in class_name or 'NonblockingAssignment' in class_name:
                if hasattr(expr, 'left'):
                    lhs_name = self._get_signal_name(expr.left)
                    if lhs_name and m.curr_always in m.always_writes:
                        if lhs_name not in m.always_writes[m.curr_always]:
                            m.always_writes[m.curr_always].append(lhs_name)

    def _get_signal_name(self, expr) -> str:
        """Extract signal name from an expression (LHS of assignment)."""
        if expr is None:
            return None

        # NamedValue - direct variable reference
        if hasattr(expr, 'kind') and expr.kind == ps.ExpressionKind.NamedValue:
            if hasattr(expr, 'symbol') and hasattr(expr.symbol, 'name'):
                return expr.symbol.name

        # IdentifierNameSyntax
        if hasattr(expr, 'identifier'):
            if hasattr(expr.identifier, 'valueText'):
                return expr.identifier.valueText

        # ElementSelect (array access) - get base name
        if hasattr(expr, 'kind') and expr.kind == ps.ExpressionKind.ElementSelect:
            if hasattr(expr, 'value'):
                return self._get_signal_name(expr.value)

        # RangeSelect (part select) - get base name
        if hasattr(expr, 'kind') and expr.kind == ps.ExpressionKind.RangeSelect:
            if hasattr(expr, 'value'):
                return self._get_signal_name(expr.value)

        # Concatenation - return first element's name (simplified)
        if hasattr(expr, 'kind') and expr.kind == ps.ExpressionKind.Concatenation:
            if hasattr(expr, 'operands') and len(expr.operands) > 0:
                return self._get_signal_name(expr.operands[0])

        # Fallback: try to get name attribute
        if hasattr(expr, 'name'):
            return expr.name

        return None

    def get_assertions(self, m: "ExecutionManager", items, instance_path: str = "") -> None:
        """Traverse the AST and get the assertion conditions.
        PySlang version - looks for ImmediateAssertion and ConcurrentAssertion statements.

        Each assertion is stored as a tuple (condition, instance_name) so that
        the caller knows which instance the assertion belongs to.
        """
        if items is None:
            return

        # Handle iterable (module body, block body, etc.)
        if hasattr(items, '__iter__') and not isinstance(items, str):
            for item in items:
                if type(item) == ps.ProceduralBlockSymbol:
                    self.get_assertions(m, item.body, instance_path)
                elif type(item) == ps.InstanceSymbol:
                    if hasattr(item, 'body'):
                        # Use the instance name (e.g., "test_1") as the path
                        child_path = item.name if not instance_path else f"{instance_path}.{item.name}"
                        self.get_assertions(m, item.body, child_path)
                else:
                    self.get_assertions(m, item, instance_path)
            return

        # Handle Statement objects (compiled AST)
        if hasattr(items, 'kind'):
            kind = items.kind

            if kind == ps.StatementKind.Block:
                if hasattr(items, 'body'):
                    body = items.body
                    if hasattr(body, '__iter__') and not isinstance(body, str):
                        for substmt in body:
                            self.get_assertions(m, substmt, instance_path)
                    else:
                        self.get_assertions(m, body, instance_path)

            elif kind == ps.StatementKind.List:
                if hasattr(items, 'list'):
                    for substmt in items.list:
                        self.get_assertions(m, substmt, instance_path)

            elif kind == ps.StatementKind.Timed:
                if hasattr(items, 'stmt'):
                    self.get_assertions(m, items.stmt, instance_path)

            elif kind == ps.StatementKind.Conditional:
                if hasattr(items, 'ifTrue'):
                    self.get_assertions(m, items.ifTrue, instance_path)
                if hasattr(items, 'ifFalse') and items.ifFalse is not None:
                    self.get_assertions(m, items.ifFalse, instance_path)

            elif kind == ps.StatementKind.Case:
                if hasattr(items, 'items'):
                    for case in items.items:
                        if hasattr(case, 'stmt'):
                            self.get_assertions(m, case.stmt, instance_path)

            elif kind in [ps.StatementKind.ForLoop, ps.StatementKind.WhileLoop,
                         ps.StatementKind.DoWhileLoop, ps.StatementKind.RepeatLoop]:
                if hasattr(items, 'body'):
                    self.get_assertions(m, items.body, instance_path)

            elif kind == ps.StatementKind.ImmediateAssertion:
                # Found an immediate assertion - extract the condition
                if hasattr(items, 'cond'):
                    m.assertions.append((items.cond, instance_path))
                    print(f"[get_assertions] Found ImmediateAssertion in '{instance_path or 'top'}': {items.cond}")
                elif hasattr(items, 'expr'):
                    m.assertions.append((items.expr, instance_path))
                    print(f"[get_assertions] Found ImmediateAssertion (expr) in '{instance_path or 'top'}': {items.expr}")

            elif kind == ps.StatementKind.ConcurrentAssertion:
                # Found a concurrent assertion
                if hasattr(items, 'propertySpec'):
                    m.assertions.append((items.propertySpec, instance_path))
                    print(f"[get_assertions] Found ConcurrentAssertion in '{instance_path or 'top'}': {items.propertySpec}")

    def count_conditionals_2(self, m:ExecutionManager, items) -> int:
        """(Alternative conditional counter) Rewrite to actually return an int"""
        stmts = items
        if isinstance(items, ps.BlockStatementSyntax):
            # PySlang uses .items, not .statements for BlockStatementSyntax
            stmts = items.items
            # items.cname = "Block"

        if hasattr(stmts, '__iter__'):
            for item in stmts:
                if isinstance(item, CONDITIONALS):
                    if isinstance(item, ps.ConditionalStatementSyntax) or isinstance(item, ps.CaseStatementSyntax):
                        if isinstance(item, ps.ConditionalStatementSyntax):
                            return self.count_conditionals_2(m, item.ifTrue) + self.count_conditionals_2(m, item.ifFalse)  + 1
                        if isinstance(items, ps.CaseStatementSyntax):
                            return self.count_conditionals_2(m, items.items) + 1
                if isinstance(item, ps.BlockStatementSyntax):
                    return self.count_conditionals_2(m, item.statements)
                elif hasattr(ps, "AlwaysConstructSyntax") and isinstance(item, ps.AlwaysConstructSyntax):
                    return self.count_conditionals_2(m, item.statement)             
                elif hasattr(ps, "InitialConstructSyntax") and isinstance(item, ps.InitialConstructSyntax):
                    return self.count_conditionals_2(m, item.statement)
        elif items is not None:
            if isinstance(items, ps.ConditionalStatementSyntax):
                return  ( self.count_conditionals_2(m, items.ifTrue) + 
                self.count_conditionals_2(m, items.ifFalse)) + 1
            if isinstance(items, ps.CaseStatementSyntax):
                return self.count_conditionals_2(m, items.items) + 1
        return 0

    def seen_all_cases(self, m: ExecutionManager, bit_index: int, nested_ifs: int) -> bool:
        """Checks if we've seen all the cases for this index in the bit string.
        We know there are no more nested conditionals within the block, just want to check 
        that we have seen the path where this bit was turned on but the thing to the left of it
        could vary """
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
