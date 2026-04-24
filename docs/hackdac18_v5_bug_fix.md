# Critical Bug Fix: Wrong Assertions Being Checked

**Date**: 2026-04-24  
**Issue**: All HackAtDAC18 benchmarks were checking the same assertion (HACKDAC_p10)

## Root Cause

The `isolate_property()` function in `run_hackatdac18.sh` only handled **uncommented** property blocks. Since all properties except `HACKDAC_p10` were commented out in `properties.sv`, the script failed to uncomment the target property for each run.

**Result**: Every benchmark run checked `(passchk == 1) |-> (bitindex == 32)` regardless of the milestone JSON target.

## Evidence

From log analysis:
```
HACKDAC_p3:  JSON target: priv_lvl_n == 2'b11 && mstatus_n.mpp == 2'b00
             Actual assertion: (passchk == 1) |-> (bitindex == 32)

HACKDAC_p4:  JSON target: PWDATA == 0x12345678 && s_apb_addr == 5'b10010 && r_gpio_lock == 0x12345678
             Actual assertion: (passchk == 1) |-> (bitindex == 32)

HACKDAC_p6:  JSON target: GPIO_START_ADDR == 0x1A101000 && GPIO_END_ADDR == 0x1A101FFF
             Actual assertion: (passchk == 1) |-> (bitindex == 32)
```

All 12 problems checked the p10 assertion.

## Fix Applied

Updated the Python script in `run_hackatdac18.sh` to:

1. **Detect both commented and uncommented properties**:
   ```python
   stripped = re.sub(r'^[\s/]*', '', line)
   m = re.match(r'(HACKDAC_\w+)\s*:\s*(assert|cover)\s+property\s*\(', stripped)
   ```

2. **Uncomment the target property**:
   ```python
   if prop_name == target:
       out.extend(re.sub(r'^(\s*)//\s?', r'\1', bl) for bl in block_raw)
   ```

3. **Ensure all other properties are commented**:
   ```python
   else:
       def ensure_commented(bl):
           core = re.sub(r'^(\s*)//\s?', r'\1', bl)
           indent = re.match(r'^(\s*)', core).group(1)
           rest = core[len(indent):]
           return indent + '// ' + rest
       out.extend(ensure_commented(bl) for bl in block_raw)
   ```

## Validation

Tested the fix on multiple targets:
```
HACKDAC_p3: uncommented=['HACKDAC_p3']
HACKDAC_p4: uncommented=['HACKDAC_p4']
HACKDAC_p6: uncommented=['HACKDAC_p6']
HACKDAC_p9: uncommented=['HACKDAC_p9']
HACKDAC_p10: uncommented=['HACKDAC_p10']
HACKDAC_p16: uncommented=['HACKDAC_p16']
HACKDAC_p27: uncommented=['HACKDAC_p27']
```

Each target correctly uncomments only its own property.

## Impact on Previous Results

The v5 results are **invalid** for most benchmarks:

**False positives** (succeeded but checked wrong assertion):
- p6, p8: Succeeded because their violations are unconditional constants
- p11, p14, p16: Unclear why they succeeded — need investigation

**False negatives** (timed out because checking wrong assertion):
- p3, p4, p5, p9, p10, p13, p27: All timed out trying to reach milestones for bug X while checking assertion for bug Y

## Next Steps

1. **Re-run the full benchmark suite** with the fixed script
2. **Compare new results** to identify which bugs are actually solvable
3. **Investigate p11/p14/p16** to understand why they succeeded despite checking the wrong assertion
4. **Update memory** with lessons learned about property isolation

## Files Modified

- `run_hackatdac18.sh`: Fixed `isolate_property()` Python script (lines 14-57)
