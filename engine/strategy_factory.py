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

        # Value prediction without milestones: use the value-predict directed
        # strategy instead of blind search, so the §4.2 value predictor drives
        # exploration. Only applies when the user did not already request the
        # directed strategy or provide milestones/auto-plan (those paths build
        # their own MilestoneDirectedStrategy downstream).
        if (getattr(config, "value_predict", False)
                and strategy_name not in ("directed",)
                and not config.milestone_file
                and not config.auto_plan):
            from engine.strategies import ValuePredictDirectedStrategy
            print("[StrategyFactory] value_predict enabled without milestones — "
                  "using value-predict directed strategy")
            return ValuePredictDirectedStrategy(max_cycles=config.num_cycles)

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
