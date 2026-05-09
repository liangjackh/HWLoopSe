#!/bin/bash

MILESTONE_DIR="milestones/hackatdac21"
LOG_DIR="logs/hackatdac21"
PROPERTIES_SV="designs/benchmarks/hackatdac21/properties.sv"
TIMEOUT_SEC=300  # 5 minutes
TIMED_OUT_FILES=()

# Python helper: comment out all property blocks except the target one.
# Usage: python3 -c "..." <properties.sv> <target_name>
# Prints the modified file content to stdout.
# A "property block" is a line matching /^\s*HACKDAC_\w+:/ up to the closing ");"
# Already-commented blocks (// HACKDAC_...) are left untouched.
read -r -d '' PY_ISOLATE << 'PYEOF'
import sys, re

props_file = sys.argv[1]
target     = sys.argv[2]

with open(props_file) as f:
    content = f.read()

lines = content.splitlines(keepends=True)
out   = []
i     = 0
while i < len(lines):
    line = lines[i]

    # Strip leading whitespace+comment prefix to find property declarations,
    # handling both uncommented and commented-out blocks.
    stripped = re.sub(r'^[\s/]*', '', line)
    m = re.match(r'(HACKDAC_\w+)\s*:\s*(assert|cover)\s+property\s*\(', stripped)
    if m:
        prop_name = m.group(1)
        # Collect the full block until paren depth returns to 0.
        # Work on the stripped content for depth counting.
        block_raw = [line]
        depth = stripped.count('(') - stripped.count(')')
        j = i + 1
        while j < len(lines) and depth > 0:
            block_raw.append(lines[j])
            s = re.sub(r'^[\s/]*', '', lines[j])
            depth += s.count('(') - s.count(')')
            j += 1

        if prop_name == target:
            # Uncomment every line: strip leading //\s* prefix
            out.extend(re.sub(r'^(\s*)//\s?', r'\1', bl) for bl in block_raw)
        else:
            # Ensure every line is commented out
            def ensure_commented(bl):
                core = re.sub(r'^(\s*)//\s?', r'\1', bl)  # strip existing comment
                indent = re.match(r'^(\s*)', core).group(1)
                rest = core[len(indent):]
                return indent + '// ' + rest
            out.extend(ensure_commented(bl) for bl in block_raw)
        i = j
    else:
        out.append(line)
        i += 1

sys.stdout.write(''.join(out))
PYEOF

isolate_property() {
    local target="$1"
    python3 -c "$PY_ISOLATE" "$PROPERTIES_SV" "$target" > "${PROPERTIES_SV}.tmp" \
        && mv "${PROPERTIES_SV}.tmp" "$PROPERTIES_SV"
}

# Save original properties.sv once
PROPERTIES_ORIG="${PROPERTIES_SV}.orig"
cp "$PROPERTIES_SV" "$PROPERTIES_ORIG"

restore_properties() {
    cp "$PROPERTIES_ORIG" "$PROPERTIES_SV"
}

# Always restore on exit (Ctrl-C, error, etc.)
trap restore_properties EXIT

for milestone_file in "$MILESTONE_DIR"/*.json; do
    prefix=$(basename "$milestone_file" .json)
    log_file="$LOG_DIR/${prefix}.log"

    echo "Running: $prefix"

    # Isolate this property in properties.sv
    isolate_property "$prefix"

    timeout "$TIMEOUT_SEC" python3 -m main 30 hackdac21.F --sv \
        --auto-plan \
        --milestone-file "$milestone_file" \
        --coi \
        --strategy directed \
        -t top_wrapper_dac21 \
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
    restore_properties
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
