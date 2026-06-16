# Rewrite Matrix

| Section | Unit ID | Current Function | Motivation Link | Operation | Intended Move | Evidence Source | Model Pattern | Target Length | Logic Change | Decision |
|---|---|---|---|---|---|---|---|---|---|---|
| Whole paper | W1 | Present MileSE as a milestone-guided RTL symbolic execution framework. | Confirmed motivation requires temporal path prioritization under solver authority. | REWRITE | Build a single problem-solution arc across all section openings. | E01-E14 | Conference claim compression. | Whole manuscript. | Structural/rhetorical. | Rewrite around "temporally irrelevant branches -> milestone scheduling -> solver validation." |
| Abstract | A1 | Problem plus method plus implementation list. | Needs immediate bottleneck and scoped contribution. | REWRITE | One compact abstract with problem, method, guardrail, mechanisms, evidence boundary. | E01, E05-E10, E14 | Problem-method-boundary abstract. | 1 paragraph. | Rhetorical/evidence. | Remove "current draft"; avoid speedup claims. |
| Introduction | I1 | Broad SoC security setup. | Must narrow quickly to deep sequential RTL bugs. | REWRITE | Compress field problem and define temporal path explosion. | E01, E12 | Front-loaded bottleneck. | 2 paragraphs. | Rhetorical. | Reduce generic background. |
| Introduction | I2 | Milestone idea and LLM role. | Milestones must be scheduling hints only. | REWRITE | State property/planner-derived waypoints and solver validation. | E01, E05, E06 | Correctness-boundary statement. | 1 paragraph. | Structural/rhetorical. | LLM becomes optional source, not authority. |
| Introduction | I3 | Failure modes and contributions. | Practical mechanisms support the central search policy. | REWRITE | Turn risks into contributions. | E04, E09, E14 | Typed contribution list. | 1 paragraph + bullets. | Structural. | Delete meta-writing bullet. |
| Background | B1 | Define symbolic execution. | Supports cycle-level search decisions. | REWRITE | Tie state tuple and RTL semantics to frontier scheduling. | Draft, E14 | Minimal preliminaries. | 3 paragraphs. | Rhetorical. | Keep necessary formal terms only. |
| Background | B2 | Toy accumulator example. | Concrete example of temporal waste. | REWRITE | Use reset/valid/stall alternatives to motivate milestones. | E11 | Motivating example. | Listing plus 2 paragraphs. | Rhetorical. | Preserve listing/label. |
| Background | B3 | Milestones and failure modes. | Explains design requirements. | REWRITE | Define progress hints and risks. | E02, E04, E05, E09 | Gap-to-requirement transition. | 4 subsections. | Structural/rhetorical. | Make failure modes feed method. |
| System Overview | S1 | Component overview. | Shows architecture supporting solver-driven milestone scheduling. | REWRITE | Role-based architecture: frontend, execution core, milestone manager, strategy. | E05-E09, E14 | Systems architecture overview. | 4 paragraphs. | Rhetorical. | Avoid raw implementation dump. |
| Method | M1 | Worklist queue. | Central scheduling mechanism. | REWRITE | Define work item and lazy resume context. | E06, E14 | Algorithmic description. | 2 paragraphs. | Rhetorical. | Keep concept. |
| Method | M2 | Priority equation. | Operationalizes milestone prioritization. | REWRITE | Clarify remaining milestones, cycle, distance, capped tie-breaker. | E14 | Heuristic score explanation. | Equation + 3 paragraphs. | Rhetorical. | Keep equation. |
| Method | M3 | Lazy forking. | Avoids expanding irrelevant branches early. | REWRITE | Preferred path first, bounded siblings later. | E06, E14 | Queue-control design. | 2 paragraphs. | Rhetorical. | Remove anecdotal language. |
| Method | M4 | Checking, recovery, local depth, violation reporting. | Guardrails keep milestones from replacing formal reasoning. | REWRITE | Solver push/pop, hallucinated skip, small lookahead, expected cycles, solver-driven assertions. | E01, E02, E04, E05, E14 | Heuristic-with-guardrails. | 5 subsections. | Evidence/structural. | Keep formulas and caveats. |
| Implementation | P1 | Frontend/CFG and state updates. | RTL semantic coverage makes milestone observations meaningful. | REWRITE | Link PySlang features and bug fixes to milestone correctness. | E07-E09, E14 | Implementation rationale. | 4 subsections. | Evidence/rhetorical. | Compress list into rationale. |
| Evaluation | E1 | Current status and questions. | Needs evidence contract for central claim. | REWRITE | State benchmark families, baselines, metrics, and `[AUTHOR VERIFY]` placeholders. | E03, E10 | Evaluation methodology under pending results. | 5 paragraphs + bullets. | Structural/evidence. | Avoid final numbers. |
| Related Work | RW1 | Short contrast. | Position contribution between RTL structural SE and LLM guidance. | REWRITE | Expand contrast without new unresolved citations. | C01-C06, C13-C15. | Contrastive related work. | 3 paragraphs. | Rhetorical. | Leave bibliography integration for later. |
| Conclusion | C1 | Restate draft. | Close paper contribution and boundary. | REWRITE | State what MileSE contributes and what final evaluation must show. | E01-E14 | Bounded conclusion. | 1 paragraph. | Rhetorical. | Remove "This draft." |

## Section Audits

| Section | All Obligatory Moves Present | Red Thread Advanced | Numbers Traced | Claims Calibrated | LaTeX Commands Preserved |
|---|---|---|---|---|---|
| Abstract | pass | pass | pass: no numbers introduced | pass | applicable |
| Introduction | pass | pass | pass: no numbers introduced | pass | applicable |
| Background | pass | pass | pass: toy constants preserved | pass | labels/listing preserved |
| Method | pass | pass | pass: formula constants preserved from draft | pass | equations preserved |
| Implementation | pass | pass | pass: no new numbers | pass | section labels preserved |
| Evaluation | pass as methodology | pass | pass: uses `[AUTHOR VERIFY]` placeholders | pass | applicable |
| Related Work | pass | pass | pass: no unresolved citation commands introduced | pass | applicable |
| Conclusion | pass | pass | pass | pass | applicable |
