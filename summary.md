# Milestone Generation for Directed Symbolic Execution — Methodology Summary

## Overview

This document summarizes the methodology used to generate milestone JSON files for the HACKatDAC 2018 benchmark (`hackdac18`). Milestones are waypoints that steer the symbolic execution engine toward a verification target, reducing path explosion by providing temporal guidance.

---

## Workflow

### Step 1: Parse the Property File

Read `properties.sv` (or the equivalent JasperGold `.tcl` property list) and extract:
- Property name (e.g., `HACKDAC_p2_fixed`)
- Trigger condition (antecedent of `|->` or `|=>`)
- Target condition (consequent, or the negated assertion body)
- Module scope (hierarchical path prefix, e.g., `top_wrapper.soc_interconnect`)

Strip all SVA temporal operators (`|->`, `|=>`, `##N`, `$rose`, `$past`, `@(posedge clk)`). Only keep the boolean expressions.

### Step 2: Identify the Relevant RTL Module

For each property, trace the hierarchical signal path to the owning module. Read the module source to understand:
- Is the logic **combinational** or **sequential**?
- Are there **FSM states** that must be traversed?
- Are there **counters** that must reach a threshold?
- What are the **exact signal names** (avoid guessing — always grep the source)?

### Step 3: Calculate `expected_cycles`

| Logic Type | Cycle Estimate |
|---|---|
| Pure combinational (assign) | 1 cycle |
| Single sequential register update | 1–2 cycles |
| FSM transition (N states to traverse) | N cycles |
| Counter reaching threshold T | T cycles |
| Pipeline with D stages | D cycles |
| CDC synchronizer (2-stage) | 2 cycles |

For long-running counters (e.g., `rtc_clock.r_sec_counter` at 32,768 cycles/second), use the actual counter threshold as `expected_cycles`. The engine's margin will handle small deviations.

### Step 4: Construct the Milestone Sequence

Every property must follow this structure:

1. **Step 0** — Reset: `condition: "rst_n == 0"` (or `rstn_top == 0`). Only the reset signal. No other conditions.
2. **Intermediate steps** — Bridge the gap between reset and the violation. Each step must be reachable only AFTER the previous one.
3. **Final step** — The exact violation condition (negation of the assertion, or the antecedent + negated consequent for `|->` properties).

---

## Property Classification

### Category A: Combinational / Single-Cycle Violations

These properties check conditions that can be violated in a single clock cycle after reset. Milestones only need reset + 1–2 intermediate steps.

| Property | Module | Key Signal | Cycles to Violation |
|---|---|---|---|
| p2_fixed | soc_interconnect | FC_DATA_gnt_o, FC_DATA_add_i | 3–4 |
| p3 | riscv_cs_registers | priv_lvl_n, mstatus_n.mpp | 3–4 |
| p7 | axi_address_decoder_AR | outstanding_trans_i, CS, NS | 2–3 |
| p11 | riscv_debug_unit | dbg_halt, rdata_sel_n | 3–4 |
| p14 | riscv_alu | vector_mode_i, adder_in_a[18] | 3–4 |
| p21 | mux_func | c, temperature_out | 2–3 |
| p27 | riscv_cs_registers | csr_we_int, PULP_SECURE | 3–4 |
| p28 | jtag_tap_top | td_i | 2 |
| p29 | mux_func | aes_out, c | 1–2 |

### Category B: Sequential Write / Register Update

These require an APB/AXI write transaction to complete before the violation is observable. Milestones must include the write-enable handshake.

| Property | Module | Key Signal | Cycles to Violation |
|---|---|---|---|
| p4 | apb_gpio | PWDATA, s_apb_addr, r_gpio_lock | 4–5 |
| p5 | apb_gpio | HRESETn, r_gpio_lock | 3–4 |

**APB write sequence**: `PSEL=1` → `PENABLE=1 && PWRITE=1` → register updated (next cycle).

### Category C: FSM-Dependent Violations

These require the design's FSM to traverse specific states before the violation can occur.

| Property | Module | FSM | States to Traverse | Cycles |
|---|---|---|---|---|
| p13 | riscv_controller | ctrl_fsm_ns | RESET→BOOT_SET→FIRST_FETCH→DECODE | 4–5 |

**RISC-V controller FSM** (5-bit enum, 16 states):
- `RESET = 5'b00000`, `BOOT_SET = 5'b00001`, `FIRST_FETCH = 5'b00100`, `DECODE = 5'b00101`

### Category D: Counter-Threshold Violations

These require a counter to reach a specific value. `expected_cycles` must match the counter threshold.

| Property | Module | Counter | Threshold | Cycles |
|---|---|---|---|---|
| p15 | rtc_clock | r_sec_counter → r_seconds | 32,768 per second | 32,768 |
| p9/p10 | adbg_tap_top | correct, bitindex | correct >= 131,071 | 5–10 (symbolic) |
| p12 | adbg_tap_top | correct | passchk asserted | 5–10 (symbolic) |
| p16 | adbg_tap_top | correct | trstn_pad_i reset | 3–4 |

**Note on adbg_tap_top**: The password check requires `correct >= 32'h0001_FFFF` (131,071 matches). In symbolic execution, the engine can find a satisfying assignment without iterating all cycles — use a small `expected_cycles` (5–10) and let Z3 solve the constraint directly.

### Category E: Constant / Parameter Violations

These check compile-time constants (address defines). They are trivially violated or satisfied based on the `periph_bus_defines.sv` values. No sequential behavior needed.

| Property | Condition | Actual Values | Violated? |
|---|---|---|---|
| p6 | GPIO_START_ADDR == 0x1A101000 && GPIO_END_ADDR == 0x1A101FFF | START=0x1A101000, END=0x1A10AFFF | YES (END wrong) |
| p8 | No overlap between GPIO, UDMA, SOC_CTRL | GPIO END (0x1A10AFFF) > UDMA START (0x1A102000) | YES (overlap) |

For these, milestones are degenerate (reset + immediate violation check).

---

## Key RTL Insights

### soc_interconnect
- `FC_DATA_gnt_o` is driven by a combinational assign: `{FC_INSTR_gnt_o, ..., FC_DATA_gnt_o} = FC_data_gnt_INT_32`
- Address remapping: if `FC_DATA_add_i[31:20] == 12'h000`, it is remapped to `12'h1C0` before routing
- Grant is issued in the same cycle as the request (combinational arbitration through XBAR_L2)

### riscv_cs_registers
- `priv_lvl_n` and `mstatus_n` are **next-state** signals (combinational), registered on posedge clk
- `PULP_SECURE` is a **parameter** (not a runtime signal) — always 0 in this configuration
- `csr_we_int` is the write-enable gate for all CSR updates

### apb_gpio
- `r_gpio_lock` is at APB address `5'b10010` (offset 0x48)
- Write sequence: `PSEL=1 && PENABLE=1 && PWRITE=1 && s_apb_addr==5'b10010` → `r_gpio_lock <= PWDATA` (next cycle)
- `s_apb_addr = PADDR[6:2]` (word-addressed)

### adbg_tap_top
- Password: `pass = 32'hDEADBEEF` (hardcoded)
- `passchk` is set when `correct >= 32'h0001_FFFF` — this is the bug: should be `>= 32` (one per bit)
- `bitindex` is 5-bit but `correct` is 32-bit, allowing `correct` to exceed 31 without `bitindex` reaching 32

### riscv_controller
- FSM is a 5-bit enum with 16 states
- Normal boot path: `RESET(0) → BOOT_SET(1) → FIRST_FETCH(4) → DECODE(5)`
- The p13 bug: DECODE state can loop back to itself (missing transition out)

### rtc_clock
- `r_sec_counter` is 15-bit, increments every cycle
- `s_update_seconds = (r_sec_counter == 15'h7FFF)` — fires every 32,768 cycles
- `r_seconds` is BCD: tens digit in `[7:4]`, units in `[3:0]`
- Bug: wrap condition `r_seconds >= 8'h59` should be `r_seconds == 8'h59` — allows `r_seconds` to reach 0x59 instead of wrapping at 0x58

### mux_func
- Output mux is **sequential** (`always_ff`): `if(d[3]) c = temperature_out; else c = 0`
- Bug: `d[3]` selects temperature sensor output into `c`, which should only carry crypto output
- `aes_out` is combinational (aes_1cc has `clk=0`)

### axi_address_decoder_AR
- 2-state FSM: `OPERATIVE(0)` and `ERROR(1)`
- Bug: when `outstanding_trans_i=1` and an error occurs, `CS == NS` (no state transition) — decoder ignores the error

---

## Lessons Learned

1. **Always verify signal names against source** — property files often use shorthand (e.g., `riscv_core.cs_registers_i` not `cs_registers`).

2. **Distinguish `_n` (next) from `_q` (registered)** — milestone conditions on `_n` signals are visible in the same cycle they are computed; `_q` signals reflect the previous cycle's value.

3. **Parameters vs signals** — `PULP_SECURE` is a parameter, not a runtime signal. Milestones cannot constrain it; it is fixed at elaboration time.

4. **Combinational violations need fewer milestones** — if the violation is purely combinational, 2–3 milestones suffice (reset, operational, violation).

5. **Counter-based violations** — for very long counters (32K+ cycles), set `expected_cycles` to the actual threshold. The symbolic engine can solve the constraint without simulating every cycle.

6. **APB write handshake** — always include `PSEL && PENABLE && PWRITE` as an intermediate milestone before checking a register's updated value.

7. **FSM state encoding** — always grep the source for the enum definition to get exact numeric values. Do not assume binary encoding order.

8. **Hierarchical paths** — use the full `top_wrapper.<instance>.<subinstance>.<signal>` path. Partial paths cause lookup failures in the symbolic engine.
