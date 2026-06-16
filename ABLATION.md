# Ablation Study Scripts

This document describes how to run the ablation experiments for the two optimizations in the milestone-directed strategy:

- **Eager Target Evaluation**: before advancing to the next cycle, speculatively checks if the final milestone is already SAT. If so, reports the violation immediately without waiting for the normal milestone progression.
- **Sliding-Window Lookahead**: after each cycle, scans ahead within a window to skip hallucinated milestones (those whose conditions can never be satisfied on the current path) and advance progress automatically.

---

## Scripts

| Script | Benchmark | Assertions | Cycles |
|---|---|---|---|
| `run_or1200.sh` | or1200 RISC CPU | `p1`–`p71` (71 total) | 10 |
| `run_hackatdac18.sh` | HackAtDAC 2018 SoC | `HACKDAC_p2_fixed`, `p3`–`p16`, `p21`, `p27`–`p29` (19 total) | 30 |
| `run_hackatdac19.sh` | HackAtDAC 2019 SoC | `HACKDAC_p1`, `p5`, `p9`, `p21`–`p26`, `p29`, `p32` (11 total) | 30 |
| `run_hackatdac21.sh` | HackAtDAC 2021 SoC | `HACKDAC_p1`, `p2`, `p7`, `p14`, `p18`, `p30`, `p35`, `p36`, `p39`, `p42`, `p46`, `p47`, `p48`, `p57`, `p84`, `p95`, `p96_modified` (17 total) | 30 |

Each script iterates over all milestone JSON files in its `milestones/` subdirectory, isolates one assertion at a time, runs the engine with a 300-second timeout per property, and writes per-property logs under `logs/`.

---

## Usage

```bash
./run_or1200.sh [--no-eager] [--no-sliding] [--both-off]
./run_hackatdac18.sh [--no-eager] [--no-sliding] [--both-off]
./run_hackatdac19.sh [--no-eager] [--no-sliding] [--both-off]
./run_hackatdac21.sh [--no-eager] [--no-sliding] [--both-off]
```

| Flag | Effect | Ablation tag | Log directory |
|---|---|---|---|
| *(none)* | Both optimizations enabled | `full` | `logs/{bench}/full/` |
| `--no-eager` | Disable eager target evaluation | `no_eager` | `logs/{bench}/no_eager/` |
| `--no-sliding` | Disable sliding-window lookahead | `no_sliding` | `logs/{bench}/no_sliding/` |
| `--both-off` | Disable both (baseline) | `baseline` | `logs/{bench}/baseline/` |

---

## Running All Four Conditions

To collect results for a full ablation table, run each condition in turn:

```bash
# or1200
./run_or1200.sh               # full
./run_or1200.sh --no-eager    # w/o eager
./run_or1200.sh --no-sliding  # w/o sliding window
./run_or1200.sh --both-off    # baseline

# HackAtDAC 2018
./run_hackatdac18.sh               # full
./run_hackatdac18.sh --no-eager    # w/o eager
./run_hackatdac18.sh --no-sliding  # w/o sliding window
./run_hackatdac18.sh --both-off    # baseline

# HackAtDAC 2019
./run_hackatdac19.sh               # full
./run_hackatdac19.sh --no-eager    # w/o eager
./run_hackatdac19.sh --no-sliding  # w/o sliding window
./run_hackatdac19.sh --both-off    # baseline

# HackAtDAC 2021
./run_hackatdac21.sh               # full
./run_hackatdac21.sh --no-eager    # w/o eager
./run_hackatdac21.sh --no-sliding  # w/o sliding window
./run_hackatdac21.sh --both-off    # baseline
```

Logs are written to separate directories so all four conditions can coexist:

```
logs/
├── or1200/
│   ├── full/        p1.log  p2.log  ...
│   ├── no_eager/    p1.log  p2.log  ...
│   ├── no_sliding/  p1.log  p2.log  ...
│   └── baseline/    p1.log  p2.log  ...
├── hackatdac18/
│   ├── full/        HACKDAC_p2_fixed.log  ...
│   ├── no_eager/    HACKDAC_p2_fixed.log  ...
│   ├── no_sliding/  HACKDAC_p2_fixed.log  ...
│   └── baseline/    HACKDAC_p2_fixed.log  ...
├── hackatdac19/
│   ├── full/        HACKDAC_p1.log  ...
│   ├── no_eager/    HACKDAC_p1.log  ...
│   ├── no_sliding/  HACKDAC_p1.log  ...
│   └── baseline/    HACKDAC_p1.log  ...
└── hackatdac21/
    ├── full/        HACKDAC_p1.log  ...
    ├── no_eager/    HACKDAC_p1.log  ...
    ├── no_sliding/  HACKDAC_p1.log  ...
    └── baseline/    HACKDAC_p1.log  ...
```

---

## Interpreting Results

Each log file ends with one of:

- `VIOLATION FOUND` — assertion bug detected within the cycle budget
- `No violation found` — no bug within the cycle budget
- `[TIMEOUT after 300s]` — engine did not finish within the time limit

A quick way to count outcomes across a condition:

```bash
# Count violations found
grep -rl "VIOLATION FOUND" logs/or1200/full/ | wc -l

# Count timeouts
grep -rl "TIMEOUT" logs/or1200/full/ | wc -l

# Compare timeout counts across conditions
for tag in full no_eager no_sliding baseline; do
    echo -n "$tag: "
    grep -rl "TIMEOUT" logs/or1200/$tag/ 2>/dev/null | wc -l
done
```

---

## Prerequisites

- Milestone JSON files must exist under `milestones/or1200/`, `milestones/hackatdac18/`, `milestones/hackatdac19/`, and `milestones/hackatdac21/`.
- The assertion/property source files must be present at the paths hardcoded in each script:
  - `designs/benchmarks/or1200/buggy-or1200/or1200_assertions.sv`
  - `designs/benchmarks/hackatdac18/properties.sv`
  - `designs/benchmarks/hackatdac19/properties.sv`
  - `designs/benchmarks/hackatdac21/properties.sv`
- Scripts must be run from the repository root (same directory as `main.py`).
- Each script saves a `.orig` backup of the assertion file on startup and restores it on exit (including Ctrl-C), so the source files are never permanently modified.
