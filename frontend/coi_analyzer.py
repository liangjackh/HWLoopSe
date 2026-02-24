"""Cone of Influence (COI) analyzer for pruning irrelevant always blocks.

Traces backward from assertion signals to find only the always blocks
(and module instances) that can influence those signals.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Set, Tuple, Any, Optional
from collections import deque
import pyslang as ps


@dataclass
class COIResult:
    """Result of COI analysis."""
    relevant_cfgs: Set[Tuple[str, int]] = field(default_factory=set)    # (instance_name, cfg_index)
    relevant_instances: Set[str] = field(default_factory=set)            # instances with >= 1 relevant CFG
    cone_signals: Set[Tuple[str, str]] = field(default_factory=set)      # (instance_name, signal_name)


class COIAnalyzer:
    """Backward cone-of-influence analysis at always-block granularity.

    Given seed signals (from assertions), traces backward through:
    - Always block write/read sets
    - Continuous assignment write/read sets
    - Cross-module port connections
    to find the minimal set of always blocks that can influence the seeds.
    """

    def __init__(self, modules_dict: Dict[str, Any], cfgs_by_module: Dict[str, list], modules: list):
        """
        Args:
            modules_dict: instance_name -> InstanceSymbol
            cfgs_by_module: instance_name -> list of CFG objects
            modules: full list of module instances
        """
        self.modules_dict = modules_dict
        self.cfgs_by_module = cfgs_by_module
        self.modules = modules

        # Per (instance, cfg_idx): set of signal names written/read
        self.block_writes: Dict[Tuple[str, int], Set[str]] = {}
        self.block_reads: Dict[Tuple[str, int], Set[str]] = {}

        # Per instance: continuous assignment writes/reads
        self.comb_writes: Dict[str, Dict[str, Set[str]]] = {}  # inst -> signal -> set of read signals
        self.comb_reads: Dict[str, Set[str]] = {}

        # Cross-module port map: (child_inst, port_name) -> (parent_inst, parent_signal)
        self.port_map_child_to_parent: Dict[Tuple[str, str], Tuple[str, str]] = {}
        # Reverse: (parent_inst, signal) -> list of (child_inst, port_name)
        self.port_map_parent_to_child: Dict[Tuple[str, str], List[Tuple[str, str]]] = {}

        self._build_signal_maps()
        self._extract_port_connections()

    # ------------------------------------------------------------------
    # 2a. Build per-block write/read sets
    # ------------------------------------------------------------------

    def _build_signal_maps(self):
        """For each (instance, cfg_idx), extract write and read signal sets."""
        for instance_name, cfg_list in self.cfgs_by_module.items():
            for cfg_idx, cfg in enumerate(cfg_list):
                writes = set()
                reads = set()

                # Walk basic blocks
                for block in cfg.basic_block_list:
                    for stmt in block:
                        if stmt is None:
                            continue
                        self._extract_stmt_signals(stmt, writes, reads)

                self.block_writes[(instance_name, cfg_idx)] = writes
                self.block_reads[(instance_name, cfg_idx)] = reads

            # Also handle continuous assignments from the first CFG's comb list
            # (comb is shared across CFGs of the same definition, stored on each)
            if cfg_list:
                self.comb_writes[instance_name] = {}
                self.comb_reads[instance_name] = set()
                for comb_node in cfg_list[0].comb:
                    self._extract_comb_signals(instance_name, comb_node)

    def _extract_stmt_signals(self, stmt, writes: Set[str], reads: Set[str]):
        """Extract write and read signals from a statement (syntax node)."""
        if stmt is None:
            return

        cname = stmt.__class__.__name__

        # Assignment expressions (blocking/nonblocking)
        if isinstance(stmt, ps.ExpressionStatementSyntax):
            expr = getattr(stmt, 'expression', getattr(stmt, 'expr', None))
            if expr is not None:
                self._extract_assignment_signals(expr, writes, reads)
            return

        # Conditional: condition is a read dependency, recurse into branches
        if isinstance(stmt, ps.ConditionalStatementSyntax):
            # Extract reads from condition
            predicate = getattr(stmt, 'predicate', None)
            if predicate is None:
                # Try conditions list
                conditions = getattr(stmt, 'conditions', None)
                if conditions:
                    for cond in conditions:
                        cond_expr = getattr(cond, 'expr', getattr(cond, 'expression', cond))
                        self._collect_read_signals(cond_expr, reads)
            else:
                self._collect_read_signals(predicate, reads)

            # Recurse into branches
            for attr in ('ifTrue', 'statement'):
                body = getattr(stmt, attr, None)
                if body is not None:
                    self._extract_stmt_signals(body, writes, reads)
                    break
            else_clause = getattr(stmt, 'elseClause', None)
            if else_clause is not None:
                else_body = getattr(else_clause, 'statement', getattr(else_clause, 'clause', else_clause))
                self._extract_stmt_signals(else_body, writes, reads)
            return

        # Case statement
        if isinstance(stmt, ps.CaseStatementSyntax):
            case_expr = getattr(stmt, 'expr', getattr(stmt, 'expression', None))
            if case_expr is not None:
                self._collect_read_signals(case_expr, reads)
            items = getattr(stmt, 'items', [])
            for item in items:
                body = getattr(item, 'statements', getattr(item, 'statement', None))
                if body is not None:
                    self._extract_stmt_signals(body, writes, reads)
            return

        # Block statement
        if isinstance(stmt, ps.BlockStatementSyntax):
            items = getattr(stmt, 'items', getattr(stmt, 'statements', []))
            if items:
                for item in items:
                    self._extract_stmt_signals(item, writes, reads)
            return

        # Loop statements
        if isinstance(stmt, (ps.ForLoopStatementSyntax, ps.ForeachLoopStatementSyntax)):
            body = getattr(stmt, 'statement', getattr(stmt, 'body', None))
            if body is not None:
                self._extract_stmt_signals(body, writes, reads)
            return

        # Iterable container
        if hasattr(stmt, '__iter__') and not isinstance(stmt, str):
            for item in stmt:
                self._extract_stmt_signals(item, writes, reads)
            return

    def _extract_assignment_signals(self, expr, writes: Set[str], reads: Set[str]):
        """Extract LHS (write) and RHS (read) signals from an assignment expression."""
        if expr is None:
            return

        cname = expr.__class__.__name__

        # Check for assignment patterns in syntax nodes
        if 'Assignment' in cname or 'NonblockingAssignment' in cname:
            lhs = getattr(expr, 'left', None)
            rhs = getattr(expr, 'right', None)
            if lhs is not None:
                name = self._get_signal_name_syntax(lhs)
                if name:
                    writes.add(name)
            if rhs is not None:
                self._collect_read_signals(rhs, reads)
            return

        # BinaryExpression with assignment operator
        if 'BinaryExpression' in cname:
            op = getattr(expr, 'operatorToken', None)
            if op is not None:
                op_text = getattr(op, 'valueText', str(op))
                if '=' in op_text:
                    lhs = getattr(expr, 'left', None)
                    rhs = getattr(expr, 'right', None)
                    if lhs is not None:
                        name = self._get_signal_name_syntax(lhs)
                        if name:
                            writes.add(name)
                    if rhs is not None:
                        self._collect_read_signals(rhs, reads)
                    return

        # Fallback: treat entire expression as reads
        self._collect_read_signals(expr, reads)

    def _collect_read_signals(self, expr, reads: Set[str]):
        """Recursively collect all signal names referenced in an expression (syntax node)."""
        if expr is None:
            return

        cname = expr.__class__.__name__

        # Identifier / NameSyntax
        if 'IdentifierName' in cname or 'IdentifierSelectName' in cname:
            name = self._get_signal_name_syntax(expr)
            if name:
                reads.add(name)
            return

        # Try to get identifier directly
        if hasattr(expr, 'identifier'):
            ident = expr.identifier
            if hasattr(ident, 'valueText') and ident.valueText:
                reads.add(ident.valueText)

        # Recurse into children for compound expressions
        for attr in ('left', 'right', 'operand', 'expression', 'expr',
                     'predicate', 'value', 'selector'):
            child = getattr(expr, attr, None)
            if child is not None:
                self._collect_read_signals(child, reads)

        # Handle lists (concatenation operands, etc.)
        for attr in ('operands', 'elements', 'arguments', 'expressions', 'items'):
            children = getattr(expr, attr, None)
            if children is not None and hasattr(children, '__iter__'):
                for child in children:
                    self._collect_read_signals(child, reads)

    def _get_signal_name_syntax(self, expr) -> Optional[str]:
        """Extract signal name from a syntax node."""
        if expr is None:
            return None

        # Direct identifier
        if hasattr(expr, 'identifier'):
            ident = expr.identifier
            if hasattr(ident, 'valueText') and ident.valueText:
                return ident.valueText

        # NameSyntax with name attribute
        if hasattr(expr, 'name'):
            name = expr.name
            if isinstance(name, str):
                return name
            if hasattr(name, 'valueText'):
                return name.valueText

        # ElementSelect / RangeSelect: get base name
        if hasattr(expr, 'value'):
            return self._get_signal_name_syntax(expr.value)

        # Fallback: try string representation
        text = str(expr).strip()
        # Filter out numeric literals and keywords
        if text and text[0].isalpha() and text not in ('begin', 'end', 'if', 'else', 'case'):
            # Take just the identifier part (before any [, (, etc.)
            for delim in ('[', '(', ' ', '.'):
                if delim in text:
                    text = text[:text.index(delim)]
            if text.isidentifier():
                return text

        return None

    def _extract_comb_signals(self, instance_name: str, comb_node):
        """Extract write/read signals from a continuous assignment node."""
        if comb_node is None:
            return

        # ContinuousAssignSyntax has .assigns which contains assignment expressions
        assigns = getattr(comb_node, 'assigns', None)
        if assigns is None:
            assigns = getattr(comb_node, 'assignment', None)
            if assigns is not None:
                assigns = [assigns]
            else:
                return

        if not hasattr(assigns, '__iter__'):
            assigns = [assigns]

        for assign in assigns:
            lhs = getattr(assign, 'left', None)
            rhs = getattr(assign, 'right', None)

            if lhs is None and rhs is None:
                # Try declarator style: assign x = expr
                declarators = getattr(assign, 'declarators', None)
                if declarators:
                    for decl in declarators:
                        name_node = getattr(decl, 'name', None)
                        init = getattr(decl, 'initializer', None)
                        if name_node:
                            name = getattr(name_node, 'valueText', str(name_node))
                            write_reads = set()
                            if init:
                                init_expr = getattr(init, 'expr', getattr(init, 'expression', init))
                                self._collect_read_signals(init_expr, write_reads)
                            self.comb_writes[instance_name][name] = write_reads
                            self.comb_reads[instance_name].update(write_reads)
                continue

            lhs_name = self._get_signal_name_syntax(lhs)
            if lhs_name:
                rhs_reads = set()
                self._collect_read_signals(rhs, rhs_reads)
                self.comb_writes[instance_name][lhs_name] = rhs_reads
                self.comb_reads[instance_name].update(rhs_reads)

    # ------------------------------------------------------------------
    # 2b. Extract cross-module port connections
    # ------------------------------------------------------------------

    def _extract_port_connections(self):
        """Build port mapping between parent and child instances."""
        for instance_name, module in self.modules_dict.items():
            if not hasattr(module, 'body'):
                continue

            # Look for child InstanceSymbol nodes in this instance's body
            for child in module.body:
                if child.kind != ps.SymbolKind.Instance:
                    continue

                child_name = child.name
                # Check if this child is one of our tracked instances
                if child_name not in self.modules_dict:
                    continue

                # Get port connections from the syntax node
                syntax = getattr(child, 'syntax', None)
                if syntax is None:
                    continue

                self._extract_ports_from_syntax(instance_name, child_name, syntax)

    def _extract_ports_from_syntax(self, parent_inst: str, child_inst: str, syntax):
        """Extract named port connections from an instance syntax node."""
        # Look for port connections in the syntax tree
        connections = getattr(syntax, 'connections', None)
        if connections is None:
            # Try portConnections
            connections = getattr(syntax, 'portConnections', None)
        if connections is None:
            # Walk children looking for NamedPortConnectionSyntax
            connections = []
            self._find_port_connections(syntax, connections)

        if not connections:
            return

        for conn in connections:
            cname = conn.__class__.__name__
            if 'NamedPortConnection' not in cname and 'OrderedPortConnection' not in cname:
                # Try to recurse if it's a separator list
                if hasattr(conn, '__iter__'):
                    for item in conn:
                        item_cname = item.__class__.__name__
                        if 'NamedPortConnection' in item_cname:
                            self._process_named_port(parent_inst, child_inst, item)
                continue

            if 'NamedPortConnection' in cname:
                self._process_named_port(parent_inst, child_inst, conn)

    def _process_named_port(self, parent_inst: str, child_inst: str, conn):
        """Process a single named port connection."""
        # Get port name on child
        port_name_node = getattr(conn, 'name', None)
        if port_name_node is None:
            return
        port_name = getattr(port_name_node, 'valueText', str(port_name_node))

        # Get expression in parent scope
        expr = getattr(conn, 'expr', getattr(conn, 'expression', None))
        if expr is None:
            # Implicit connection (.port_name) - parent signal has same name
            parent_signal = port_name
        else:
            parent_signal = self._get_signal_name_syntax(expr)
            if parent_signal is None:
                parent_signal = port_name

        # Store bidirectional mapping
        self.port_map_child_to_parent[(child_inst, port_name)] = (parent_inst, parent_signal)

        key = (parent_inst, parent_signal)
        if key not in self.port_map_parent_to_child:
            self.port_map_parent_to_child[key] = []
        self.port_map_parent_to_child[key].append((child_inst, port_name))

    def _find_port_connections(self, node, result: list):
        """Recursively find NamedPortConnectionSyntax nodes in a syntax tree."""
        if node is None:
            return

        cname = node.__class__.__name__
        if 'NamedPortConnection' in cname:
            result.append(node)
            return

        # Recurse into children
        if hasattr(node, '__iter__') and not isinstance(node, str):
            for child in node:
                self._find_port_connections(child, result)
        else:
            for attr in ('connections', 'portConnections', 'items', 'members', 'arguments'):
                child = getattr(node, attr, None)
                if child is not None and hasattr(child, '__iter__'):
                    for item in child:
                        self._find_port_connections(item, result)

    # ------------------------------------------------------------------
    # 2c. Backward fixpoint analysis
    # ------------------------------------------------------------------

    def analyze(self, seed_signals: List[Tuple[str, str]]) -> COIResult:
        """Run backward COI analysis from seed signals.

        Args:
            seed_signals: List of (instance_name, signal_name) from assertions

        Returns:
            COIResult with relevant CFGs, instances, and cone signals
        """
        result = COIResult()
        visited = set()  # (instance_name, signal_name)
        worklist = deque(seed_signals)

        print(f"[COI] Starting analysis with {len(seed_signals)} seed signal(s)")
        for inst, sig in seed_signals:
            print(f"[COI]   seed: {inst}.{sig}")

        while worklist:
            instance, signal = worklist.popleft()

            if (instance, signal) in visited:
                continue
            visited.add((instance, signal))
            result.cone_signals.add((instance, signal))

            # 1. Find always blocks that write this signal
            if instance in self.cfgs_by_module:
                for cfg_idx in range(len(self.cfgs_by_module[instance])):
                    key = (instance, cfg_idx)
                    if key in self.block_writes and signal in self.block_writes[key]:
                        result.relevant_cfgs.add(key)
                        result.relevant_instances.add(instance)
                        # Add all read signals of this block to worklist
                        if key in self.block_reads:
                            for read_sig in self.block_reads[key]:
                                if (instance, read_sig) not in visited:
                                    worklist.append((instance, read_sig))

            # 2. Check continuous assignments
            if instance in self.comb_writes:
                if signal in self.comb_writes[instance]:
                    result.relevant_instances.add(instance)
                    for read_sig in self.comb_writes[instance][signal]:
                        if (instance, read_sig) not in visited:
                            worklist.append((instance, read_sig))

            # 3. Trace through port connections
            # If signal is a port on a child instance, trace to parent
            if (instance, signal) in self.port_map_child_to_parent:
                parent_inst, parent_sig = self.port_map_child_to_parent[(instance, signal)]
                if (parent_inst, parent_sig) not in visited:
                    worklist.append((parent_inst, parent_sig))

            # If signal in parent drives a child port, trace into child
            if (instance, signal) in self.port_map_parent_to_child:
                for child_inst, port_name in self.port_map_parent_to_child[(instance, signal)]:
                    if (child_inst, port_name) not in visited:
                        worklist.append((child_inst, port_name))

        print(f"[COI] Analysis complete:")
        print(f"[COI]   Relevant instances: {result.relevant_instances}")
        print(f"[COI]   Relevant CFGs: {result.relevant_cfgs}")
        print(f"[COI]   Cone signals: {len(result.cone_signals)}")

        return result
