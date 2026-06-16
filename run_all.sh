#!/bin/bash

# Run all benchmarks under all four ablation conditions.
# Conditions:
#   (none)       -- full: both optimizations enabled
#   --no-eager   -- sliding window only
#   --no-sliding -- eager target evaluation only
#   --both-off   -- baseline: neither optimization

BENCHMARKS=(
    run_or1200.sh
    #run_hackatdac18.sh
    #run_hackatdac19.sh
    #run_hackatdac21.sh
)

CONDITIONS=(
    ""
    "--no-eager"
    "--no-sliding"
    "--both-off"
)

for bench in "${BENCHMARKS[@]}"; do
    for cond in "${CONDITIONS[@]}"; do
        echo "=============================="
        echo "Running: ./$bench $cond"
        echo "=============================="
        bash "./$bench" $cond
    done
done
