# HACK@DAC 2019 Formal Verification Setup

## Overview

This document describes the formal verification setup for the HACK@DAC 2019 hardware design using SymbiYosys (sby) with open-source tools.

## Design Background

The HACK@DAC 2019 challenge is a complex SoC based on the Ariane/CVA6 RISC-V processor with:
- AXI interconnect
- Multiple cache subsystems (std_cache_subsystem)
- Debug module, CLINT, PLIC peripherals
- Known security vulnerabilities (32 bugs across 11 CWE categories)

## Conversion Pipeline

### Challenge: SystemVerilog to Verilog

Yosys's built-in SystemVerilog parser cannot handle advanced features used in Ariane:
- Packages with functions
- Interfaces
- Complex structs
- Concatenation in return statements

### Solution: sv2v Conversion

Used `sv2v` to convert the entire design to plain Verilog:

```bash
sv2v -DVERILATOR --siloed --top=formal_top \
  [all source files] \
  -w sv2v_out/design.v
```

**Key exclusions:**
- Simulation-only files (`instruction_tracer_pkg.sv`, `instruction_tracer_if.sv`)
- PITON-specific wrappers (`ariane_verilog_wrap.sv`, `serpent_peripherals.sv`)
- Serpent cache subsystem (design uses `std_cache_subsystem`)

**Wrapper approach:**
- Created `formal_top.sv` wrapper that instantiates `top_wrapper_dac19` with flattened AXI_BUS interface ports
- sv2v inlined the wrapper, creating hierarchy: `formal_top.dut.ariane_i.*`

**Result:**
- ~16K lines of Verilog
- Successfully parsed by Yosys with `prep -top formal_top`
- 60 combinational loop warnings (typical for complex SoC, mostly false positives)

## Assertion Strategy

### Problem: Hierarchical References

Original SVA assertions used `bind` and hierarchical references like:
```systemverilog
bind top_wrapper_dac19 hackatdac19_assertions ...
assert (top_wrapper_dac19.ariane_i.csr_regfile_i.debug_mode_q && ...)
```

Yosys doesn't support:
- `bind` statements
- Cross-module hierarchical references in assertions

### Solution: Direct Injection

Injected assertions directly into the relevant modules in the sv2v output:

| Property | Module | Signals Checked |
|----------|--------|-----------------|
| p5 | csr_regfile | debug_mode_q, umode_i |
| p9 | csr_regfile | csr_we, csr_read, csr_addr, csr_exception_o |
| p21 | commit_stage | amo_valid_commit_o, exception_o, csr_exception_i |
| p22 | commit_stage | amo_valid_commit_o, commit_ack_o |
| p23 | ariane | amo_valid_commit, flush_ctrl_* |
| p24 | csr_regfile | tvm_o, csr_rdata_o, satp_q |
| p25 | csr_regfile | tvm_o, satp_d, csr_wdata_i |
| p26 | ariane | priv_lvl, flush_ctrl_* |
| p29 | csr_regfile | instret_q, debug_mode_q |
| p32 | controller | halt_o, ex_valid_i |

### Conditional Compilation

Each assertion wrapped in `ifdef` guards for per-property verification:

```verilog
`ifdef FORMAL
`ifdef FORMAL_P32
  always @(posedge clk_i) 
    if (rst_ni) 
      HACK_DAC19_p32: assert (!(halt_o) || ex_valid_i);
`endif
`endif
```

## SymbiYosys Configuration

### File: `hackatdac19.sby`

```ini
[tasks]
p5
p9
p21
p22
p23
p24
p25
p26
p29
p32

[options]
mode bmc
depth 20

[engines]
smtbmc

[script]
p5:  read_verilog -formal -DFORMAL -DFORMAL_P5  design_formal.v
p9:  read_verilog -formal -DFORMAL -DFORMAL_P9  design_formal.v
...
p32: read_verilog -formal -DFORMAL -DFORMAL_P32 design_formal.v

prep -top formal_top

[files]
sv2v_out/design_formal.v
```

## Usage

### Run single property:
```bash
sby -f hackatdac19.sby p32
```

### Run all properties:
```bash
sby -f hackatdac19.sby
```

### Run specific subset:
```bash
sby -f hackatdac19.sby p9 p21 p22
```

### Output:
- Each task creates directory: `hackatdac19_p<N>/`
- Counterexample VCD trace: `hackatdac19_p<N>/engine_0/trace.vcd`
- Verilog testbench: `hackatdac19_p<N>/engine_0/trace_tb.v`

## Results

### p32 (Bug 32 - CWE: Exception signal not set at halt)

**Status:** FAIL at step 1 (29 seconds)

**Assertion:** `halt_o |-> ex_valid_i`

**Counterexample:** `hackatdac19_p32/engine_0/trace.vcd`

This confirms the formal verification pipeline is working and detecting known bugs.

## Known Issues & Future Work

### p1 (Bug 1 - CWE-1220: Insufficient Access Control)

Not yet implemented. The original property references `connectivity_mapping` module which is purely combinational (no clock). Requires different assertion approach, possibly at `axi_node_intf_wrap` level.

### p5 Translation Issue

Current translation:
```verilog
assert (!(debug_mode_q && umode_i) || (2'b11 != 2'b0));
```

The `2'b11 != 2'b0` is always true, making this assertion trivial. Original JasperGold property used `riscv::PRIV_LVL_M` as a guard. Needs investigation of original intent.

### Performance Optimization

- Current depth: 20 cycles
- Solver: yices (default)
- Consider trying other solvers (z3, boolector) for comparison
- Consider increasing depth for properties that pass at depth 20

## File Structure

```
designs/benchmarks/hackatdac19/
├── design/                      # Original SystemVerilog sources
├── sv2v_out/
│   ├── design.v                # sv2v converted output (clean)
│   └── design_formal.v         # With injected assertions
├── formal_top.sv               # Wrapper for sv2v conversion
├── hackatdac19.sby             # SymbiYosys configuration
├── hackatdac19_p*/             # Per-property output directories
└── FORMAL_VERIFICATION_SETUP.md # This file
```

## References

- HACK@DAC 2019: https://github.com/hackdac/2019
- Ariane/CVA6: https://github.com/openhwgroup/cva6
- SymbiYosys: https://github.com/YosysHQ/sby
- sv2v: https://github.com/zachjs/sv2v
- Original properties: `properties.tcl` (JasperGold format)
