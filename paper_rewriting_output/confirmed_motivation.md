# Confirmed Motivation

- User confirmation status: confirmed by user on 2026-05-29
- Selected option: A

## Exact Confirmed Motivation

Multi-cycle RTL symbolic execution still wastes most effort on temporally irrelevant branches, so this paper should present a solver-driven way to prioritize states using milestone guidance.

## Rejected Options And Why

- Option B: rejected because it is close to the selected motivation but frames the paper too much as a rebuttal to prior pruning work rather than as a clean statement of the paper's own contribution.
- Option C: rejected because it is too implementation-specific and too narrow to serve as the main throughline for the whole paper.

## Scope Limits

- The paper should claim milestone-guided search prioritization for deep multi-cycle RTL verification.
- The paper should keep solver-based feasibility and bug detection as the correctness authority.
- The paper should treat milestone parsing, recovery, and bounded local depth as enabling mechanisms for the search policy.
- The paper should emphasize practical improvement on deep sequential properties rather than broad claims about all RTL verification workloads.

## Forbidden Overclaims

- Do not claim that the LLM replaces formal reasoning, solver checks, or bug validation.
- Do not claim universal improvement across all properties, benchmarks, or RTL designs without evidence.
- Do not present the contribution as a general AI verification framework.
- Do not inflate benchmark-specific protocol knowledge into a scene-wide theorem.
