"""Context Slicer for extracting relevant RTL source code."""

import pyslang as ps
from typing import List, Optional, Set, Dict, Any


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

            # Recurse into children
            if hasattr(module, 'body'):
                for child in module.body:
                    if hasattr(child, 'kind') and child.kind == ps.SymbolKind.Instance:
                        collect_instances(child, full_path)

        for module in self.modules:
            collect_instances(module)

    def _extract_source(self, module: Any) -> Optional[str]:
        """
        Extract the raw Verilog source code for a module.

        Args:
            module: A pyslang module instance

        Returns:
            The raw source code string, or None if extraction fails
        """
        try:
            # Try to get the syntax node and its source range
            syntax = None
            if hasattr(module, 'definition') and module.definition:
                definition = module.definition
                if hasattr(definition, 'syntax') and definition.syntax:
                    syntax = definition.syntax

            # Fallback: try module.syntax directly
            if syntax is None and hasattr(module, 'syntax') and module.syntax:
                syntax = module.syntax

            if syntax is None:
                return None

            # Get source range
            sr = syntax.sourceRange
            if callable(sr):
                sr = sr()

            # Extract using buffer ID and offsets
            buffer_id = sr.start.buffer
            start_offset = sr.start.offset
            end_offset = sr.end.offset

            # Get full source text from buffer, then slice
            full_text = self.source_manager.getSourceText(buffer_id)
            return full_text[start_offset:end_offset]

        except Exception as e:
            print(f"[ContextSlicer] Warning: Could not extract source for {module.name}: {e}")

        return None

    def _parse_target_instances(self, target_expr: str) -> Set[str]:
        """
        Parse the target expression to find referenced instance names.

        Args:
            target_expr: A target expression like "test_1.out > 3"

        Returns:
            Set of instance names referenced in the expression
        """
        instances = set()

        # Extract the signal path (left side of comparison)
        # Simple parsing: split by operators and take the first part
        for op in ['==', '!=', '>=', '<=', '>', '<']:
            if op in target_expr:
                signal_path = target_expr.split(op)[0].strip()
                break
        else:
            signal_path = target_expr.strip()

        # Extract instance names from hierarchical path
        if '.' in signal_path:
            parts = signal_path.split('.')
            # All parts except the last are instance names
            for i in range(len(parts) - 1):
                # Build cumulative path
                instance_path = '.'.join(parts[:i+1])
                instances.add(instance_path)
                # Also add individual instance name
                instances.add(parts[i])

        return instances

    def get_context(self, target_expr: str, include_top: bool = True) -> str:
        """
        Get the relevant RTL context for a verification target.

        Args:
            target_expr: The verification target (e.g., "test_1.out > 3")
            include_top: Whether to include the top module source

        Returns:
            Combined Verilog source code of relevant modules
        """
        sources = []
        seen_definitions = set()

        # Parse target to find referenced instances
        target_instances = self._parse_target_instances(target_expr)
        print(f"[ContextSlicer] Target instances: {target_instances}")

        # Extract source for each referenced instance
        for instance_name in target_instances:
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

        # Include top module if requested
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
            # Fallback: return all module sources
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
