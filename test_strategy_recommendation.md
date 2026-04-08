# OR1200 Assertion Testing Strategy for Paper Verification

## Current Situation
- **Total assertions**: 71 in `or1200_assertions.sv`
- **Assertion types**: Mix of instruction decoding checks, register file checks, memory consistency, etc.

## Recommended Testing Strategies

### Strategy 1: Category-Based Selection (Recommended for Papers)
Test representative assertions from different categories to demonstrate breadth:

1. **Simple assertions** (easier to violate, good for baseline):
   - `p1`: PC consistency check
   - `p51`: Data consistency check
   
2. **Medium complexity** (instruction-related):
   - `p30-p44`: Register file write checks (RF_WE assertions)
   - `p49-p50`: Specific instruction checks
   
3. **Complex assertions** (multi-signal dependencies):
   - `p5-p6`: Operand comparison checks
   - `p68`: Memory data consistency

**Paper benefit**: Shows your approach works across different complexity levels

### Strategy 2: Bug-Focused Testing
If the "buggy-or1200" has known bugs, select assertions that:
- Are likely to catch those specific bugs
- Demonstrate your tool's effectiveness at finding real issues

### Strategy 3: Incremental Testing
Start with a subset and expand:

```bash
# Phase 1: Test 5 representative assertions (quick validation)
# Modify or1200_assertions.sv to only include p1, p30, p49, p51, p68

# Phase 2: Test 10-15 assertions (medium coverage)
# Add more from different categories

# Phase 3: Full test (if time permits)
# All 71 assertions
```

## Practical Recommendations for Your Paper

### For Experimental Results:
1. **Select 5-10 representative assertions** covering different types
2. **Report metrics for each**:
   - Time to find violation
   - Number of paths explored
   - Milestone effectiveness (if using directed search)
   - Comparison with baseline (blind search)

3. **Show scalability**: 
   - Test with increasing assertion complexity
   - Compare performance across different assertion types

### Creating Focused Test Files

You can create a simplified assertion module with just the assertions you want to test:

```bash
# Create a custom assertion file with selected assertions
cat > designs/benchmarks/or1200/buggy-or1200/or1200_assertions_subset.sv << 'SUBSET'
module or1200_assertions_subset (
    input wire clk,
    input wire rst,
    // ... (only the signals needed for your selected assertions)
);
    always @(posedge clk) begin
        p1: assert ((except_wb_pc == sprs_spr_dat_ppc) || (rst == 1));
        p30: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 47)) || (rf_we == 0) || (rst == 1));
        // ... add more selected assertions
    end
endmodule
SUBSET
```

### Suggested Assertion Subset for Paper (5 assertions):

1. **p1**: Simple PC check - demonstrates basic functionality
2. **p30**: RF write check - common hardware property
3. **p49**: Specific instruction check - shows instruction-level verification
4. **p51**: Data path consistency - multi-signal dependency
5. **p68**: Memory consistency - complex data flow

This gives you:
- ✅ Different complexity levels
- ✅ Different verification aspects (control, data, memory)
- ✅ Manageable test time
- ✅ Clear story for paper

## Command Examples

```bash
# Test with full assertions
python3 -m main 50 or1200.F --sv --auto-plan --llm-provider deepseek --coi --strategy directed -t or1200_top

# Test with subset (after creating subset file)
python3 -m main 50 or1200_subset.F --sv --auto-plan --llm-provider deepseek --coi --strategy directed -t or1200_top
```

## Paper Writing Tips

**Good**: "We evaluated our approach on 5 representative assertions from the OR1200 processor, covering instruction decoding (p30), control flow (p1), data path (p51), and memory consistency (p68)..."

**Better**: "We selected assertions spanning three complexity categories: simple (1 signal), medium (2-3 signals), and complex (4+ signals with dependencies). Our directed search found violations 3.2x faster than blind search on average..."

## Time Estimation

- **Per assertion with directed search**: 1-5 minutes (depending on complexity)
- **5 assertions**: ~15-30 minutes total
- **10 assertions**: ~30-60 minutes total
- **71 assertions**: Several hours (probably not necessary for paper)

## My Recommendation

For a paper submission, I recommend:
1. **Test 5-8 carefully selected assertions** (not all 71)
2. **Show detailed analysis** of these few cases
3. **Demonstrate your approach's advantages** (directed vs blind, COI effectiveness, etc.)
4. **Include one "hard" assertion** that takes longer to show scalability

Quality > Quantity for academic papers!
