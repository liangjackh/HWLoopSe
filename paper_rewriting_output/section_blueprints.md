# Section Blueprints

## Whole-Paper Throughline

| Element | Blueprint |
|---|---|
| Red thread | Multi-cycle RTL symbolic execution remains expensive because many feasible cycle-to-cycle branches do not move toward the target property; MileSE uses milestones as solver-checked scheduling hints so the engine explores temporally relevant states earlier without letting an LLM or heuristic decide feasibility. |
| Structure | Title and abstract name the bottleneck and response; Introduction narrows from RTL security bugs to temporal path explosion; Background gives the cycle-level semantics and toy example; System/Method explain scheduling, recovery, and solver authority; Implementation explains why RTL semantic support is required; Evaluation Plan states the comparison that must be completed; Related Work positions MileSE between RTL structural symbolic execution and LLM-guided verification. |
| Claim boundary | The paper may claim a milestone-guided prioritization framework and implementation. It may not claim final speedups, universal improvement, or LLM-based bug validation without final evidence. |

## Abstract Blueprint

| Target Unit | Move | Source Evidence | Operation |
|---|---|---|---|
| Abstract sentence group 1 | State the specific bottleneck: deep multi-cycle properties create many feasible but temporally irrelevant states. | E01, E11, E12 | Rewrite |
| Abstract sentence group 2 | Present MileSE as priority scheduling with milestones and distance scoring. | E05, E06, E14 | Rewrite |
| Abstract sentence group 3 | State the correctness boundary: milestones do not constrain feasibility or validate violations. | E01, E14 | Rewrite |
| Abstract sentence group 4 | Name practical mechanisms and evidence status without overclaiming. | E04-E10 | Rewrite |

## Introduction Blueprint

| Target Unit | Move | Source Evidence | Operation |
|---|---|---|---|
| P1 | Establish RTL security/control-logic relevance and immediately focus on deep sequential bugs. | E01 | Rewrite |
| P2 | Explain the gap after intra-cycle/structural optimizations: which cycle frontier should advance? | E12 | Rewrite |
| P3 | Introduce milestones as progress hints and explain solver-owned semantics. | E01, E05, E06 | Rewrite |
| P4 | Explain why robust integration is the research problem: malformed milestones, infeasibility, sparse plans, frontend semantics. | E04, E09 | Rewrite |
| Contributions | Four research bullets: bottleneck, scheduling design, robust implementation, evaluation plan/scope. | E01-E14 | Rewrite |

## Background and Motivation Blueprint

| Target Unit | Move | Source Evidence | Operation |
|---|---|---|---|
| RTL symbolic execution | Define state, path condition, RTL cycle semantics, and why future-cycle selection matters. | Draft, E14 | Rewrite |
| Toy accumulator | Use reset/valid temporal alternatives to make path explosion concrete. | E11 | Keep with tighter explanation |
| Prior optimization contrast | Separate spatial/intra-cycle reduction from temporal frontier prioritization. | E12 | Rewrite |
| Milestones | Define weak progress, observational checking, and scheduling effect. | E01, E02 | Rewrite |
| Failure modes | Convert implementation lessons into method requirements. | E04, E09 | Rewrite |

## System and Method Blueprint

| Target Unit | Move | Source Evidence | Operation |
|---|---|---|---|
| System overview | Present architecture roles: frontend, symbolic state, solver, milestone manager, strategy. | E05-E09, E14 | Rewrite |
| Worklist | Define work item contents and why lazy queue items avoid Cartesian explosion. | E06, E14 | Rewrite |
| Priority function | Explain score as heuristic ranking, not proof rule. | E14 | Rewrite |
| Lazy forking | Explain preferred execution first, bounded siblings later. | E14 | Rewrite |
| Checking/recovery | Make push/pop satisfiability and sliding-window recovery the semantic guardrail. | E01, E04, E05 | Rewrite |
| Local depth | Explain expected-cycle pruning as resource control. | E02, E04 | Keep with rewrite |
| Violation reporting | State solver-driven assertion checks and calibrated reporting. | E01, E14 | Rewrite |

## Implementation Blueprint

| Target Unit | Move | Source Evidence | Operation |
|---|---|---|---|
| Frontend and CFG | Explain PySlang instance traversal, generated subinstances, and CFG sharing. | E07, E09 | Rewrite |
| State updates | Explain NBA commit, fresh inputs, and semantic fixes. | E09, E14 | Rewrite |
| Combinational reevaluation | Explain why derived signals must be fresh for milestone scoring. | E14 | Rewrite |
| COI pruning | Position COI as optional, seeded by assertions and milestones. | E08, E10 | Rewrite |

## Evaluation, Related Work, and Conclusion Blueprint

| Target Unit | Move | Source Evidence | Operation |
|---|---|---|---|
| Evaluation plan | Turn "current status" into a clear experimental design and author-verification placeholders. | E03, E10 | Rewrite |
| Related work | Contrast with structural RTL symbolic execution and LLM-guided DV/search. | E12, E13 | Rewrite |
| Conclusion | Restate the contribution and boundary without "draft" language. | E01-E14 | Rewrite |
