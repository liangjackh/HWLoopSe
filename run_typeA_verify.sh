#!/bin/bash
# 验证 Type A 25个 assertion 修复效果

ASSERTIONS_FILE="designs/benchmarks/or1200/buggy-or1200/or1200_assertions_imp.sv"
ASSERTIONS_ORIG="${ASSERTIONS_FILE}.orig"
LOG_DIR="logs/or1200_typeA_verify"
FILELIST="or1200_bind_imp.F"
TOP_MODULE="or1200_top"
TIMEOUT_SEC=300

mkdir -p "$LOG_DIR"

read -r -d '' PY_ISOLATE << 'PYEOF'
import sys, re
assertions_file = sys.argv[1]
target = sys.argv[2]
with open(assertions_file) as f:
    lines = f.readlines()
out = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = re.sub(r'^[\s/]*', '', line)
    if re.match(r'always\s*@\s*\(posedge\s+clk\)\s*begin', stripped):
        block = [line]; j = i + 1; depth = 1
        while j < len(lines) and depth > 0:
            block.append(lines[j]); s = re.sub(r'^[\s/]*', '', lines[j])
            if re.match(r'begin\b', s): depth += 1
            if re.match(r'end\b', s): depth -= 1
            j += 1
        label = None
        for bl in block:
            s = re.sub(r'^[\s/]*', '', bl); m = re.match(r'(p\d+)\s*:\s*assert\s*\(', s)
            if m: label = m.group(1); break
        if label is None:
            out.extend(block)
        elif label == target:
            out.extend(re.sub(r'^(\s*)//\s?', r'\1', bl) for bl in block)
        else:
            def ensure_commented(bl):
                core = re.sub(r'^(\s*)//\s?', r'\1', bl)
                indent = re.match(r'^(\s*)', core).group(1)
                rest = core[len(indent):]
                return indent + '// ' + rest
            out.extend(ensure_commented(bl) for bl in block)
        i = j
    else:
        out.append(line); i += 1
sys.stdout.write(''.join(out))
PYEOF

cp "$ASSERTIONS_FILE" "$ASSERTIONS_ORIG"
trap "cp '$ASSERTIONS_ORIG' '$ASSERTIONS_FILE'" EXIT

TYPE_A="p3 p6 p10 p20 p24 p46 p50 p52 p53 p54 p55 p56 p57 p58 p59 p60 p61 p62 p63 p64 p65 p66 p67 p68 p71"

printf "%-6s %-8s %-14s %-6s %s\n" "NAME" "EXIT" "MILESTONE" "TIME" "LAST_STEP"
printf "%-6s %-8s %-14s %-6s %s\n" "----" "----" "---------" "----" "---------"

for prefix in $TYPE_A; do
    python3 -c "$PY_ISOLATE" "$ASSERTIONS_FILE" "$prefix" \
        > "${ASSERTIONS_FILE}.tmp" && mv "${ASSERTIONS_FILE}.tmp" "$ASSERTIONS_FILE"

    log="$LOG_DIR/${prefix}.log"
    timeout $TIMEOUT_SEC python3 -m main 10 "$FILELIST" --sv \
        --auto-plan --milestone-file "milestones/or1200/${prefix}.json" \
        --coi --strategy directed -t "$TOP_MODULE" \
        > "$log" 2>&1
    code=$?

    last_m=$(grep "Popped:" "$log" | tail -1 | grep -o "milestones=[0-9]*/[0-9]*")
    last_step=$(grep "\[Milestone\] Step" "$log" | tail -1 | sed 's/.*\[Milestone\] //')
    elapsed=$(grep "Total time" "$log" | grep -oP '[0-9]+\.[0-9]+' | head -1)
    if [ $code -eq 124 ]; then
        tag="TIMEOUT"
    elif [ $code -eq 0 ]; then
        tag="OK"
    else
        tag="ERR($code)"
    fi

    printf "%-6s %-8s %-14s %-6s %s\n" "$prefix" "$tag" "${last_m:-?}" "${elapsed:--}" "${last_step:-(none)}"

    cp "$ASSERTIONS_ORIG" "$ASSERTIONS_FILE"
done
