//////////////////////////////////////////////////////////////////////
// OR1200 Security Assertions
// 71 assertions from properties.md converted to valid SystemVerilog
//////////////////////////////////////////////////////////////////////

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_assertions (
    input wire clk,
    input wire rst,

    // From or1200_except
    input wire [31:0] except_wb_pc,
    input wire [31:0] except_epcr,
    input wire [31:0] except_eear,
    input wire [`OR1200_SR_WIDTH-1:0] except_esr,
    input wire [31:0] except_lsu_addr,
    input wire [31:0] except_spr_dat_npc,

    // From or1200_sprs
    input wire [31:0] sprs_spr_dat_ppc,
    input wire [31:0] sprs_spr_dat_npc,
    input wire [`OR1200_SR_WIDTH-1:0] sprs_sr,
    input wire [`OR1200_SR_WIDTH-1:0] sprs_to_sr,
    input wire [31:0] sprs_spr_dat_o,

    // From or1200_ctrl
    input wire [31:0] ctrl_ex_insn,
    input wire [31:0] ctrl_wb_insn,
    input wire [31:0] ctrl_ex_pc,

    // From or1200_rf
    input wire [4:0] rf_rf_addrw,
    input wire [4:0] rf_addrw,
    input wire [31:0] rf_rf_dataw,
    input wire rf_we,

    // From or1200_genpc
    input wire [31:0] genpc_pc,

    // From or1200_cpu (operand muxes)
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    input wire [31:0] ex_simm,

    // From or1200_if
    input wire [31:0] if_insn,
    input wire [31:0] if_insn_saved,

    // From or1200_lsu
    input wire [31:0] lsu_dcpu_dat_i,
    input wire [31:0] mem2reg_regdata,
    input wire [31:0] mem2reg_memdata,
    input wire [31:0] reg2mem_memdata,
    input wire [31:0] reg2mem_regdata,

    // External interfaces
    input wire [31:0] icpu_dat_i,
    input wire [31:0] dcpu_adr_o,
    input wire [31:0] dcpu_dat_o,

    // ID stage
    input wire [31:0] id_insn,
    input wire id_freeze
);

    // Previous state registers for temporal properties
    reg [`OR1200_SR_WIDTH-1:0] prev_sr0;
    reg [31:0] prev_epcr;
    reg [31:0] prev_eear;
    reg [`OR1200_SR_WIDTH-1:0] prev_esr;
    reg [31:0] prev_ex_insn;
    reg [31:0] prev_if_insn;
    reg prev_id_freeze;

    // Update previous state
    always @(posedge clk) begin
        if (rst) begin
            prev_sr0 <= 0;
            prev_epcr <= 0;
            prev_eear <= 0;
            prev_esr <= 0;
            prev_ex_insn <= 0;
            prev_if_insn <= 0;
            prev_id_freeze <= 0;
        end else begin
            prev_sr0 <= sprs_sr[0];
            prev_epcr <= except_epcr;
            prev_eear <= except_eear;
            prev_esr <= except_esr;
            prev_ex_insn <= ctrl_ex_insn;
            prev_if_insn <= if_insn;
            prev_id_freeze <= id_freeze;
        end
    end

    //==========================================================================
    // Control Flow Assertions (CWE-1281)
    //==========================================================================

    // p1: Control flow - wb_pc matches spr_dat_ppc
    always @(posedge clk) begin
        p1: assert ((except_wb_pc == sprs_spr_dat_ppc) || (rst == 1));
    end

    // p2: Control flow - ex_pc matches spr_dat_npc for instruction class 1
    always @(posedge clk) begin
        p2: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 1)) ||
                   (ctrl_ex_pc == sprs_spr_dat_npc) || (rst == 1));
    end

    // p3: Control flow - ex_pc matches spr_dat_npc for instruction class 2
    always @(posedge clk) begin
        p3: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 2)) ||
                   (ctrl_ex_pc == sprs_spr_dat_npc) || (rst == 1));
    end

    // p4: Control flow - ex_pc matches spr_dat_npc for instruction class 3
    always @(posedge clk) begin
        p4: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 3)) ||
                   (ctrl_ex_pc == sprs_spr_dat_npc) || (rst == 1));
    end

    // p5: Control flow - flag set when operand_a > operand_b for specific instruction
    always @(posedge clk) begin
        p5: assert ((~(((ctrl_ex_insn & 32'hFFE00000) >> 21) == 1826) || ~(operand_a > operand_b)) ||
                   (sprs_to_sr[9] == 1) || (rst == 1));
    end

    // p6: Control flow - flag set when operand_a <= operand_b for specific instruction
    always @(posedge clk) begin
        p6: assert ((~(((ctrl_ex_insn & 32'hFFE00000) >> 21) == 1829) || ~(operand_a <= operand_b)) ||
                   (sprs_to_sr[9] == 1) || (rst == 1));
    end

    // p7: Control flow - rf_addrw == 9 for l.jal instruction
    always @(posedge clk) begin
        p7: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 1)) ||
                   (rf_rf_addrw == 9) || (rst == 1));
    end

    // p8: Control flow - rf_addrw != 9 for instruction class 2
    always @(posedge clk) begin
        p8: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 2)) ||
                   (rf_rf_addrw != 9) || (rst == 1));
    end

    //==========================================================================
    // Privilege Escalation/De-escalation Assertions (CWE-1198)
    //==========================================================================

    // p9: SR[0] unchanged for instruction class 1
    always @(posedge clk) begin
        p9: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 1)) ||
                   (sprs_sr[0] == prev_sr0) || (rst == 1));
    end

    // p10: SR[0] unchanged for instruction class 2
    always @(posedge clk) begin
        p10: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 2)) ||
                    (sprs_sr[0] == prev_sr0) || (rst == 1));
    end

    // p11: SR[0] unchanged for instruction class 3 with specific mask
    always @(posedge clk) begin
        p11: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 3) ||
                    ~((ctrl_ex_insn & 32'h3C000000) != 0)) ||
                    (sprs_sr[0] == prev_sr0) || (rst == 1));
    end

    // p12: EPCR unchanged for instruction class 1
    always @(posedge clk) begin
        p12: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 1)) ||
                    (except_epcr == prev_epcr) || (rst == 1));
    end

    // p13: EPCR unchanged for instruction class 2
    always @(posedge clk) begin
        p13: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 2)) ||
                    (except_epcr == prev_epcr) || (rst == 1));
    end

    // p14: EPCR unchanged for instruction class 3
    always @(posedge clk) begin
        p14: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 3)) ||
                    (except_epcr == prev_epcr) || (rst == 1));
    end

    // p15: EEAR unchanged for instruction class 1
    always @(posedge clk) begin
        p15: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 1)) ||
                    (except_eear == prev_eear) || (rst == 1));
    end

    // p16: EEAR unchanged for instruction class 2
    always @(posedge clk) begin
        p16: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 2)) ||
                    (except_eear == prev_eear) || (rst == 1));
    end

    // p17: EEAR unchanged for instruction class 3
    always @(posedge clk) begin
        p17: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 3)) ||
                    (except_eear == prev_eear) || (rst == 1));
    end

    // p18: ESR unchanged for instruction class 1
    always @(posedge clk) begin
        p18: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 1)) ||
                    (except_esr == prev_esr) || (rst == 1));
    end

    // p19: ESR unchanged for instruction class 2
    always @(posedge clk) begin
        p19: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 2)) ||
                    (except_esr == prev_esr) || (rst == 1));
    end

    // p20: ESR unchanged for instruction class 3 with specific mask
    always @(posedge clk) begin
        p20: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 3) ||
                    ~((ctrl_ex_insn & 32'h3C000000) != 0)) ||
                    (except_esr == prev_esr) || (rst == 1));
    end

    // p21: EEAR unchanged for l.rfe instruction (opcode 9)
    always @(posedge clk) begin
        p21: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 9)) ||
                    (except_eear == prev_eear) || (rst == 1));
    end

    // p22: EPCR unchanged for l.rfe instruction
    always @(posedge clk) begin
        p22: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 9)) ||
                    (except_epcr == prev_epcr) || (rst == 1));
    end

    // p23: ESR unchanged for l.rfe instruction
    always @(posedge clk) begin
        p23: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 9)) ||
                    (except_esr == prev_esr) || (rst == 1));
    end

    // p24: PC restored from EPCR for l.rfe
    always @(posedge clk) begin
        p24: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 9)) ||
                    (genpc_pc == except_epcr) || (rst == 1));
    end

    // p25: SR restored from ESR for l.rfe
    always @(posedge clk) begin
        p25: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 9)) ||
                    (sprs_to_sr == except_esr) || (rst == 1));
    end

    // p26: LSU address saved to EEAR on exception
    always @(posedge clk) begin
        p26: assert ((~(((prev_ex_insn & 32'hFFFF0000) >> 16) == 8192)) ||
                    (~(((ctrl_ex_insn & 32'hFFFF0000) >> 16) != 8192)) ||
                    (except_lsu_addr == except_eear) || (rst == 1));
    end

    // p27: NPC saved to EPCR on exception
    always @(posedge clk) begin
        p27: assert ((~(((prev_ex_insn & 32'hFFFF0000) >> 16) == 8192)) ||
                    (~(((ctrl_ex_insn & 32'hFFFF0000) >> 16) != 8192)) ||
                    (except_spr_dat_npc == except_epcr) || (rst == 1));
    end

    // p28: LSU address saved to EEAR for wb_insn
    always @(posedge clk) begin
        p28: assert ((~(((ctrl_wb_insn & 32'hFFFF0000) >> 16) == 8192)) ||
                    (except_lsu_addr == except_eear) || (rst == 1));
    end

    // p29: NPC saved to EPCR for wb_insn
    always @(posedge clk) begin
        p29: assert ((~(((ctrl_wb_insn & 32'hFFFF0000) >> 16) == 8192)) ||
                    (except_spr_dat_npc == except_epcr) || (rst == 1));
    end

    // p30: rf_addrw matches instruction encoding
    always @(posedge clk) begin
        p30: assert ((~(((ctrl_ex_insn & 32'hFFFF0000) >> 16) == 8192)) ||
                    (rf_rf_addrw == ((ctrl_ex_insn & 32'h03E00000) >> 21)) || (rst == 1));
    end

    //==========================================================================
    // Update Registers Assertions (CWE-1262)
    //==========================================================================

    // p31-p45: rf_we == 0 for store/branch instructions
    always @(posedge clk) begin
        p31: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 47)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p32: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 57)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p33: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 51)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p34: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 52)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p35: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 53)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p36: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 54)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p37: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 55)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p38: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 48)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p39: assert ((~(((ctrl_ex_insn & 32'hFF000000) >> 24) == 21)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p40: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 9)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p41: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 17)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p42: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 0)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p43: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 4)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p44: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 3)) || (rf_we == 0) || (rst == 1));
    end

    always @(posedge clk) begin
        p45: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 8)) || (rf_we == 0) || (rst == 1));
    end

    // p46: spr_dat_o matches operand_b for l.mtspr
    always @(posedge clk) begin
        p46: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 48)) ||
                    (sprs_spr_dat_o == operand_b));
    end

    //==========================================================================
    // Correct Results Assertions (CWE-1221)
    //==========================================================================

    // p47: rf_addrw matches instruction encoding for class 2
    always @(posedge clk) begin
        p47: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 2)) ||
                    (((ctrl_ex_insn & 32'h03E00000) >> 21) == rf_addrw) || (rst == 1));
    end

    // p48: rf_addrw matches instruction encoding for class 3
    always @(posedge clk) begin
        p48: assert ((~(((ctrl_ex_insn & 32'hC0000000) >> 30) == 3)) ||
                    (((ctrl_ex_insn & 32'h03E00000) >> 21) == rf_addrw) || (rst == 1));
    end

    //==========================================================================
    // Instruction Executed Assertions (CWE-1281)
    //==========================================================================

    // p49: Opcode 0x1c should not be executed
    always @(posedge clk) begin
        p49: assert ((((ctrl_ex_insn & 32'hFC000000) >> 26) != 32'h1c) || (rst == 1));
    end

    // p50: ID instruction consistency
    always @(posedge clk) begin
        p50: assert ((id_insn == 32'h14410000) || (id_insn == 32'h14610000) ||
                    (id_insn == prev_if_insn) || (prev_id_freeze) || (rst == 1));
    end

    // p51: IF instruction consistency
    always @(posedge clk) begin
        p51: assert ((if_insn == 32'h14610000) || (if_insn == 32'h14410000) ||
                    (if_insn == icpu_dat_i) || (if_insn == 0) || (rst == 1) ||
                    (if_insn == if_insn_saved));
    end

    //==========================================================================
    // Memory Access Assertions (CWE-1202)
    //==========================================================================

    // p52: operand_b matches dcpu_dat_o
    always @(posedge clk) begin
        p52: assert ((operand_b == dcpu_dat_o) || (rst == 1));
    end

    // p53-p59: rf_dataw matches dcpu_dat_o for load instructions
    always @(posedge clk) begin
        p53: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 32)) ||
                    (rf_rf_dataw == dcpu_dat_o) || (rst == 1));
    end

    always @(posedge clk) begin
        p54: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 33)) ||
                    (rf_rf_dataw == dcpu_dat_o) || (rst == 1));
    end

    always @(posedge clk) begin
        p55: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 34)) ||
                    (rf_rf_dataw == dcpu_dat_o) || (rst == 1));
    end

    always @(posedge clk) begin
        p56: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 35)) ||
                    (rf_rf_dataw == dcpu_dat_o) || (rst == 1));
    end

    always @(posedge clk) begin
        p57: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 36)) ||
                    (rf_rf_dataw == dcpu_dat_o) || (rst == 1));
    end

    always @(posedge clk) begin
        p58: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 37)) ||
                    (rf_rf_dataw == dcpu_dat_o) || (rst == 1));
    end

    always @(posedge clk) begin
        p59: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 38)) ||
                    (rf_rf_dataw == dcpu_dat_o) || (rst == 1));
    end

    // p60-p66: dcpu_adr_o matches operand_a + ex_simm for load/store
    always @(posedge clk) begin
        p60: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 32)) ||
                    (dcpu_adr_o == operand_a + ex_simm) || (rst == 1));
    end

    always @(posedge clk) begin
        p61: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 33)) ||
                    (dcpu_adr_o == operand_a + ex_simm) || (rst == 1));
    end

    always @(posedge clk) begin
        p62: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 34)) ||
                    (dcpu_adr_o == operand_a + ex_simm) || (rst == 1));
    end

    always @(posedge clk) begin
        p63: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 35)) ||
                    (dcpu_adr_o == operand_a + ex_simm) || (rst == 1));
    end

    always @(posedge clk) begin
        p64: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 36)) ||
                    (dcpu_adr_o == operand_a + ex_simm) || (rst == 1));
    end

    always @(posedge clk) begin
        p65: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 37)) ||
                    (dcpu_adr_o == operand_a + ex_simm) || (rst == 1));
    end

    always @(posedge clk) begin
        p66: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 38)) ||
                    (dcpu_adr_o == operand_a + ex_simm) || (rst == 1));
    end

    // p67: Upper 16 bits of regdata are zero for l.lhz
    always @(posedge clk) begin
        p67: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 37)) ||
                    ((mem2reg_regdata & 32'hFFFF0000) == 0) || (rst == 1));
    end

    // p68: Lower 16 bits match for l.sh
    always @(posedge clk) begin
        p68: assert ((~(((ctrl_ex_insn & 32'hFC000000) >> 26) == 53)) ||
                    ((reg2mem_memdata & 16'hFFFF) == (reg2mem_regdata & 16'hFFFF)) || (rst == 1));
    end

    // p69: dcpu_dat_i matches memdata
    always @(posedge clk) begin
        p69: assert ((lsu_dcpu_dat_i == mem2reg_memdata) || (rst == 1));
    end

    // p70: Writing to r0 must write 0
    always @(posedge clk) begin
        p70: assert ((~((rf_we == 1) && (rf_rf_addrw == 0))) ||
                    (rf_rf_dataw == 0) || (rst == 1));
    end

    // p71: Rotate right instruction result
    always @(posedge clk) begin
        p71: assert ((~((ctrl_ex_insn & 32'hFC0003CF) == 32'hE00000C8)) ||
                    (((operand_a << (32 - {1'b0, operand_b[4:0]})) |
                      (operand_a >> operand_b[4:0])) == rf_rf_dataw) ||
                    (rf_rf_dataw == 0) || (rst == 1));
    end

endmodule
