"""Configuration dataclass for ExecutionEngine."""
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class EngineConfig:
    """Configuration for the symbolic execution engine.

    Attributes:
        num_cycles: Number of clock cycles to simulate
        include_paths: List of include directories for compilation
        defines: List of macro definitions
        top_module: Name of the top module to analyze (None = auto-detect)
        debug: Enable debug output
        use_cache: Enable Redis query caching
        strategy: Exploration strategy name ('blind', 'directed', 'lookahead')
        auto_plan: Enable LLM-based milestone generation
        llm_api_key: API key for LLM provider
        llm_provider: LLM provider name ('openai', 'anthropic', 'deepseek', 'auto')
        llm_base_url: Custom base URL for LLM API
        llm_mock: Use mock LLM responses for testing
        explore_time: Time limit for exploration in seconds (None = no limit)
        coi: Enable Cone of Influence pruning
    """
    num_cycles: int = 1
    include_paths: List[str] = field(default_factory=list)
    defines: List[str] = field(default_factory=list)
    top_module: Optional[str] = None
    debug: bool = False
    use_cache: bool = False
    strategy: str = "blind"
    auto_plan: bool = False
    milestone_file: Optional[str] = None
    llm_api_key: Optional[str] = None
    llm_provider: str = "auto"
    llm_base_url: Optional[str] = None
    llm_mock: bool = False
    explore_time: Optional[int] = None
    coi: bool = False

    @classmethod
    def from_options(cls, options, num_cycles: int) -> "EngineConfig":
        """Create config from optparse options object.

        Args:
            options: optparse options object
            num_cycles: Number of cycles from command line args

        Returns:
            EngineConfig instance
        """
        return cls(
            num_cycles=int(num_cycles),
            include_paths=options.include or [],
            defines=options.define or [],
            top_module=options.topmodule if options.topmodule != "top" else None,
            debug=options.showdebug or False,
            use_cache=options.use_cache or False,
            strategy=options.strategy or "blind",
            auto_plan=options.auto_plan or False,
            milestone_file=getattr(options, 'milestone_file', None),
            llm_api_key=options.llm_api_key,
            llm_provider=options.llm_provider or "auto",
            llm_base_url=options.llm_base_url,
            llm_mock=options.mock or False,
            explore_time=int(options.explore_time) if options.explore_time else None,
            coi=options.coi or False,
        )
