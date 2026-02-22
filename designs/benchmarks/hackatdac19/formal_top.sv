// Thin formal wrapper that instantiates top_wrapper_dac19
// with AXI_BUS interfaces instantiated and connected.
// This allows sv2v to resolve the interface ports.

module formal_top;

  logic clk_i, rst_ni;
  logic [63:0] boot_addr_i, hart_id_i;
  logic [1:0] irq_i;
  logic ipi_i, time_irq_i, debug_req_i;
  logic [1:0] priv_lvl_o;
  logic umode_i;
  logic testmode_i;
  logic [31:0] jtag_key;
  logic dmi_rst_no;
  logic [40:0] dmi_req_o;
  logic dmi_req_valid_o, dmi_req_ready_i;
  logic [33:0] dmi_resp_i;
  logic dmi_resp_ready_o, dmi_resp_valid_i;
  logic tck_i, tms_i, trst_ni, td_i, td_o, tdo_oe_o;
  logic umode_o;
  logic test_en_i;
  logic [7:0] priv_lvl_i;
  logic [7:0][7:0][7:0] access_ctrl_i;
  logic [7:0][31:0] start_addr_i, end_addr_i;

`ifdef AXI64_CACHE_PORTS
  logic [270:0] axi_req_o;
  logic [70:0] axi_resp_i;
`else
  logic [127:0] l15_req_o;
  logic [127:0] l15_rtrn_i;
`endif

  AXI_BUS #(
    .AXI_ADDR_WIDTH(32), .AXI_DATA_WIDTH(32),
    .AXI_ID_WIDTH(10), .AXI_USER_WIDTH(0)
  ) subordinate[7:0] ();

  AXI_BUS #(
    .AXI_ADDR_WIDTH(32), .AXI_DATA_WIDTH(32),
    .AXI_ID_WIDTH(10), .AXI_USER_WIDTH(0)
  ) primary[7:0] ();

  top_wrapper_dac19 dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .boot_addr_i(boot_addr_i),
    .hart_id_i(hart_id_i),
    .irq_i(irq_i),
    .ipi_i(ipi_i),
    .time_irq_i(time_irq_i),
    .debug_req_i(debug_req_i),
    .priv_lvl_o(priv_lvl_o),
    .umode_i(umode_i),
    .testmode_i(testmode_i),
    .jtag_key(jtag_key),
    .dmi_rst_no(dmi_rst_no),
    .dmi_req_o(dmi_req_o),
    .dmi_req_valid_o(dmi_req_valid_o),
    .dmi_req_ready_i(dmi_req_ready_i),
    .dmi_resp_i(dmi_resp_i),
    .dmi_resp_ready_o(dmi_resp_ready_o),
    .dmi_resp_valid_i(dmi_resp_valid_i),
    .tck_i(tck_i),
    .tms_i(tms_i),
    .trst_ni(trst_ni),
    .td_i(td_i),
    .td_o(td_o),
    .tdo_oe_o(tdo_oe_o),
    .umode_o(umode_o),
    .test_en_i(test_en_i),
    .subordinate(subordinate),
    .primary(primary),
    .priv_lvl_i(priv_lvl_i),
    .access_ctrl_i(access_ctrl_i),
    .start_addr_i(start_addr_i),
    .end_addr_i(end_addr_i),
`ifdef AXI64_CACHE_PORTS
    .axi_req_o(axi_req_o),
    .axi_resp_i(axi_resp_i)
`else
    .l15_req_o(l15_req_o),
    .l15_rtrn_i(l15_rtrn_i)
`endif
  );

endmodule
