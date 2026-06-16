# Evidence Bank

This bank records evidence available for the MileSE rewrite. It is deliberately conservative: no numerical speedup or benchmark result should be written as a finding unless the author later supplies final logs/tables.

| Evidence ID | Evidence Source | What It Supports | Manuscript Use | Claim Strength |
|---|---|---|---|---|
| E01 | `paper_rewriting_output/confirmed_motivation.md` | The confirmed paper spine is milestone-guided prioritization for multi-cycle RTL symbolic execution. | Title, abstract, introduction, contribution framing, conclusion. | Authoritative for this rewrite. |
| E02 | `summary.md` methodology workflow | Milestones are derived from properties, RTL modules, reset behavior, FSM transitions, counters, APB handshakes, and exact signal names. | Background motivation, milestone construction, evaluation methodology. | Strong for method rationale; not a performance result. |
| E03 | `summary.md` property categories | HACK@DAC-style properties include combinational, sequential write, FSM-dependent, counter-threshold, and constant/parameter cases. | Evaluation-plan scope and robustness discussion. | Strong for benchmark diversity if author verifies final benchmark set. |
| E04 | `summary.md` lessons learned | Hierarchical signal names, `_n` vs `_q`, parameters vs signals, and expected cycle estimates materially affect milestone quality. | Milestone failure modes and recovery rationale. | Strong implementation evidence. |
| E05 | `docs/CHANGELOG.md` 2026-02-10 | Compound milestone conditions are parsed into simple/compound condition trees and converted to Z3 expressions. | System overview and milestone parsing. | Strong implementation evidence. |
| E06 | `docs/CHANGELOG.md` 2026-02-06 | Strategy pattern separates blind search and milestone-directed search. | Worklist organization and evaluation baselines. | Strong implementation evidence. |
| E07 | `docs/CHANGELOG.md` 2026-02-05 | CFGs are built once per module definition and shared across instances while preserving per-instance state. | Frontend/CFG construction. | Strong implementation evidence. |
| E08 | `docs/CHANGELOG.md` 2026-02-04 | LHS signal tracking and assertion extraction support COI analysis. | COI pruning subsection. | Strong implementation evidence. |
| E09 | `docs/BUGFIX_NOTES.md` | PySlang instance handling, submodule traversal, and if-without-else skip paths affected path discovery. | RTL semantic coverage and implementation credibility. | Strong for implementation necessity. |
| E10 | `PAPER_VERIFICATION_GUIDE.md` | OR1200 subset experiments are planned for directed search with COI, directed search without COI, and blind search. | Evaluation methodology section. | Planning evidence only; mark final values as author-verify. |
| E11 | Draft listing `toy_accumulator` | Reset/stall alternatives create many temporal combinations before the assertion violation. | Motivating example. | Strong illustrative evidence, not benchmark evidence. |
| E12 | `citation_support_bank.md` C01/C13 | Prior RTL symbolic execution exploits hardware structure to reduce intra-cycle work. | Introduction gap and related work. | Literature support; no TeX citation inserted because no `.bib` exists. |
| E13 | `citation_support_bank.md` C02-C06 | LLMs can guide symbolic execution, tests, or hardware DV tasks but remain heuristic. | Related work and LLM scope limits. | Literature support; no TeX citation inserted because no `.bib` exists. |
| E14 | Draft implementation text | PySlang frontend, Z3 backend, priority queue, distance heuristic, lazy forking, recovery, expected cycles, targeted recomputation. | Method and implementation sections. | Strong if verified against code; no performance magnitude implied. |

## Claims Allowed In The Rewrite

| Claim | Evidence IDs | Wording Constraint |
|---|---|---|
| Multi-cycle RTL symbolic execution wastes effort on temporally irrelevant branches. | E01, E02, E11, E12 | State as motivation/observation; avoid universal quantification over all designs. |
| MileSE uses milestones only to prioritize work items. | E01, E05, E06, E14 | Must explicitly say solver checks still decide feasibility and violations. |
| Compound parsing, expected-cycle budgets, recovery, and semantic RTL support are necessary practical mechanisms. | E04, E05, E09, E14 | Present as implementation design choices, not as independently evaluated ablations unless final data exists. |
| Evaluation should compare blind search, directed search, and directed+COI on deep sequential properties. | E03, E10 | Frame as methodology/current evaluation plan until logs/tables are supplied. |

## Claims To Avoid

| Avoided Claim | Reason |
|---|---|
| MileSE is sound because milestones guide it. | Milestones are scheduling hints; soundness authority remains solver feasibility and assertion checking. |
| MileSE universally improves all RTL verification workloads. | Confirmed motivation forbids universal overclaims and final quantitative data is not present. |
| The LLM validates bugs or replaces formal reasoning. | Forbidden by confirmed motivation and contradicted by method design. |
| Specific speedup values. | `PAPER_VERIFICATION_GUIDE.md` contains expected/example values, not final verified results. |
