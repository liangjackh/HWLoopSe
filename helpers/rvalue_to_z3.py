"""Helpers for working with Z3, specifically parsing the symbolic expressions into 
Z3 expressions and solving for assertion violations."""

import z3
from z3 import Solver, Int, BitVec, Context, BitVecSort, ExprRef, BitVecRef, If, BitVecVal, And, IntVal, Int2BV, Or, Not, ULT, UGT, Z3Exception, BoolRef
from z3 import is_and, is_app_of, Z3_OP_EXTRACT, is_eq, is_distinct
from helpers.rvalue_parser import parse_tokens, tokenize
from engine.execution_manager import ExecutionManager
from engine.symbolic_state import SymbolicState
import pyslang as ps
import networkx as nx
import ast
from copy import deepcopy


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
        if str(left_expr.sort()) == "Bool" and str(right_expr.sort()) != "Bool":
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
    print(f"[DEBUG parse_expr_to_Z3] expr: {e}, type: {type(e)}, class: {e.__class__.__name__}")
    if hasattr(e, 'kind'):
        print(f"[DEBUG parse_expr_to_Z3] kind: {e.kind}")
    if hasattr(e, 'op'):
        print(f"[DEBUG parse_expr_to_Z3] op: {e.op}")

    # Handle PySlang semantic expressions FIRST (ExpressionKind)
    if hasattr(e, 'kind'):
        kind = e.kind

        # Handle BinaryOp semantic expressions (e.g., out <= 2)
        if kind == ps.ExpressionKind.BinaryOp:
            lhs = parse_expr_to_Z3(e.left, s, m)
            rhs = parse_expr_to_Z3(e.right, s, m)
            op = str(e.op) if hasattr(e, 'op') else ""
            print(f"[DEBUG BinaryOp] lhs={lhs}, rhs={rhs}, op={op}")

            # Map PySlang binary operators to Z3
            if "LessThanEqual" in op or "LessEq" in op:
                return z3.ULE(lhs, rhs)
            elif "LessThan" in op and "Equal" not in op:
                return ULT(lhs, rhs)
            elif "GreaterThanEqual" in op or "GreaterEq" in op:
                return z3.UGE(lhs, rhs)
            elif "GreaterThan" in op and "Equal" not in op:
                return UGT(lhs, rhs)
            elif "Equality" in op or op == "BinaryOperator.Eq":
                return lhs == rhs
            elif "Inequality" in op or "NotEq" in op:
                return lhs != rhs
            elif "Add" in op or "Plus" in op:
                return lhs + rhs
            elif "Subtract" in op or "Sub" in op or "Minus" in op:
                return lhs - rhs
            elif "Multiply" in op or "Mul" in op or "Times" in op:
                return lhs * rhs
            elif "Divide" in op or "Div" in op:
                return z3.UDiv(lhs, rhs)
            elif "Mod" in op:
                return z3.URem(lhs, rhs)
            elif "BinaryAnd" in op:
                return lhs & rhs
            elif "BinaryOr" in op:
                return lhs | rhs
            elif "BinaryXor" in op or "Xor" in op:
                return lhs ^ rhs
            elif "LogicalAnd" in op or "Land" in op:
                lhs_bool = lhs != BitVecVal(0, 32) if hasattr(lhs, 'size') else lhs
                rhs_bool = rhs != BitVecVal(0, 32) if hasattr(rhs, 'size') else rhs
                return And(lhs_bool, rhs_bool)
            elif "LogicalOr" in op or "Lor" in op:
                lhs_bool = lhs != BitVecVal(0, 32) if hasattr(lhs, 'size') else lhs
                rhs_bool = rhs != BitVecVal(0, 32) if hasattr(rhs, 'size') else rhs
                return Or(lhs_bool, rhs_bool)
            elif "LogicalShiftLeft" in op or "Sll" in op:
                return lhs << rhs
            elif "LogicalShiftRight" in op or "Srl" in op:
                return z3.LShR(lhs, rhs)
            elif "ArithmeticShiftRight" in op or "Sra" in op:
                return lhs >> rhs
            else:
                print(f"[Warning] Unhandled binary operator: {op}")
                return BitVecVal(0, 32)

        # Handle NamedValue semantic expressions (variable references)
        elif kind == ps.ExpressionKind.NamedValue:
            symbol = getattr(e, 'symbol', None)
            if symbol is not None:
                var_name = symbol.name
                module_name = m.curr_module
                print(f"[DEBUG NamedValue] var_name={var_name}, module={module_name}, store keys={list(s.store.get(module_name, {}).keys())}")
                if module_name in s.store and var_name in s.store[module_name]:
                    sym_val = s.store[module_name][var_name]
                    if isinstance(sym_val, str) and sym_val.isdigit():
                        return BitVecVal(int(sym_val), 32)
                    elif isinstance(sym_val, str):
                        return BitVec(sym_val, 32)
                    else:
                        return sym_val
                else:
                    # Variable not in store, create a fresh symbolic variable
                    return BitVec(var_name, 32)
            return BitVecVal(0, 32)

        # Handle IntegerLiteral semantic expressions
        elif kind == ps.ExpressionKind.IntegerLiteral:
            val = getattr(e, 'value', 0)
            if hasattr(val, 'value'):
                val = val.value
            print(f"[DEBUG IntegerLiteral] val={val}")
            return BitVecVal(int(val), 32)

        # Handle Conversion expressions (type casts)
        elif kind == ps.ExpressionKind.Conversion:
            operand = getattr(e, 'operand', None)
            if operand is not None:
                return parse_expr_to_Z3(operand, s, m)
            return BitVecVal(0, 32)

        # Handle UnaryOp semantic expressions
        elif kind == ps.ExpressionKind.UnaryOp:
            operand = parse_expr_to_Z3(e.operand, s, m)
            op = str(e.op) if hasattr(e, 'op') else ""
            if "Not" in op or "LogicalNot" in op:
                if hasattr(operand, 'size'):
                    return operand == BitVecVal(0, 32)
                return Not(operand)
            elif "BitwiseNot" in op:
                return ~operand
            elif "Minus" in op:
                return -operand
            elif "Plus" in op:
                return operand
            else:
                print(f"[Warning] Unhandled unary operator: {op}")
                return BitVecVal(0, 32)

    # Handle PySlang SYNTAX nodes (SyntaxKind) - these are different from semantic ExpressionKind
    class_name = e.__class__.__name__

    # Handle ParenthesizedExpressionSyntax - unwrap and recurse
    if class_name == "ParenthesizedExpressionSyntax":
        inner_expr = getattr(e, 'expression', None)
        if inner_expr is not None:
            print(f"[DEBUG ParenthesizedExpressionSyntax] unwrapping to: {inner_expr}")
            return parse_expr_to_Z3(inner_expr, s, m)
        return BitVecVal(0, 32)

    # Handle BinaryExpressionSyntax
    if class_name == "BinaryExpressionSyntax":
        lhs = parse_expr_to_Z3(e.left, s, m)
        rhs = parse_expr_to_Z3(e.right, s, m)
        op_token = str(getattr(e, 'operatorToken', ''))
        print(f"[DEBUG BinaryExpressionSyntax] lhs={lhs}, rhs={rhs}, op_token={op_token}")

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
            lhs_bool = lhs != BitVecVal(0, 32) if hasattr(lhs, 'size') else lhs
            rhs_bool = rhs != BitVecVal(0, 32) if hasattr(rhs, 'size') else rhs
            return And(lhs_bool, rhs_bool)
        elif "||" in op_token:
            lhs_bool = lhs != BitVecVal(0, 32) if hasattr(lhs, 'size') else lhs
            rhs_bool = rhs != BitVecVal(0, 32) if hasattr(rhs, 'size') else rhs
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

    # Handle LiteralExpressionSyntax (integer literals)
    if class_name == "LiteralExpressionSyntax" or class_name == "IntegerVectorExpressionSyntax":
        # Try to get the literal value
        literal_token = getattr(e, 'literal', None)
        if literal_token is not None:
            val_str = str(literal_token)
            # Parse Verilog integer literals (e.g., "2", "32'd5", "8'hFF")
            try:
                if "'" in val_str:
                    # Handle sized literals like 32'd5
                    parts = val_str.split("'")
                    base_char = parts[1][0] if len(parts[1]) > 0 else 'd'
                    num_str = parts[1][1:] if len(parts[1]) > 1 else '0'
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

    # Legacy handling for syntax nodes and Z3 expressions below
    tokens_list = parse_tokens(tokenize(e, s, m))
    new_constraint = evaluate_expr(tokens_list, s, m)
    new_constants = []
    if not new_constraint is None:
        new_constants = get_constants_list(new_constraint, s, m)
    if is_and(e):
        lhs = parse_expr_to_Z3(e.left, s, m)
        rhs = parse_expr_to_Z3(e.right, s, m)
        # Return the AND of the two Z3 expressions without modifying path condition
        return And(lhs, rhs)
    elif is_app_of(e, Z3_OP_EXTRACT):
        part_sel_expr = f"{e.var.name}[{e.msb}:{e.lsb}]"
        module_name = m.curr_module
        is_reg = e.var.name in m.reg_decls
        if not e.var.scope is None:
            module_name = e.scope.labellist[0].name
        if s.store[module_name][e.var.name].isdigit():
            int_val = IntVal(int(s.store[module_name][e.name]))
            return Int2BV(int_val, 32)
        else:
            # Look up the symbolic value without modifying the store
            # If part_sel_expr doesn't exist, use the base variable's symbolic value
            if part_sel_expr in s.store[module_name]:
                sym_val = s.store[module_name][part_sel_expr]
            elif "[" in part_sel_expr:
                parts = part_sel_expr.partition("[")
                first_part = parts[0]
                sym_val = s.store[module_name].get(first_part, part_sel_expr)
            else:
                sym_val = part_sel_expr
            return BitVec(sym_val, 32)
    elif e.__class__.__name__ == "IdentifierNameSyntax":
        module_name = m.curr_module  # Default to current module
        # PySlang 7.0 IdentifierNameSyntax uses .identifier.valueText for the name
        # Access the identifier name through .identifier attribute
        if not hasattr(e, "identifier"):
            # Fallback: try to get name directly if identifier attribute doesn't exist
            var_name = getattr(e, "valueText", getattr(e, "name", None))
            if var_name is None:
                return BitVecVal(0, 32)  # Return zero if we can't get the name
        else:
            var_name = e.identifier.valueText if hasattr(e.identifier, "valueText") else None
            if var_name is None:
                var_name = getattr(e.identifier, "name", None)
        
        if var_name is None:
            return BitVecVal(0, 32)  # Return zero if we can't get the name
            
        is_reg = var_name in m.reg_decls if hasattr(m, "reg_decls") else False
        
        # Check if variable exists in store, if not return zero
        if module_name not in s.store or var_name not in s.store[module_name]:
            return BitVecVal(0, 32)
            
        if s.store[module_name][var_name].isdigit():
            int_val = IntVal(int(s.store[module_name][var_name]))
            return Int2BV(int_val, 32)
        else:
            return BitVec(s.store[module_name][var_name], 32)
    elif e.__class__.__name__ == "IntegerLiteralExpressionSyntax":
        int_val = IntVal(e.value)
        return Int2BV(int_val, 32)
    elif is_eq(e):
        lhs = parse_expr_to_Z3(e.left, s, m)
        rhs = parse_expr_to_Z3(e.right, s, m)
        # Return the equality expression without modifying path condition
        return (lhs == rhs)
    elif is_distinct(e):
        lhs = parse_expr_to_Z3(e.left, s, m)
        rhs = parse_expr_to_Z3(e.right, s, m)
        # Return the inequality expression without modifying path condition
        # Handle type conversion if needed
        if isinstance(rhs, z3.z3.BitVecRef) and not isinstance(lhs, z3.z3.BitVecRef):
            c = If(lhs, BitVecVal(1, 32), BitVecVal(0, 32))
            return (c != rhs)
        else:
            return (lhs != rhs)

    # Handle PySlang semantic expressions (ExpressionKind)
    if hasattr(e, 'kind'):
        kind = e.kind

        # Handle BinaryOp semantic expressions (e.g., out <= 2)
        if kind == ps.ExpressionKind.BinaryOp:
            lhs = parse_expr_to_Z3(e.left, s, m)
            rhs = parse_expr_to_Z3(e.right, s, m)
            op = str(e.op) if hasattr(e, 'op') else ""

            # Map PySlang binary operators to Z3
            if op == "BinaryOperator.LessThanEqual" or "LessEq" in op:
                return z3.ULE(lhs, rhs)
            elif op == "BinaryOperator.LessThan" or "LessThan" in op:
                return ULT(lhs, rhs)
            elif op == "BinaryOperator.GreaterThanEqual" or "GreaterEq" in op:
                return z3.UGE(lhs, rhs)
            elif op == "BinaryOperator.GreaterThan" or "GreaterThan" in op:
                return UGT(lhs, rhs)
            elif op == "BinaryOperator.Equality" or "Eq" in op:
                return lhs == rhs
            elif op == "BinaryOperator.Inequality" or "NotEq" in op:
                return lhs != rhs
            elif op == "BinaryOperator.Add" or "Add" in op or "Plus" in op:
                return lhs + rhs
            elif op == "BinaryOperator.Subtract" or "Sub" in op or "Minus" in op:
                return lhs - rhs
            elif op == "BinaryOperator.Multiply" or "Mul" in op or "Times" in op:
                return lhs * rhs
            elif op == "BinaryOperator.Divide" or "Div" in op:
                return z3.UDiv(lhs, rhs)
            elif op == "BinaryOperator.Mod" or "Mod" in op:
                return z3.URem(lhs, rhs)
            elif op == "BinaryOperator.BinaryAnd" or "And" in op:
                return lhs & rhs
            elif op == "BinaryOperator.BinaryOr" or "Or" in op:
                return lhs | rhs
            elif op == "BinaryOperator.BinaryXor" or "Xor" in op:
                return lhs ^ rhs
            elif op == "BinaryOperator.LogicalAnd" or "Land" in op:
                # Convert to bool if needed
                lhs_bool = lhs != BitVecVal(0, 32) if hasattr(lhs, 'size') else lhs
                rhs_bool = rhs != BitVecVal(0, 32) if hasattr(rhs, 'size') else rhs
                return And(lhs_bool, rhs_bool)
            elif op == "BinaryOperator.LogicalOr" or "Lor" in op:
                lhs_bool = lhs != BitVecVal(0, 32) if hasattr(lhs, 'size') else lhs
                rhs_bool = rhs != BitVecVal(0, 32) if hasattr(rhs, 'size') else rhs
                return Or(lhs_bool, rhs_bool)
            elif op == "BinaryOperator.LogicalShiftLeft" or "Sll" in op:
                return lhs << rhs
            elif op == "BinaryOperator.LogicalShiftRight" or "Srl" in op:
                return z3.LShR(lhs, rhs)
            elif op == "BinaryOperator.ArithmeticShiftRight" or "Sra" in op:
                return lhs >> rhs
            else:
                print(f"[Warning] Unhandled binary operator: {op}")
                return BitVecVal(0, 32)

        # Handle NamedValue semantic expressions (variable references)
        elif kind == ps.ExpressionKind.NamedValue:
            symbol = getattr(e, 'symbol', None)
            if symbol is not None:
                var_name = symbol.name
                module_name = m.curr_module
                if module_name in s.store and var_name in s.store[module_name]:
                    sym_val = s.store[module_name][var_name]
                    if isinstance(sym_val, str) and sym_val.isdigit():
                        return BitVecVal(int(sym_val), 32)
                    elif isinstance(sym_val, str):
                        return BitVec(sym_val, 32)
                    else:
                        return sym_val
                else:
                    # Variable not in store, create a fresh symbolic variable
                    return BitVec(var_name, 32)
            return BitVecVal(0, 32)

        # Handle IntegerLiteral semantic expressions
        elif kind == ps.ExpressionKind.IntegerLiteral:
            val = getattr(e, 'value', 0)
            if hasattr(val, 'value'):
                val = val.value
            return BitVecVal(int(val), 32)

        # Handle Conversion expressions (type casts)
        elif kind == ps.ExpressionKind.Conversion:
            operand = getattr(e, 'operand', None)
            if operand is not None:
                return parse_expr_to_Z3(operand, s, m)
            return BitVecVal(0, 32)

        # Handle UnaryOp semantic expressions
        elif kind == ps.ExpressionKind.UnaryOp:
            operand = parse_expr_to_Z3(e.operand, s, m)
            op = str(e.op) if hasattr(e, 'op') else ""
            if "Not" in op or "LogicalNot" in op:
                if hasattr(operand, 'size'):
                    return operand == BitVecVal(0, 32)
                return Not(operand)
            elif "BitwiseNot" in op:
                return ~operand
            elif "Minus" in op:
                return -operand
            elif "Plus" in op:
                return operand
            else:
                print(f"[Warning] Unhandled unary operator: {op}")
                return BitVecVal(0, 32)

    # Default: return a BitVecVal of 0 if expression type is not recognized
    print(f"[Warning] Unrecognized expression type: {type(e)}, returning 0")
    return BitVecVal(0, 32)

def solve_pc(s: Solver) -> bool:
    """Solve path condition."""
    result = str(s.check())
    if str(result) == "sat":
        model = s.model()
        return True
    else:
        print("unsat")
        print(s)
        print(s.unsat_core())
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
        if (isinstance(rhs,str)) and not rhs.isdigit():
            return f"({op} ({eval_expr(lhs, s, m)}) {s.get_symbolic_expr(m.curr_module, rhs)})"
        else:
            return f"({op} ({eval_expr(lhs, s, m)}) {str(rhs)})"
    elif (isinstance(rhs,tuple)):
        if (isinstance(lhs,str)) and not lhs.isdigit():
            return f"({op} ({s.get_symbolic_expr(m.curr_module, lhs)}) ({eval_expr(rhs, s, m)}))"
        else:
            return f"({op} {str(lhs)}  ({eval_expr(rhs, s, m)}))"
    else:
        if (isinstance(lhs ,str) and isinstance(rhs , str)) and not lhs.isdigit() and not rhs.isdigit():
            return f"({op} {s.get_symbolic_expr(m.curr_module, lhs)} {s.get_symbolic_expr(m.curr_module, rhs)})"
        elif (isinstance(lhs ,str)) and not lhs.isdigit():
            return f"({op} {s.get_symbolic_expr(m.curr_module, lhs)} {str(rhs)})"
        elif (isinstance(rhs ,str)) and not rhs.isdigit():
            return f"({op} {str(lhs)}  {s.get_symbolic_expr(m.curr_module, rhs)})"
        else: 
            return f"({op} {str(lhs)} {str(rhs)})"
 
def eval_expr(expr, s: SymbolicState, m: ExecutionManager) -> str:
    """Takes in an AST and should return the new symbolic expression for the symbolic state."""
    if expr is not None and len(expr) > 0 and expr[0] in BINARY_OPS:
        return evaluate_expr_to_smt(expr[1], expr[2], op_map[expr[0]], s, m)

