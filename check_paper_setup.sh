#!/bin/bash
# Quick validation script for paper verification setup

echo "=========================================="
echo "OR1200 Paper Verification Setup Check"
echo "=========================================="
echo ""

# Check if files exist
echo "[1/5] Checking files..."
files=(
    "or1200_subset.F"
    "designs/benchmarks/or1200/buggy-or1200/or1200_assertions_subset.sv"
    "PAPER_VERIFICATION_GUIDE.md"
)

all_exist=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
        all_exist=false
    fi
done

if [ "$all_exist" = false ]; then
    echo ""
    echo "ERROR: Some files are missing. Please check the setup."
    exit 1
fi

echo ""
echo "[2/5] Checking Python environment..."
if python3 -c "import pyslang" 2>/dev/null; then
    echo "  ✓ PySlang installed"
else
    echo "  ✗ PySlang not found"
    exit 1
fi

if python3 -c "import z3" 2>/dev/null; then
    echo "  ✓ Z3 installed"
else
    echo "  ✗ Z3 not found"
    exit 1
fi

echo ""
echo "[3/5] Checking compilation..."
timeout 30 python3 -m main 1 or1200_subset.F --sv -t or1200_top 2>&1 | grep -q "Found.*module instance"
if [ $? -eq 0 ]; then
    echo "  ✓ Design compiles successfully"
else
    echo "  ✗ Compilation failed"
    exit 1
fi

echo ""
echo "[4/5] Checking assertion detection..."
assertion_count=$(timeout 30 python3 -m main 1 or1200_subset.F --sv -t or1200_top 2>&1 | grep -c "Found.*unique assertion")
if [ "$assertion_count" -gt 0 ]; then
    echo "  ✓ Assertions detected (found in output)"
else
    echo "  ⚠ Assertions not detected in quick test (may need longer run)"
fi

echo ""
echo "[5/5] Checking LLM provider..."
if [ -n "$DEEPSEEK_API_KEY" ]; then
    echo "  ✓ DEEPSEEK_API_KEY is set"
elif [ -n "$OPENAI_API_KEY" ]; then
    echo "  ✓ OPENAI_API_KEY is set"
else
    echo "  ⚠ No LLM API key found (you can use --mock-llm for testing)"
fi

echo ""
echo "=========================================="
echo "Setup Check Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Read PAPER_VERIFICATION_GUIDE.md for detailed instructions"
echo "2. Run quick test:"
echo "   python3 -m main 10 or1200_subset.F --sv --coi -t or1200_top"
echo ""
echo "3. Run full experiment:"
echo "   python3 -m main 50 or1200_subset.F --sv --auto-plan \\"
echo "           --llm-provider deepseek --coi --strategy directed \\"
echo "           -t or1200_top"
echo ""
echo "Good luck with your paper! 🚀"
