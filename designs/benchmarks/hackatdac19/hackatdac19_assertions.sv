// SVA assertions for HACK@DAC 2019 properties
// Translated from properties.tcl (JasperGold format) to standard SVA
//
// NOTE: These assertions use hierarchical references into the design.
// They must be bound to the top_wrapper_dac19 module.

module hackatdac19_assertions (
    input logic clk_i,
    input logic rst_ni
);

    // Default clocking and reset
    default clocking @(posedge clk_i); endclocking
    default disable iff (!rst_ni);

    // p1: Processor access to CLINT grants it access to PLIC regardless of PLIC access configuration
    // Bug 1, CWE-1220
    HACK_DAC19_p1: assert property (
        ~( (top_wrapper_dac19.axi_node_intf_wrap_i.i_connectivity_map.runtime_j == 6) &&
            top_wrapper_dac19.axi_node_intf_wrap_i.i_connectivity_map.access_ctrl_i
                [top_wrapper_dac19.axi_node_intf_wrap_i.i_connectivity_map.runtime_i]
                [7]
                [top_wrapper_dac19.axi_node_intf_wrap_i.i_connectivity_map.priv_lvl_i] )
    );

    // p5: Incorrect access control setting leaving debug enabled
    // Bug 5, CWE-1244
    HACK_DAC19_p5: assert property (
        ~(top_wrapper_dac19.ariane_i.csr_regfile_i.debug_mode_q &&
          top_wrapper_dac19.ariane_i.csr_regfile_i.umode_i)
        || (riscv::PRIV_LVL_M)
    );

    // p9: Execute machine level instructions from user mode
    // Bug 9, CWE-1262
    HACK_DAC19_p9: assert property (
        ((top_wrapper_dac19.ariane_i.csr_regfile_i.csr_we ||
          top_wrapper_dac19.ariane_i.csr_regfile_i.csr_read) &&
         (top_wrapper_dac19.ariane_i.csr_regfile_i.csr_addr.address == riscv::CSR_MEPC))
        |-> top_wrapper_dac19.ariane_i.csr_regfile_i.csr_exception_o.valid == 1'b1
    );

    // p21: Receive CSR interrupts when committing atomic instructions
    // Bug 21, CWE-1281
    HACK_DAC19_p21: assert property (
        top_wrapper_dac19.ariane_i.commit_stage_i.amo_valid_commit_o
        |-> (top_wrapper_dac19.ariane_i.commit_stage_i.exception_o !=
             top_wrapper_dac19.ariane_i.commit_stage_i.csr_exception_i)
    );

    // p22: Commit the second instruction even if the first is atomic instruction
    // Bug 22
    HACK_DAC19_p22: assert property (
        top_wrapper_dac19.ariane_i.commit_stage_i.amo_valid_commit_o
        |-> ~top_wrapper_dac19.ariane_i.commit_stage_i.commit_ack_o[1]
    );

    // p23: Pipeline not flushed after committing an atomic instruction
    // Bug 23
    HACK_DAC19_p23: assert property (
        top_wrapper_dac19.ariane_i.amo_valid_commit
        |-> (top_wrapper_dac19.ariane_i.flush_ctrl_if &&
             top_wrapper_dac19.ariane_i.flush_ctrl_id &&
             top_wrapper_dac19.ariane_i.flush_ctrl_ex)
    );

    // p24: SATP register (read) accessible in Supervisor mode even if TVM is enabled
    // Bug 24
    HACK_DAC19_p24: assert property (
        top_wrapper_dac19.ariane_i.csr_regfile_i.tvm_o
        |-> (top_wrapper_dac19.ariane_i.csr_regfile_i.csr_rdata_o !=
             top_wrapper_dac19.ariane_i.csr_regfile_i.satp_q)
    );

    // p25: SATP register (write) accessible in Supervisor mode even if TVM is enabled
    // Bug 25
    HACK_DAC19_p25: assert property (
        top_wrapper_dac19.ariane_i.csr_regfile_i.tvm_o
        |-> (top_wrapper_dac19.ariane_i.csr_regfile_i.satp_d !=
             top_wrapper_dac19.ariane_i.csr_regfile_i.csr_wdata_i)
    );

    // p26: Pipeline not flushed after change in virtual address translation mode
    // Bug 26
    HACK_DAC19_p26: assert property (
        (top_wrapper_dac19.ariane_i.priv_lvl != $past(top_wrapper_dac19.ariane_i.priv_lvl))
        |-> (top_wrapper_dac19.ariane_i.flush_ctrl_if &&
             top_wrapper_dac19.ariane_i.flush_ctrl_id &&
             top_wrapper_dac19.ariane_i.flush_ctrl_ex)
    );

    // p29: Instruction retired counters are updated in non-debug mode
    // Bug 29
    HACK_DAC19_p29: assert property (
        (top_wrapper_dac19.ariane_i.csr_regfile_i.instret_q !=
         $past(top_wrapper_dac19.ariane_i.csr_regfile_i.instret_q))
        |-> top_wrapper_dac19.ariane_i.csr_regfile_i.debug_mode_q
    );

    // p32: Exception signal is not set at halt
    // Bug 32
    HACK_DAC19_p32: assert property (
        top_wrapper_dac19.ariane_i.controller_i.halt_o
        |-> top_wrapper_dac19.ariane_i.controller_i.ex_valid_i
    );

endmodule

bind top_wrapper_dac19 hackatdac19_assertions u_assertions (
    .clk_i  (clk_i),
    .rst_ni (rst_ni)
);
