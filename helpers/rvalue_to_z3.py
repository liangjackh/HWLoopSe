"""Helpers for working with Z3, specifically parsing the symbolic expressions into
Z3 expressions and solving for assertion violations."""

import z3
import re
import logging
from z3 import Solver, Int, BitVec, Context, BitVecSort, ExprRef, BitVecRef, If, BitVecVal, And, IntVal, Int2BV, Or, Not, ULT, UGT, Z3Exception, BoolRef
from z3 import is_and, is_app_of, Z3_OP_EXTRACT, is_eq, is_distinct
from helpers.rvalue_parser import parse_tokens, tokenize
from engine.execution_manager import ExecutionManager
from engine.symbolic_state import SymbolicState, smt_stats
import pyslang as ps
import networkx as nx
import ast


def _bool_to_bv(expr, width=1):
    """Convert a Z3 BoolRef to a BitVecRef of the given width."""
    if isinstance(expr, BoolRef) and not isinstance(expr, BitVecRef):
        return If(expr, BitVecVal(1, width), BitVecVal(0, width))
    return expr


def _match_bv_widths(lhs, rhs):
    """Coerce BoolRef to BitVec if needed, then zero-extend the narrower operand (Verilog semantics)."""
    # Fast path: both are BitVecRef with same width (most common case)
    if isinstance(lhs, BitVecRef) and isinstance(rhs, BitVecRef):
        lw, rw = lhs.size(), rhs.size()
        if lw == rw:
            return lhs, rhs
        if lw < rw:
            return z3.ZeroExt(rw - lw, lhs), rhs
        return lhs, z3.ZeroExt(lw - rw, rhs)

    # Convert BoolRef operands to 1-bit BitVec so they can participate in bitwise ops
    lhs_is_bool = isinstance(lhs, BoolRef) and not isinstance(lhs, BitVecRef)
    rhs_is_bool = isinstance(rhs, BoolRef) and not isinstance(rhs, BitVecRef)

    if lhs_is_bool and rhs_is_bool:
        return lhs, rhs

    if lhs_is_bool:
        target_w = rhs.size() if isinstance(rhs, BitVecRef) else 1
        lhs = _bool_to_bv(lhs, target_w)
    elif rhs_is_bool:
        target_w = lhs.size() if isinstance(lhs, BitVecRef) else 1
        rhs = _bool_to_bv(rhs, target_w)

    # Reconcile BitVec widths after bool coercion
    if isinstance(lhs, BitVecRef) and isinstance(rhs, BitVecRef):
        lw, rw = lhs.size(), rhs.size()
        if lw < rw:
            lhs = z3.ZeroExt(rw - lw, lhs)
        elif rw < lw:
            rhs = z3.ZeroExt(lw - rw, rhs)
    return lhs, rhs


def parse_verilog_literal(val_str: str):
    """Parse Verilog-style literals like 1'b0, 32'd5, 8'hFF and return (value, bit_width).

    Returns (int_value, bit_width) if it's a valid Verilog literal, or (None, None) if not.
    Also handles plain decimal strings like "0", "123".
    """
    if val_str is None:
        return None, None

    val_str = str(val_str).strip()

    # Handle plain decimal integers
    if val_str.isdigit():
        return int(val_str), 32

    # Handle negative integers
    if val_str.startswith('-') and val_str[1:].isdigit():
        return int(val_str), 32

    # Handle Verilog-style literals: [size]'[base][value]
    # Examples: 1'b0, 32'd5, 8'hFF, 'b0, 'd10
    match = re.match(r"(\d*)'([bBdDhHoO])([0-9a-fA-F_xXzZ]+)", val_str)
    if match:
        size_str, base_char, num_str = match.groups()
        bit_width = int(size_str) if size_str else 32

        # Remove underscores (Verilog allows them for readability)
        num_str = num_str.replace('_', '')

        # Handle x and z as 0 for now (unknown/high-impedance)
        if 'x' in num_str.lower() or 'z' in num_str.lower():
            return 0, bit_width

        base_char = base_char.lower()
        if base_char == 'b':
            return int(num_str, 2), bit_width
        elif base_char == 'd':
            return int(num_str, 10), bit_width
        elif base_char == 'h':
            return int(num_str, 16), bit_width
        elif base_char == 'o':
            return int(num_str, 8), bit_width

    return None, None


def is_verilog_literal(val_str: str) -> bool:
    """Check if a string is a Verilog literal (including plain decimals)."""
    val, _ = parse_verilog_literal(val_str)
    return val is not None


def parse_infix_expr_to_z3(expr_str: str, s, m):
    """Parse an infix expression string like '(0  +  1)' to a Z3 expression.

    This handles expression strings stored in the symbolic store that represent
    computed values like '(0  +  1)', '(x  +  y)', etc.

    Returns a Z3 expression if parsing succeeds, or None if it fails.
    """
    if expr_str is None:
        return None

    expr_str = str(expr_str).strip()

    # First, try to parse as a simple Verilog literal
    lit_val, _ = parse_verilog_literal(expr_str)
    if lit_val is not None:
        return BitVecVal(lit_val, 32)

    # Check if it's a parenthesized expression like '(0  +  1)'
    if expr_str.startswith('(') and expr_str.endswith(')'):
        inner = expr_str[1:-1].strip()

        # Try to find binary operators: +, -, *, /, <=, >=, <, >, ==, !=, &, |, ^
        # We need to handle operators carefully to avoid splitting on wrong positions
        operators = [' + ', ' - ', ' * ', ' / ', ' <= ', ' >= ', ' < ', ' > ',
                     ' == ', ' != ', ' & ', ' | ', ' ^ ', ' << ', ' >> ']

        for op in operators:
            # Find the operator (handle nested parentheses)
            depth = 0
            for i in range(len(inner)):
                if inner[i] == '(':
                    depth += 1
                elif inner[i] == ')':
                    depth -= 1
                elif depth == 0 and inner[i:].startswith(op):
                    lhs_str = inner[:i].strip()
                    rhs_str = inner[i + len(op):].strip()

                    # Recursively parse left and right operands
                    lhs = parse_infix_expr_to_z3(lhs_str, s, m)
                    rhs = parse_infix_expr_to_z3(rhs_str, s, m)

                    if lhs is None or rhs is None:
                        continue

                    lhs, rhs = _match_bv_widths(lhs, rhs)

                    # Apply the operator
                    op_stripped = op.strip()
                    if op_stripped == '+':
                        return lhs + rhs
                    elif op_stripped == '-':
                        return lhs - rhs
                    elif op_stripped == '*':
                        return lhs * rhs
                    elif op_stripped == '/':
                        return z3.UDiv(lhs, rhs)
                    elif op_stripped == '<=':
                        return z3.ULE(lhs, rhs)
                    elif op_stripped == '>=':
                        return z3.UGE(lhs, rhs)
                    elif op_stripped == '<':
                        return ULT(lhs, rhs)
                    elif op_stripped == '>':
                        return UGT(lhs, rhs)
                    elif op_stripped == '==':
                        return lhs == rhs
                    elif op_stripped == '!=':
                        return lhs != rhs
                    elif op_stripped == '&':
                        return lhs & rhs
                    elif op_stripped == '|':
                        return lhs | rhs
                    elif op_stripped == '^':
                        return lhs ^ rhs
                    elif op_stripped == '<<':
                        return lhs << rhs
                    elif op_stripped == '>>':
                        return z3.LShR(lhs, rhs)

    # If it's a variable name, look it up in the store or create a symbolic variable
    if m is not None and s is not None:
        module_name = m.curr_module
        if module_name in s.store and expr_str in s.store[module_name]:
            sym_val = s.store[module_name][expr_str]
            # Avoid infinite recursion - if the stored value is the same, return a BitVec
            if sym_val != expr_str:
                return parse_infix_expr_to_z3(sym_val, s, m)
    elif m is None and isinstance(s, dict) and expr_str in s:
        # Flat store dict passed directly (e.g., from milestone checking)
        sym_val = s[expr_str]
        if sym_val != expr_str:
            return parse_infix_expr_to_z3(sym_val, s, m)

    # Return None to indicate we couldn't parse it (caller will create a BitVec)
    return None


BINARY_OPS = ("Plus", "Minus", "Power", "Times", "Divide", "Mod", "Sll", "Srl", "Sla", "Sra", "LessThan",
"GreaterThan", "LessEq", "GreaterEq", "Eq", "NotEq", "Eql", "NotEql", "And", "Xor",
"Xnor", "Or", "Land", "Lor")
op_map = {"Plus": "+", "Minus": "-", "Power": "**", "Times": "*", "Divide": "/", "Mod": "%", "Sll": "<<", "Srl": ">>>",
"Sra": ">>", "LessThan": "<", "GreaterThan": ">", "LessEq": "<=", "GreaterEq": ">=", "Eq": "=", "NotEq": "!=", "Eql": "===", "NotEql": "!==",
"And": "&", "Xor": "^", "Xnor": "<->", "Land": "&&", "Lor": "||"}

class Z3Visitor():
    def __init__(self, prefix):
        """Constructor that sets the prefix for variable names."""
        self.prefix = prefix
        print("prefix", prefix)
        #self.visited_nodes = set() 

    def visit(self, node):
        """A visitor that processes the node to generate Z3 expressions."""
        print(f"Visiting node: {node}") 
        print(f"Visiting node Type: {type(node)}")  
        if isinstance(node, ps.Token):
            result = self.handle_token(node)
        elif isinstance(node, ps.IdentifierNameSyntax):
            result = self.handle_identifier(node)
        elif isinstance(node, ps.IdentifierSelectNameSyntax):
            result = self.handle_identifier_select_name(node)
        elif isinstance(node, ps.ElementSelectSyntax):
            result = self.handle_element_select(node)
        elif isinstance(node, ps.BinaryExpressionSyntax):
            result = self.handle_binary_expression(node)
        elif isinstance(node, ps.ParenthesizedExpressionSyntax):
            result = self.handle_parenthesized_expression(node)
            print("result", type(result))
        elif isinstance(node, ps.LiteralExpressionSyntax):
            result = self.handle_literal_expression(node)
        elif isinstance(node, ps.BitSelectSyntax):
            result = self.handle_bit_select(node)
        elif isinstance(node, ps.ScopedNameSyntax):
            result = self.handle_scoped_name(node)
        elif isinstance(node, ps.IntegerVectorExpressionSyntax):
            result = self.handle_integer_vector_expression(node)
        elif isinstance(node, ps.PrefixUnaryExpressionSyntax):
            result = self.handle_prefix_unary_expression(node)
        else:
            print(f"Unhandled syntax: {type(node)}")
            return None
        print(result)
        if isinstance(result, ps.VisitAction):
            print(f"Encountered VisitAction: {result}")
            return None  
        return result

    def handle_integer_vector_expression(self, node):
        """Handle integer vector expressions."""
        print(f"Handling IntegerVectorExpression: {node}")
        
        print("Attributes of the node:", dir(node))

        if hasattr(node, 'value'):
            value = node.value  
            print(f"Value of the IntegerVectorExpression: {value}")
            return BitVecVal(int(str(value)), 32)  #

        elif hasattr(node, 'size'):
            size = node.size 
            print(f"Size of the IntegerVectorExpression: {size}")
            return BitVecVal(int(str(size)), 32)  
        return None   

    def handle_identifier(self, node):
        """Handle identifiers."""
        print(f"Handling identifier: {str(node.identifier)}")
        variable = str(node.identifier)
        return BitVec(variable, 32)
    
    def handle_identifier_select_name(self, node):
        """Handle indexed or array accesses like 'match[i]'."""
        print(f"Handling identifier select: {str(node.identifier)}[{node.selectors}]")
        
        # Extract the identifier ('match' or 'conf_i')
        identifier = str(node.identifier)
        
        # Get the index, assuming it's the first selector for example  'match[i]', i will be the selector)
        index_expr = self.visit(node.selectors[0])  
        print("index_expr",type(index_expr))
        index_val = int(str(index_expr))  
        variable = f"{identifier}[{index_val}]" 
        print("Fully Verified Variable:", variable)
        return BitVec(variable, 32)
 
    def handle_scoped_name(self, node):
            """Handle scoped names, including indexed names like conf_i[i].locked."""
            print(f"Handling scoped name: {node}")
            
            if str(node.separator) == "::":
                # Scoped names like riscv::PRIV_LVL_M
                scoped_name = str(node)
                return BitVec(scoped_name, 32)
            
            elif str(node.separator) == ".":
                # Field access like conf_i[i].locked
                # First, handle the base (conf_i[i])
                base = self.visit(node.left)  # Conf_i[i]
                print("base",base)
                # Then handle the field (locked)
                field = str(node.right)  # Field access (locked)
                variable= str(f"{base}[{field}]")
                return BitVec(variable, 32)

    def handle_element_select(self, node):
        """Handle element selection like structs and arrays."""
        print(f"Handling element select: {node}")
        element = self.visit(node.selector)  
        return element
    

    def handle_bit_select(self, node):
        """Handle bit select expressions like 'match[i]'."""
        print(f"Handling bit select expression: {node}")

       
        return BitVec(f"{node}", 32)

    def handle_literal_expression(self, node):
        """Handle literal expressions."""
        print(f"Handling literal expression: {node}")
        literal_value = node  
        if literal_value == 0:
            return BitVecVal(0, 32)  
        return BitVecVal(int(str(literal_value)), 32)  

    def convert_bitvec_to_bool(self, bitvec_expr):
        """Converts a BitVec expression to a Boolean (True if non-zero, False if zero)."""
        return UGT(bitvec_expr, BitVecVal(0, 32))

    def handle_prefix_unary_expression(self, node):
        """Handle prefix unary expressions (like NOT)."""
        print(f"Handling prefix unary expression: {node}")
        operator = str(node.operatorToken).strip()
        operand = self.visit(node.operand)
        if operator == "!":
            return Not(operand)
        elif operator == "-":
            return -operand
        else:
            print(f"Unsupported unary operator: {operator}")
            raise ValueError(f"Unsupported unary operator: {operator}")


    def handle_binary_expression(self, node):
        """Handle binary expressions (AND, OR, equality, etc.)."""
        print(f"Handling binary expression: {node.operatorToken}")
        left_expr = self.visit(node.left)
        print("done")
        right_expr = self.visit(node.right)
        print("done2")
        operator = str(node.operatorToken).strip()

        # issue
        print((left_expr))
        print(node.left)
        if z3.is_bool(left_expr) and not z3.is_bool(right_expr):
            right_expr = UGT(right_expr, BitVecVal(0, 32)) 
            print(f"Converted Right Expression to Bool: {right_expr}")

        print(operator)
        print(node.left)
        print(node.right)
        print(left_expr.sort())
        print(right_expr.sort())
        if operator == "==":
            return left_expr == right_expr
        elif operator == "!=":
            return left_expr != right_expr
        elif operator == "&&":
            return And(left_expr, right_expr)
        elif operator == "||":
            return Or(left_expr, right_expr)
        elif operator == ">":
            return UGT(left_expr, right_expr) 
        elif operator == "<":
            return ULT(left_expr, right_expr) 
        elif isinstance(left_expr, BitVecRef) and isinstance(right_expr, BitVecRef):
            return UGT(left_expr, BitVecVal(0, 32)) == right_expr
        
        else:
            print(f"Unsupported binary operator: {operator}")
            raise ValueError(f"Unsupported binary operator: {operator}")


    def handle_parenthesized_expression(self, node):
        """Handle parenthesized expressions."""
        print("Handling parenthesized expression.")
        return (self.visit(node.expression))
    
    def get_full_variable_name(self,variable):
        """Generate the full variable name by appending the variable to the prefix."""
        return f"{self.prefix}.{variable}"
    
def pyslang_to_z3(expr, prefix=""):
    """Parse the expression and convert it into a Z3 expression."""
    print(f"Parsing expression: {expr}")
    syntax_tree = ps.SyntaxTree.fromText(expr)
    root = syntax_tree.root
    visitor = Z3Visitor(prefix)
    z3_expression = visitor.visit(root)    
    return z3_expression


def get_constants_list(new_constraint, s: SymbolicState, m: ExecutionManager):
    """Get list of constants that need to be added to z3 context from symbolic expressions."""
    res = []
    words = new_constraint.split(" ")
    for word in words:
        if word in s.store[m.curr_module].values():
            res.append(word)
    return res

def parse_concat_to_Z3(concat, s: SymbolicState, m: ExecutionManager):
    """Takes a concatenation of symbolic symbols areturns the list of bitvectors"""
    res = []
    for key in concat:
        x = BitVec(concat[key], 1)
        res.append(x)
    return res


_BINARY_OP_DISPATCH = {
    ps.BinaryOperator.LessThanEqual:      lambda l, r: z3.ULE(l, r),
    ps.BinaryOperator.LessThan:           lambda l, r: ULT(l, r),
    ps.BinaryOperator.GreaterThanEqual:   lambda l, r: z3.UGE(l, r),
    ps.BinaryOperator.GreaterThan:        lambda l, r: UGT(l, r),
    ps.BinaryOperator.Equality:           lambda l, r: l == r,
    ps.BinaryOperator.CaseEquality:       lambda l, r: l == r,
    ps.BinaryOperator.Inequality:         lambda l, r: l != r,
    ps.BinaryOperator.CaseInequality:     lambda l, r: l != r,
    ps.BinaryOperator.Add:                lambda l, r: l + r,
    ps.BinaryOperator.Subtract:           lambda l, r: l - r,
    ps.BinaryOperator.Multiply:           lambda l, r: l * r,
    ps.BinaryOperator.Divide:             lambda l, r: z3.UDiv(l, r),
    ps.BinaryOperator.Mod:                lambda l, r: z3.URem(l, r),
    ps.BinaryOperator.BinaryAnd:          lambda l, r: l & r,
    ps.BinaryOperator.BinaryOr:           lambda l, r: l | r,
    ps.BinaryOperator.BinaryXor:          lambda l, r: l ^ r,
    ps.BinaryOperator.LogicalShiftLeft:   lambda l, r: l << r,
    ps.BinaryOperator.LogicalShiftRight:  lambda l, r: z3.LShR(l, r),
    ps.BinaryOperator.ArithmeticShiftLeft:  lambda l, r: l << r,
    ps.BinaryOperator.ArithmeticShiftRight: lambda l, r: l >> r,
}

def _kind_binary_op(e, s, m):
    from helpers.debug import debug_print
    lhs = parse_expr_to_Z3(e.left, s, m)
    rhs = parse_expr_to_Z3(e.right, s, m)
    op = e.op if hasattr(e, 'op') else None
    lhs, rhs = _match_bv_widths(lhs, rhs)
    # Fast path: direct enum dispatch (no str() conversion)
    if op is not None:
        handler = _BINARY_OP_DISPATCH.get(op)
        if handler is not None:
            return handler(lhs, rhs)
        # LogicalAnd / LogicalOr need bool coercion
        if op == ps.BinaryOperator.LogicalAnd:
            lhs_bool = lhs != BitVecVal(0, 32) if hasattr(lhs, 'size') else lhs
            rhs_bool = rhs != BitVecVal(0, 32) if hasattr(rhs, 'size') else rhs
            return And(lhs_bool, rhs_bool)
        if op == ps.BinaryOperator.LogicalOr:
            lhs_bool = lhs != BitVecVal(0, 32) if hasattr(lhs, 'size') else lhs
            rhs_bool = rhs != BitVecVal(0, 32) if hasattr(rhs, 'size') else rhs
            return Or(lhs_bool, rhs_bool)
    print(f"[Warning] Unhandled binary operator: {op}")
    return BitVecVal(0, 32)


def _kind_named_value(e, s, m):
    from helpers.debug import debug_print, DEBUG_ENABLED
    symbol = getattr(e, 'symbol', None)
    if symbol is not None:
        var_name = symbol.name
        module_name = m.curr_module
        if DEBUG_ENABLED:
            debug_print("NamedValue", f"var_name={var_name}, module={module_name}, store keys={list(s.store.get(module_name, {}).keys())}")
        if module_name in s.store and var_name in s.store[module_name]:
            sym_val = s.store[module_name][var_name]
            if isinstance(sym_val, str):
                parsed_z3 = parse_infix_expr_to_z3(sym_val, s, m)
                if parsed_z3 is not None:
                    return parsed_z3
                else:
                    return BitVec(sym_val, 32)
            else:
                return sym_val
        else:
            return BitVec(var_name, 32)
    return BitVecVal(0, 32)


def _kind_integer_literal(e, s, m):
    from helpers.debug import debug_print, DEBUG_ENABLED
    val = getattr(e, 'value', 0)
    if hasattr(val, 'value'):
        val = val.value
    if DEBUG_ENABLED:
        debug_print("IntegerLiteral", f"val={val}")
    return BitVecVal(int(val), 32)


def _kind_conversion(e, s, m):
    operand = getattr(e, 'operand', None)
    if operand is not None:
        return parse_expr_to_Z3(operand, s, m)
    return BitVecVal(0, 32)


def _kind_unary_op(e, s, m):
    operand = parse_expr_to_Z3(e.operand, s, m)
    op = e.op if hasattr(e, 'op') else None
    if op == ps.UnaryOperator.LogicalNot:
        if hasattr(operand, 'size'):
            return operand == BitVecVal(0, 32)
        return Not(operand)
    elif op == ps.UnaryOperator.BitwiseNot:
        return ~operand
    elif op == ps.UnaryOperator.Minus:
        return -operand
    elif op == ps.UnaryOperator.Plus:
        return operand
    else:
        print(f"[Warning] Unhandled unary operator: {op}")
        return BitVecVal(0, 32)


def _kind_concatenation(e, s, m):
    operands = list(e.operands)
    if not operands:
        return BitVecVal(0, 32)
    parts = [parse_expr_to_Z3(op, s, m) for op in operands]
    sized_parts = []
    for i, (part, op) in enumerate(zip(parts, operands)):
        width = 32
        if hasattr(op, 'type') and hasattr(op.type, 'getBitVectorRange'):
            try:
                bvr = op.type.getBitVectorRange()
                width = bvr.width
            except Exception:
                pass
        elif hasattr(op, 'type') and hasattr(op.type, 'bitWidth'):
            width = op.type.bitWidth
        if hasattr(part, 'size'):
            cur_size = part.size()
            if cur_size > width:
                part = z3.Extract(width - 1, 0, part)
            elif cur_size < width:
                part = z3.ZeroExt(width - cur_size, part)
        sized_parts.append(part)
    result = sized_parts[0]
    for p in sized_parts[1:]:
        result = z3.Concat(result, p)
    if hasattr(result, 'size') and result.size() < 32:
        result = z3.ZeroExt(32 - result.size(), result)
    elif hasattr(result, 'size') and result.size() > 32:
        result = z3.Extract(31, 0, result)
    return result


def _kind_range_select(e, s, m):
    base = parse_expr_to_Z3(e.value, s, m)
    left_val = parse_expr_to_Z3(e.left, s, m)
    right_val = parse_expr_to_Z3(e.right, s, m)
    try:
        msb = left_val.as_long() if hasattr(left_val, 'as_long') else int(str(left_val))
        lsb = right_val.as_long() if hasattr(right_val, 'as_long') else int(str(right_val))
    except (ValueError, z3.Z3Exception):
        return BitVecVal(0, 32)
    if hasattr(base, 'size'):
        bw = base.size()
        if msb >= bw:
            msb = bw - 1
        if lsb < 0:
            lsb = 0
        return z3.Extract(msb, lsb, base)
    return BitVecVal(0, 32)


def _kind_element_select(e, s, m):
    base = parse_expr_to_Z3(e.value, s, m)
    selector = parse_expr_to_Z3(e.selector, s, m)
    try:
        idx = selector.as_long() if hasattr(selector, 'as_long') else int(str(selector))
    except (ValueError, z3.Z3Exception):
        return BitVecVal(0, 32)
    if hasattr(base, 'size'):
        bw = base.size()
        if idx < bw:
            bit = z3.Extract(idx, idx, base)
            return z3.ZeroExt(31, bit)
    return BitVecVal(0, 32)


def _kind_replication(e, s, m):
    count_expr = e.count
    concat_expr = e.concat
    try:
        count = count_expr.value if hasattr(count_expr, 'value') else int(str(count_expr))
        if hasattr(count, 'value'):
            count = count.value
        count = int(count)
    except (ValueError, AttributeError):
        count = 1
    inner = parse_expr_to_Z3(concat_expr, s, m)
    if count <= 1:
        return inner
    if hasattr(concat_expr, 'type') and hasattr(concat_expr.type, 'bitWidth'):
        inner_width = concat_expr.type.bitWidth
    elif hasattr(inner, 'size'):
        inner_width = inner.size()
    else:
        inner_width = 32
    if hasattr(inner, 'size') and inner.size() != inner_width:
        if inner.size() > inner_width:
            inner = z3.Extract(inner_width - 1, 0, inner)
        else:
            inner = z3.ZeroExt(inner_width - inner.size(), inner)
    result = inner
    for _ in range(count - 1):
        result = z3.Concat(result, inner)
    total_width = inner_width * count
    if total_width < 32:
        result = z3.ZeroExt(32 - total_width, result)
    elif total_width > 32:
        result = z3.Extract(31, 0, result)
    return result


def _syntax_parenthesized(e, s, m):
    from helpers.debug import debug_print, DEBUG_ENABLED
    inner_expr = getattr(e, 'expression', None)
    if inner_expr is not None:
        if DEBUG_ENABLED:
            debug_print("ParenthesizedExpressionSyntax", f"unwrapping to: {inner_expr}")
        return parse_expr_to_Z3(inner_expr, s, m)
    return BitVecVal(0, 32)


def _syntax_binary_expression(e, s, m):
    from helpers.debug import debug_print, DEBUG_ENABLED
    lhs = parse_expr_to_Z3(e.left, s, m)
    rhs = parse_expr_to_Z3(e.right, s, m)
    op_token = str(getattr(e, 'operatorToken', ''))
    if DEBUG_ENABLED:
        debug_print("BinaryExpressionSyntax", f"lhs={lhs}, rhs={rhs}, op_token={op_token}")
    lhs, rhs = _match_bv_widths(lhs, rhs)
    if "<=" in op_token:
        return z3.ULE(lhs, rhs)
    elif ">=" in op_token:
        return z3.UGE(lhs, rhs)
    elif "<" in op_token and "=" not in op_token:
        return ULT(lhs, rhs)
    elif ">" in op_token and "=" not in op_token:
        return UGT(lhs, rhs)
    elif "==" in op_token:
        return lhs == rhs
    elif "!=" in op_token:
        return lhs != rhs
    elif "+" in op_token:
        return lhs + rhs
    elif "-" in op_token:
        return lhs - rhs
    elif "*" in op_token:
        return lhs * rhs
    elif "/" in op_token:
        return z3.UDiv(lhs, rhs)
    elif "%" in op_token:
        return z3.URem(lhs, rhs)
    elif "&&" in op_token:
        lhs_bool = lhs != BitVecVal(0, lhs.size()) if hasattr(lhs, 'size') else lhs
        rhs_bool = rhs != BitVecVal(0, rhs.size()) if hasattr(rhs, 'size') else rhs
        return And(lhs_bool, rhs_bool)
    elif "||" in op_token:
        lhs_bool = lhs != BitVecVal(0, lhs.size()) if hasattr(lhs, 'size') else lhs
        rhs_bool = rhs != BitVecVal(0, rhs.size()) if hasattr(rhs, 'size') else rhs
        return Or(lhs_bool, rhs_bool)
    elif "&" in op_token:
        return lhs & rhs
    elif "|" in op_token:
        return lhs | rhs
    elif "^" in op_token:
        return lhs ^ rhs
    elif "<<" in op_token:
        return lhs << rhs
    elif ">>" in op_token:
        return z3.LShR(lhs, rhs)
    else:
        print(f"[Warning] Unhandled binary operator token: {op_token}")
        return BitVecVal(0, 32)


def _syntax_literal_expression(e, s, m):
    literal_token = getattr(e, 'literal', None)
    if literal_token is not None:
        val_str = str(literal_token)
        try:
            if "'" in val_str:
                parts = val_str.split("'")
                base_char = parts[1][0] if len(parts[1]) > 0 else 'd'
                num_str = parts[1][1:].replace('_', '') if len(parts[1]) > 1 else '0'
                if base_char == 'd':
                    return BitVecVal(int(num_str), 32)
                elif base_char == 'h':
                    return BitVecVal(int(num_str, 16), 32)
                elif base_char == 'b':
                    return BitVecVal(int(num_str, 2), 32)
                elif base_char == 'o':
                    return BitVecVal(int(num_str, 8), 32)
            else:
                return BitVecVal(int(val_str), 32)
        except ValueError:
            print(f"[Warning] Could not parse literal: {val_str}")
            return BitVecVal(0, 32)
    return BitVecVal(0, 32)


def _syntax_integer_vector(e, s, m):
    literal_token = getattr(e, 'literal', None)
    if literal_token is not None:
        val_str = str(literal_token)
        try:
            if "'" in val_str:
                parts = val_str.split("'")
                try:
                    declared_width = int(parts[0])
                except (ValueError, TypeError):
                    declared_width = 32
                base_char = parts[1][0] if len(parts[1]) > 0 else 'd'
                num_str = parts[1][1:].replace('_', '') if len(parts[1]) > 1 else '0'
                if base_char == 'd':
                    return BitVecVal(int(num_str), declared_width)
                elif base_char == 'h':
                    return BitVecVal(int(num_str, 16), declared_width)
                elif base_char == 'b':
                    return BitVecVal(int(num_str, 2), declared_width)
                elif base_char == 'o':
                    return BitVecVal(int(num_str, 8), declared_width)
            else:
                return BitVecVal(int(val_str), 32)
        except ValueError:
            print(f"[Warning] Could not parse literal: {val_str}")
            return BitVecVal(0, 32)
    if hasattr(e, 'size') and hasattr(e, 'value'):
        try:
            width = int(str(e.size))
            val_str = str(e.value).replace('_', '')
            full_str = str(e).strip()
            if "'" in full_str:
                base_char = full_str.split("'")[1][0].lower() if len(full_str.split("'")[1]) > 0 else 'd'
                if base_char == 'h':
                    return BitVecVal(int(val_str, 16), width)
                elif base_char == 'b':
                    return BitVecVal(int(val_str, 2), width)
                elif base_char == 'o':
                    return BitVecVal(int(val_str, 8), width)
                else:
                    return BitVecVal(int(val_str), width)
            else:
                return BitVecVal(int(val_str), width)
        except (ValueError, TypeError):
            pass
    return BitVecVal(0, 32)


def _syntax_identifier_name(e, s, m):
    module_name = m.curr_module
    if not hasattr(e, "identifier"):
        var_name = getattr(e, "valueText", getattr(e, "name", None))
        if var_name is None:
            return BitVecVal(0, 32)
    else:
        var_name = e.identifier.valueText if hasattr(e.identifier, "valueText") else None
        if var_name is None:
            var_name = getattr(e.identifier, "name", None)
    if var_name is None:
        return BitVecVal(0, 32)
    if module_name not in s.store or var_name not in s.store[module_name]:
        return BitVecVal(0, 32)
    sym_val = s.store[module_name][var_name]
    if isinstance(sym_val, str):
        parsed_z3 = parse_infix_expr_to_z3(sym_val, s, m)
        if parsed_z3 is not None:
            return parsed_z3
        else:
            return BitVec(sym_val, 32)
    else:
        return sym_val


def _syntax_integer_literal_expr(e, s, m):
    int_val = IntVal(e.value)
    return Int2BV(int_val, 32)


def _syntax_identifier_select(e, s, m):
    module_name = m.curr_module
    base_name = None
    if hasattr(e, 'identifier'):
        base_name = getattr(e.identifier, 'valueText', getattr(e.identifier, 'value', str(e.identifier)))
    idx_str = None
    is_range = False
    range_msb = None
    range_lsb = None
    if hasattr(e, 'selectors'):
        for sel in e.selectors:
            inner = getattr(sel, 'selector', getattr(sel, 'expr', getattr(sel, 'expression', None)))
            if inner is not None:
                if inner.__class__.__name__ == 'RangeSelectSyntax':
                    is_range = True
                    left_tok = getattr(inner, 'left', None)
                    right_tok = getattr(inner, 'right', None)
                    if left_tok is not None and right_tok is not None:
                        try:
                            range_msb = int(str(getattr(left_tok, 'value', getattr(left_tok, 'valueText', left_tok))))
                            range_lsb = int(str(getattr(right_tok, 'value', getattr(right_tok, 'valueText', right_tok))))
                        except (ValueError, TypeError):
                            pass
                    idx_str = f"{range_msb}:{range_lsb}" if range_msb is not None else str(inner)
                else:
                    inner_val = getattr(inner, 'value', getattr(inner, 'valueText', None))
                    if inner_val is not None:
                        idx_str = str(inner_val)
                    else:
                        lit = getattr(inner, 'literal', None)
                        if lit is not None:
                            idx_str = str(getattr(lit, 'value', lit))
                        else:
                            idx_str = str(inner)
    if base_name and idx_str is not None:
        if is_range and range_msb is not None and range_lsb is not None:
            if module_name in s.store and base_name in s.store[module_name]:
                sym_val = s.store[module_name][base_name]
                if isinstance(sym_val, str):
                    lit_val, lit_width = parse_verilog_literal(sym_val)
                    if lit_val is not None:
                        mask = ((1 << (range_msb - range_lsb + 1)) - 1)
                        extracted = (lit_val >> range_lsb) & mask
                        return BitVecVal(extracted, range_msb - range_lsb + 1)
                    return BitVec(f"{sym_val}[{range_msb}:{range_lsb}]", range_msb - range_lsb + 1)
                elif hasattr(sym_val, 'size'):
                    bv_size = sym_val.size()
                    actual_msb = min(range_msb, bv_size - 1)
                    return z3.Extract(actual_msb, range_lsb, sym_val)
            return BitVecVal(0, range_msb - range_lsb + 1)
        full_name = f"{base_name}[{idx_str}]"
        if module_name in s.store and full_name in s.store[module_name]:
            sym_val = s.store[module_name][full_name]
            if isinstance(sym_val, str):
                lit_val, lit_width = parse_verilog_literal(sym_val)
                if lit_val is not None:
                    return BitVecVal(lit_val, 32)
                return BitVec(sym_val, 32)
            return sym_val
        elif module_name in s.store and base_name in s.store[module_name]:
            sym_val = s.store[module_name][base_name]
            try:
                idx_int = int(idx_str)
            except (ValueError, TypeError):
                idx_int = None
            if isinstance(sym_val, str):
                lit_val, lit_width = parse_verilog_literal(sym_val)
                if lit_val is not None:
                    if idx_int is not None:
                        bit = (lit_val >> idx_int) & 1
                        return BitVecVal(bit, 32)
                    return BitVecVal(lit_val, 32)
                return BitVec(f"{sym_val}[{idx_str}]", 32)
            elif hasattr(sym_val, 'size') and idx_int is not None:
                bv_size = sym_val.size()
                if idx_int < bv_size:
                    bit = z3.Extract(idx_int, idx_int, sym_val)
                    return z3.ZeroExt(31, bit)
                else:
                    return BitVecVal(0, 32)
            return sym_val
        else:
            return BitVec(full_name, 32)
    return BitVecVal(0, 32)


def _syntax_multiple_concat(e, s, m):
    count_expr = getattr(e, 'expression', None)
    concatenation = getattr(e, 'concatenation', None)
    count_val = 1
    if count_expr is not None:
        count_raw = getattr(count_expr, 'value', getattr(count_expr, 'literal', None))
        if count_raw is not None:
            count_raw = getattr(count_raw, 'value', count_raw)
            try:
                count_val = int(str(count_raw))
            except (ValueError, TypeError):
                count_val = 32
    if concatenation is not None:
        inner_exprs = getattr(concatenation, 'expressions', getattr(concatenation, 'items', None))
        if inner_exprs:
            inner_val = 0
            inner_bits = 1
            for inner_e in inner_exprs:
                if hasattr(inner_e, 'literal'):
                    lit_str = str(getattr(inner_e.literal, 'value', inner_e.literal))
                    lit_val, lit_width = parse_verilog_literal(lit_str)
                    if lit_val is not None:
                        inner_val = lit_val
                        inner_bits = lit_width if lit_width else 1
            result_val = 0
            for i in range(count_val):
                result_val = (result_val << inner_bits) | (inner_val & ((1 << inner_bits) - 1))
            return BitVecVal(result_val, 32)
    return BitVecVal(0, 32)


def _syntax_concatenation(e, s, m):
    expressions = getattr(e, 'expressions', getattr(e, 'items', []))
    if not expressions:
        return BitVecVal(0, 32)
    parts = []
    for sub_expr in expressions:
        if sub_expr.__class__.__name__ == "Token":
            continue
        part_z3 = parse_expr_to_Z3(sub_expr, s, m)
        if isinstance(part_z3, BoolRef) and not isinstance(part_z3, BitVecRef):
            part_z3 = _bool_to_bv(part_z3, 1)
        elif not isinstance(part_z3, BitVecRef):
            try:
                part_z3 = BitVecVal(int(part_z3), 32)
            except (TypeError, ValueError):
                part_z3 = BitVecVal(0, 32)
        parts.append(part_z3)
    if len(parts) == 0:
        return BitVecVal(0, 32)
    if len(parts) == 1:
        return parts[0]
    result = parts[0]
    for p in parts[1:]:
        result = z3.Concat(result, p)
    result_size = result.size() if hasattr(result, 'size') else 32
    if result_size > 32:
        result = z3.Extract(31, 0, result)
    elif result_size < 32:
        result = z3.ZeroExt(32 - result_size, result)
    return result


def _syntax_token(e, s, m):
    return BitVecVal(0, 32)


def _syntax_prefix_unary(e, s, m):
    operand_node = getattr(e, 'operand', None)
    if operand_node is None:
        return BitVecVal(0, 32)
    operand = parse_expr_to_Z3(operand_node, s, m)
    op_token = getattr(e, 'operatorToken', getattr(e, 'operator', None))
    op_str = str(getattr(op_token, 'valueText', getattr(op_token, 'kind', ''))) if op_token else ''
    if '!' in op_str or 'Not' in op_str or 'LogicalNot' in str(getattr(e, 'kind', '')):
        if hasattr(operand, 'size'):
            return operand == BitVecVal(0, operand.size())
        return Not(operand)
    elif '~' in op_str or 'BitwiseNot' in str(getattr(e, 'kind', '')):
        return ~operand
    elif '-' in op_str and '+' not in op_str:
        return -operand
    else:
        if hasattr(operand, 'size'):
            return operand == BitVecVal(0, operand.size())
        return Not(operand)


def _syntax_conditional_pattern(e, s, m):
    expr = getattr(e, 'expr', getattr(e, 'expression', None))
    if expr is not None:
        return parse_expr_to_Z3(expr, s, m)
    return BitVecVal(0, 32)



# ---------------------------------------------------------------------------
# Dispatch tables (built after all handler functions are defined)
# ---------------------------------------------------------------------------
_KIND_DISPATCH = None  # populated below after ps is imported at module level

def _build_dispatch_tables():
    global _KIND_DISPATCH
    _KIND_DISPATCH = {
        ps.ExpressionKind.BinaryOp:       _kind_binary_op,
        ps.ExpressionKind.NamedValue:     _kind_named_value,
        ps.ExpressionKind.IntegerLiteral: _kind_integer_literal,
        ps.ExpressionKind.Conversion:     _kind_conversion,
        ps.ExpressionKind.UnaryOp:        _kind_unary_op,
        ps.ExpressionKind.Concatenation:  _kind_concatenation,
        ps.ExpressionKind.RangeSelect:    _kind_range_select,
        ps.ExpressionKind.ElementSelect:  _kind_element_select,
        ps.ExpressionKind.Replication:    _kind_replication,
    }

_SYNTAX_DISPATCH = {
    "ParenthesizedExpressionSyntax":        _syntax_parenthesized,
    "BinaryExpressionSyntax":               _syntax_binary_expression,
    "LiteralExpressionSyntax":              _syntax_literal_expression,
    "IntegerVectorExpressionSyntax":        _syntax_integer_vector,
    "IdentifierNameSyntax":                 _syntax_identifier_name,
    "IntegerLiteralExpressionSyntax":       _syntax_integer_literal_expr,
    "IdentifierSelectNameSyntax":           _syntax_identifier_select,
    "MultipleConcatenationExpressionSyntax": _syntax_multiple_concat,
    "ConcatenationExpressionSyntax":        _syntax_concatenation,
    "Token":                                _syntax_token,
    "PrefixUnaryExpressionSyntax":          _syntax_prefix_unary,
    "ConditionalPatternSyntax":             _syntax_conditional_pattern,
}


def parse_expr_to_Z3(e: ps.ExpressionSyntax, s: SymbolicState, m: ExecutionManager):
    """Converts a Verilog Expression to a Z3 expression.

    This function is a pure converter - it reads from the symbolic store
    but does NOT modify it. It also does NOT update the path condition.
    The caller (visit_stmt in slang_helpers.py) is responsible for
    adding the returned Z3 expression to the path condition.

    Args:
        e: PySlang expression syntax node
        s: SymbolicState (read-only access to store)
        m: ExecutionManager (read-only access to module context)

    Returns:
        Z3 expression (BitVecRef, BoolRef, etc.)
    """
    # Fast path 1: ExpressionKind dispatch (semantic elaborated nodes)
    kind = getattr(e, 'kind', None)
    if kind is not None:
        # Lazily build the kind dispatch table on first call
        global _KIND_DISPATCH
        if _KIND_DISPATCH is None:
            _build_dispatch_tables()
        handler = _KIND_DISPATCH.get(kind)
        if handler is not None:
            return handler(e, s, m)

    # Fast path 2: class name dispatch (syntax parse-tree nodes)
    class_name = e.__class__.__name__
    handler = _SYNTAX_DISPATCH.get(class_name)
    if handler is not None:
        return handler(e, s, m)

    # Slow fallback: legacy Z3 expression checks and SyntaxKind string matching
    return _fallback_dispatch(e, s, m)


def _fallback_dispatch(e, s, m):
    """Fallback handler for nodes not caught by the dispatch tables.

    Handles: Z3 native expressions (is_eq, is_and, is_app_of),
    SyntaxKind string-based dispatch, and any remaining class name checks.
    """
    from helpers.debug import debug_print
    from z3 import is_bool

    # Legacy handling for Z3 expressions and tokenized fallback
    tokens_list = parse_tokens(tokenize(e, s, m))
    new_constraint = evaluate_expr(tokens_list, s, m)
    new_constants = []
    if not new_constraint is None:
        new_constants = get_constants_list(new_constraint, s, m)
    if is_and(e):
        lhs = parse_expr_to_Z3(e.left, s, m)
        rhs = parse_expr_to_Z3(e.right, s, m)
        return And(lhs, rhs)
    elif is_app_of(e, Z3_OP_EXTRACT):
        part_sel_expr = f"{e.var.name}[{e.msb}:{e.lsb}]"
        module_name = m.curr_module
        is_reg = e.var.name in m.reg_decls
        if not e.var.scope is None:
            module_name = e.scope.labellist[0].name
        sym_val = s.store[module_name][e.var.name]
        lit_val, lit_width = parse_verilog_literal(sym_val)
        if lit_val is not None:
            int_val = IntVal(lit_val)
            return Int2BV(int_val, 32)
        else:
            if part_sel_expr in s.store[module_name]:
                sym_val = s.store[module_name][part_sel_expr]
            elif "[" in part_sel_expr:
                parts = part_sel_expr.partition("[")
                first_part = parts[0]
                sym_val = s.store[module_name].get(first_part, part_sel_expr)
            else:
                sym_val = part_sel_expr
            return BitVec(sym_val, 32)
    elif is_eq(e):
        lhs = parse_expr_to_Z3(e.left, s, m)
        rhs = parse_expr_to_Z3(e.right, s, m)
        lhs, rhs = _match_bv_widths(lhs, rhs)
        return (lhs == rhs)
    elif is_distinct(e):
        lhs = parse_expr_to_Z3(e.left, s, m)
        rhs = parse_expr_to_Z3(e.right, s, m)
        lhs, rhs = _match_bv_widths(lhs, rhs)
        if isinstance(rhs, z3.z3.BitVecRef) and not isinstance(lhs, z3.z3.BitVecRef):
            c = If(lhs, BitVecVal(1, 32), BitVecVal(0, 32))
            return (c != rhs)
        else:
            return (lhs != rhs)

    # SyntaxKind string-based dispatch (nodes that have .kind but it's a SyntaxKind)
    if hasattr(e, 'kind'):
        kind = e.kind
        kind_str = str(kind)

        if 'SyntaxKind' in kind_str:
            class_name = e.__class__.__name__
            if class_name == "PrefixUnaryExpressionSyntax":
                operand_node = getattr(e, 'operand', None)
                if operand_node is None:
                    return BitVecVal(0, 32)
                operand = parse_expr_to_Z3(operand_node, s, m)
                if 'LogicalNot' in kind_str:
                    if hasattr(operand, 'size'):
                        return operand == BitVecVal(0, operand.size())
                    return Not(operand)
                elif 'BitwiseNot' in kind_str:
                    return ~operand
                elif 'UnaryMinus' in kind_str:
                    return -operand
                else:
                    if hasattr(operand, 'size'):
                        return operand == BitVecVal(0, operand.size())
                    return Not(operand)

            elif class_name == "BinaryExpressionSyntax":
                lhs_node = getattr(e, 'left', None)
                rhs_node = getattr(e, 'right', None)
                if lhs_node is None or rhs_node is None:
                    return BitVecVal(0, 32)
                lhs = parse_expr_to_Z3(lhs_node, s, m)
                rhs = parse_expr_to_Z3(rhs_node, s, m)
                if 'LessThanEqual' in kind_str and m is not None and getattr(m, 'curr_module', '') == 'u_assert':
                    print(f"[LESSEQ-SYNTAX-DEBUG] lhs={lhs} rhs={rhs} kind_str={kind_str}")
                    print(f"[LESSEQ-SYNTAX-DEBUG]   lhs_node={lhs_node} type={type(lhs_node).__name__} kind={getattr(lhs_node, 'kind', '?')}")
                    print(f"[LESSEQ-SYNTAX-DEBUG]   rhs_node={rhs_node} type={type(rhs_node).__name__} kind={getattr(rhs_node, 'kind', '?')}")
                    if hasattr(rhs_node, 'value'):
                        print(f"[LESSEQ-SYNTAX-DEBUG]   rhs_node.value={rhs_node.value}")
                    if hasattr(rhs_node, 'literal'):
                        print(f"[LESSEQ-SYNTAX-DEBUG]   rhs_node.literal={rhs_node.literal} value={getattr(rhs_node.literal, 'value', 'N/A')}")
                    if hasattr(rhs_node, 'constantValue'):
                        print(f"[LESSEQ-SYNTAX-DEBUG]   rhs_node.constantValue={rhs_node.constantValue}")

                def _to_bv(x):
                    if hasattr(x, 'size'):
                        return x
                    if is_bool(x):
                        return If(x, BitVecVal(1, 32), BitVecVal(0, 32))
                    return BitVecVal(0, 32)

                if 'LogicalAnd' in kind_str:
                    lb = lhs != BitVecVal(0, lhs.size()) if hasattr(lhs, 'size') else lhs
                    rb = rhs != BitVecVal(0, rhs.size()) if hasattr(rhs, 'size') else rhs
                    return And(lb, rb)
                elif 'LogicalOr' in kind_str:
                    lb = lhs != BitVecVal(0, lhs.size()) if hasattr(lhs, 'size') else lhs
                    rb = rhs != BitVecVal(0, rhs.size()) if hasattr(rhs, 'size') else rhs
                    return Or(lb, rb)
                elif 'Equality' in kind_str:
                    return _to_bv(lhs) == _to_bv(rhs)
                elif 'Inequality' in kind_str:
                    return _to_bv(lhs) != _to_bv(rhs)
                elif 'GreaterThanEqual' in kind_str:
                    return UGE(_to_bv(lhs), _to_bv(rhs))
                elif 'GreaterThan' in kind_str:
                    return UGT(_to_bv(lhs), _to_bv(rhs))
                elif 'LessThanEqual' in kind_str:
                    return ULE(_to_bv(lhs), _to_bv(rhs))
                elif 'LessThan' in kind_str:
                    return ULT(_to_bv(lhs), _to_bv(rhs))
                elif 'Add' in kind_str:
                    return _to_bv(lhs) + _to_bv(rhs)
                elif 'Subtract' in kind_str:
                    return _to_bv(lhs) - _to_bv(rhs)
                elif 'Multiply' in kind_str:
                    return _to_bv(lhs) * _to_bv(rhs)
                elif 'ShiftLeft' in kind_str:
                    return _to_bv(lhs) << _to_bv(rhs)
                elif 'ShiftRight' in kind_str:
                    return LShR(_to_bv(lhs), _to_bv(rhs))
                elif 'BitwiseAnd' in kind_str:
                    return _to_bv(lhs) & _to_bv(rhs)
                elif 'BitwiseOr' in kind_str:
                    return _to_bv(lhs) | _to_bv(rhs)
                elif 'BitwiseXor' in kind_str:
                    return _to_bv(lhs) ^ _to_bv(rhs)
                elif 'NonblockingAssignment' in kind_str or 'Assignment' in kind_str:
                    return rhs
                else:
                    print(f"[Warning] Unhandled binary syntax kind: {kind_str}")
                    return BitVecVal(0, 32)

            elif class_name == "IdentifierNameSyntax":
                module_name = m.curr_module
                var_name = None
                if hasattr(e, "identifier"):
                    var_name = getattr(e.identifier, 'valueText', getattr(e.identifier, 'value', None))
                if var_name is None:
                    var_name = getattr(e, "valueText", getattr(e, "name", None))
                if var_name is None:
                    return BitVecVal(0, 32)
                if module_name not in s.store or var_name not in s.store[module_name]:
                    return BitVec(var_name, 32)
                sym_val = s.store[module_name][var_name]
                if isinstance(sym_val, str):
                    parsed_z3 = parse_infix_expr_to_z3(sym_val, s, m)
                    if parsed_z3 is not None:
                        return parsed_z3
                    return BitVec(sym_val, 32)
                return sym_val

            elif class_name == "ConditionalPatternSyntax":
                expr = getattr(e, 'expr', getattr(e, 'expression', None))
                if expr is not None:
                    return parse_expr_to_Z3(expr, s, m)
                return BitVecVal(0, 32)

            elif class_name == "ParenthesizedExpressionSyntax":
                inner = getattr(e, 'expression', getattr(e, 'expr', None))
                if inner is not None:
                    return parse_expr_to_Z3(inner, s, m)
                return BitVecVal(0, 32)

            elif class_name == "IntegerLiteralExpressionSyntax":
                int_val = IntVal(e.value)
                return Int2BV(int_val, 32)

            elif class_name == "IdentifierSelectNameSyntax":
                return _syntax_identifier_select(e, s, m)

            elif class_name == "ScopedNameSyntax":
                # Hierarchical reference like top_wrapper.soc_interconnect.TCDM_data_gnt
                # Flatten the left-recursive tree to get the rightmost signal name,
                # then look it up in the store (the store uses bare signal names keyed
                # by instance, so we use the last component as the variable name).
                def _flatten_scoped(node):
                    left = getattr(node, 'left', None)
                    right = getattr(node, 'right', None)
                    right_name = getattr(right, 'identifier', None)
                    if right_name is not None:
                        right_name = getattr(right_name, 'valueText', getattr(right_name, 'value', str(right_name)))
                    else:
                        right_name = getattr(right, 'valueText', str(right)) if right is not None else ''
                    if left is None:
                        return right_name
                    left_kind = getattr(left, 'kind', None)
                    if left_kind == ps.SyntaxKind.ScopedName:
                        left_name = _flatten_scoped(left)
                    else:
                        ident = getattr(left, 'identifier', None)
                        left_name = getattr(ident, 'valueText', getattr(ident, 'value', str(left))) if ident else str(left)
                    return f"{left_name}.{right_name}"

                full_path = _flatten_scoped(e)
                parts = full_path.split('.')
                var_name = parts[-1]
                # For a hierarchical path a.b.c, the owning instance is parts[-2].
                # Try that first, then current module, then all modules.
                owner_mod = parts[-2] if len(parts) >= 2 else None
                search_order = []
                if owner_mod:
                    search_order.append(owner_mod)
                if m is not None and m.curr_module not in search_order:
                    search_order.append(m.curr_module)
                for mod in list(s.store.keys()):
                    if mod not in search_order:
                        search_order.append(mod)
                for mod in search_order:
                    if mod in s.store and var_name in s.store[mod]:
                        return s.store[mod][var_name]
                # Not found — return a fresh symbolic variable
                return BitVec(var_name, 32)

            elif class_name == "MultipleConcatenationExpressionSyntax":
                return _syntax_multiple_concat(e, s, m)

            elif class_name == "ConcatenationExpressionSyntax":
                return _syntax_concatenation(e, s, m)

            elif class_name == "Token":
                return BitVecVal(0, 32)

            else:
                print(f"[Warning] Unrecognized SyntaxKind expression: {e.__class__.__name__} kind={kind_str}")
                return BitVecVal(0, 32)

        # ExpressionKind fallback (duplicate of Phase 1, for nodes that slipped through)
        elif kind == ps.ExpressionKind.BinaryOp:
            return _kind_binary_op(e, s, m)
        elif kind == ps.ExpressionKind.NamedValue:
            return _kind_named_value(e, s, m)
        elif kind == ps.ExpressionKind.IntegerLiteral:
            return _kind_integer_literal(e, s, m)
        elif kind == ps.ExpressionKind.Conversion:
            return _kind_conversion(e, s, m)
        elif kind == ps.ExpressionKind.UnaryOp:
            return _kind_unary_op(e, s, m)

    # Final class-name fallbacks for nodes that reach here
    class_name = e.__class__.__name__
    if class_name == "PrefixUnaryExpressionSyntax":
        return _syntax_prefix_unary(e, s, m)
    elif class_name == "BinaryExpressionSyntax":
        lhs_node = getattr(e, 'left', None)
        rhs_node = getattr(e, 'right', None)
        if lhs_node is None or rhs_node is None:
            return BitVecVal(0, 32)
        lhs = parse_expr_to_Z3(lhs_node, s, m)
        rhs = parse_expr_to_Z3(rhs_node, s, m)
        kind_str = str(getattr(e, 'kind', ''))
        op_token = getattr(e, 'operatorToken', getattr(e, 'operator', None))
        op_str = str(getattr(op_token, 'valueText', '')) if op_token else ''

        def to_bv(x):
            if hasattr(x, 'size'):
                return x
            if is_bool(x):
                return If(x, BitVecVal(1, 32), BitVecVal(0, 32))
            return BitVecVal(0, 32)

        if 'LogicalAnd' in kind_str or op_str == '&&':
            lb = lhs != BitVecVal(0, lhs.size()) if hasattr(lhs, 'size') else lhs
            rb = rhs != BitVecVal(0, rhs.size()) if hasattr(rhs, 'size') else rhs
            return And(lb, rb)
        elif 'LogicalOr' in kind_str or op_str == '||':
            lb = lhs != BitVecVal(0, lhs.size()) if hasattr(lhs, 'size') else lhs
            rb = rhs != BitVecVal(0, rhs.size()) if hasattr(rhs, 'size') else rhs
            return Or(lb, rb)
        elif 'Equality' in kind_str or op_str == '==':
            return to_bv(lhs) == to_bv(rhs)
        elif 'Inequality' in kind_str or op_str == '!=':
            return to_bv(lhs) != to_bv(rhs)
        elif 'GreaterThanEqual' in kind_str or op_str == '>=':
            return UGE(to_bv(lhs), to_bv(rhs))
        elif 'GreaterThan' in kind_str or op_str == '>':
            return UGT(to_bv(lhs), to_bv(rhs))
        elif 'LessThanEqual' in kind_str or op_str == '<=':
            return ULE(to_bv(lhs), to_bv(rhs))
        elif 'LessThan' in kind_str or op_str == '<':
            return ULT(to_bv(lhs), to_bv(rhs))
        elif 'Add' in kind_str or op_str == '+':
            return to_bv(lhs) + to_bv(rhs)
        elif 'Subtract' in kind_str or op_str == '-':
            return to_bv(lhs) - to_bv(rhs)
        elif 'Multiply' in kind_str or op_str == '*':
            return to_bv(lhs) * to_bv(rhs)
        elif 'LogicalShiftLeft' in kind_str or op_str == '<<':
            return to_bv(lhs) << to_bv(rhs)
        elif 'LogicalShiftRight' in kind_str or op_str == '>>':
            return LShR(to_bv(lhs), to_bv(rhs))
        elif 'BitwiseAnd' in kind_str or op_str == '&':
            return to_bv(lhs) & to_bv(rhs)
        elif 'BitwiseOr' in kind_str or op_str == '|':
            return to_bv(lhs) | to_bv(rhs)
        elif 'BitwiseXor' in kind_str or op_str == '^':
            return to_bv(lhs) ^ to_bv(rhs)
        else:
            print(f"[Warning] Unhandled binary op: kind={kind_str} op={op_str}")
            return BitVecVal(0, 32)
    elif class_name == "ConditionalPatternSyntax":
        return _syntax_conditional_pattern(e, s, m)
    elif class_name == "ParenthesizedExpressionSyntax":
        return _syntax_parenthesized(e, s, m)

    print(f"[Warning] Unrecognized expression type: {type(e)}, returning 0")
    return BitVecVal(0, 32)

def solve_pc(s: Solver) -> bool:
    """Solve path condition."""
    from z3 import sat as z3_sat
    if smt_stats.timed_check(s) == z3_sat:
        model = s.model()
        return True
    else:
        logging.debug(f"UNSAT: {len(s.assertions())} constraint(s)")
        return False

def evaluate_expr(parsedList, s: SymbolicState, m: ExecutionManager):
    for i in parsedList:
        res = eval_expr(i, s, m)
    return res

def evaluate_expr_to_smt(lhs, rhs, op, s: SymbolicState, m: ExecutionManager) -> str:
    """Helper function to resolve binary symbolic expressions."""
    if (isinstance(lhs,tuple) and isinstance(rhs,tuple)):
        return f"({op} ({eval_expr(lhs, s, m)})  ({eval_expr(rhs, s, m)}))"
    elif (isinstance(lhs,tuple)):
        if (isinstance(rhs,str)) and not is_verilog_literal(rhs):
            return f"({op} ({eval_expr(lhs, s, m)}) {s.get_symbolic_expr(m.curr_module, rhs)})"
        else:
            return f"({op} ({eval_expr(lhs, s, m)}) {str(rhs)})"
    elif (isinstance(rhs,tuple)):
        if (isinstance(lhs,str)) and not is_verilog_literal(lhs):
            return f"({op} ({s.get_symbolic_expr(m.curr_module, lhs)}) ({eval_expr(rhs, s, m)}))"
        else:
            return f"({op} {str(lhs)}  ({eval_expr(rhs, s, m)}))"
    else:
        if (isinstance(lhs ,str) and isinstance(rhs , str)) and not is_verilog_literal(lhs) and not is_verilog_literal(rhs):
            return f"({op} {s.get_symbolic_expr(m.curr_module, lhs)} {s.get_symbolic_expr(m.curr_module, rhs)})"
        elif (isinstance(lhs ,str)) and not is_verilog_literal(lhs):
            return f"({op} {s.get_symbolic_expr(m.curr_module, lhs)} {str(rhs)})"
        elif (isinstance(rhs ,str)) and not is_verilog_literal(rhs):
            return f"({op} {str(lhs)}  {s.get_symbolic_expr(m.curr_module, rhs)})"
        else:
            return f"({op} {str(lhs)} {str(rhs)})"
 
def eval_expr(expr, s: SymbolicState, m: ExecutionManager) -> str:
    """Takes in an AST and should return the new symbolic expression for the symbolic state."""
    if expr is not None and len(expr) > 0 and expr[0] in BINARY_OPS:
        return evaluate_expr_to_smt(expr[1], expr[2], op_map[expr[0]], s, m)

