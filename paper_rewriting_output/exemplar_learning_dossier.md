# Exemplar Learning Dossier

## Exemplar Inventory

1. `iccd2026/prior_work/hacdac2025_draft.tex`: local IEEE-style draft and direct rewrite source, useful for extracting the current section ordering, contribution placement, and evaluation packaging.
2. `iccd2026/prior_work/Ryan-2023-Sylvia Countering the Path Explosion Problem in the Symbolic Ex...-vor.pdf`: closest technical predecessor and a stronger conference exemplar for how to frame a symbolic-execution scalability claim under page pressure.
3. `/home/ljh/.codex/skills/paper-spine-research/references/scenario-conference.md`: not a paper exemplar, but a scene constraint reference confirming that novelty, compressed related work, and tightly selected experiments should dominate the structure.

## Structural Patterns

The HacDAC draft follows a conventional IEEE conference spine: Abstract, Keywords, Introduction, a combined preliminaries-and-motivation section, method, evaluation, related work, and conclusion. Structurally, its strongest move is to bring the motivating example forward and let it bridge background into method, which helps a hardware-verification paper avoid a long pure-survey opening. The draft also places the contribution bullets at the end of the introduction and uses the roadmap sentence immediately after, matching standard conference expectations. Its weaker pattern is overloading the early paper with background detail before the core claim is fully sharpened; for rewriting, the useful lesson is to keep the same overall spine but shorten preliminaries, tighten the motivation-to-method handoff, and reserve technical depth for the pruning section and results section.

The Sylvia FMCAD paper uses a sharper conference structure built around claim compression. The introduction states the problem, names the technique early, quantifies the asymptotic improvement in the introduction itself, and then lists contributions as method, implementation, and evaluation. After that, the paper moves through preliminaries, formalization, algorithm design, implementation, evaluation, related work, and conclusion. This ordering is effective because it escalates from intuition to formal model to system evidence without breaking the thread. For the rewrite, the main structural takeaway is to adopt Sylvia’s front-loaded novelty discipline: define the technical idea early, state why it changes the exploration complexity, then let the later sections justify the claim with one motivating example, one precise method section, and a focused evaluation block rather than repeatedly re-explaining symbolic execution.

## Rhetorical Patterns

Both exemplars present novelty as a direct answer to one bottleneck, not as a broad platform claim. The conference-friendly pattern is: establish hardware-security importance, isolate path explosion as the concrete blocker, show why prior symbolic-execution approaches still leave redundant work, then state one mechanism that removes that waste. Contribution lists are short and typed: observation, technique, implementation, evaluation. Related work is deferred and compressed so the introduction stays claim-first. Limitations are handled implicitly by narrowing scope, such as focusing on one-cycle behavior or combinational logic, instead of apologizing at length.

## Language Patterns

The stronger language pattern is precise, economical, and quantitative. Titles and abstracts name the optimization target directly. Introductions prefer verbs such as “leverage,” “reduce,” “reconstruct,” “prune,” and “evaluate,” which keep the prose technical rather than promotional. Good conference phrasing also couples every qualitative claim with a concrete object: paths, always blocks, clock cycles, assertions, or designs. For the rewrite, the style target should be shorter sentences, earlier naming of the pruning idea, fewer generic statements about verification importance, and faster transition to measurable outcomes and scope boundaries.
