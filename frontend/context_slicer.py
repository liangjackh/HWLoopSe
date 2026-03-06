"""Context Slicer for extracting relevant RTL source code."""

import re
import pyslang as ps
from typing import List, Optional, Set, Dict, Any, Tuple


class ContextSlicer:
    """
    Extracts relevant RTL source code for a given verification target.

    This class analyzes a target expression (e.g., "test_1.out > 3") and
    extracts only the relevant module source code to minimize LLM token usage.
    """

    def __init__(self, driver: ps.Driver, compilation: Any, modules: List[Any]):
        """
        Initialize the ContextSlicer.

        Args:
            driver: The pyslang Driver (contains sourceManager)
            compilation: The pyslang Compilation object
            modules: List of module instances from compilation.getRoot().topInstances
        """
        self.driver = driver
        self.compilation = compilation
        self.modules = modules
        self.source_manager = driver.sourceManager

        # Build instance name -> module mapping
        self._instance_map: Dict[str, Any] = {}
        self._definition_map: Dict[str, Any] = {}
        # parent_path -> list of child instance modules
        self._children_map: Dict[str, List[Any]] = {}
        self._build_maps()

    def _build_maps(self):
        """Build mappings from instance names and definition names to modules."""
        def collect_instances(module, parent_path=""):
            """Recursively collect all instances."""
            instance_name = module.name
            full_path = f"{parent_path}.{instance_name}" if parent_path else instance_name

            self._instance_map[instance_name] = module
            self._instance_map[full_path] = module

            # Map definition name
            if hasattr(module, 'definition') and module.definition:
                def_name = module.definition.name
                if def_name not in self._definition_map:
                    self._definition_map[def_name] = module

            # Track children
            children = []
            if hasattr(module, 'body'):
                for child in module.body:
                    if hasattr(child, 'kind') and child.kind == ps.SymbolKind.Instance:
                        children.append(child)
                        collect_instances(child, full_path)
            self._children_map[full_path] = children

        for module in self.modules:
            collect_instances(module)

    def _extract_source(self, module: Any) -> Optional[str]:
        """
        Extract the raw Verilog source code for a module.
        """
        try:
            syntax = None
            if hasattr(module, 'definition') and module.definition:
                definition = module.definition
                if hasattr(definition, 'syntax') and definition.syntax:
                    syntax = definition.syntax

            if syntax is None and hasattr(module, 'syntax') and module.syntax:
                syntax = module.syntax

            if syntax is None:
                return None

            sr = syntax.sourceRange
            if callable(sr):
                sr = sr()

            buffer_id = sr.start.buffer
            start_offset = sr.start.offset
            end_offset = sr.end.offset

            full_text = self.source_manager.getSourceText(buffer_id)
            return full_text[start_offset:end_offset]

        except Exception as e:
            print(f"[ContextSlicer] Warning: Could not extract source for {module.name}: {e}")

        return None

    def _extract_signal_names_from_expr(self, target_expr: str) -> Set[str]:
        """
        Extract all signal leaf names from a target expression.
        E.g. "!((or1200_cpu.u_assertions.lsu_dcpu_dat_i == ...))"
        -> {'lsu_dcpu_dat_i', 'mem2reg_memdata', 'rst'}
        """
        # Remove operators and parentheses, extract identifiers
        # Strip Verilog literals like 32'hFC000000, 1'b0, etc.
        cleaned = re.sub(r"\d+'[hbdHBD][0-9a-fA-F_]+", "", target_expr)
        cleaned = re.sub(r"\d+", "", cleaned)
        tokens = re.findall(r'[a-zA-Z_]\w*(?:\.[a-zA-Z_]\w*)*', cleaned)
        signals = set()
        skip = {'assert', 'or', 'and', 'not', 'rst'}
        for tok in tokens:
            if '.' in tok:
                # Take the leaf signal name
                leaf = tok.split('.')[-1]
                if leaf not in skip:
                    signals.add(leaf)
            elif tok not in skip:
                signals.add(tok)
        return signals

    def _find_assertion_module_parent(self, target_expr: str) -> Optional[Tuple[Any, str]]:
        """
        Find the parent module that instantiates the assertion module referenced
        in the target expression.

        Returns (parent_module, parent_full_path) or None.
        """
        # Look for assertion instance path in target, e.g. "or1200_cpu.u_assertions"
        paths = re.findall(r'[a-zA-Z_]\w*(?:\.[a-zA-Z_]\w*)+', target_expr)
        for path in paths:
            parts = path.split('.')
            for i in range(len(parts) - 1):
                inst_name = parts[i]
                child_name = parts[i + 1]
                if 'assert' in child_name.lower():
                    # Found assertion instance, parent is parts[:i+1]
                    if inst_name in self._instance_map:
                        parent = self._instance_map[inst_name]
                        return (parent, inst_name)
        return None

    def _find_sibling_modules_for_signals(self, parent_module: Any, parent_path: str,
                                           signal_names: Set[str]) -> Set[str]:
        """
        Given a parent module and signal names used in an assertion,
        find sibling submodule instances whose ports connect to those signals.

        Returns set of instance names to include in context.
        """
        relevant = set()
        # Get the parent's source to find port connections
        source = self._extract_source(parent_module)
        if not source:
            return relevant

        # For each child instance of the parent, check if its port connections
        # reference any of our target signals
        children = self._children_map.get(parent_path, [])
        for child in children:
            child_name = child.name
            def_name = child.definition.name if hasattr(child, 'definition') and child.definition else child_name
            # Skip the assertion module itself
            if 'assert' in child_name.lower() or 'assert' in def_name.lower():
                continue

            # Check if any of the target signals appear in this child's port connections
            # by looking for the instance in the parent source
            # Pattern: instance_name ( .port(signal), ... )
            # We use a simple heuristic: search for child_name followed by port connections
            # containing our signal names
            pattern = re.compile(
                rf'{re.escape(def_name)}\s+{re.escape(child_name)}\s*\(([^;]*?)\)\s*;',
                re.DOTALL
            )
            match = pattern.search(source)
            if match:
                port_text = match.group(1)
                for sig in signal_names:
                    if sig in port_text:
                        relevant.add(child_name)
                        break

        return relevant

    def _parse_target_instances(self, target_expr: str) -> Set[str]:
        """
        Parse the target expression to find referenced instance names.
        """
        instances = set()

        for op in ['==', '!=', '>=', '<=', '>', '<']:
            if op in target_expr:
                signal_path = target_expr.split(op)[0].strip()
                break
        else:
            signal_path = target_expr.strip()

        if '.' in signal_path:
            parts = signal_path.split('.')
            for i in range(len(parts) - 1):
                instance_path = '.'.join(parts[:i+1])
                instances.add(instance_path)
                instances.add(parts[i])

        return instances

    def get_context(self, target_expr: str, include_top: bool = True, coi_result=None) -> str:
        """
        Get the relevant RTL context for a verification target.

        When the target references an assertion module, this method traces the
        assertion's signal dependencies to include sibling submodules that
        produce those signals, not just the top module.
        """
        sources = []
        seen_definitions = set()

        # If COI result is provided and has relevant instances, use them
        if coi_result is not None and coi_result.relevant_instances:
            print(f"[ContextSlicer] Using COI result: {coi_result.relevant_instances}")
            for instance_name in coi_result.relevant_instances:
                if instance_name in self._instance_map:
                    module = self._instance_map[instance_name]
                    def_name = module.definition.name if hasattr(module, 'definition') and module.definition else module.name

                    if def_name not in seen_definitions:
                        source = self._extract_source(module)
                        if source:
                            sources.append(f"// Module: {def_name} (instance: {instance_name})")
                            sources.append(source)
                            sources.append("")
                            seen_definitions.add(def_name)

            if sources:
                return "\n".join(sources)

        # Strategy: find the assertion module's parent, extract signal names
        # from the target, then find sibling modules that drive those signals
        assertion_signal_names = self._extract_signal_names_from_expr(target_expr)
        parent_info = self._find_assertion_module_parent(target_expr)

        relevant_instances = set()

        if parent_info:
            parent_module, parent_path = parent_info
            print(f"[ContextSlicer] Assertion parent module: {parent_path}")
            print(f"[ContextSlicer] Assertion signals: {assertion_signal_names}")

            # Include the parent module itself
            relevant_instances.add(parent_path)

            # Find sibling submodules connected to assertion signals
            siblings = self._find_sibling_modules_for_signals(
                parent_module, parent_path, assertion_signal_names
            )
            print(f"[ContextSlicer] Relevant sibling modules: {siblings}")

            # Add siblings with full path (parent_path.sibling_name)
            for sibling in siblings:
                full_sibling_path = f"{parent_path}.{sibling}"
                relevant_instances.add(full_sibling_path)
                # Also try just the sibling name in case it's mapped that way
                relevant_instances.add(sibling)
        else:
            # Fallback: parse target for instance names
            relevant_instances = self._parse_target_instances(target_expr)
            print(f"[ContextSlicer] Target instances (fallback): {relevant_instances}")

        # Extract source for each relevant instance
        for instance_name in relevant_instances:
            if instance_name in self._instance_map:
                module = self._instance_map[instance_name]
                def_name = module.definition.name if hasattr(module, 'definition') and module.definition else module.name

                if def_name not in seen_definitions:
                    source = self._extract_source(module)
                    if source:
                        print(f"[ContextSlicer] Adding module {def_name} (instance: {instance_name}), source length: {len(source)}")
                        sources.append(f"// Module: {def_name} (instance: {instance_name})")
                        sources.append(source)
                        sources.append("")
                        seen_definitions.add(def_name)
                    else:
                        print(f"[ContextSlicer] Warning: Could not extract source for {def_name} (instance: {instance_name})")
            else:
                print(f"[ContextSlicer] Warning: Instance '{instance_name}' not found in instance map")

        # Include top module if requested and not already included
        if include_top and self.modules:
            top_module = self.modules[0]
            def_name = top_module.definition.name if hasattr(top_module, 'definition') and top_module.definition else top_module.name

            if def_name not in seen_definitions:
                source = self._extract_source(top_module)
                if source:
                    sources.insert(0, f"// Top Module: {def_name}")
                    sources.insert(1, source)
                    sources.insert(2, "")

        if not sources:
            print("[ContextSlicer] Warning: No specific modules found, returning all sources")
            for module in self.modules:
                source = self._extract_source(module)
                if source:
                    def_name = module.definition.name if hasattr(module, 'definition') and module.definition else module.name
                    if def_name not in seen_definitions:
                        sources.append(f"// Module: {def_name}")
                        sources.append(source)
                        sources.append("")
                        seen_definitions.add(def_name)

        return "\n".join(sources)

    def get_all_instance_names(self) -> List[str]:
        """Return all known instance names."""
        return list(self._instance_map.keys())

    def get_all_definition_names(self) -> List[str]:
        """Return all known module definition names."""
        return list(self._definition_map.keys())
