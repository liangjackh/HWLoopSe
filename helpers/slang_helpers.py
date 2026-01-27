"""A library of helper functions for working with the PySlang AST."""
import pyslang as ps
import re
from helpers.utils import init_symbol
from engine.execution_manager import ExecutionManager
from engine.symbolic_state import SymbolicState
from helpers.rvalue_to_z3 import solve_pc
from helpers.rvalue_parser import conjunction_with_pointers
from z3 import Not, is_bool, BoolVal, ExprRef, BitVecRef, BitVecVal


def substitute_symbols(expr_str: str, store: dict) -> str:
    """Substitute variable names in expression string with their symbolic values from store.

    Args:
        expr_str: Expression string like "(+ out 1)"
        store: Dict mapping variable names to symbolic values

    Returns:
        Expression string with variables replaced by symbolic values, e.g. "(+ abc123 1)"
    """
    if not store:
        return expr_str

    # Sort variables by length (longest first) to avoid partial replacements
    # e.g., replace "out_wire" before "out"
    sorted_vars = sorted(store.keys(), key=len, reverse=True)

    result = expr_str
    for var_name in sorted_vars:
        sym_val = store[var_name]
        # Use word boundary regex to avoid partial matches
        # Match variable name that is not part of a larger identifier
        pattern = r'\b' + re.escape(var_name) + r'\b'
        result = re.sub(pattern, str(sym_val), result)

    return result

def init_state(s: SymbolicState, prev_store, ast, symbol_visitor):
    """give fresh symbols and merge register values in."""
    global_module_to_port_to_direction = dict()
    expr_symbol_visitor = ExpressionSymbolCollector()
    symbol_visitor.dfs(ast)
    params = expr_symbol_visitor.parameters
    port_list = expr_symbol_visitor.ports
    for i, token in enumerate(port_list):
        port = extract_kinds_from_descendants(token, desired_kinds=[ps.SyntaxKind.ImplicitAnsiPort])
        port_list.append(port)

    merge_states(s, prev_store)

def merge_states(state: SymbolicState, store):
    """Merges two symbolic states"""
    for key, val in state.store.items():
        if type(val) != dict:
            continue
        else:
            for key2, var in val.items():
                if var in store.values():
                    prev_symbol = state.store[key][key2]
                    new_symbol = store[key][key2]
                    state.store[key][key2].replace(prev_symbol, new_symbol)
                else:
                    state.store[key][key2] = store[key][key2]

def get_module_name(module) -> str:
    """Extracts module name from module syntax object"""
    return module.name

class SlangSymbolVisitor:
    """Visits a Slang AST by each Symbol, counting branches and paths"""

    def __init__(self): #Post processor visitor -> doesn't depend on the num_cycles
        self.symbol_id_to_symbol = dict()
        self.sourceRange_to_symbol_id = dict()
        self.kind_to_symbol_id = dict()

        self.symbol_id = 0
        self.branch_points = 0
        self.paths = 0
    
    def visit_stmt(self, stmt):
        """Visits statements, counts branches (conditionals, cases, loops)"""
        # print("visiting stmt!")  # DEBUG
        if stmt is None:
            self.paths += 1
            return

        kind = stmt.kind

        if kind == ps.StatementKind.Conditional:
            self.branch_points += 1
            if stmt.conditions:
                for cond in stmt.conditions:
                    self.visit_expr(cond.expr)
            if stmt.ifTrue:
                self.visit_stmt(stmt.ifTrue)
            else:
                self.paths += 1
            if stmt.ifFalse:
                self.visit_stmt(stmt.ifFalse)
            else:
                self.paths += 1

        elif kind == ps.StatementKind.Case:
            self.branch_points += 1
            self.visit_expr(stmt.expr)
            for case in stmt.cases:
                for e in case.exprs:
                    self.visit_expr(e)
                self.visit_stmt(case.stmt)

        elif kind in [ps.StatementKind.WhileLoop, ps.StatementKind.DoWhileLoop,
                      ps.StatementKind.ForLoop, ps.StatementKind.ForeverLoop,
                      ps.StatementKind.RepeatLoop, ps.StatementKind.ForeachLoop]:
            self.branch_points += 1
            if hasattr(stmt, 'cond'):
                self.visit_expr(stmt.cond)
            if hasattr(stmt, 'init'):
                self.visit_stmt(stmt.init)
            if hasattr(stmt, 'body'):
                self.visit_stmt(stmt.body)
            if hasattr(stmt, 'incr'):
                self.visit_stmt(stmt.incr)
            self.paths += 1  # conservative

        elif kind == ps.StatementKind.List and hasattr(stmt, 'body'):
            for s in stmt.body:
                self.visit_stmt(s)

        elif kind == ps.StatementKind.Block and hasattr(stmt, 'body'):
            for substmt in stmt.body:
                self.visit_stmt(substmt)

        elif kind in [ps.StatementKind.Return, ps.StatementKind.Break,
                      ps.StatementKind.Continue, ps.StatementKind.Disable,
                      ps.StatementKind.ForeverLoop]:
            self.paths += 1

        elif kind == ps.StatementKind.Timed and hasattr(stmt, 'stmt'):
            self.visit_stmt(stmt.stmt)

        elif kind in [ps.StatementKind.ImmediateAssertion, ps.StatementKind.ConcurrentAssertion,
                      ps.StatementKind.Wait, ps.StatementKind.WaitFork, ps.StatementKind.WaitOrder,
                      ps.StatementKind.RandCase, ps.StatementKind.RandSequence]:
            if hasattr(stmt, 'stmt'):
                self.visit_stmt(stmt.stmt)

        elif kind in [ps.StatementKind.ExpressionStatement,
                      ps.StatementKind.ProceduralAssign, ps.StatementKind.ProceduralDeassign,
                      ps.StatementKind.DisableFork, ps.StatementKind.EventTrigger,
                      ps.StatementKind.VariableDeclaration, ps.StatementKind.Empty]:
            pass  # no effect on path or branching

        else:
            pass  # other kinds not relevant here

    def visit_expr(self, expr):
        """Visit expressions"""
        if expr is None:
            return

        kind = expr.kind
        if kind == ps.ExpressionKind.ConditionalOp:
            self.branch_points += 1
            self.visit_expr(expr.predicate)
            self.visit_expr(expr.left)
            self.visit_expr(expr.right)

        elif kind == ps.ExpressionKind.BinaryOp:
            self.visit_expr(expr.left)
            self.visit_expr(expr.right)

        elif kind == ps.ExpressionKind.UnaryOp:
            self.visit_expr(expr.operand)

        elif kind in [ps.ExpressionKind.Assignment,
                      ps.ExpressionKind.NamedValue,
                      ps.ExpressionKind.ElementSelect,
                      ps.ExpressionKind.RangeSelect,
                      ps.ExpressionKind.MemberAccess,
                      ps.ExpressionKind.Call]:
            if hasattr(expr, 'left'):
                self.visit_expr(expr.left)
            if hasattr(expr, 'right'):
                self.visit_expr(expr.right)
            if hasattr(expr, 'value'):
                self.visit_expr(expr.value)

        elif kind in [ps.ExpressionKind.Concatenation, ps.ExpressionKind.Replication,
                      ps.ExpressionKind.SimpleAssignmentPattern,
                      ps.ExpressionKind.StructuredAssignmentPattern,
                      ps.ExpressionKind.ReplicatedAssignmentPattern,
                      ps.ExpressionKind.List, ps.ExpressionKind.Pattern,
                      ps.ExpressionKind.StructurePattern]:
            for e in getattr(expr, 'elements', getattr(expr, 'operands', [])):
                if hasattr(e, 'value'):
                    self.visit_expr(e.value)
                else:
                    self.visit_expr(e)
    def _recurse_if_present(self, symbol, *attr_names):
        """Helper: for given attribute names, if present on symbol recurse into them."""
        for a in attr_names:
            if hasattr(symbol, a):
                val = getattr(symbol, a)
                if val is None:
                    continue
                if isinstance(val, (list, tuple, set)):
                    for item in val:
                        if hasattr(item, "kind"):
                            self.visit(item)
                else:
                    if hasattr(val, "kind") or isinstance(val, ps.Symbol):
                        self.visit(val)
    
    def visit(self, symbol):
        """Main entry point for visiting symbols"""
        if isinstance(symbol, (list, tuple, set)):
            for s in symbol:
                self.visit(s)
            return

        if not isinstance(symbol, ps.Symbol):
            # Not every AST node in Slang is a ps.Symbol, so therefore I added a traversal here which traveres through their .members attribute because they might contian Statements there such as Compilation root, Definition objects, etc.
            if hasattr(symbol, "members"):
                for m in getattr(symbol, "members"):
                    self.visit(m)
            return
        
        # if symbol.kind == ps.SymbolKind.Unknown:
        #     # unknown symbol
        #     ...
        # elif symbol.kind == ps.SymbolKind.Root:
        #     # root symbol
        #     ...
        # Root / Compilation unit: recurse into members
        if symbol.kind in (ps.SymbolKind.Root, ps.SymbolKind.CompilationUnit):
            self._recurse_if_present(symbol, "members", "items", "declarations")
            return
        
        elif symbol.kind == ps.SymbolKind.Definition:
            # definitions can contain members, etc.
            self._recurse_if_present(symbol, "members", "declarations", "items", "body", "syntax")
            return
        
        # Procedural block: count branches by delegating to visit_stmt
        if symbol.kind == ps.SymbolKind.ProceduralBlock:
            # some procedural blocks expose `.body` or `.statement`
            body = getattr(symbol, "body", getattr(symbol, "statement", None))
            if body is not None:
                try:
                    self.visit_stmt(body)
                except Exception:
                    # fall back to recursing members if visit_stmt fails
                    self._recurse_if_present(symbol, "members", "body")
            else:
                self._recurse_if_present(symbol, "members")
            return
        
        elif symbol.kind == ps.SymbolKind.ContinuousAssign:
            try:
                assign = getattr(symbol, "assignment", None)
                if assign is not None:
                    self.visit_expr(assign)
            except Exception:
                pass
            self._recurse_if_present(symbol, "members", "children")
            return
        
        elif symbol.kind == ps.SymbolKind.Instance:
            # instance.name is a common attribute
            try:
                instance_name = getattr(symbol, "name", None)
            except Exception:
                instance_name = None
            self._recurse_if_present(symbol, "instanceBody", "parentInstance", "members", "children")
            return
        
        # Instance Body / Instance Array: recurse into members/statements
        elif symbol.kind in (ps.SymbolKind.InstanceBody, ps.SymbolKind.InstanceArray):
            self._recurse_if_present(symbol, "members", "statements", "items")
            return
        

        elif symbol.kind in (ps.SymbolKind.Port, ps.SymbolKind.Variable, ps.SymbolKind.Net, ps.SymbolKind.Parameter):
            # If there is an initializer or assignment expression, visit it
            init_expr = getattr(symbol, "initializer", None) or getattr(symbol, "assignment", None)
            if init_expr is not None:
                try:
                    self.visit_expr(init_expr)
                except Exception:
                    self._recurse_if_present(init_expr, "members", "elements", "expressions")
            # recurse into members to catch nested declarations
            self._recurse_if_present(symbol, "members", "declarations", "children")
            return
        
        # Cases where the symbol was not contributing to the RTL executable code, I have implemented a transversion mechanism to register the symbol in the internal maps and advance symbol_id.:
        # Attempt to recurse known container-like attributes (members/body/statements/children)
        self._recurse_if_present(symbol,
                                "members", "body", "statement", "statements",
                                "items", "declarations", "children", "syntax")
        return
    if False: #left the other symbol kinds for reference
        #Types (Only provide structure information. They don't produce any RTL executable code)
        if symbol.kind == ps.SymbolKind.PredefinedIntegerType:
            # predefinedintegertype symbol
            ...
        elif symbol.kind == ps.SymbolKind.ScalarType:
            # scalartype symbol
            ...
        elif symbol.kind == ps.SymbolKind.FloatingType:
            # floatingtype symbol
            ...
        elif symbol.kind == ps.SymbolKind.EnumType:
            # enumtype symbol
            ...
        elif symbol.kind == ps.SymbolKind.EnumValue:
            # enumvalue symbol
            ...
        elif symbol.kind == ps.SymbolKind.PackedArrayType:
            # packedarraytype symbol
            ...
        elif symbol.kind == ps.SymbolKind.FixedSizeUnpackedArrayType:
            # fixedsizeunpackedarraytype symbol
            ...
        elif symbol.kind == ps.SymbolKind.DynamicArrayType:
            # dynamicarraytype symbol
            ...
        elif symbol.kind == ps.SymbolKind.DPIOpenArrayType:
            # dpiopenarraytype symbol
            ...
        elif symbol.kind == ps.SymbolKind.AssociativeArrayType:
            # associativearraytype symbol
            ...
        elif symbol.kind == ps.SymbolKind.QueueType:
            # queuetype symbol
            ...
        elif symbol.kind == ps.SymbolKind.PackedStructType:
            # packedstructtype symbol
            ...
        elif symbol.kind == ps.SymbolKind.UnpackedStructType:
            # unpackedstructtype symbol
            ...
        elif symbol.kind == ps.SymbolKind.PackedUnionType:
            # packeduniontype symbol
            ...
        elif symbol.kind == ps.SymbolKind.UnpackedUnionType:
            # unpackeduniontype symbol
            ...
    elif False:
        # ********* These are not RTL executable code *********
            if symbol.kind == ps.SymbolKind.ClassType:
            # classtype symbol
                ...
            elif symbol.kind == ps.SymbolKind.CovergroupType:
                # covergrouptype symbol
                ...
            elif symbol.kind == ps.SymbolKind.VoidType:
                # voidtype symbol
                ...
            elif symbol.kind == ps.SymbolKind.NullType:
                # nulltype symbol
                ...
            elif symbol.kind == ps.SymbolKind.CHandleType:
                # chandletype symbol
                ...
            elif symbol.kind == ps.SymbolKind.StringType:
                # stringtype symbol
                ...
            elif symbol.kind == ps.SymbolKind.UnboundedType:
                # unboundedtype symbol
                ...
            elif symbol.kind == ps.SymbolKind.TypeRefType:
                # typereftype symbol
                ...
            elif symbol.kind == ps.SymbolKind.UntypedType:
                # untypedtype symbol
                ...
            elif symbol.kind == ps.SymbolKind.SequenceType:
                # sequencetype symbol
                ...
            elif symbol.kind == ps.SymbolKind.PropertyType:
                # propertytype symbol
                ...
            elif symbol.kind == ps.SymbolKind.VirtualInterfaceType:
                # virtualinterfacetype symbol
                ...
            elif symbol.kind == ps.SymbolKind.TypeAlias:
                # typealias symbol
                ...
            elif symbol.kind == ps.SymbolKind.ErrorType:
                # errortype symbol
                ...
            elif symbol.kind == ps.SymbolKind.ForwardingTypedef:
                # forwardingtypedef symbol
                ...
            elif symbol.kind == ps.SymbolKind.NetType:
                # nettype symbol
                ...
            elif symbol.kind == ps.SymbolKind.TypeParameter:
                # typeparameter symbol
                ...
            elif symbol.kind == ps.SymbolKind.MultiPort:
                # multiport symbol
                ...
            elif symbol.kind == ps.SymbolKind.InterfacePort:
                # interfaceport symbol
                ...
            elif symbol.kind == ps.SymbolKind.Modport:
                # modport symbol
                ...
            elif symbol.kind == ps.SymbolKind.ModportPort:
                # modportport symbol
                ...
            elif symbol.kind == ps.SymbolKind.ModportClocking:
                # modportclocking symbol
                ...
            elif symbol.kind == ps.SymbolKind.Package:
                # package symbol
                ...
            elif symbol.kind == ps.SymbolKind.ExplicitImport:
                # explicitimport symbol
                ...
            elif symbol.kind == ps.SymbolKind.WildcardImport:
                # wildcardimport symbol
                ...
            elif symbol.kind == ps.SymbolKind.Attribute:
                # attribute symbol
                ...
            elif symbol.kind == ps.SymbolKind.Genvar:
                # genvar symbol
                ...
            elif symbol.kind == ps.SymbolKind.GenerateBlock:
                # generateblock symbol
                ...
            elif symbol.kind == ps.SymbolKind.GenerateBlockArray:
                # generateblockarray symbol
                ...
            elif symbol.kind == ps.SymbolKind.StatementBlock:
                # statementblock symbol
                ...
            elif symbol.kind == ps.SymbolKind.FormalArgument:
                # formalargument symbol
                ...
            elif symbol.kind == ps.SymbolKind.Field:
                # field symbol
                ...
            elif symbol.kind == ps.SymbolKind.ClassProperty:
                # classproperty symbol
                ...
            elif symbol.kind == ps.SymbolKind.Subroutine:
                # subroutine symbol
                ...
            elif symbol.kind == ps.SymbolKind.ElabSystemTask:
                # elabsystemtask symbol
                ...
            elif symbol.kind == ps.SymbolKind.GenericClassDef:
                # genericclassdef symbol
                ...
            elif symbol.kind == ps.SymbolKind.MethodPrototype:
                # methodprototype symbol
                ...
            elif symbol.kind == ps.SymbolKind.UninstantiatedDef:
                # uninstantiateddef symbol
                ...
            elif symbol.kind == ps.SymbolKind.Iterator:
                # iterator symbol
                ...
            elif symbol.kind == ps.SymbolKind.PatternVar:
                # patternvar symbol
                ...
            elif symbol.kind == ps.SymbolKind.ConstraintBlock:
                # constraintblock symbol
                ...
            elif symbol.kind == ps.SymbolKind.DefParam:
                # defparam symbol
                ...
            elif symbol.kind == ps.SymbolKind.Primitive:
                # primitive symbol
                ...
            elif symbol.kind == ps.SymbolKind.PrimitivePort:
                # primitiveport symbol
                ...
            elif symbol.kind == ps.SymbolKind.PrimitiveInstance:
                # primitiveinstance symbol
                ...
            elif symbol.kind == ps.SymbolKind.SpecifyBlock:
                # specifyblock symbol
                ...
            elif symbol.kind == ps.SymbolKind.Sequence:
                # sequence symbol
                ...
            elif symbol.kind == ps.SymbolKind.Property:
                # property symbol
                ...
            elif symbol.kind == ps.SymbolKind.AssertionPort:
                # assertionport symbol
                ...
            elif symbol.kind == ps.SymbolKind.ClockingBlock:
                # clockingblock symbol
                ...
            elif symbol.kind == ps.SymbolKind.ClockVar:
                # clockvar symbol
                ...
            elif symbol.kind == ps.SymbolKind.LocalAssertionVar:
                # localassertionvar symbol
                ...
            elif symbol.kind == ps.SymbolKind.LetDecl:
                # letdecl symbol
                ...
            elif symbol.kind == ps.SymbolKind.Checker:
                # checker symbol
                ...
            elif symbol.kind == ps.SymbolKind.CheckerInstance:
                # checkerinstance symbol
                ...
            elif symbol.kind == ps.SymbolKind.CheckerInstanceBody:
                # checkerinstancebody symbol
                ...
            elif symbol.kind == ps.SymbolKind.RandSeqProduction:
                # randseqproduction symbol
                ...
            elif symbol.kind == ps.SymbolKind.CovergroupBody:
                # covergroupbody symbol
                ...
            elif symbol.kind == ps.SymbolKind.Coverpoint:
                # coverpoint symbol
                ...
            elif symbol.kind == ps.SymbolKind.CoverCross:
                # covercross symbol
                ...
            elif symbol.kind == ps.SymbolKind.CoverCrossBody:
                # covercrossbody symbol
                ...
            elif symbol.kind == ps.SymbolKind.CoverageBin:
                # coveragebin symbol
                ...
            elif symbol.kind == ps.SymbolKind.TimingPath:
                # timingpath symbol
                ...
            elif symbol.kind == ps.SymbolKind.PulseStyle:
                # pulsestyle symbol
                ...
            elif symbol.kind == ps.SymbolKind.SystemTimingCheck:
                # systemtimingcheck symbol
                ...
            elif symbol.kind == ps.SymbolKind.AnonymousProgram:
                # anonymousprogram symbol
                ...
            elif symbol.kind == ps.SymbolKind.ConfigBlock:
                ...

class SymbolicDFS:
    """DFS visitor for PySlang symbols, updating symbolic store and path condition."""

    def __init__(self, cycles, symbolic_store=None, path_condition=None):
        self.symbolic_store = symbolic_store if symbolic_store is not None else {}
        self.path_condition = path_condition if path_condition is not None else []
        self.visited = set()
        self.cycles = 0

    def dfs(self, symbol):
        """Main DFS traversal of symbols"""
        if not isinstance(symbol, ps.Symbol):
            return

        if symbol is None or symbol in self.visited:
            return
        self.visited.add(symbol)

        # Update symbolic store for variables, parameters, nets, etc.
        if hasattr(symbol, "name") and symbol.kind in (
            ps.SymbolKind.Variable,
            ps.SymbolKind.Parameter,
            ps.SymbolKind.Port,
            ps.SymbolKind.Net,
        ):
            self.symbolic_store[symbol.name] = symbol

        # Update path condition for conditional statements
        if symbol.kind == ps.SymbolKind.ProceduralBlock and hasattr(symbol, "body"):
            self.dfs_stmt(symbol.body)
        elif symbol.kind == ps.SymbolKind.ContinuousAssign and hasattr(symbol, "assignment"):
            self.dfs_expr(symbol.assignment)

        # Recursively visit children if available
        # PySlang 9.x: symbols are directly iterable (no 'members' attribute)
        # PySlang 7.x: symbols have 'members' attribute
        if hasattr(symbol, "members"):
            for member in symbol.members:
                self.dfs(member)
        else:
            # Try direct iteration for PySlang 9.x
            try:
                for child in symbol:
                    self.dfs(child)
            except TypeError:
                pass  # Symbol is not iterable

        if hasattr(symbol, "body") and symbol.kind != ps.SymbolKind.ProceduralBlock:
            self.dfs(symbol.body)

    def dfs_stmt(self, stmt):
        """DFS traversal of statements"""
        if stmt is None:
            return
        if stmt.kind == ps.StatementKind.ExpressionStatement:
            self.dfs_expr(stmt.expr)
        elif stmt.kind == ps.StatementKind.Block:
            if hasattr(stmt, "body"):
                self.dfs_stmt(stmt.body)
        elif stmt.kind == ps.StatementKind.Conditional:
            cond_expr = stmt.conditions[0].expr if stmt.conditions else None
            if cond_expr:
                self.dfs_expr(cond_expr)
                self.path_condition.append(cond_expr)
            if stmt.ifTrue:
                self.dfs_stmt(stmt.ifTrue)
            if stmt.ifFalse:
                self.dfs_stmt(stmt.ifFalse)
            if cond_expr:
                self.path_condition.pop()
        elif stmt.kind == ps.StatementKind.List:
            for s in stmt.body:
                self.dfs_stmt(s)

    def dfs_expr(self, expr):
        """DFS traversal of expressions"""
        if expr is None:
            return
        # For now, just a placeholder that doesn't traverse into expressions
        # This prevents the AttributeError when dfs_expr is called
        pass

    def visit_expr(self, m: ExecutionManager, s: SymbolicState, expr):
        """Visits expressions"""
        # print(expr.__class__.__name__, dir(expr))  # DEBUG
        if expr is None:
            return

        kind = expr.kind

        if kind == ps.ExpressionKind.NamedValue:
            return s.store[m.curr_module].get(expr.symbol.name, init_symbol())

        elif kind == ps.ExpressionKind.BinaryOp:
            self.visit_expr(m, s, expr.left)
            self.visit_expr(m, s, expr.right)

        # Handle SyntaxKind binary expressions (from syntax tree)
        elif kind in [ps.SyntaxKind.LogicalAndExpression, ps.SyntaxKind.LogicalOrExpression,
                      ps.SyntaxKind.BinaryAndExpression, ps.SyntaxKind.BinaryOrExpression,
                      ps.SyntaxKind.BinaryXorExpression, ps.SyntaxKind.BinaryXnorExpression,
                      ps.SyntaxKind.LogicalShiftLeftExpression, ps.SyntaxKind.LogicalShiftRightExpression,
                      ps.SyntaxKind.LogicalEquivalenceExpression, ps.SyntaxKind.LogicalImplicationExpression]:
            if hasattr(expr, 'left'):
                self.visit_expr(m, s, expr.left)
            if hasattr(expr, 'right'):
                self.visit_expr(m, s, expr.right)

        elif kind == ps.ExpressionKind.UnaryOp:
            self.visit_expr(m, s, expr.operand)

        elif kind == ps.ExpressionKind.ConditionalOp:
            self.visit_expr(m, s, expr.predicate)
            self.visit_expr(m, s, expr.left)
            self.visit_expr(m, s, expr.right)

        elif kind == ps.SyntaxKind.AssignmentExpression:
            if hasattr(expr.left, "identifier"):
                lhs_var = expr.left.identifier.value
                # Check for simple var-to-var assignment first
                if hasattr(expr.right, "identifier") and expr.right.identifier.value in s.store[m.curr_module]:
                    s.store[m.curr_module][lhs_var] = s.store[m.curr_module][expr.right.identifier.value]
                elif expr.right.kind == ps.SyntaxKind.ConcatenationExpression:
                    # Handle concatenation on RHS
                    parts = [str(operand.literal.value) for operand in expr.right.expressions if hasattr(operand, "literal")]
                    s.store[m.curr_module][lhs_var] = "".join(parts)
                elif hasattr(expr.right, "literal"):
                    # Handle literal expressions (IntegerLiteralExpression, etc.)
                    s.store[m.curr_module][lhs_var] = str(expr.right.literal.value)
                else:
                    # Handle complex RHS expressions (e.g., out + 1 + out_wire)
                    # Convert RHS to string representation and substitute symbolic values
                    rhs_str = conjunction_with_pointers(expr.right, s, m)
                    rhs_with_symbols = substitute_symbols(rhs_str, s.store[m.curr_module])
                    s.store[m.curr_module][lhs_var] = rhs_with_symbols
            else:
                # LHS doesn't have an identifier attribute — skip for now
                ...

        elif kind == ps.SyntaxKind.NonblockingAssignmentExpression:
            if hasattr(expr.left, "identifier"):
                lhs_var = expr.left.identifier.value
                # Check for simple var-to-var assignment first
                if hasattr(expr.right, "identifier") and expr.right.identifier.value in s.store[m.curr_module]:
                    s.store[m.curr_module][lhs_var] = s.store[m.curr_module][expr.right.identifier.value]
                elif expr.right.kind == ps.SyntaxKind.ConcatenationExpression:
                    # Handle concatenation on RHS
                    concat_value = ""
                    for operand in expr.right.expressions:
                        if hasattr(operand, "value"):
                            concat_value += str(operand.value)
                    s.store[m.curr_module][lhs_var] = concat_value
                elif hasattr(expr.right, "literal"):
                    # Handle literal expressions
                    s.store[m.curr_module][lhs_var] = str(expr.right.literal.value)
                else:
                    # Handle complex RHS expressions (e.g., out + 1 + out_wire)
                    # Convert RHS to string representation and substitute symbolic values
                    rhs_str = conjunction_with_pointers(expr.right, s, m)
                    rhs_with_symbols = substitute_symbols(rhs_str, s.store[m.curr_module])
                    s.store[m.curr_module][lhs_var] = rhs_with_symbols
            else:
                # LHS doesn't have an identifier attribute — skip for now
                ...

        elif kind ==ps.ExpressionKind.Concatenation:
            for e in expr.operands:
                self.visit_expr(m, s, e)

        elif kind == ps.ExpressionKind.Call:
            for arg in expr.arguments:
                self.visit_expr(m, s, arg)

        elif kind == ps.ExpressionKind.ElementSelect:
            self.visit_expr(m, s, expr.value)
            self.visit_expr(m, s, expr.selector)

        elif kind == ps.ExpressionKind.RangeSelect:
            self.visit_expr(m, s, expr.value)
            self.visit_expr(m, s, expr.left)
            self.visit_expr(m, s, expr.right)

        elif kind in [ps.ExpressionKind.MemberAccess, ps.ExpressionKind.Streaming,
                    ps.ExpressionKind.Replication, ps.ExpressionKind.TaggedUnion,
                    ps.ExpressionKind.Conversion, ps.ExpressionKind.CopyClass,
                    ps.ExpressionKind.Streaming]:
            self.visit_expr(m, s, expr.value)

        elif kind in [ps.ExpressionKind.SimpleAssignmentPattern]:
            for e in expr.elements:
                self.visit_expr(m, s, e)

        elif kind in [ps.ExpressionKind.StructuredAssignmentPattern, ps.ExpressionKind.ReplicatedAssignmentPattern]:
            for e in expr.elements:
                self.visit_expr(m, s, e.value)

        elif kind in [ps.ExpressionKind.MinTypMax]:
            self.visit_expr(m, s, expr.min)
            self.visit_expr(m, s, expr.typ)
            self.visit_expr(m, s, expr.max)


        # Ignore literals and null
        elif kind in [ps.ExpressionKind.IntegerLiteral, ps.ExpressionKind.RealLiteral,
                    ps.ExpressionKind.TimeLiteral, ps.ExpressionKind.NullLiteral,
                    ps.ExpressionKind.StringLiteral, ps.ExpressionKind.UnbasedUnsizedIntegerLiteral,
                    ps.UnboundedLiteral]:
            pass

        # Ignore misc. nodes in syntax tree
        elif kind in [ps.TokenKind.IntegerLiteral, ps.SyntaxKind.IntegerVectorExpression,
                      ps.SyntaxKind.ConcatenationExpression, ps.SyntaxKind.IdentifierName,
                      ps.SyntaxKind.IdentifierSelectName, ps.TokenKind.Comma, ps.SyntaxKind.IntegerLiteralExpression,
                      ps.SyntaxKind.SimplePropertyExpr]:
            pass

        else:
            # print(f"Unsupported Expression: {expr} of kind {kind}")  # DEBUG
            pass


    def visit_stmt(self, m: ExecutionManager, s: SymbolicState, stmt, modules=None, direction=None):
        """Visits statements"""
        # class_name = stmt.__class__.__name__
        # print("visit:", class_name, getattr(getattr(stmt, "kind", None), "name", getattr(stmt, "kind", None)))  # DEBUG
        # if "Assert" in class_name or "Concurrent" in class_name:
        #     print(f"  [ASSERTION NODE] {class_name}")
        if stmt is None or m.ignore:
            return

        kind = stmt.kind

        # Handle SyntaxList by iterating through children
        if kind == ps.SyntaxKind.SyntaxList:
            for child in stmt:
                self.visit_stmt(m, s, child, modules, direction)
            return

        # Handle PropertySpecSyntax - contains assertion condition
        if kind == ps.SyntaxKind.PropertySpec:
            self._handle_property_spec(m, s, stmt, modules, direction)
            return

        if kind == ps.SyntaxKind.ExpressionStatement:
            self.visit_expr(m, s, stmt.expr)

        elif kind == ps.StatementKind.Block and hasattr(stmt, "body"):
            for substmt in stmt.body:
                self.visit_stmt(m, s, substmt, modules, direction)

        elif kind == ps.StatementKind.Conditional or isinstance(stmt, ps.ConditionalStatementSyntax):
            m.branch_count += 1
            # PySlang 7.0 uses conditions list, not predicate attribute
            # Pattern matches usage in dfs_stmt() method (line 550)
            cond_expr = stmt.conditions[0].expr if (hasattr(stmt, 'conditions') and stmt.conditions) else None
            if cond_expr:
                self.visit_expr(m, s, cond_expr)
                s.pc.push()
                s.assertion_counter += 1
                cond_z3 = self.expr_to_z3(m, s, cond_expr)
                if direction:
                    key = str(cond_z3)
                    self.branch = True
                    if m.cache is not None and m.cache.exists(key):
                        result = m.cache.get(key).decode()
                    else:
                        result = str(solve_pc(s.pc))
                        if m.cache is not None:
                            m.cache.set(str(cond_z3), str(solve_pc(s.pc)))
                    s.pc.assert_and_track(cond_z3, f"p{s.assertion_counter}")
                else:
                    self.branch = False
                    key = f"~{cond_z3}"
                    if m.cache is not None and m.cache.exists(key):
                        result = m.cache.get(key).decode()
                    else:
                        result = str(solve_pc(s.pc))
                        if m.cache is not None:
                            m.cache.set(f"~{cond_z3}", str(solve_pc(s.pc)))
                    s.pc.assert_and_track(cond_z3, f"p{s.assertion_counter}")
                if not solve_pc(s.pc):
                    if m.cache is not None:
                        m.cache.set(f"~{str(cond_z3)}", False)
                    s.pc.pop()
                    m.abandon = True
                    m.ignore = True
                    return

            # PySlang 7.0 uses ifTrue/ifFalse for ConditionalStatementSyntax
            # The branches are visited as separate basic blocks in the CFG path,
            # so we should NOT visit them here. The direction parameter determines
            # which path was taken, and the branch statements will be executed
            # when we visit the corresponding basic block.
            # We only need to evaluate the condition and update the path condition here.

            if cond_expr:
                s.pc.pop()

        elif kind == ps.StatementKind.List:
            
            for s_sub in stmt.body:
                self.visit_stmt(m, s, s_sub, modules, direction)

        elif kind == ps.StatementKind.ForLoop:
            if hasattr(stmt, "init"):
                self.visit_stmt(m, s, stmt.init, modules, direction)
            if hasattr(stmt, "cond"):
                self.visit_expr(m, s, stmt.cond)
            if hasattr(stmt, "body"):
                self.visit_stmt(m, s, stmt.body, modules, direction)
            if hasattr(stmt, "incr"):
                self.visit_stmt(m, s, stmt.incr, modules, direction)

        elif kind == ps.StatementKind.WhileLoop:
            # print("whileloop")  # DEBUG
            m.branch_count += 1
            if hasattr(stmt, "cond"):
                self.visit_expr(m, s, stmt.cond)
                s.pc.push()
                s.assertion_counter += 1
                cond_z3 = self.expr_to_z3(m, s, stmt.cond)
                if direction:
                    key = str(cond_z3)
                    self.branch = True
                    if m.cache is not None and m.cache.exists(key):
                        result = m.cache.get(key).decode()
                    else:
                        result = str(solve_pc(s.pc))
                        if m.cache is not None:
                            m.cache.set(str(cond_z3), str(solve_pc(s.pc)))
                    s.pc.assert_and_track(cond_z3, f"p{s.assertion_counter}")
                else:
                    key = str(f"~{cond_z3}")
                    self.branch = False
                    if m.cache is not None and m.cache.exists(key):
                        result = m.cache.get(key).decode()
                    else:
                        result = str(solve_pc(s.pc))
                        if m.cache is not None:
                            m.cache.set(f"~{str(cond_z3)}", str(solve_pc(s.pc)))
                    s.pc.assert_and_track(~cond_z3, f"p{s.assertion_counter}")
                if not solve_pc(s.pc):
                    s.pc.pop()
                    if m.cache is not None:
                        m.cache.set(str(cond_z3), False)
                    m.abandon = True
                    m.ignore = True
                    return
            if hasattr(stmt, "body"):
                self.visit_stmt(m, s, stmt.body, modules, direction)
            if hasattr(stmt, "cond"):
                s.pc.pop()

        elif kind == ps.StatementKind.DoWhileLoop:
            # print("dowhile")  # DEBUG
            m.branch_count += 1
            if hasattr(stmt, "body"):
                self.visit_stmt(m, s, stmt.body, modules, direction)
            if hasattr(stmt, "cond"):
                self.visit_expr(m, s, stmt.cond)

        #elif kind == ps.StatementKind.Case:
        elif stmt.__class__.__name__ == "CaseStatementSyntax":
            # print("case")  # DEBUG
            m.branch_count += 1
            self.visit_expr(m, s, stmt.expr)

            cond_z3 = self.expr_to_z3(m, s, stmt.expr)

            #for case in stmt.cases:
            for case in getattr(stmt, "items", getattr(stmt, "case_items", [])):
                exprs = getattr(case, "expressions", getattr(case, "exprs", []))
                #for e in case.exprs:
                for e in exprs:
                    self.visit_expr(m, s, e)
                    s.pc.push()
                    s.assertion_counter += 1
                    case_z3 = self.expr_to_z3(m, s, e)

                    cond_expr = cond_z3 if isinstance(cond_z3, ExprRef) else None
                    case_expr = case_z3 if isinstance(case_z3, ExprRef) else None

                    if cond_expr is not None:
                        if is_bool(cond_expr):
                            match_guard = cond_expr
                            mismatch_guard = Not(cond_expr)
                        elif case_expr is not None:
                            match_guard = cond_expr == case_expr
                            mismatch_guard = cond_expr != case_expr
                        elif isinstance(cond_expr, BitVecRef):
                            zero = BitVecVal(0, cond_expr.size())
                            match_guard = cond_expr != zero
                            mismatch_guard = cond_expr == zero
                        else:
                            match_guard = BoolVal(True)
                            mismatch_guard = BoolVal(True)
                    else:
                        match_guard = BoolVal(True)
                        mismatch_guard = BoolVal(True)

                    guard = match_guard if direction else mismatch_guard
                    if not isinstance(guard, ExprRef) or not is_bool(guard):
                        guard = BoolVal(True)

                    key = str(guard)
                    self.branch = bool(direction)
                    if m.cache is not None and m.cache.exists(key):
                        result = m.cache.get(key).decode()
                    else:
                        result = str(solve_pc(s.pc))
                        if m.cache is not None:
                            m.cache.set(key, result)
                    s.pc.assert_and_track(guard, f"p{s.assertion_counter}")
                    if not solve_pc(s.pc):
                        s.pc.pop()
                        if m.cache is not None:
                            m.cache.set(key, str(False))
                        m.abandon = True
                        m.ignore = True
                        return

                    case_body = getattr(case, "statement", getattr(case, "stmt", None))
                    if case_body is None and hasattr(case, "statements"):
                        case_body = case.statements

                    if case_body is None:
                        s.pc.pop()
                        continue

                    if isinstance(case_body, (list, tuple)):
                        body_iter = case_body
                    elif hasattr(case_body, "__iter__") and not isinstance(case_body, ps.StatementSyntax):
                        body_iter = list(case_body)
                    else:
                        body_iter = [case_body]

                    for stmt_node in body_iter:
                        if stmt_node is None:
                            continue
                        self.visit_stmt(m, s, stmt_node, modules, direction)

                    s.pc.pop()

        elif kind in [ps.StatementKind.ProceduralAssign]:
            self.visit_expr(m, s, stmt.left)
            self.visit_expr(m, s, stmt.right)
            if hasattr(stmt.left, 'symbol') and hasattr(stmt.right, 'symbol'):
                lhs = stmt.left.symbol.name
                rhs = stmt.right.symbol.name
                s.store[m.curr_module][lhs] = s.store[m.curr_module].get(rhs, init_symbol())
            elif hasattr(stmt.left, 'symbol'):
                lhs = stmt.left.symbol.name
                s.store[m.curr_module][lhs] = init_symbol()

        # elif kind == ps.StatementKind.ProcedureCall:
        #     self.visit_expr(m, s, stmt.expr)

        elif kind in [ps.StatementKind.Block,
                    ps.StatementKind.Timed]:
            self.visit_stmt(m, s, stmt.body, modules, direction)

        # elif kind in [ps.StatementKind.Assert, ps.StatementKind.Assume, ps.StatementKind.Cover]:
        #     self.visit_expr(m, s, stmt.expr)
        #     self.visit_stmt(m, s, stmt.body, modules, direction)
        #     if hasattr(stmt, "elseBody"):
        #         self.visit_stmt(m, s, stmt.elseBody, modules, direction)

        # Handle ImmediateAssertionStatement (semantic node)
        elif kind == ps.StatementKind.ImmediateAssertion:
            self._handle_immediate_assertion(m, s, stmt, modules, direction)

        # Handle ConcurrentAssertionStatement (SVA property assertions)
        elif kind == ps.StatementKind.ConcurrentAssertion:
            self._handle_concurrent_assertion(m, s, stmt, modules, direction)

        # Handle AssertPropertyStatement syntax (SVA assert property)
        elif kind == ps.SyntaxKind.AssertPropertyStatement:
            self._handle_assert_property_syntax(m, s, stmt, modules, direction)

        # Handle ConcurrentAssertionStatementSyntax by class name
        elif stmt.__class__.__name__ == "ConcurrentAssertionStatementSyntax":
            self._handle_assert_property_syntax(m, s, stmt, modules, direction)

        # Handle ConcurrentAssertionMember syntax
        elif kind == ps.SyntaxKind.ConcurrentAssertionMember:
            if hasattr(stmt, 'statement'):
                self.visit_stmt(m, s, stmt.statement, modules, direction)

        # Handle ConcurrentAssertionMemberSyntax by class name
        elif stmt.__class__.__name__ == "ConcurrentAssertionMemberSyntax":
            if hasattr(stmt, 'statement'):
                self.visit_stmt(m, s, stmt.statement, modules, direction)

        # Handle ImmediateAssertionStatementSyntax (syntax node)
        elif stmt.__class__.__name__ == "ImmediateAssertionStatementSyntax":
            self._handle_immediate_assertion_syntax(m, s, stmt, modules, direction)

        elif kind == ps.StatementKind.Return and hasattr(stmt, "expr"):
            self.visit_expr(m, s, stmt.expr)
        
        elif kind == ps.StatementKind.ExpressionStatement:
            self.visit_expr(m, s, stmt.expr)

    def _handle_immediate_assertion(self, m: ExecutionManager, s: SymbolicState, stmt, modules, direction):
        """Handle ImmediateAssertionStatement (semantic node).

        Task #1: Extract assertion condition
        Task #2: Convert to Z3
        Task #3: Check for violations
        """
        # Task #1: Extract the assertion condition
        cond = getattr(stmt, 'cond', None)
        if cond is None:
            return

        # Get assertion kind (assert, assume, cover)
        assertion_kind = getattr(stmt, 'assertionKind', None)

        # Visit the condition expression to update symbolic state
        self.visit_expr(m, s, cond)

        # Task #2: Convert condition to Z3
        try:
            cond_z3 = self.expr_to_z3(m, s, cond)
        except Exception as e:
            # If conversion fails, skip this assertion
            return

        if cond_z3 is None:
            return

        # Task #3: Check for assertion violation
        # An assertion is violated if the condition can be false
        # We check if NOT(condition) is satisfiable
        from z3 import Not, is_bool

        if not is_bool(cond_z3):
            # Try to convert to boolean
            from z3 import BitVecVal
            cond_z3 = cond_z3 != BitVecVal(0, cond_z3.size()) if hasattr(cond_z3, 'size') else cond_z3

        # Push a new context for checking
        s.pc.push()
        s.pc.add(Not(cond_z3))

        # Check if the negated condition is satisfiable
        if solve_pc(s.pc):
            # Assertion can be violated!
            m.assertion_violation = True
            # Store the assertion info for reporting
            if not hasattr(m, 'violated_assertions'):
                m.violated_assertions = []
            m.violated_assertions.append({
                'condition': str(cond),
                'z3_condition': str(cond_z3),
                'kind': str(assertion_kind) if assertion_kind else 'assert'
            })

        # Pop the context
        s.pc.pop()

        # Handle ifTrue/ifFalse actions if present
        if hasattr(stmt, 'ifTrue') and stmt.ifTrue:
            self.visit_stmt(m, s, stmt.ifTrue, modules, direction)
        if hasattr(stmt, 'ifFalse') and stmt.ifFalse:
            self.visit_stmt(m, s, stmt.ifFalse, modules, direction)

    def _handle_immediate_assertion_syntax(self, m: ExecutionManager, s: SymbolicState, stmt, modules, direction):
        """Handle ImmediateAssertionStatementSyntax (syntax node).

        Task #1: Extract assertion condition from syntax node
        Task #2: Convert to Z3
        Task #3: Check for violations
        """
        # Task #1: Extract the assertion expression from syntax node
        expr = getattr(stmt, 'expr', None)
        if expr is None:
            return

        # Get assertion keyword (assert, assume, cover)
        keyword = getattr(stmt, 'keyword', None)
        assertion_kind = str(keyword) if keyword else 'assert'

        # Visit the expression to update symbolic state
        self.visit_expr(m, s, expr)

        # Task #2: Convert expression to Z3
        try:
            cond_z3 = self.expr_to_z3(m, s, expr)
        except Exception as e:
            # If conversion fails, skip this assertion
            return

        if cond_z3 is None:
            return

        # Task #3: Check for assertion violation
        from z3 import Not, is_bool

        if not is_bool(cond_z3):
            from z3 import BitVecVal
            cond_z3 = cond_z3 != BitVecVal(0, cond_z3.size()) if hasattr(cond_z3, 'size') else cond_z3

        # Push a new context for checking
        s.pc.push()
        s.pc.add(Not(cond_z3))

        # Check if the negated condition is satisfiable
        if solve_pc(s.pc):
            # Assertion can be violated!
            m.assertion_violation = True
            if not hasattr(m, 'violated_assertions'):
                m.violated_assertions = []
            m.violated_assertions.append({
                'condition': str(expr),
                'z3_condition': str(cond_z3),
                'kind': assertion_kind
            })

        # Pop the context
        s.pc.pop()

        # Handle action block if present
        action = getattr(stmt, 'action', None)
        if action:
            self.visit_stmt(m, s, action, modules, direction)

    def _handle_concurrent_assertion(self, m: ExecutionManager, s: SymbolicState, stmt, modules, direction):
        """Handle ConcurrentAssertionStatement (SVA property assertions).

        SVA concurrent assertions like: assert property (p_name);
        These reference named properties defined elsewhere.
        """
        # Get the property specification
        propertySpec = getattr(stmt, 'propertySpec', None)
        if propertySpec is None:
            return

        # Get assertion kind (assert, assume, cover)
        assertion_kind = getattr(stmt, 'assertionKind', None)

        # Try to extract the property expression
        # For concurrent assertions, the property may be a reference to a named property
        expr = None
        if hasattr(propertySpec, 'expr'):
            expr = propertySpec.expr
        elif hasattr(propertySpec, 'property'):
            expr = propertySpec.property

        if expr is None:
            return

        # Visit the expression to update symbolic state
        self.visit_expr(m, s, expr)

        # Try to convert to Z3
        try:
            cond_z3 = self.expr_to_z3(m, s, expr)
        except Exception as e:
            return

        if cond_z3 is None:
            return

        # Check for assertion violation
        from z3 import Not, is_bool

        if not is_bool(cond_z3):
            from z3 import BitVecVal
            cond_z3 = cond_z3 != BitVecVal(0, cond_z3.size()) if hasattr(cond_z3, 'size') else cond_z3

        # Push a new context for checking
        s.pc.push()
        s.pc.add(Not(cond_z3))

        # Check if the negated condition is satisfiable
        if solve_pc(s.pc):
            m.assertion_violation = True
            if not hasattr(m, 'violated_assertions'):
                m.violated_assertions = []
            m.violated_assertions.append({
                'condition': str(expr),
                'z3_condition': str(cond_z3),
                'kind': str(assertion_kind) if assertion_kind else 'assert',
                'type': 'concurrent'
            })

        s.pc.pop()

    def _handle_assert_property_syntax(self, m: ExecutionManager, s: SymbolicState, stmt, modules, direction):
        """Handle AssertPropertyStatement syntax node.

        SVA syntax: assert property (property_spec);
        """
        # Get the property spec
        propertySpec = getattr(stmt, 'propertySpec', None)
        if propertySpec is None:
            return

        # Try to extract the property expression
        expr = None
        if hasattr(propertySpec, 'expr'):
            expr = propertySpec.expr
        elif hasattr(propertySpec, 'property'):
            expr = propertySpec.property

        if expr is None:
            return

        # Visit the expression
        self.visit_expr(m, s, expr)

        # Try to convert to Z3
        try:
            cond_z3 = self.expr_to_z3(m, s, expr)
        except Exception as e:
            return

        if cond_z3 is None:
            return

        # Check for assertion violation
        from z3 import Not, is_bool

        if not is_bool(cond_z3):
            from z3 import BitVecVal
            cond_z3 = cond_z3 != BitVecVal(0, cond_z3.size()) if hasattr(cond_z3, 'size') else cond_z3

        s.pc.push()
        s.pc.add(Not(cond_z3))

        if solve_pc(s.pc):
            m.assertion_violation = True
            if not hasattr(m, 'violated_assertions'):
                m.violated_assertions = []
            m.violated_assertions.append({
                'condition': str(expr),
                'z3_condition': str(cond_z3),
                'kind': 'assert property',
                'type': 'concurrent'
            })
            print(f"[ASSERTION VIOLATION] assert property: {expr}")

        s.pc.pop()

    def _handle_property_spec(self, m: ExecutionManager, s: SymbolicState, stmt, modules, direction):
        """Handle PropertySpecSyntax - contains assertion condition.

        PropertySpec contains the actual property expression that needs to be checked.
        """
        # print(f"[PROPERTY SPEC] Processing PropertySpecSyntax")
        # print(f"[PROPERTY SPEC] Children: {[type(c).__name__ for c in stmt]}")

        # Try to extract the property expression
        expr = None
        if hasattr(stmt, 'expr'):
            expr = stmt.expr
        elif hasattr(stmt, 'property'):
            expr = stmt.property

        if expr is None:
            # Try to iterate through children to find the expression
            for child in stmt:
                child_kind = getattr(child, 'kind', None)
                # print(f"[PROPERTY SPEC] Child: {type(child).__name__}, kind: {child_kind}")
                if child_kind and 'Expr' in str(child_kind):
                    expr = child
                    break
                # Check for SimplePropertyExpr
                if child_kind == ps.SyntaxKind.SimplePropertyExpr:
                    expr = child
                    break

        if expr is None:
            # print(f"[PROPERTY SPEC] No expression found in PropertySpec")
            return

        # print(f"[PROPERTY SPEC] Found expression: {expr}, type: {type(expr).__name__}")

        # Visit the expression
        self.visit_expr(m, s, expr)

        # Try to convert to Z3
        try:
            cond_z3 = self.expr_to_z3(m, s, expr)
        except Exception as e:
            # print(f"[PROPERTY SPEC] Failed to convert to Z3: {e}")
            return

        if cond_z3 is None:
            # print(f"[PROPERTY SPEC] Z3 conversion returned None")
            return

        # print(f"[PROPERTY SPEC] Z3 condition: {cond_z3}, type: {type(cond_z3)}")

        # Check if Z3 conversion returned SymbolicState (indicates property name reference)
        if isinstance(cond_z3, SymbolicState):
            # print(f"[PROPERTY SPEC] Property name reference detected, skipping Z3 check")
            return

        # Check for assertion violation
        from z3 import Not, is_bool, ExprRef

        # Verify we have a valid Z3 expression
        if not isinstance(cond_z3, ExprRef):
            # print(f"[PROPERTY SPEC] Invalid Z3 expression type: {type(cond_z3)}")
            return

        if not is_bool(cond_z3):
            from z3 import BitVecVal
            cond_z3 = cond_z3 != BitVecVal(0, cond_z3.size()) if hasattr(cond_z3, 'size') else cond_z3

        s.pc.push()
        s.pc.add(Not(cond_z3))

        if solve_pc(s.pc):
            m.assertion_violation = True
            if not hasattr(m, 'violated_assertions'):
                m.violated_assertions = []
            m.violated_assertions.append({
                'condition': str(expr),
                'z3_condition': str(cond_z3),
                'kind': 'property',
                'type': 'concurrent'
            })
            print(f"[ASSERTION VIOLATION] property: {expr}")

        s.pc.pop()

class ExpressionSymbolCollector:
    """Visitor that traverses an expression and collects parameter and port symbols."""

    def __init__(self):
        self.parameters = set()
        self.ports = set()

    def visit(self, expr):
        if expr is None:
            return
        kind = expr.kind
        if kind == ps.ExpressionKind.NamedValue:
            symbol = getattr(expr, "symbol", None)
            if symbol is not None:
                if symbol.kind == ps.SymbolKind.Parameter:
                    self.parameters.add(symbol)
                elif symbol.kind == ps.SymbolKind.Port:
                    self.ports.add(symbol)
        elif kind == ps.ExpressionKind.BinaryOp:
            self.visit(expr.left)
            self.visit(expr.right)
        elif kind == ps.ExpressionKind.UnaryOp:
            self.visit(expr.operand)
        elif kind == ps.ExpressionKind.Assignment:
            self.visit(expr.left)
            self.visit(expr.right)
        elif kind == ps.ExpressionKind.Concatenation:
            for e in expr.operands:
                self.visit(e)
        elif kind == ps.ExpressionKind.Call:
            for arg in expr.arguments:
                self.visit(arg)
        elif kind == ps.ExpressionKind.ElementSelect:
            self.visit(expr.value)
            self.visit(expr.selector)
        elif kind == ps.ExpressionKind.RangeSelect:
            self.visit(expr.value)
            self.visit(expr.left)
            self.visit(expr.right)
        elif kind == ps.ExpressionKind.ConditionalOp:
            self.visit(expr.predicate)
            self.visit(expr.left)
            self.visit(expr.right)
        elif kind == ps.ExpressionKind.MemberAccess:
            self.visit(expr.value)
        elif kind == ps.ExpressionKind.Streaming:
            self.visit(expr.value)
        elif kind == ps.ExpressionKind.Replication:
            self.visit(expr.value)
            for e in expr.elements:
                self.visit(e)
        elif kind == ps.ExpressionKind.SimpleAssignmentPattern:
            for e in expr.elements:
                self.visit(e)
        elif kind == ps.ExpressionKind.StructuredAssignmentPattern:
            for e in expr.elements:
                self.visit(e.value)
        elif kind == ps.ExpressionKind.ReplicatedAssignmentPattern:
            self.visit(expr.value)
            for e in expr.elements:
                self.visit(e)
        # Add more cases as needed for other expression kinds

    def collect(self, expr):
        self.visit(expr)
        return list(self.parameters), list(self.ports)


# Commented out this slangNodeVisitor - unused dead code (~1200 lines)
# Was imported but never instantiated or called anywhere in the codebase.
# Only contains print statements for ig debugging PySlang node types, no actual logic.
# The codebase uses SlangSymbolVisitor and SymbolicDFS instead (symbol-based visitors).
# Wrapped in 'if False:' to make it unreachable but preserve for reference.
if False: 
    class SlangNodeVisitor:
        """Visits a Slang AST by each Node (not by symbols)"""
        visitor_for_symbol = None
        
        def __init__(self, visitor_for_symbol):
            # print("building a node visitor")  # DEBUG
            self.visitor_for_symbol = visitor_for_symbol
            self.node_id_to_node = dict()
            self.node_id_to_pid  = {0:None}
            self.node_id_to_cids = dict()
            self.node_id_to_cids = {0:None}
            self.node_id_to_name = {0:""}
            self.node_id_to_name_symbol = {0:""}
            self.node_id_to_predicates = {0:[]}

            self.kind_to_node_ids = dict()
            
            self.level = 0
            self.num_children_in_level = 1
            self.num_children_in_next_level = 0
            self.num_children_processed = 0
            self.processed_children_ids = list()

            self.node_id = 0

        def traverse_tree(self, starting_node):
            """Traverse the AST."""

            self.queue = [starting_node]

            while len(self.queue) > 0:
                curr_node = self.queue.pop(0)
                self.visit(curr_node, use_queue=True)
            
            return True

        def process_node_for_predicates(self, node):
            pid = self.node_id_to_pid[self.node_id]
            if pid == None:
                return
            p_node = self.node_id_to_node[pid]

            new_predicate = []
            if p_node.kind == ps.SyntaxKind.ConditionalStatement:
                if p_node.statement == node:
                    new_predicate = [(self.find_corresponding_child_id(pid, p_node.predicate), True)]
                elif p_node.elseClause == node:
                    new_predicate = [(self.find_corresponding_child_id(pid, p_node.predicate), False)]
            if p_node.kind == ps.SyntaxKind.ConditionalExpression:
                if   p_node.left  == node:
                    new_predicate = [(self.find_corresponding_child_id(pid, p_node.predicate), True)]
                elif p_node.right == node:
                    new_predicate = [(self.find_corresponding_child_id(pid, p_node.predicate), False)]
            
            prev_predicates = self.node_id_to_predicates[pid]
            self.node_id_to_predicates[self.node_id] = prev_predicates+new_predicate

        def process_node_for_name(self, node):
            pid = self.node_id_to_pid[self.node_id]
            if pid == None:
                return
            p_node = self.node_id_to_node[pid]
            prev_name = self.node_id_to_name[pid]

            new_name = None
            # if node.kind == ps.SyntaxKind.CompilationUnit:
            #     new_name = "/"
            if node.kind == ps.SyntaxKind.ModuleDeclaration:
                new_name = node.header.name.value
            elif node.kind == ps.SyntaxKind.HierarchicalInstance:
                new_name = node.decl.name.value
            elif node.kind == ps.SyntaxKind.Declarator:
                new_name = node.name.value

            if new_name == None:
                self.node_id_to_name[self.node_id] = f"{prev_name}"
            else:
                self.node_id_to_name[self.node_id] = f"{prev_name}.{new_name}"

        def extract_kinds_from_descendants(self, nid, desired_kinds=[ps.TokenKind.Identifier]):
            desired_nids = list()

            queue = [(nid, [])]
            while len(queue) > 0:
                curr_nid, curr_metadata = queue.pop(0)
                curr_node = self.node_id_to_node[curr_nid]
                
                if curr_node.kind in desired_kinds:
                    desired_nids.append(curr_nid)

                for curr_cid in self.node_id_to_cids[curr_nid]:
                    new_metadata = []
                    queue.append((curr_cid, curr_metadata+new_metadata))

            return desired_nids

        def visit(self, node, use_queue=True):
            self.node_id_to_node[self.node_id] = node
            self.node_id_to_cids[self.node_id] = list()

            if node.kind == ps.SyntaxKind.Unknown:
                # print("UNKNOWN NODE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SyntaxList:
                # print("SYNTAX LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TokenList:
                # print("TOKEN LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SeparatedList:
                # print("SEPARATED LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AcceptOnPropertyExpr:
                # print("ACCEPT ON PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ActionBlock:
                # print("ACTION BLOCK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AddAssignmentExpression:
                # print("ADD ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AddExpression:
                # print("ADD EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ProceduralBlockSyntax:
                # print("ALWAYS BLOCK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AlwaysCombBlock:
                # print("ALWAYS COMB BLOCK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AlwaysFFBlock:
                # print("ALWAYS FF BLOCK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AlwaysLatchBlock:
                # print("ALWAYS LATCH BLOCK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AndAssignmentExpression:
                # print("AND ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AndPropertyExpr:
                # print("AND PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AndSequenceExpr:
                # print("AND SEQUENCE EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AnonymousProgram:
                # print("ANONYMOUS PROGRAM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AnsiPortList:
                # print("ANSI PORT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AnsiUdpPortList:
                # print("ANSI UDP PORT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ArgumentList:
                # print("ARGUMENT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ArithmeticLeftShiftAssignmentExpression:
                # print("ARITHMETIC LEFT SHIFT ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ArithmeticRightShiftAssignmentExpression:
                # print("ARITHMETIC RIGHT SHIFT ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ArithmeticShiftLeftExpression:
                # print("ARITHMETIC SHIFT LEFT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ArithmeticShiftRightExpression:
                # print("ARITHMETIC SHIFT RIGHT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ArrayAndMethod:
                # print("ARRAY AND METHOD")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ArrayOrMethod:
                # print("ARRAY OR METHOD")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ArrayOrRandomizeMethodExpression:
                # print("ARRAY OR RANDOMIZE METHOD EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ArrayUniqueMethod:
                # print("ARRAY UNIQUE METHOD")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ArrayXorMethod:
                # print("ARRAY XOR METHOD")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AscendingRangeSelect:
                # print("ASCENDING RANGE SELECT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AssertPropertyStatement:
                # print("ASSERT PROPERTY STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AssertionItemPort:
                # print("ASSERTION ITEM PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AssertionItemPortList:
                # print("ASSERTION ITEM PORT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AssignmentExpression:
                # print("ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AssignmentPatternExpression:
                # print("ASSIGNMENT PATTERN EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AssignmentPatternItem:
                # print("ASSIGNMENT PATTERN ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AssumePropertyStatement:
                # print("ASSUME PROPERTY STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AttributeInstance:
                # print("ATTRIBUTE INSTANCE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.AttributeSpec:
                # print("ATTRIBUTE SPEC")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BadExpression:
                # print("BAD EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BeginKeywordsDirective:
                # print("BEGIN KEYWORDS DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BinSelectWithFilterExpr:
                # print("BIN SELECT WITH FILTER EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BinaryAndExpression:
                # print("BINARY AND EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BinaryBinsSelectExpr:
                # print("BINARY BINS SELECT EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BinaryBlockEventExpression:
                # print("BINARY BLOCK EVENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BinaryConditionalDirectiveExpression:
                # print("BINARY CONDITIONAL DIRECTIVE EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BinaryEventExpression:
                # print("BINARY EVENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BinaryOrExpression:
                # print("BINARY OR EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BinaryXnorExpression:
                # print("BINARY XNOR EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BinaryXorExpression:
                # print("BINARY XOR EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BindDirective:
                # print("BIND DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BindTargetList:
                # print("BIND TARGET LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BinsSelectConditionExpr:
                # print("BINS SELECT CONDITION EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BinsSelection:
                # print("BINS SELECTION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BitSelect:
                # print("BIT SELECT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BitType:
                # print("BIT TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BlockCoverageEvent:
                # print("BLOCK COVERAGE EVENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.BlockingEventTriggerStatement:
                # print("BLOCKING EVENT TRIGGER STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ByteType:
                # print("BYTE TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CHandleType:
                # print("CHANDLE TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CaseEqualityExpression:
                # print("CASE EQUALITY EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CaseGenerate:
                # print("CASE GENERATE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CaseInequalityExpression:
                # print("CASE INEQUALITY EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CasePropertyExpr:
                # print("CASE PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CaseStatement:
                # print("CASE STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CastExpression:
                # print("CAST EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CellConfigRule:
                # print("CELL CONFIG RULE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CellDefineDirective:
                # print("CELL DEFINE DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ChargeStrength:
                # print("CHARGE STRENGTH")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CheckerDataDeclaration:
                # print("CHECKER DATA DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CheckerDeclaration:
                # print("CHECKER DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CheckerInstanceStatement:
                # print("CHECKER INSTANCE STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CheckerInstantiation:
                # print("CHECKER INSTANTIATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClassDeclaration:
                # print("CLASS DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClassMethodDeclaration:
                # print("CLASS METHOD DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClassMethodPrototype:
                # print("CLASS METHOD PROTOTYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClassName:
                # print("CLASS NAME")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClassPropertyDeclaration:
                # print("CLASS PROPERTY DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClassSpecifier:
                # print("CLASS SPECIFIER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClockingDeclaration:
                # print("CLOCKING DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClockingDirection:
                # print("CLOCKING DIRECTION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClockingItem:
                # print("CLOCKING ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClockingPropertyExpr:
                # print("CLOCKING PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClockingSequenceExpr:
                # print("CLOCKING SEQUENCE EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ClockingSkew:
                # print("CLOCKING SKEW")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ColonExpressionClause:
                # print("COLON EXPRESSION CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CompilationUnit:
                # print("COMPILATION UNIT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConcatenationExpression:
                # print("CONCATENATION EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConcurrentAssertionMember:
                # print("CONCURRENT ASSERTION MEMBER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConditionalConstraint:
                # print("CONDITIONAL CONSTRAINT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConditionalExpression:
                # print("CONDITIONAL EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConditionalPathDeclaration:
                # print("CONDITIONAL PATH DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConditionalPattern:
                # print("CONDITIONAL PATTERN")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConditionalPredicate:
                # print("CONDITIONAL PREDICATE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConditionalPropertyExpr:
                # print("CONDITIONAL PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConditionalStatement:
                # print("CONDITIONAL STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConfigCellIdentifier:
                # print("CONFIG CELL IDENTIFIER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConfigDeclaration:
                # print("CONFIG DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConfigInstanceIdentifier:
                # print("CONFIG INSTANCE IDENTIFIER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConfigLiblist:
                # print("CONFIG LIBLIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConfigUseClause:
                # print("CONFIG USE CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConstraintBlock:
                # print("CONSTRAINT BLOCK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConstraintDeclaration:
                # print("CONSTRAINT DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConstraintPrototype:
                # print("CONSTRAINT PROTOTYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ConstructorName:
                # print("CONSTRUCTOR NAME")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ContinuousAssign:
                # print("ASSIGNMENT STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CopyClassExpression:
                # print("COPY CLASS EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CoverCross:
                # print("COVER CROSS")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CoverPropertyStatement:
                # print("COVER PROPERTY STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CoverSequenceStatement:
                # print("COVER SEQUENCE STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CoverageBins:
                # print("COVERAGE BINS")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CoverageBinsArraySize:
                # print("COVERAGE BINS ARRAY SIZE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CoverageIffClause:
                # print("COVERAGE IFF CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CoverageOption:
                # print("COVERAGE OPTION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CovergroupDeclaration:
                # print("COVERGROUP DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.Coverpoint:
                # print("COVERPOINT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.CycleDelay:
                # print("CYCLE DELAY")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DPIExport:
                # print("DPI EXPORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DPIImport:
                # print("DPI IMPORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DataDeclaration:
                # print("DATA DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.Declarator:
                # print("DECLARATOR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefParam:
                # print("DEF PARAM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefParamAssignment:
                # print("DEF PARAM ASSIGNMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultCaseItem:
                # print("DEFAULT CASE ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultClockingReference:
                # print("DEFAULT CLOCKING REFERENCE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultConfigRule:
                # print("DEFAULT CONFIG RULE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultCoverageBinInitializer:
                # print("DEFAULT COVERAGE BIN INITIALIZER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultDecayTimeDirective:
                # print("DEFAULT DECAY TIME DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultDisableDeclaration:
                # print("DEFAULT DISABLE DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultDistItem:
                # print("DEFAULT DIST ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultExtendsClauseArg:
                # print("DEFAULT EXTENDS CLAUSE ARG")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultFunctionPort:
                # print("DEFAULT FUNCTION PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultNetTypeDirective:
                # print("DEFAULT NET TYPE DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultPatternKeyExpression:
                # print("DEFAULT PATTERN KEY EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultPropertyCaseItem:
                # print("DEFAULT PROPERTY CASE ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultRsCaseItem:
                # print("DEFAULT RS CASE ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultSkewItem:
                # print("DEFAULT SKEW ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefaultTriregStrengthDirective:
                # print("DEFAULT TRIREG STRENGTH DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DeferredAssertion:
                # print("DEFERRED ASSERTION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DefineDirective:
                # print("DEFINE DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.Delay3:
                # print("DELAY 3")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DelayControl:
                # print("DELAY CONTROL")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DelayModeDistributedDirective:
                # print("DELAY MODE DISTRIBUTED DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DelayModePathDirective:
                # print("DELAY MODE PATH DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DelayModeUnitDirective:
                # print("DELAY MODE UNIT DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DelayModeZeroDirective:
                # print("DELAY MODE ZERO DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DelayedSequenceElement:
                # print("DELAYED SEQUENCE ELEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DelayedSequenceExpr:
                # print("DELAYED SEQUENCE EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DescendingRangeSelect:
                # print("DESCENDING RANGE SELECT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DisableConstraint:
                # print("DISABLE CONSTRAINT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DisableForkStatement:
                # print("DISABLE FORK STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DisableIff:
                # print("DISABLE IFF")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DisableStatement:
                # print("DISABLE STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DistConstraintList:
                # print("DIST CONSTRAINT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DistItem:
                # print("DIST ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DistWeight:
                # print("DIST WEIGHT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DivideAssignmentExpression:
                # print("DIVIDE ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DivideExpression:
                # print("DIVIDE EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DividerClause:
                # print("DIVIDER CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DoWhileStatement:
                # print("DO WHILE STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DotMemberClause:
                # print("DOT MEMBER CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.DriveStrength:
                # print("DRIVE STRENGTH")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EdgeControlSpecifier:
                # print("EDGE CONTROL SPECIFIER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EdgeDescriptor:
                # print("EDGE DESCRIPTOR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EdgeSensitivePathSuffix:
                # print("EDGE SENSITIVE PATH SUFFIX")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ElabSystemTask:
                # print("ELAB SYSTEM TASK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ElementSelect:
                # print("ELEMENT SELECT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ElementSelectExpression:
                # print("ELEMENT SELECT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ElsIfDirective:
                # print("ELSIF DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ElseClause:
                # print("ELSE CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ElseConstraintClause:
                # print("ELSE CONSTRAINT CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ElseDirective:
                # print("ELSE DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ElsePropertyClause:
                # print("ELSE PROPERTY CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EmptyArgument:
                # print("EMPTY ARGUMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EmptyIdentifierName:
                # print("EMPTY IDENTIFIER NAME")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EmptyMember:
                # print("EMPTY MEMBER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EmptyNonAnsiPort:
                # print("EMPTY NON ANSI PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EmptyPortConnection:
                # print("EMPTY PORT CONNECTION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EmptyQueueExpression:
                # print("EMPTY QUEUE EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EmptyStatement:
                # print("EMPTY STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EmptyTimingCheckArg:
                # print("EMPTY TIMING CHECK ARG")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EndCellDefineDirective:
                # print("END CELL DEFINE DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EndIfDirective:
                # print("END IF DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EndKeywordsDirective:
                # print("END KEYWORDS DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EndProtectDirective:
                # print("END PROTECT DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EndProtectedDirective:
                # print("END PROTECTED DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EnumType:
                # print("ENUM TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EqualityExpression:
                # print("EQUALITY EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EqualsAssertionArgClause:
                # print("EQUALS ASSERTION ARG CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EqualsTypeClause:
                # print("EQUALS TYPE CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EqualsValueClause:
                # print("EQUALS VALUE CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EventControl:
                # print("EVENT CONTROL")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EventControlWithExpression:
                # print("EVENT CONTROL WITH EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.EventType:
                # print("EVENT TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExpectPropertyStatement:
                # print("EXPECT PROPERTY STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExplicitAnsiPort:
                # print("EXPLICIT ANSI PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExplicitNonAnsiPort:
                # print("EXPLICIT NON ANSI PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExpressionConstraint:
                # print("EXPRESSION CONSTRAINT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExpressionCoverageBinInitializer:
                # print("EXPRESSION COVERAGE BIN INITIALIZER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExpressionOrDist:
                # print("EXPRESSION OR DIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExpressionPattern:
                # print("EXPRESSION PATTERN")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExpressionStatement:
                # print("EXPRESSION STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExpressionTimingCheckArg:
                # print("EXPRESSION TIMING CHECK ARG")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExtendsClause:
                # print("EXTENDS CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExternInterfaceMethod:
                # print("EXTERN INTERFACE METHOD")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExternModuleDecl:
                # print("EXTERN MODULE DECL")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ExternUdpDecl:
                # print("EXTERN UDP DECL")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.FilePathSpec:
                # print("FILE PATH SPEC")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.FinalBlock:
                # print("FINAL BLOCK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.FirstMatchSequenceExpr:
                # print("FIRST MATCH SEQUENCE EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.FollowedByPropertyExpr:
                # print("FOLLOWED BY PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ForLoopStatement:
                # print("FOR LOOP STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ForVariableDeclaration:
                # print("FOR VARIABLE DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ForeachLoopList:
                # print("FOREACH LOOP LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ForeachLoopStatement:
                # print("FOREACH LOOP STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ForeverStatement:
                # print("FOREVER STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ForwardTypeRestriction:
                # print("FORWARD TYPE RESTRICTION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ForwardTypedefDeclaration:
                # print("FORWARD TYPEDEF DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.FunctionDeclaration:
                # print("FUNCTION DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.FunctionPort:
                # print("FUNCTION PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.FunctionPortList:
                # print("FUNCTION PORT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.FunctionPrototype:
                # print("FUNCTION PROTOTYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.GenerateBlock:
                # print("GENERATE BLOCK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.GenerateRegion:
                # print("GENERATE REGION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.GenvarDeclaration:
                # print("GENVAR DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.GreaterThanEqualExpression:
                # print("GREATER THAN EQUAL EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.GreaterThanExpression:
                # print("GREATER THAN EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.HierarchicalInstance:
                # print("HIERARCHICAL INSTANCE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.HierarchyInstantiation:
                # print("HIERARCHY INSTANTIATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IdWithExprCoverageBinInitializer:
                # print("ID WITH EXPR COVERAGE BIN INITIALIZER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IdentifierName:
                # print("IDENTIFIER NAME")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IdentifierSelectName:
                # print("IDENTIFIER SELECT NAME")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IfDefDirective:
                # print("IFDEF DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IfGenerate:
                # print("IF GENERATE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IfNDefDirective:
                # print("IFNDEF DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IfNonePathDeclaration:
                # print("IF NONE PATH DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IffEventClause:
                # print("IFF EVENT CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IffPropertyExpr:
                # print("IFF PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImmediateAssertStatement:
                # print("IMMEDIATE ASSERT STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImmediateAssertionMember:
                # print("IMMEDIATE ASSERTION MEMBER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImmediateAssumeStatement:
                # print("IMMEDIATE ASSUME STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImmediateCoverStatement:
                # print("IMMEDIATE COVER STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImplementsClause:
                # print("IMPLEMENTS CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImplicationConstraint:
                # print("IMPLICATION CONSTRAINT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImplicationPropertyExpr:
                # print("IMPLICATION PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImplicitAnsiPort:
                # print("IMPLICIT ANSI PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImplicitEventControl:
                # print("IMPLICIT EVENT CONTROL")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImplicitNonAnsiPort:
                # print("IMPLICIT NON ANSI PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImplicitType:
                # print("IMPLICIT TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ImpliesPropertyExpr:
                # print("IMPLIES PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IncludeDirective:
                # print("INCLUDE DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.InequalityExpression:
                # print("INEQUALITY EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.InitialBlock:
                # print("INITIAL BLOCK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.InsideExpression:
                # print("INSIDE EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.InstanceConfigRule:
                # print("INSTANCE CONFIG RULE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.InstanceName:
                # print("INSTANCE NAME")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IntType:
                # print("INT TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IntegerLiteralExpression:
                # print("INTEGER LITERAL EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IntegerType:
                # print("INTEGER TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IntegerVectorExpression:
                # print("INTEGER VECTOR EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.InterfaceDeclaration:
                # print("INTERFACE DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.InterfaceHeader:
                # print("INTERFACE HEADER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.InterfacePortHeader:
                # print("INTERFACE PORT HEADER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IntersectClause:
                # print("INTERSECT CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.IntersectSequenceExpr:
                # print("INTERSECT SEQUENCE EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.InvocationExpression:
                # print("INVOCATION EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.JumpStatement:
                # print("JUMP STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LessThanEqualExpression:
                # print("LESS THAN EQUAL EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LessThanExpression:
                # print("LESS THAN EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LetDeclaration:
                # print("LET DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LibraryDeclaration:
                # print("LIBRARY DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LibraryIncDirClause:
                # print("LIBRARY INC DIR CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LibraryIncludeStatement:
                # print("LIBRARY INCLUDE STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LibraryMap:
                # print("LIBRARY MAP")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LineDirective:
                # print("LINE DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LocalScope:
                # print("LOCAL SCOPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LocalVariableDeclaration:
                # print("LOCAL VARIABLE DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LogicType:
                # print("LOGIC TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LogicalAndExpression:
                # print("LOGICAL AND EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LogicalEquivalenceExpression:
                # print("LOGICAL EQUIVALENCE EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LogicalImplicationExpression:
                # print("LOGICAL IMPLICATION EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LogicalLeftShiftAssignmentExpression:
                # print("LOGICAL LEFT SHIFT ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LogicalOrExpression:
                # print("LOGICAL OR EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LogicalRightShiftAssignmentExpression:
                # print("LOGICAL RIGHT SHIFT ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LogicalShiftLeftExpression:
                # print("LOGICAL SHIFT LEFT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LogicalShiftRightExpression:
                # print("LOGICAL SHIFT RIGHT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LongIntType:
                # print("LONG INT TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LoopConstraint:
                # print("LOOP CONSTRAINT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LoopGenerate:
                # print("LOOP GENERATE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.LoopStatement:
                # print("LOOP STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MacroActualArgument:
                # print("MACRO ACTUAL ARGUMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MacroActualArgumentList:
                # print("MACRO ACTUAL ARGUMENT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MacroArgumentDefault:
                # print("MACRO ARGUMENT DEFAULT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MacroFormalArgument:
                # print("MACRO FORMAL ARGUMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MacroFormalArgumentList:
                # print("MACRO FORMAL ARGUMENT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MacroUsage:
                # print("MACRO USAGE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MatchesClause:
                # print("MATCHES CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MemberAccessExpression:
                # print("MEMBER ACCESS EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MinTypMaxExpression:
                # print("MIN TYP MAX EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModAssignmentExpression:
                # print("MOD ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModExpression:
                # print("MOD EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModportClockingPort:
                # print("MODPORT CLOCKING PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModportDeclaration:
                # print("MODPORT DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModportExplicitPort:
                # print("MODPORT EXPLICIT PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModportItem:
                # print("MODPORT ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModportNamedPort:
                # print("MODPORT NAMED PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModportSimplePortList:
                # print("MODPORT SIMPLE PORT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModportSubroutinePort:
                # print("MODPORT SUBROUTINE PORT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModportSubroutinePortList:
                # print("MODPORT SUBROUTINE PORT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModuleDeclaration:
                # print("MODULE DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ModuleHeader:
                # print("MODULE HEADER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MultipleConcatenationExpression:
                # print("MULTIPLE CONCATENATION EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MultiplyAssignmentExpression:
                # print("MULTIPLY ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.MultiplyExpression:
                # print("MULTIPLY EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NameValuePragmaExpression:
                # print("NAME VALUE PRAGMA EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NamedArgument:
                # print("NAMED ARGUMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NamedBlockClause:
                # print("NAMED BLOCK CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NamedConditionalDirectiveExpression:
                # print("NAMED CONDITIONAL DIRECTIVE EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NamedLabel:
                # print("NAMED LABEL")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NamedParamAssignment:
                # print("NAMED PARAM ASSIGNMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NamedPortConnection:
                # print("NAMED PORT CONNECTION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NamedStructurePatternMember:
                # print("NAMED STRUCTURE PATTERN MEMBER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NamedType:
                # print("NAMED TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NetAlias:
                # print("NET ALIAS")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NetDeclaration:
                # print("NET DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NetPortHeader:
                # print("NET PORT HEADER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NetTypeDeclaration:
                # print("NET TYPE DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NewArrayExpression:
                # print("NEW ARRAY EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NewClassExpression:
                # print("NEW CLASS EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NoUnconnectedDriveDirective:
                # print("NO UNCONNECTED DRIVE DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NonAnsiPortList:
                # print("NON ANSI PORT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NonAnsiUdpPortList:
                # print("NON ANSI UDP PORT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NonblockingAssignmentExpression:
                # print("NONBLOCKING ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NonblockingEventTriggerStatement:
                # print("NONBLOCKING EVENT TRIGGER STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NullLiteralExpression:
                # print("NULL LITERAL EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.NumberPragmaExpression:
                # print("NUMBER PRAGMA EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.OneStepDelay:
                # print("ONE STEP DELAY")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.OrAssignmentExpression:
                # print("OR ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.OrPropertyExpr:
                # print("OR PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.OrSequenceExpr:
                # print("OR SEQUENCE EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.OrderedArgument:
                # print("ORDERED ARGUMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.OrderedParamAssignment:
                # print("ORDERED PARAM ASSIGNMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.OrderedPortConnection:
                # print("ORDERED PORT CONNECTION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.OrderedStructurePatternMember:
                # print("ORDERED STRUCTURE PATTERN MEMBER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PackageDeclaration:
                # print("PACKAGE DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PackageExportAllDeclaration:
                # print("PACKAGE EXPORT ALL DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PackageExportDeclaration:
                # print("PACKAGE EXPORT DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PackageHeader:
                # print("PACKAGE HEADER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PackageImportDeclaration:
                # print("PACKAGE IMPORT DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PackageImportItem:
                # print("PACKAGE IMPORT ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParallelBlockStatement:
                # print("PARALLEL BLOCK STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParameterDeclaration:
                # print("PARAMETER DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParameterDeclarationStatement:
                # print("PARAMETER DECLARATION STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParameterPortList:
                # print("PARAMETER PORT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParameterValueAssignment:
                # print("PARAMETER VALUE ASSIGNMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParenExpressionList:
                # print("PAREN EXPRESSION LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParenPragmaExpression:
                # print("PAREN PRAGMA EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParenthesizedBinsSelectExpr:
                # print("PARENTHESIZED BINS SELECT EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParenthesizedConditionalDirectiveExpression:
                # print("PARENTHESIZED CONDITIONAL DIRECTIVE EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParenthesizedEventExpression:
                # print("PARENTHESIZED EVENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParenthesizedExpression:
                # print("PARENTHESIZED EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParenthesizedPattern:
                # print("PARENTHESIZED PATTERN")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParenthesizedPropertyExpr:
                # print("PARENTHESIZED PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ParenthesizedSequenceExpr:
                # print("PARENTHESIZED SEQUENCE EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PathDeclaration:
                # print("PATH DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PathDescription:
                # print("PATH DESCRIPTION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PatternCaseItem:
                # print("PATTERN CASE ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PortConcatenation:
                # print("PORT CONCATENATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PortDeclaration:
                # print("PORT DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PortReference:
                # print("PORT REFERENCE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PostdecrementExpression:
                # print("POSTDECREMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PostincrementExpression:
                # print("POSTINCREMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PowerExpression:
                # print("POWER EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PragmaDirective:
                # print("PRAGMA DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PrimaryBlockEventExpression:
                # print("PRIMARY BLOCK EVENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PrimitiveInstantiation:
                # print("PRIMITIVE INSTANTIATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ProceduralAssignStatement:
                # print("PROCEDURAL ASSIGN STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ProceduralDeassignStatement:
                # print("PROCEDURAL DEASSIGN STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ProceduralForceStatement:
                # print("PROCEDURAL FORCE STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ProceduralReleaseStatement:
                # print("PROCEDURAL RELEASE STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.Production:
                # print("PRODUCTION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ProgramDeclaration:
                # print("PROGRAM DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ProgramHeader:
                # print("PROGRAM HEADER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PropertyDeclaration:
                # print("PROPERTY DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PropertySpec:
                # print("PROPERTY SPEC")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PropertyType:
                # print("PROPERTY TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ProtectDirective:
                # print("PROTECT DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ProtectedDirective:
                # print("PROTECTED DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PullStrength:
                # print("PULL STRENGTH")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.PulseStyleDeclaration:
                # print("PULSE STYLE DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.QueueDimensionSpecifier:
                # print("QUEUE DIMENSION SPECIFIER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RandCaseItem:
                # print("RAND CASE ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RandCaseStatement:
                # print("RAND CASE STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RandJoinClause:
                # print("RAND JOIN CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RandSequenceStatement:
                # print("RAND SEQUENCE STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RangeCoverageBinInitializer:
                # print("RANGE COVERAGE BIN INITIALIZER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RangeDimensionSpecifier:
                # print("RANGE DIMENSION SPECIFIER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RangeList:
                # print("RANGE LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RealLiteralExpression:
                # print("REAL LITERAL EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RealTimeType:
                # print("REAL TIME TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RealType:
                # print("REAL TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RegType:
                # print("REG TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RepeatedEventControl:
                # print("REPEATED EVENT CONTROL")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ReplicatedAssignmentPattern:
                # print("REPLICATED ASSIGNMENT PATTERN")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ResetAllDirective:
                # print("RESET ALL DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RestrictPropertyStatement:
                # print("RESTRICT PROPERTY STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ReturnStatement:
                # print("RETURN STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RootScope:
                # print("ROOT SCOPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RsCase:
                # print("RS CASE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RsCodeBlock:
                # print("RS CODE BLOCK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RsElseClause:
                # print("RS ELSE CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RsIfElse:
                # print("RS IF ELSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RsProdItem:
                # print("RS PROD ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RsRepeat:
                # print("RS REPEAT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RsRule:
                # print("RS RULE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.RsWeightClause:
                # print("RS WEIGHT CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SUntilPropertyExpr:
                # print("S UNTIL PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SUntilWithPropertyExpr:
                # print("S UNTIL WITH PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ScopedName:
                # print("SCOPED NAME")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SequenceDeclaration:
                # print("SEQUENCE DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SequenceMatchList:
                # print("SEQUENCE MATCH LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SequenceRepetition:
                # print("SEQUENCE REPETITION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SequenceType:
                # print("SEQUENCE TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SequentialBlockStatement:
                # print("SEQUENTIAL BLOCK STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ShortIntType:
                # print("SHORT INT TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ShortRealType:
                # print("SHORT REAL TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SignalEventExpression:
                # print("SIGNAL EVENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SignedCastExpression:
                # print("SIGNED CAST EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SimpleAssignmentPattern:
                # print("SIMPLE ASSIGNMENT PATTERN")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SimpleBinsSelectExpr:
                # print("SIMPLE BINS SELECT EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SimplePathSuffix:
                # print("SIMPLE PATH SUFFIX")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SimplePragmaExpression:
                # print("SIMPLE PRAGMA EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SimplePropertyExpr:
                # print("SIMPLE PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SimpleRangeSelect:
                # print("SIMPLE RANGE SELECT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SimpleSequenceExpr:
                # print("SIMPLE SEQUENCE EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SolveBeforeConstraint:
                # print("SOLVE BEFORE CONSTRAINT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SpecifyBlock:
                # print("SPECIFY BLOCK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SpecparamDeclaration:
                # print("SPECPARAM DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SpecparamDeclarator:
                # print("SPECPARAM DECLARATOR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StandardCaseItem:
                # print("STANDARD CASE ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StandardPropertyCaseItem:
                # print("STANDARD PROPERTY CASE ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StandardRsCaseItem:
                # print("STANDARD RS CASE ITEM")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StreamExpression:
                # print("STREAM EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StreamExpressionWithRange:
                # print("STREAM EXPRESSION WITH RANGE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StreamingConcatenationExpression:
                # print("STREAMING CONCATENATION EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StringLiteralExpression:
                # print("STRING LITERAL EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StringType:
                # print("STRING TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StrongWeakPropertyExpr:
                # print("STRONG WEAK PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StructType:
                # print("STRUCT TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StructUnionMember:
                # print("STRUCT UNION MEMBER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StructurePattern:
                # print("STRUCTURE PATTERN")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.StructuredAssignmentPattern:
                # print("STRUCTURED ASSIGNMENT PATTERN")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SubtractAssignmentExpression:
                # print("SUBTRACT ASSIGNMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SubtractExpression:
                # print("SUBTRACT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SuperHandle:
                # print("SUPER HANDLE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SuperNewDefaultedArgsExpression:
                # print("SUPER NEW DEFAULTED ARGS EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SystemName:
                # print("SYSTEM NAME")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.SystemTimingCheck:
                # print("SYSTEM TIMING CHECK")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TaggedPattern:
                # print("TAGGED PATTERN")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TaggedUnionExpression:
                # print("TAGGED UNION EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TaskDeclaration:
                # print("TASK DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ThisHandle:
                # print("THIS HANDLE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ThroughoutSequenceExpr:
                # print("THROUGHOUT SEQUENCE EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TimeLiteralExpression:
                # print("TIME LITERAL EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TimeScaleDirective:
                # print("TIME SCALE DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TimeType:
                # print("TIME TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TimeUnitsDeclaration:
                # print("TIME UNITS DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TimingCheckEventArg:
                # print("TIMING CHECK EVENT ARG")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TimingCheckEventCondition:
                # print("TIMING CHECK EVENT CONDITION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TimingControlExpression:
                # print("TIMING CONTROL EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TimingControlStatement:
                # print("TIMING CONTROL STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TransListCoverageBinInitializer:
                # print("TRANS LIST COVERAGE BIN INITIALIZER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TransRange:
                # print("TRANS RANGE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TransRepeatRange:
                # print("TRANS REPEAT RANGE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TransSet:
                # print("TRANS SET")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TypeAssignment:
                # print("TYPE ASSIGNMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TypeParameterDeclaration:
                # print("TYPE PARAMETER DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TypeReference:
                # print("TYPE REFERENCE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.TypedefDeclaration:
                # print("TYPEDEF DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UdpBody:
                # print("UDP BODY")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UdpDeclaration:
                # print("UDP DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UdpEdgeField:
                # print("UDP EDGE FIELD")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UdpEntry:
                # print("UDP ENTRY")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UdpInitialStmt:
                # print("UDP INITIAL STMT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UdpInputPortDecl:
                # print("UDP INPUT PORT DECL")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UdpOutputPortDecl:
                # print("UDP OUTPUT PORT DECL")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UdpSimpleField:
                # print("UDP SIMPLE FIELD")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryBinsSelectExpr:
                # print("UNARY BINS SELECT EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryBitwiseAndExpression:
                # print("UNARY BITWISE AND EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryBitwiseNandExpression:
                # print("UNARY BITWISE NAND EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryBitwiseNorExpression:
                # print("UNARY BITWISE NOR EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryBitwiseNotExpression:
                # print("UNARY BITWISE NOT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryBitwiseOrExpression:
                # print("UNARY BITWISE OR EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryBitwiseXnorExpression:
                # print("UNARY BITWISE XNOR EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryBitwiseXorExpression:
                # print("UNARY BITWISE XOR EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryConditionalDirectiveExpression:
                # print("UNARY CONDITIONAL DIRECTIVE EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryLogicalNotExpression:
                # print("UNARY LOGICAL NOT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryMinusExpression:
                # print("UNARY MINUS EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryPlusExpression:
                # print("UNARY PLUS EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryPredecrementExpression:
                # print("UNARY PREDECREMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryPreincrementExpression:
                # print("UNARY PREINCREMENT EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnaryPropertyExpr:
                # print("UNARY PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnarySelectPropertyExpr:
                # print("UNARY SELECT PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnbasedUnsizedLiteralExpression:
                # print("UNBASED UNSIZED LITERAL EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnconnectedDriveDirective:
                # print("UNCONNECTED DRIVE DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UndefDirective:
                # print("UNDEF DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UndefineAllDirective:
                # print("UNDEFINE ALL DIRECTIVE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnionType:
                # print("UNION TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UniquenessConstraint:
                # print("UNIQUENESS CONSTRAINT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UnitScope:
                # print("UNIT SCOPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UntilPropertyExpr:
                # print("UNTIL PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UntilWithPropertyExpr:
                # print("UNTIL WITH PROPERTY EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.Untyped:
                # print("UNTYPED")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.UserDefinedNetDeclaration:
                # print("USER DEFINED NET DECLARATION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.ValueRangeExpression:
                # print("VALUE RANGE EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.VariableDimension:
                # print("VARIABLE DIMENSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.VariablePattern:
                # print("VARIABLE PATTERN")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.VariablePortHeader:
                # print("VARIABLE PORT HEADER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.VirtualInterfaceType:
                # print("VIRTUAL INTERFACE TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.VoidCastedCallStatement:
                # print("VOID CASTED CALL STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.VoidType:
                # print("VOID TYPE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WaitForkStatement:
                # print("WAIT FORK STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WaitOrderStatement:
                # print("WAIT ORDER STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WaitStatement:
                # print("WAIT STATEMENT")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WildcardDimensionSpecifier:
                # print("WILDCARD DIMENSION SPECIFIER")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WildcardEqualityExpression:
                # print("WILDCARD EQUALITY EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WildcardInequalityExpression:
                # print("WILDCARD INEQUALITY EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WildcardLiteralExpression:
                # print("WILDCARD LITERAL EXPRESSION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WildcardPattern:
                # print("WILDCARD PATTERN")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WildcardPortConnection:
                # print("WILDCARD PORT CONNECTION")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WildcardPortList:
                # print("WILDCARD PORT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WildcardUdpPortList:
                # print("WILDCARD UDP PORT LIST")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WithClause:
                # print("WITH CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WithFunctionClause:
                # print("WITH FUNCTION CLAUSE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WithFunctionSample:
                # print("WITH FUNCTION SAMPLE")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.WithinSequenceExpr:
                # print("WITHIN SEQUENCE EXPR")  # DEBUG
                pass
            elif node.kind == ps.SyntaxKind.XorAssignmentExpression:
                # print("XOR ASSIGNMENT EXPRESSION")  # DEBUG
                pass



        #self.process_node_for_predicates(node)
        self.process_node_for_name(node)
        try:
            self.kind_to_node_ids[node.kind].append(self.node_id)
        except KeyError:
            self.kind_to_node_ids[node.kind] = [self.node_id]

        self.num_children_processed += 1
        self.processed_children_ids.append(self.node_id)
        try:
            for i in range(len(node)):
                self.num_children_in_next_level += 1
                child_id = self.node_id + (self.num_children_in_level - self.num_children_processed) + self.num_children_in_next_level
                self.node_id_to_pid[child_id] = self.node_id
                self.node_id_to_cids[self.node_id].append(child_id)

                if use_queue:
                    self.queue.append(node.__getitem__(i))
        except TypeError:
            # This exception is required because, unlike SyntaxNode, Token
            # objects do not have a len() function (i.e., getChildCount)
            pass
        

        if self.num_children_processed == self.num_children_in_level:
            self.level += 1
            self.num_children_in_level = self.num_children_in_next_level
            self.num_children_in_next_level = 0
            self.num_children_processed = 0
            self.processed_children_ids = list()

        self.node_id += 1