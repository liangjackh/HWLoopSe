"""Factory for creating exploration strategies."""
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from engine.strategies import ExplorationStrategy
    from engine.config import EngineConfig


class StrategyFactory:
    """Factory for creating exploration strategies based on configuration."""

    @staticmethod
    def create(config: "EngineConfig") -> "ExplorationStrategy":
        """Create an exploration strategy based on configuration.

        Args:
            config: Engine configuration containing strategy name and related options

        Returns:
            ExplorationStrategy instance

        Raises:
            ValueError: If strategy name is unknown
        """
        strategy_name = config.strategy.lower()

        if strategy_name == "directed":
            from engine.strategies import MilestoneDirectedStrategy
            from engine.milestone import MilestoneManager

            # Create empty milestone manager - milestones will be populated
            # by auto-plan if enabled, or manually configured
            milestone_manager = MilestoneManager([])
            return MilestoneDirectedStrategy(
                milestone_manager,
                max_cycles=config.num_cycles,
                enable_eager_target_eval=config.enable_eager_target_eval,
                enable_sliding_window=config.enable_sliding_window,
            )

        elif strategy_name == "lookahead":
            # Placeholder for future lookahead strategy (Paper A)
            from engine.strategies import BlindSearchStrategy
            print("[StrategyFactory] Lookahead strategy not yet implemented, falling back to blind")
            return BlindSearchStrategy()

        elif strategy_name == "blind":
            from engine.strategies import BlindSearchStrategy
            return BlindSearchStrategy()

        else:
            raise ValueError(f"Unknown strategy: {strategy_name}. "
                           f"Available: blind, directed, lookahead")
