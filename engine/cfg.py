"""Converts PySlang AST (representing SystemVerilog) into executable CFG structure that enables path exploration"""
from math import comb
from operator import indexOf
import z3
from z3 import Solver, Int, BitVec, Context, BitVecSort, ExprRef, BitVecRef, If, BitVecVal, And
from .execution_manager import ExecutionManager
from .symbolic_state import SymbolicState
import os
from optparse import OptionParser
from typing import Optional
import random, string
import time
import gc
from itertools import product, permutations, combinations
import logging
from helpers.utils import to_binary
import sys
import networkx as nx
import matplotlib.pyplot as plt
import pyslang as ps
from pyslang import ConditionalStatementSyntax, DataDeclarationSyntax

class CFG:
    """Represents the control flow graph of a module/always block"""
    def __init__(self):
        # basic blocks. A list made up of slices of all_nodes determined by partition_points.
        self.basic_block_list = []

        # for partitioning
        self.curr_idx = 0

        # add all nodes in the always block
        self.all_nodes = []

        # partition indices
        self.partition_points = set()
        self.partition_points.add(0)

        # the edgelist will be a list of tuples of indices of the ast nodes blocks
        self.edgelist = []

        # edges between basic blocks, determined by the above edgelist
        self.cfg_edges = []

        # indices of basic blocks that need to connect to dummy exit node
        self.leaves = set()

        #paths... list of paths with start and end being the dummy nodes
        self.paths = []

        # name corresponding to the module. there could be multiple always blocks (or CFGS) per module
        self.module_name = ""

        # Decl nodes outside the always block to be executed once up front for all paths
        self.decls = []

        # Combinational logic nodes outside the always block to be twice for all paths
        self.comb = []

        # the nodes in the AST that correspond to always blocks
        self.always_blocks = []

        # branch-point set
        # for each basic statement, there may be some indpendent branching points
        self.ind_branch_points = {1: set()}

        # stack of flags for if we are looking at a block statement
        self.block_smt = [False]

        # Whether this CFG is from an initial block (should only execute once)
        self.is_initial = False

        # how many nested block statements we've seen so far
        self.block_stmt_depth = 0

        #submodules defined
        self.submodules = []

    def reset(self):
        """Return to defaults."""
        self.__init__()
        """self.basic_block_list = []
        self.curr_idx = 0
        self.all_nodes = []
        self.partition_points = set()
        self.partition_points.add(0)
        self.edgelist = []
        self.cfg_edges = []
        self.leaves = set()
        self.paths = []
        self.always_blocks = []
        self.ind_branch_points = {1: set()}
        self.block_smt = [False]
        self.block_stmt_depth = 0"""

    def compute_direction(self, path):
        """Given a path, figure out the direction"""
        directions = []
        for i in range(1, len(path)-1):
            if path[i] + 1 == path[i + 1]:
                directions.append(1)
            else:
                directions.append(0)
        return directions
    
    def resolve_independent_branch_pts(self, idx):
        """After visiting a basic block, form edges between the branching points at that same level."""
        if len(self.ind_branch_points[idx]) <= 1:
            return 

        res = list(combinations(self.ind_branch_points[idx], r=len(self.ind_branch_points[idx])))

        self.edgelist += res 


    def get_always_sv(self, m: ExecutionManager, s: SymbolicState, ast):
        """Extracts always blocks from PySlang AST"""
        # Handle InstanceSymbol (from topInstances or child instances)
        if ast is not None and ast.__class__.__name__ == "InstanceSymbol":
            # Iterate over the body to find ProceduralBlockSymbol, ContinuousAssign, and child instances
            if hasattr(ast, 'body'):
                for item in ast.body:
                    if item.__class__.__name__ == "ProceduralBlockSymbol":
                        # Get the syntax node from the symbol
                        if hasattr(item, 'syntax') and item.syntax is not None:
                            self.always_blocks.append(item.syntax)
                    elif item.__class__.__name__ == "ContinuousAssignSymbol":
                        # Collect continuous assignments for COI analysis
                        if hasattr(item, 'syntax') and item.syntax is not None:
                            self.comb.append(item.syntax)
                    elif item.__class__.__name__ == "NetSymbol":
                        # Handle wire declarations with inline assignment:
                        # wire x = expr; (creates NetSymbol with initializer, not ContinuousAssignSymbol)
                        if hasattr(item, 'syntax') and item.syntax is not None:
                            self.comb.append(item.syntax)
                    elif item.__class__.__name__ == "InstanceSymbol":
                        # Recursively process child instances (submodules)
                        self.get_always_sv(m, s, item)
            return

        if (ast != None and isinstance(ast, ps.DefinitionSymbol)):
            self.get_always_sv(m, s, ast.syntax)
            return

        if isinstance(ast, ps.ModuleDeclarationSyntax):
            for mem in ast.members:
                self.get_always_sv(m, s, mem)
            return

        if hasattr(ast, '__iter__'):
            if ast.__class__.__name__ == "ProceduralBlockSyntax":
                self.always_blocks.append(ast)
            elif ast.__class__.__name__ == "ConditionalStatementSyntax":
                self.get_always_sv(m, s, ast.statement)
                self.get_always_sv(m, s, ast.elseClause)
            elif ast.__class__.__name__ == "CaseStatementSyntax":
                return self.get_always_sv(m, s, ast.items)
            elif ast.__class__.__name__ == "ForLoopStatementSyntax":
                return self.get_always_sv(m, s, ast.statement)
            elif ast.__class__.__name__ == "BlockStatementSyntax":
                self.get_always_sv(m, s, ast.items)
            elif ast.__class__.__name__ == "NetDeclarationSyntax":
                # Wire declarations: collect those with initializers as comb
                has_init = False
                declarators = getattr(ast, 'declarators', None)
                if declarators:
                    for decl in declarators:
                        if getattr(decl, 'initializer', None) is not None:
                            has_init = True
                            break
                if has_init:
                    self.comb.append(ast)
                else:
                    self.decls.append(ast)
            elif ast.__class__.__name__ == "DataDeclarationSyntax":
                has_init = False
                declarators = getattr(ast, 'declarators', None)
                if declarators:
                    for decl in declarators:
                        if getattr(decl, 'initializer', None) is not None:
                            has_init = True
                            break
                if has_init:
                    self.comb.append(ast)
                else:
                    self.decls.append(ast)
            elif ast.__class__.__name__ == "ContinuousAssignSyntax":
                self.comb.append(ast)
            else:
                if isinstance(ast, ps.ConditionalStatementSyntax):
                    then_body = getattr(ast, "ifTrue", getattr(ast, "statement", None))
                    else_clause = getattr(ast, "elseClause", None)
                    else_body = getattr(else_clause, "statement", None) if else_clause is not None else None
                    self.get_always_sv(m, s, then_body)
                    self.get_always_sv(m, s, else_body)
                elif isinstance(ast, ps.CaseStatementSyntax):
                    self.get_always_sv(m, s, ast.items)
                elif isinstance(ast, ps.ForLoopStatementSyntax):
                    self.get_always_sv(m, s, ast.statement)
                elif isinstance(ast, ps.BlockStatementSyntax):
                    self.get_always_sv(m, s, ast.items)
                elif isinstance(ast, ps.ProceduralBlockSyntax):
                    self.always_blocks.append(ast)
                elif isinstance(ast, ps.StatementSyntax):
                    self.get_always_sv(m, s, ast.statement)
                else:
                    if isinstance(ast, ps.DataDeclarationSyntax):
                        self.decls.append(ast)
                    elif isinstance(ast, ps.ContinuousAssignSyntax):
                        self.comb.append(ast)
                    elif isinstance(ast, ps.NetDeclarationSyntax):
                        has_init = False
                        declarators = getattr(ast, 'declarators', None)
                        if declarators:
                            for decl in declarators:
                                if getattr(decl, 'initializer', None) is not None:
                                    has_init = True
                                    break
                        if has_init:
                            self.comb.append(ast)
                        else:
                            self.decls.append(ast)
                    else:
                        # Generic iterable: recurse into children
                        for child in ast:
                            self.get_always_sv(m, s, child)
        elif ast != None:
            # print(f"ast ! {ast.definitionKind} {dir(ast)}")
            # print(type(ps.DefinitionSymbol))
            # print(type(ast) == type(ps.DefinitionSymbol))
            # print(type(ast))
            if isinstance(ast, ps.ConditionalStatementSyntax):
                #print("11")
                then_body = getattr(ast, "ifTrue", getattr(ast, "statement", None))
                else_clause = getattr(ast, "elseClause", None)
                else_body = getattr(else_clause, "statement", None) if else_clause is not None else None
                self.get_always_sv(m, s, then_body)
                self.get_always_sv(m, s, else_body)
            elif isinstance(ast, ps.CaseStatementSyntax):
                #print("12")
                #self.get_always(m, s, ast.caseStatements)
                self.get_always_sv(m, s, ast.items)
            elif isinstance(ast, ps.CaseItemSyntax):
                #print("13")
                body = getattr(ast, "statements", getattr(ast, "statement", None))
                self.get_always_sv(m, s, body)
            elif isinstance(ast, ps.ForLoopStatementSyntax):
                #print("14")
                self.get_always_sv(m, s, ast.statement)
            elif isinstance(ast, ps.BlockStatementSyntax):
                #print("15")
                self.get_always_sv(m, s, ast.items)
            elif isinstance(ast, ps.ProceduralBlockSyntax):
                #print("16")
                self.always_blocks.append(ast)          
            # elif isinstance(ast, ps.InitialConstructSyntax):
            #     self.get_always(m, s, ast.statement)
            elif isinstance(ast, ps.StatementSyntax):
                #print("17")
                self.get_always_sv(m, s, ast.statement)
            else:
                #print("18")
                if isinstance(ast, ps.DataDeclarationSyntax):
                    # Check if it has an initializer (wire x = expr pattern)
                    has_init = False
                    declarators = getattr(ast, 'declarators', None)
                    if declarators:
                        for decl in declarators:
                            if getattr(decl, 'initializer', None) is not None:
                                has_init = True
                                break
                    if has_init:
                        self.comb.append(ast)
                    else:
                        self.decls.append(ast)
                elif isinstance(ast, ps.ContinuousAssignSyntax):
                    self.comb.append(ast)
                elif isinstance(ast, ps.NetDeclarationSyntax):
                    # Collect net declarations with initializers as comb
                    # e.g., wire check_en = valid_pipe[2];
                    has_init = False
                    declarators = getattr(ast, 'declarators', None)
                    if declarators:
                        for decl in declarators:
                            if getattr(decl, 'initializer', None) is not None:
                                has_init = True
                                break
                    if has_init:
                        self.comb.append(ast)
                    else:
                        self.decls.append(ast)
                ...

    def _process_conditional_sv(self, m: ExecutionManager, s: SymbolicState, parent_idx: int, node) -> None:
        """Handle ConditionalStatementSyntax nodes, including nested else-if chains."""
        then_body = getattr(node, "ifTrue", getattr(node, "statement", None))
        else_clause = getattr(node, "elseClause", None)
        else_body = None
        if else_clause is not None:
            else_body = getattr(else_clause, "statement", getattr(else_clause, "clause", None))

        # Process the true branch
        then_start_idx = self.curr_idx
        self.partition_points.add(self.curr_idx)
        self.basic_blocks_sv(m, s, then_body)
        if self.curr_idx == then_start_idx:
            # Empty branch: allocate a dummy node so the edge has a destination
            self.all_nodes.append(None)
            self.curr_idx += 1
        self.edgelist.append((parent_idx, then_start_idx))

        if else_body is None:
            # No else clause: create a "skip" path (condition false -> fall through)
            # This represents the path where the if condition is false and body is skipped
            skip_idx = self.curr_idx
            self.partition_points.add(self.curr_idx)
            self.all_nodes.append(None)  # Dummy node for the skip path
            self.curr_idx += 1
            self.edgelist.append((parent_idx, skip_idx))
            return

        if isinstance(else_body, ps.ConditionalStatementSyntax):
            # Nested else-if: treat the nested conditional as its own node
            nested_parent_idx = self.curr_idx
            self.all_nodes.append(else_body)
            self.partition_points.add(self.curr_idx)
            self.curr_idx += 1
            self.edgelist.append((parent_idx, nested_parent_idx))
            self._process_conditional_sv(m, s, nested_parent_idx, else_body)
        else:
            else_start_idx = self.curr_idx
            self.partition_points.add(self.curr_idx)
            self.basic_blocks_sv(m, s, else_body)
            if self.curr_idx == else_start_idx:
                # Empty else branch: allocate a dummy node to terminate this path
                self.all_nodes.append(None)
                self.curr_idx += 1
            self.edgelist.append((parent_idx, else_start_idx))

    def basic_blocks_sv(self, m:ExecutionManager, s: SymbolicState, ast):
        """We want to get a list of AST nodes partitioned into basic blocks.
        Need to keep track of children/parent indices of each block in the list."""
        if hasattr(ast, '__iter__'):
            # BlockStatementSyntax is iterable but iterating it directly yields raw
            # tokens (BeginKeyword, SyntaxList, EndKeyword) instead of statements.
            # Route through ast.items to get the actual statement children.
            if isinstance(ast, ps.BlockStatementSyntax):
                self.block_stmt_depth += 1
                self.block_smt.append(True)
                self.basic_blocks_sv(m, s, ast.items)
                if self.block_stmt_depth in self.ind_branch_points:
                    self.resolve_independent_branch_pts(self.block_stmt_depth)
                self.block_smt.pop()
                self.block_stmt_depth -= 1
                return
            for item in ast:
                if self.block_smt[self.block_stmt_depth] and (isinstance(item, ps.ConditionalStatementSyntax) or isinstance(item, ps.CaseStatementSyntax) or isinstance(item, ps.ForLoopStatementSyntax)):
                    if not self.block_stmt_depth in self.ind_branch_points:
                        self.ind_branch_points[self.block_stmt_depth] = set()

                    self.ind_branch_points[self.block_stmt_depth].add(self.curr_idx)

                if isinstance(item, ps.ConditionalStatementSyntax):
                    self.all_nodes.append(item)
                    self.partition_points.add(self.curr_idx)
                    parent_idx = self.curr_idx
                    self.curr_idx += 1

                    self._process_conditional_sv(m, s, parent_idx, item)

                elif isinstance(item, ps.CaseStatementSyntax):
                    self.all_nodes.append(item)
                    self.partition_points.add(self.curr_idx)
                    self.curr_idx += 1
                    #self.basic_blocks_sv(m, s, item.caselist) 
                    self.basic_blocks_sv(m, s, item.items)
                elif isinstance(item, ps.CaseItemSyntax):
                    body = getattr(item, "statements", getattr(item, "statement", None))
                    self.basic_blocks_sv(m, s, body)


                elif isinstance(item, ps.ForLoopStatementSyntax):
                    self.all_nodes.append(item)
                    #self.all_nodes.append(ast)
                    self.partition_points.add(self.curr_idx)
                    self.curr_idx += 1
                    self.basic_blocks_sv(m, s, item.statement) 
                elif isinstance(item, ps.BlockStatementSyntax):
                    self.basic_blocks_sv(m, s, item.items)
                elif isinstance(item, ps.ProceduralBlockSyntax):
                    self.all_nodes.append(item)
                    self.curr_idx += 1
                    self.basic_blocks_sv(m, s, item.statement)
                elif item.__class__.__name__ == "TimingControlStatementSyntax":
                    # Handle @(posedge clk) etc. - drill down to the actual statement
                    if hasattr(item, 'statement') and item.statement is not None:
                        self.basic_blocks_sv(m, s, item.statement)
                    else:
                        # No statement body, just add as a node
                        self.all_nodes.append(item)
                        self.curr_idx += 1
                # elif isinstance(item, ps.InitialConstructSyntax):
                #     self.all_nodes.append(item)
                #     self.curr_idx += 1
                #     self.basic_blocks(m, s, item.statement)
                else:
                    self.all_nodes.append(item)
                    self.curr_idx += 1

        elif ast != None:
            if isinstance(ast, ps.ConditionalStatementSyntax):
                self.partition_points.add(self.curr_idx)
                self.all_nodes.append(ast)
                parent_idx = self.curr_idx
                self.curr_idx += 1

                self._process_conditional_sv(m, s, parent_idx, ast)
            elif isinstance(ast, ps.CaseStatementSyntax):
                self.all_nodes.append(ast)
                self.partition_points.add(self.curr_idx)
                self.curr_idx += 1
                self.basic_blocks_sv(m, s, ast.items)
            elif isinstance(ast, ps.CaseItemSyntax):
                body = getattr(ast, "statements", getattr(ast, "statement", None))
                self.basic_blocks_sv(m, s, body)
            elif isinstance(ast, ps.ForLoopStatementSyntax):
                self.all_nodes.append(ast)
                self.partition_points.add(self.curr_idx)
                self.curr_idx += 1
                self.basic_blocks_sv(m, s, ast.statement)
            elif isinstance(ast, ps.BlockStatementSyntax):
                self.block_stmt_depth += 1
                self.block_smt.append(True)
                self.basic_blocks_sv(m, s, ast.items)
                if self.block_stmt_depth in self.ind_branch_points:
                    self.resolve_independent_branch_pts(self.block_stmt_depth)
                self.block_smt.pop()
                self.block_stmt_depth -= 1
            elif isinstance(ast, ps.ProceduralBlockSyntax):
                self.all_nodes.append(ast)
                self.curr_idx += 1
                self.basic_blocks_sv(m, s, ast.statement)
            elif ast.__class__.__name__ == "TimingControlStatementSyntax":
                # Handle @(posedge clk) etc. - drill down to the actual statement
                if hasattr(ast, 'statement') and ast.statement is not None:
                    self.basic_blocks_sv(m, s, ast.statement)
                else:
                    # No statement body, just add as a node
                    self.all_nodes.append(ast)
                    self.curr_idx += 1
            else:
                self.all_nodes.append(ast)
                self.curr_idx += 1

    def map_to_path(self):
        """Just return the paths"""
        return self.paths

    def partition(self):
        """Partitions all_nodes into basic blocks based on partition_points.

        partition_points[0] is always 0 (start).
        partition_points[1] is the first conditional (end of the "preamble" block).
        partition_points[2+] are starts of branch-target blocks.

        Block 0: all_nodes[partition_list[0] .. partition_list[1]] (inclusive - preamble + conditional)
        Block i (i>=1): all_nodes[partition_list[i+1] .. partition_list[i+2]-1]
          (each branch-target block starts at a partition point and extends to the next)
        Last block extends to the end of all_nodes.
        """
        partition_list = sorted(list(self.partition_points))

        if len(partition_list) < 2:
            # Only one partition point (or none): single block with all nodes
            self.basic_block_list.append(self.all_nodes[:])
            return

        # Block 0: preamble through the first conditional (inclusive)
        first_block = self.all_nodes[partition_list[0]:partition_list[1]+1]
        self.basic_block_list.append(first_block)

        # Subsequent blocks: each partition_list[2+] marks the START of a new block
        branch_starts = partition_list[2:]  # skip partition_list[0] and partition_list[1]
        for i, start in enumerate(branch_starts):
            if i + 1 < len(branch_starts):
                end = branch_starts[i + 1]
            else:
                end = len(self.all_nodes)
            basic_block = self.all_nodes[start:end]
            self.basic_block_list.append(basic_block)

    def find_basic_block(self, node_idx) -> int:
        """Given a node index, find the index of the basic block that contains it.

        Block 0: nodes from partition_list[0] to partition_list[1] (inclusive).
        Block i (i>=1): starts at partition_list[i+1] (branch_starts[i-1]).
        """
        partition_list = sorted(list(self.partition_points))

        if len(partition_list) < 2:
            return 0

        # Check if in block 0 (preamble + conditional)
        if node_idx <= partition_list[1]:
            return 0

        # Branch-target blocks start at partition_list[2+]
        branch_starts = partition_list[2:]
        for i in range(len(branch_starts) - 1, -1, -1):
            if node_idx >= branch_starts[i]:
                return min(i + 1, len(self.basic_block_list) - 1)

        # Fallback: return last block
        return len(self.basic_block_list) - 1

    def make_paths(self):
        """Map the edge between AST nodes to a path between basic blocks."""
        for edge in self.edgelist:
            block1 = self.find_basic_block(edge[0])
            block2 = self.find_basic_block(edge[1])
            path = (block1, block2)
            self.cfg_edges.append(path)

    def find_leaves(self):
        """Find leaves in cfg, to know which nodes need to connect to dummy exit."""
        starts = set(edge[0] for edge in self.cfg_edges)
        ends = set(edges[1] for edges in self.cfg_edges)
        self.leaves = ends - starts

    def display_cfg(self, graph):
        """Display CFG."""
        subax1 = plt.subplot(121)
        nx.draw(graph, with_labels=True, font_weight='bold')
        plt.show()

    def build_cfg(self, m: ExecutionManager, s: SymbolicState):
        """Build networkx digraph."""
        from helpers.debug import debug_print
        debug_print("build_cfg", f"all_nodes count: {len(self.all_nodes)}, edgelist count: {len(self.edgelist)}")
        debug_print("build_cfg", f"partition_points: {sorted(self.partition_points)}")
        debug_print("build_cfg", f"edgelist: {self.edgelist}")
        self.make_paths()
        debug_print("build_cfg", f"cfg_edges: {self.cfg_edges}")
        debug_print("build_cfg", f"basic_block_list count: {len(self.basic_block_list)}")
        debug_print("build_cfg", f"basic_block_list: {self.basic_block_list}")
        # print(self.cfg_edges)

        G = nx.DiGraph()
        for block in self.basic_block_list:
            # converts the list into a tuple. Needs to be hashable type
            G.add_node(indexOf(self.basic_block_list, block), data=tuple(block))

        G.add_node(-1, data="Dummy Start")
        G.add_node(-2, data="Dummy End")

        for edge in self.cfg_edges:
            start = edge[0]
            end = edge[1]
            G.add_edge(start, end)

        # edgecase lol
        if self.edgelist == []:
            G.add_edge(0, -2)

        # link up dummy start
        G.add_edge(-1, 0)
        self.find_leaves()

        # link of dummy exit
        for leaf in self.leaves:
            G.add_edge(leaf, -2)

        #print(G.edges())

        #self.display_cfg(G)

        #traversed = nx.edge_dfs(G, source=-1)
        self.paths = list(nx.all_simple_paths(G, source=-1, target=-2))
        debug_print("build_cfg", f"paths computed: {len(self.paths)} paths")
        if len(self.paths) <= 5:
            debug_print("build_cfg", f"paths: {self.paths}")
        #print(list(traversed))
        #print(list(self.paths))