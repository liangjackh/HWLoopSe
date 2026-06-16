#!/bin/bash
# Usage: ./run_or1200.sh [--no-eager] [--no-sliding] [--both-off]
#   --no-eager    : disable eager target evaluation
#   --no-sliding  : disable sliding-window lookahead
#   --both-off    : disable both (baseline)
#   (default)     : both optimizations enabled

EXTRA_FLAGS=""
ABLATION_TAG="full"

for arg in "$@"; do
    case "$arg" in
        --no-eager)   EXTRA_FLAGS="$EXTRA_FLAGS --no-eager-target-eval"; ABLATION_TAG="no_eager" ;;
        --no-sliding) EXTRA_FLAGS="$EXTRA_FLAGS --no-sliding-window";    ABLATION_TAG="no_sliding" ;;
        --both-off)   EXTRA_FLAGS="$EXTRA_FLAGS --no-eager-target-eval --no-sliding-window"; ABLATION_TAG="baseline" ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

MILESTONE_DIR="milestones/or1200"
LOG_DIR="logs/or1200/${ABLATION_TAG}"
FILELIST="or1200_bind.F"
TOP_MODULE="or1200_top"
TIMEOUT_SEC=300
TIMED_OUT_FILES=()

echo "=== Ablation: ${ABLATION_TAG} (extra flags: ${EXTRA_FLAGS:-none}) ==="

# Python helper: comment out all assertion blocks except the target one.
# Usage: python3 -c "..." <assertions.sv> <target_label>
# A "block" is: always @(posedge clk) begin\n    pXX: assert(...\nend
read -r -d '' PY_ISOLATE_OR1200 << 'PYEOF'
import sys, re

assertions_file = sys.argv[1]
target = sys.argv[2]  # e.g. "p31"

with open(assertions_file) as f:
    lines = f.readlines()

out = []
i = 0
while i < len(lines):
    line = lines[i]
    # Detect start of an always block: "always @(posedge clk) begin"
    # (possibly commented out with leading "// ")
    stripped = re.sub(r'^[\s/]*', '', line)
    if re.match(r'always\s*@\s*\(posedge\s+clk\)\s*begin', stripped):
        # Collect the full always block until matching "end"
        block = [line]
        j = i + 1
        depth = 1
        while j < len(lines) and depth > 0:
            block.append(lines[j])
            s = re.sub(r'^[\s/]*', '', lines[j])
            if re.match(r'begin\b', s):
                depth += 1
            if re.match(r'end\b', s):
                depth -= 1
            j += 1

        # Find the assertion label inside this block
        label = None
        for bl in block:
            s = re.sub(r'^[\s/]*', '', bl)
            m = re.match(r'(p\d+)\s*:\s*assert\s*\(', s)
            if m:
                label = m.group(1)
                break

        if label is None:
            # Not an assertion block — keep as-is
            out.extend(block)
        elif label == target:
            # Uncomment: strip leading "// " prefix from each line
            out.extend(re.sub(r'^(\s*)//\s?', r'\1', bl) for bl in block)
        else:
            # Comment out every line
            def ensure_commented(bl):
                core = re.sub(r'^(\s*)//\s?', r'\1', bl)
                indent = re.match(r'^(\s*)', core).group(1)
                rest = core[len(indent):]
                return indent + '// ' + rest
            out.extend(ensure_commented(bl) for bl in block)
        i = j
    else:
        out.append(line)
        i += 1

sys.stdout.write(''.join(out))
PYEOF

ASSERTIONS_FILE="designs/benchmarks/or1200/buggy-or1200/or1200_assertions.sv"
ASSERTIONS_ORIG="${ASSERTIONS_FILE}.orig"
cp "$ASSERTIONS_FILE" "$ASSERTIONS_ORIG"

isolate_assertion() {
    local target="$1"
    python3 -c "$PY_ISOLATE_OR1200" "$ASSERTIONS_FILE" "$target" \
        > "${ASSERTIONS_FILE}.tmp" \
        && mv "${ASSERTIONS_FILE}.tmp" "$ASSERTIONS_FILE"
}

restore_assertions() {
    cp "$ASSERTIONS_ORIG" "$ASSERTIONS_FILE"
}

# Always restore on exit (Ctrl-C, error, etc.)
trap restore_assertions EXIT

mkdir -p "$LOG_DIR"

for milestone_file in "$MILESTONE_DIR"/p*.json; do
    prefix=$(basename "$milestone_file" .json)
    log_file="$LOG_DIR/${prefix}.log"

    echo "Running: $prefix"

    # Isolate this assertion in or1200_assertions.sv
    isolate_assertion "$prefix"

    /usr/bin/time -v \
        timeout "$TIMEOUT_SEC" python3 -m main 10 "$FILELIST" --sv \
        --auto-plan \
        --milestone-file "$milestone_file" \
        --coi \
        --strategy directed \
        -t "$TOP_MODULE" \
        $EXTRA_FLAGS \
        > "$log_file" 2>&1

    exit_code=$?
    if [ $exit_code -eq 124 ]; then
        echo "  TIMEOUT: $prefix"
        TIMED_OUT_FILES+=("$prefix")
        echo "[TIMEOUT after ${TIMEOUT_SEC}s]" >> "$log_file"
    else
        echo "  Done (exit $exit_code)"
    fi

    # Restore original before next iteration
    restore_assertions
done

echo ""
echo "=== Summary ==="
if [ ${#TIMED_OUT_FILES[@]} -eq 0 ]; then
    echo "No timeouts."
else
    echo "Timed out (${#TIMED_OUT_FILES[@]}):"
    for f in "${TIMED_OUT_FILES[@]}"; do
        echo "  - $f"
    done
fi
