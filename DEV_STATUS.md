# Development Status - Feb 6, 2026

## Completed: Frontend Module for LLM-based Milestone Generation

### New Files
- `frontend/__init__.py` - Package exports
- `frontend/condition_parser.py` - Parses `"RST == 1"` → `(signal, operator, value)`
- `frontend/context_slicer.py` - Extracts RTL source using pyslang
- `frontend/llm_planner.py` - LLM interface with mock mode, supports OpenAI/Anthropic

### New CLI Options (in `main.py`)
```
--auto-plan      Enable LLM-based milestone generation
--target         Verification target (e.g., "test_1.out > 3")
--llm-api-key    API key for LLM
--llm-provider   openai, anthropic, or auto (default)
--mock           Use mock LLM responses for testing
```

### Verified Working Command
```bash
python3 -m main 1 designs/test-designs/test_2.v --sv --auto-plan --target "test_1.out > 3" --mock
```

---

## Known Issues / TODO

### 1. MilestoneDirectedStrategy Termination Problem (HIGH PRIORITY)
**Location:** `engine/strategies.py` - `MilestoneDirectedStrategy.run()`

**Symptom:** The priority queue keeps growing indefinitely:
```
[DirectedStrategy] Explored 100 paths, queue size: 396
[DirectedStrategy] Explored 200 paths, queue size: 796
...
```

**Root Cause:** The strategy adds new work items to the queue without proper termination conditions:
- No max path limit
- No early termination when target milestone is reached
- Each explored path spawns multiple new paths (queue grows faster than it shrinks)

**Suggested Fix:**
1. Add `max_paths` parameter to limit exploration
2. Check if final milestone is satisfied and terminate early
3. Implement proper pruning of low-priority paths
4. Consider deduplication of equivalent states

### 2. Milestone Checking Not Fully Integrated
**Location:** `engine/milestone.py` - `MilestoneManager.check_milestones()`

The milestone checking logic exists but may not be properly integrated with the directed strategy's state evaluation. Need to verify:
- Signal values are correctly extracted from `SymbolicState`
- Z3 solver is used to check milestone conditions against path constraints

### 3. Signal Name Validation in LLM Planner
**Location:** `frontend/llm_planner.py`

The mock milestones use signal names like `RST`, `out` which are base names. The actual signals in the design may have hierarchical paths like `test_1.out`. Need to:
- Decide on naming convention (base name vs full path)
- Update validation logic accordingly

### 4. Context Slicer Instance Resolution
**Location:** `frontend/context_slicer.py`

Currently extracts module definitions but doesn't fully resolve nested instance hierarchies. For target `test_1.out > 3`:
- `test_1` is an instance of `place_holder_2`
- Should extract `place_holder_2` module definition (works)
- Should also include parent module `place_holder` for context (works)

---

## Next Steps (When Resuming)

1. **Fix directed strategy termination** - Add max_paths limit and early termination
2. **Test with real LLM API** - Set `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` env var
3. **Add more mock responses** - For different test designs
4. **Unit tests** - For frontend module components

---

## Quick Test Commands

```bash
# Test frontend pipeline with mock (works)
python3 -m main 1 designs/test-designs/test_2.v --sv --auto-plan --target "test_1.out > 3" --mock

# Test blind strategy (works, baseline)
python3 -m main 1 designs/test-designs/test_2.v --sv --strategy blind

# Test directed strategy without auto-plan (has termination issue)
python3 -m main 1 designs/test-designs/test_2.v --sv --strategy directed
```
