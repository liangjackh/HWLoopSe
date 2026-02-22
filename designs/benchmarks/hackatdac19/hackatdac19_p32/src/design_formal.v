module sram (
	clk_i,
	rst_ni,
	req_i,
	we_i,
	addr_i,
	wdata_i,
	be_i,
	rdata_o
);
	reg _sv2v_0;
	parameter DATA_WIDTH = 64;
	parameter NUM_WORDS = 1024;
	parameter OUT_REGS = 0;
	input wire clk_i;
	input wire rst_ni;
	input wire req_i;
	input wire we_i;
	input wire [$clog2(NUM_WORDS) - 1:0] addr_i;
	input wire [DATA_WIDTH - 1:0] wdata_i;
	input wire [((DATA_WIDTH + 7) / 8) - 1:0] be_i;
	output reg [DATA_WIDTH - 1:0] rdata_o;
	localparam DATA_WIDTH_ALIGNED = ((DATA_WIDTH + 63) / 64) * 64;
	localparam BE_WIDTH_ALIGNED = ((((DATA_WIDTH + 7) / 8) + 7) / 8) * 8;
	reg [DATA_WIDTH_ALIGNED - 1:0] wdata_aligned;
	reg [BE_WIDTH_ALIGNED - 1:0] be_aligned;
	wire [DATA_WIDTH_ALIGNED - 1:0] rdata_aligned;
	always @(*) begin : p_align
		if (_sv2v_0)
			;
		wdata_aligned = 1'sb0;
		be_aligned = 1'sb0;
		wdata_aligned[DATA_WIDTH - 1:0] = wdata_i;
		be_aligned[BE_WIDTH_ALIGNED - 1:0] = be_i;
		rdata_o = rdata_aligned[DATA_WIDTH - 1:0];
	end
	genvar _gv_k_1;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < ((DATA_WIDTH + 63) / 64); _gv_k_1 = _gv_k_1 + 1) begin : genblk1
			localparam k = _gv_k_1;
			SyncSpRamBeNx64 #(
				.ADDR_WIDTH($clog2(NUM_WORDS)),
				.DATA_DEPTH(NUM_WORDS),
				.OUT_REGS(0),
				.SIM_INIT(2)
			) i_ram(
				.Clk_CI(clk_i),
				.Rst_RBI(rst_ni),
				.CSel_SI(req_i),
				.WrEn_SI(we_i),
				.BEn_SI(be_aligned[k * 8+:8]),
				.WrData_DI(wdata_aligned[k * 64+:64]),
				.Addr_DI(addr_i),
				.RdData_DO(rdata_aligned[k * 64+:64])
			);
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
module fifo_v2 (
	clk_i,
	rst_ni,
	flush_i,
	testmode_i,
	full_o,
	empty_o,
	alm_full_o,
	alm_empty_o,
	data_i,
	push_i,
	data_o,
	pop_i
);
	parameter [0:0] FALL_THROUGH = 1'b0;
	parameter [31:0] DATA_WIDTH = 32;
	parameter [31:0] DEPTH = 8;
	parameter [31:0] ALM_EMPTY_TH = 1;
	parameter [31:0] ALM_FULL_TH = 1;
	parameter [31:0] ADDR_DEPTH = (DEPTH > 1 ? $clog2(DEPTH) : 1);
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire testmode_i;
	output wire full_o;
	output wire empty_o;
	output wire alm_full_o;
	output wire alm_empty_o;
	input wire [DATA_WIDTH - 1:0] data_i;
	input wire push_i;
	output wire [DATA_WIDTH - 1:0] data_o;
	input wire pop_i;
	wire [ADDR_DEPTH - 1:0] usage;
	generate
		if (DEPTH == 0) begin : genblk1
			assign alm_full_o = 1'b0;
			assign alm_empty_o = 1'b0;
		end
		else begin : genblk1
			assign alm_full_o = usage >= ALM_FULL_TH[ADDR_DEPTH - 1:0];
			assign alm_empty_o = usage <= ALM_EMPTY_TH[ADDR_DEPTH - 1:0];
		end
	endgenerate
	fifo_v3_BDE01_041C4 #(
		.dtype_DATA_WIDTH(DATA_WIDTH),
		.FALL_THROUGH(FALL_THROUGH),
		.DATA_WIDTH(DATA_WIDTH),
		.DEPTH(DEPTH)
	) i_fifo_v3(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.testmode_i(testmode_i),
		.full_o(full_o),
		.empty_o(empty_o),
		.usage_o(usage),
		.data_i(data_i),
		.push_i(push_i),
		.data_o(data_o),
		.pop_i(pop_i)
	);
endmodule
module fifo_v2_925B0_BA4DE (
	clk_i,
	rst_ni,
	flush_i,
	testmode_i,
	full_o,
	empty_o,
	alm_full_o,
	alm_empty_o,
	data_i,
	push_i,
	data_o,
	pop_i
);
	parameter [31:0] dtype_ariane_pkg_FETCH_WIDTH = 0;
	parameter [31:0] dtype_ariane_pkg_INSTR_PER_FETCH = 0;
	parameter [0:0] FALL_THROUGH = 1'b0;
	parameter [31:0] DATA_WIDTH = 32;
	parameter [31:0] DEPTH = 8;
	parameter [31:0] ALM_EMPTY_TH = 1;
	parameter [31:0] ALM_FULL_TH = 1;
	parameter [31:0] ADDR_DEPTH = (DEPTH > 1 ? $clog2(DEPTH) : 1);
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire testmode_i;
	output wire full_o;
	output wire empty_o;
	output wire alm_full_o;
	output wire alm_empty_o;
	input wire [(((64 + dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_ariane_pkg_INSTR_PER_FETCH) + 0:0] data_i;
	input wire push_i;
	output wire [(((64 + dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_ariane_pkg_INSTR_PER_FETCH) + 0:0] data_o;
	input wire pop_i;
	wire [ADDR_DEPTH - 1:0] usage;
	generate
		if (DEPTH == 0) begin : genblk1
			assign alm_full_o = 1'b0;
			assign alm_empty_o = 1'b0;
		end
		else begin : genblk1
			assign alm_full_o = usage >= ALM_FULL_TH[ADDR_DEPTH - 1:0];
			assign alm_empty_o = usage <= ALM_EMPTY_TH[ADDR_DEPTH - 1:0];
		end
	endgenerate
	fifo_v3_C28B9_7997C #(
		.dtype_dtype_ariane_pkg_FETCH_WIDTH(dtype_ariane_pkg_FETCH_WIDTH),
		.dtype_dtype_ariane_pkg_INSTR_PER_FETCH(dtype_ariane_pkg_INSTR_PER_FETCH),
		.FALL_THROUGH(FALL_THROUGH),
		.DATA_WIDTH(DATA_WIDTH),
		.DEPTH(DEPTH)
	) i_fifo_v3(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.testmode_i(testmode_i),
		.full_o(full_o),
		.empty_o(empty_o),
		.usage_o(usage),
		.data_i(data_i),
		.push_i(push_i),
		.data_o(data_o),
		.pop_i(pop_i)
	);
endmodule
module fifo_v2_EC778 (
	clk_i,
	rst_ni,
	flush_i,
	testmode_i,
	full_o,
	empty_o,
	alm_full_o,
	alm_empty_o,
	data_i,
	push_i,
	data_o,
	pop_i
);
	parameter [0:0] FALL_THROUGH = 1'b0;
	parameter [31:0] DATA_WIDTH = 32;
	parameter [31:0] DEPTH = 8;
	parameter [31:0] ALM_EMPTY_TH = 1;
	parameter [31:0] ALM_FULL_TH = 1;
	parameter [31:0] ADDR_DEPTH = (DEPTH > 1 ? $clog2(DEPTH) : 1);
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire testmode_i;
	output wire full_o;
	output wire empty_o;
	output wire alm_full_o;
	output wire alm_empty_o;
	input wire [133:0] data_i;
	input wire push_i;
	output wire [133:0] data_o;
	input wire pop_i;
	wire [ADDR_DEPTH - 1:0] usage;
	generate
		if (DEPTH == 0) begin : genblk1
			assign alm_full_o = 1'b0;
			assign alm_empty_o = 1'b0;
		end
		else begin : genblk1
			assign alm_full_o = usage >= ALM_FULL_TH[ADDR_DEPTH - 1:0];
			assign alm_empty_o = usage <= ALM_EMPTY_TH[ADDR_DEPTH - 1:0];
		end
	endgenerate
	fifo_v3_24DF1 #(
		.FALL_THROUGH(FALL_THROUGH),
		.DATA_WIDTH(DATA_WIDTH),
		.DEPTH(DEPTH)
	) i_fifo_v3(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.testmode_i(testmode_i),
		.full_o(full_o),
		.empty_o(empty_o),
		.usage_o(usage),
		.data_i(data_i),
		.push_i(push_i),
		.data_o(data_o),
		.pop_i(pop_i)
	);
endmodule
module fifo_v3 (
	clk_i,
	rst_ni,
	flush_i,
	testmode_i,
	full_o,
	empty_o,
	usage_o,
	data_i,
	push_i,
	data_o,
	pop_i
);
	reg _sv2v_0;
	parameter [0:0] FALL_THROUGH = 1'b0;
	parameter [31:0] DATA_WIDTH = 32;
	parameter [31:0] DEPTH = 8;
	parameter [31:0] ADDR_DEPTH = (DEPTH > 1 ? $clog2(DEPTH) : 1);
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire testmode_i;
	output wire full_o;
	output wire empty_o;
	output wire [ADDR_DEPTH - 1:0] usage_o;
	input wire [DATA_WIDTH - 1:0] data_i;
	input wire push_i;
	output reg [DATA_WIDTH - 1:0] data_o;
	input wire pop_i;
	localparam [31:0] FIFO_DEPTH = (DEPTH > 0 ? DEPTH : 1);
	reg gate_clock;
	reg [ADDR_DEPTH - 1:0] read_pointer_n;
	reg [ADDR_DEPTH - 1:0] read_pointer_q;
	reg [ADDR_DEPTH - 1:0] write_pointer_n;
	reg [ADDR_DEPTH - 1:0] write_pointer_q;
	reg [ADDR_DEPTH:0] status_cnt_n;
	reg [ADDR_DEPTH:0] status_cnt_q;
	reg [(FIFO_DEPTH * DATA_WIDTH) - 1:0] mem_n;
	reg [(FIFO_DEPTH * DATA_WIDTH) - 1:0] mem_q;
	assign usage_o = status_cnt_q[ADDR_DEPTH - 1:0];
	generate
		if (DEPTH == 0) begin : genblk1
			assign empty_o = ~push_i;
			assign full_o = ~pop_i;
		end
		else begin : genblk1
			assign full_o = status_cnt_q == FIFO_DEPTH[ADDR_DEPTH:0];
			assign empty_o = (status_cnt_q == 0) & ~(FALL_THROUGH & push_i);
		end
	endgenerate
	always @(*) begin : read_write_comb
		if (_sv2v_0)
			;
		read_pointer_n = read_pointer_q;
		write_pointer_n = write_pointer_q;
		status_cnt_n = status_cnt_q;
		data_o = (DEPTH == 0 ? data_i : mem_q[read_pointer_q * DATA_WIDTH+:DATA_WIDTH]);
		mem_n = mem_q;
		gate_clock = 1'b1;
		if (push_i && ~full_o) begin
			mem_n[write_pointer_q * DATA_WIDTH+:DATA_WIDTH] = data_i;
			gate_clock = 1'b0;
			if (write_pointer_q == (FIFO_DEPTH[ADDR_DEPTH - 1:0] - 1))
				write_pointer_n = 1'sb0;
			else
				write_pointer_n = write_pointer_q + 1;
			status_cnt_n = status_cnt_q + 1;
		end
		if (pop_i && ~empty_o) begin
			if (read_pointer_n == (FIFO_DEPTH[ADDR_DEPTH - 1:0] - 1))
				read_pointer_n = 1'sb0;
			else
				read_pointer_n = read_pointer_q + 1;
			status_cnt_n = status_cnt_q - 1;
		end
		if (((push_i && pop_i) && ~full_o) && ~empty_o)
			status_cnt_n = status_cnt_q;
		if (((FALL_THROUGH && (status_cnt_q == 0)) && push_i) && pop_i) begin
			data_o = data_i;
			status_cnt_n = status_cnt_q;
			read_pointer_n = read_pointer_q;
			write_pointer_n = write_pointer_q;
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			read_pointer_q <= 1'sb0;
			write_pointer_q <= 1'sb0;
			status_cnt_q <= 1'sb0;
		end
		else if (flush_i) begin
			read_pointer_q <= 1'sb0;
			write_pointer_q <= 1'sb0;
			status_cnt_q <= 1'sb0;
		end
		else begin
			read_pointer_q <= read_pointer_n;
			write_pointer_q <= write_pointer_n;
			status_cnt_q <= status_cnt_n;
		end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni)
			mem_q <= 1'sb0;
		else if (!gate_clock)
			mem_q <= mem_n;
	initial _sv2v_0 = 0;
endmodule
module fifo_v3_24DF1 (
	clk_i,
	rst_ni,
	flush_i,
	testmode_i,
	full_o,
	empty_o,
	usage_o,
	data_i,
	push_i,
	data_o,
	pop_i
);
	reg _sv2v_0;
	parameter [0:0] FALL_THROUGH = 1'b0;
	parameter [31:0] DATA_WIDTH = 32;
	parameter [31:0] DEPTH = 8;
	parameter [31:0] ADDR_DEPTH = (DEPTH > 1 ? $clog2(DEPTH) : 1);
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire testmode_i;
	output wire full_o;
	output wire empty_o;
	output wire [ADDR_DEPTH - 1:0] usage_o;
	input wire [133:0] data_i;
	input wire push_i;
	output reg [133:0] data_o;
	input wire pop_i;
	localparam [31:0] FIFO_DEPTH = (DEPTH > 0 ? DEPTH : 1);
	reg gate_clock;
	reg [ADDR_DEPTH - 1:0] read_pointer_n;
	reg [ADDR_DEPTH - 1:0] read_pointer_q;
	reg [ADDR_DEPTH - 1:0] write_pointer_n;
	reg [ADDR_DEPTH - 1:0] write_pointer_q;
	reg [ADDR_DEPTH:0] status_cnt_n;
	reg [ADDR_DEPTH:0] status_cnt_q;
	reg [(FIFO_DEPTH * 134) - 1:0] mem_n;
	reg [(FIFO_DEPTH * 134) - 1:0] mem_q;
	assign usage_o = status_cnt_q[ADDR_DEPTH - 1:0];
	generate
		if (DEPTH == 0) begin : genblk1
			assign empty_o = ~push_i;
			assign full_o = ~pop_i;
		end
		else begin : genblk1
			assign full_o = status_cnt_q == FIFO_DEPTH[ADDR_DEPTH:0];
			assign empty_o = (status_cnt_q == 0) & ~(FALL_THROUGH & push_i);
		end
	endgenerate
	always @(*) begin : read_write_comb
		if (_sv2v_0)
			;
		read_pointer_n = read_pointer_q;
		write_pointer_n = write_pointer_q;
		status_cnt_n = status_cnt_q;
		data_o = (DEPTH == 0 ? data_i : mem_q[read_pointer_q * 134+:134]);
		mem_n = mem_q;
		gate_clock = 1'b1;
		if (push_i && ~full_o) begin
			mem_n[write_pointer_q * 134+:134] = data_i;
			gate_clock = 1'b0;
			if (write_pointer_q == (FIFO_DEPTH[ADDR_DEPTH - 1:0] - 1))
				write_pointer_n = 1'sb0;
			else
				write_pointer_n = write_pointer_q + 1;
			status_cnt_n = status_cnt_q + 1;
		end
		if (pop_i && ~empty_o) begin
			if (read_pointer_n == (FIFO_DEPTH[ADDR_DEPTH - 1:0] - 1))
				read_pointer_n = 1'sb0;
			else
				read_pointer_n = read_pointer_q + 1;
			status_cnt_n = status_cnt_q - 1;
		end
		if (((push_i && pop_i) && ~full_o) && ~empty_o)
			status_cnt_n = status_cnt_q;
		if (((FALL_THROUGH && (status_cnt_q == 0)) && push_i) && pop_i) begin
			data_o = data_i;
			status_cnt_n = status_cnt_q;
			read_pointer_n = read_pointer_q;
			write_pointer_n = write_pointer_q;
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			read_pointer_q <= 1'sb0;
			write_pointer_q <= 1'sb0;
			status_cnt_q <= 1'sb0;
		end
		else if (flush_i) begin
			read_pointer_q <= 1'sb0;
			write_pointer_q <= 1'sb0;
			status_cnt_q <= 1'sb0;
		end
		else begin
			read_pointer_q <= read_pointer_n;
			write_pointer_q <= write_pointer_n;
			status_cnt_q <= status_cnt_n;
		end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni)
			mem_q <= 1'sb0;
		else if (!gate_clock)
			mem_q <= mem_n;
	initial _sv2v_0 = 0;
endmodule
module fifo_v3_BDE01_041C4 (
	clk_i,
	rst_ni,
	flush_i,
	testmode_i,
	full_o,
	empty_o,
	usage_o,
	data_i,
	push_i,
	data_o,
	pop_i
);
	parameter [31:0] dtype_DATA_WIDTH = 0;
	reg _sv2v_0;
	parameter [0:0] FALL_THROUGH = 1'b0;
	parameter [31:0] DATA_WIDTH = 32;
	parameter [31:0] DEPTH = 8;
	parameter [31:0] ADDR_DEPTH = (DEPTH > 1 ? $clog2(DEPTH) : 1);
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire testmode_i;
	output wire full_o;
	output wire empty_o;
	output wire [ADDR_DEPTH - 1:0] usage_o;
	input wire [dtype_DATA_WIDTH - 1:0] data_i;
	input wire push_i;
	output reg [dtype_DATA_WIDTH - 1:0] data_o;
	input wire pop_i;
	localparam [31:0] FIFO_DEPTH = (DEPTH > 0 ? DEPTH : 1);
	reg gate_clock;
	reg [ADDR_DEPTH - 1:0] read_pointer_n;
	reg [ADDR_DEPTH - 1:0] read_pointer_q;
	reg [ADDR_DEPTH - 1:0] write_pointer_n;
	reg [ADDR_DEPTH - 1:0] write_pointer_q;
	reg [ADDR_DEPTH:0] status_cnt_n;
	reg [ADDR_DEPTH:0] status_cnt_q;
	reg [(FIFO_DEPTH * dtype_DATA_WIDTH) - 1:0] mem_n;
	reg [(FIFO_DEPTH * dtype_DATA_WIDTH) - 1:0] mem_q;
	assign usage_o = status_cnt_q[ADDR_DEPTH - 1:0];
	generate
		if (DEPTH == 0) begin : genblk1
			assign empty_o = ~push_i;
			assign full_o = ~pop_i;
		end
		else begin : genblk1
			assign full_o = status_cnt_q == FIFO_DEPTH[ADDR_DEPTH:0];
			assign empty_o = (status_cnt_q == 0) & ~(FALL_THROUGH & push_i);
		end
	endgenerate
	always @(*) begin : read_write_comb
		if (_sv2v_0)
			;
		read_pointer_n = read_pointer_q;
		write_pointer_n = write_pointer_q;
		status_cnt_n = status_cnt_q;
		data_o = (DEPTH == 0 ? data_i : mem_q[read_pointer_q * dtype_DATA_WIDTH+:dtype_DATA_WIDTH]);
		mem_n = mem_q;
		gate_clock = 1'b1;
		if (push_i && ~full_o) begin
			mem_n[write_pointer_q * dtype_DATA_WIDTH+:dtype_DATA_WIDTH] = data_i;
			gate_clock = 1'b0;
			if (write_pointer_q == (FIFO_DEPTH[ADDR_DEPTH - 1:0] - 1))
				write_pointer_n = 1'sb0;
			else
				write_pointer_n = write_pointer_q + 1;
			status_cnt_n = status_cnt_q + 1;
		end
		if (pop_i && ~empty_o) begin
			if (read_pointer_n == (FIFO_DEPTH[ADDR_DEPTH - 1:0] - 1))
				read_pointer_n = 1'sb0;
			else
				read_pointer_n = read_pointer_q + 1;
			status_cnt_n = status_cnt_q - 1;
		end
		if (((push_i && pop_i) && ~full_o) && ~empty_o)
			status_cnt_n = status_cnt_q;
		if (((FALL_THROUGH && (status_cnt_q == 0)) && push_i) && pop_i) begin
			data_o = data_i;
			status_cnt_n = status_cnt_q;
			read_pointer_n = read_pointer_q;
			write_pointer_n = write_pointer_q;
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			read_pointer_q <= 1'sb0;
			write_pointer_q <= 1'sb0;
			status_cnt_q <= 1'sb0;
		end
		else if (flush_i) begin
			read_pointer_q <= 1'sb0;
			write_pointer_q <= 1'sb0;
			status_cnt_q <= 1'sb0;
		end
		else begin
			read_pointer_q <= read_pointer_n;
			write_pointer_q <= write_pointer_n;
			status_cnt_q <= status_cnt_n;
		end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni)
			mem_q <= 1'sb0;
		else if (!gate_clock)
			mem_q <= mem_n;
	initial _sv2v_0 = 0;
endmodule
module fifo_v3_C28B9_7997C (
	clk_i,
	rst_ni,
	flush_i,
	testmode_i,
	full_o,
	empty_o,
	usage_o,
	data_i,
	push_i,
	data_o,
	pop_i
);
	parameter [31:0] dtype_dtype_ariane_pkg_FETCH_WIDTH = 0;
	parameter [31:0] dtype_dtype_ariane_pkg_INSTR_PER_FETCH = 0;
	reg _sv2v_0;
	parameter [0:0] FALL_THROUGH = 1'b0;
	parameter [31:0] DATA_WIDTH = 32;
	parameter [31:0] DEPTH = 8;
	parameter [31:0] ADDR_DEPTH = (DEPTH > 1 ? $clog2(DEPTH) : 1);
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire testmode_i;
	output wire full_o;
	output wire empty_o;
	output wire [ADDR_DEPTH - 1:0] usage_o;
	input wire [(((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0:0] data_i;
	input wire push_i;
	output reg [(((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0:0] data_o;
	input wire pop_i;
	localparam [31:0] FIFO_DEPTH = (DEPTH > 0 ? DEPTH : 1);
	reg gate_clock;
	reg [ADDR_DEPTH - 1:0] read_pointer_n;
	reg [ADDR_DEPTH - 1:0] read_pointer_q;
	reg [ADDR_DEPTH - 1:0] write_pointer_n;
	reg [ADDR_DEPTH - 1:0] write_pointer_q;
	reg [ADDR_DEPTH:0] status_cnt_n;
	reg [ADDR_DEPTH:0] status_cnt_q;
	reg [(((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) >= 0 ? (FIFO_DEPTH * ((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 1)) - 1 : (FIFO_DEPTH * (1 - ((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0))) + ((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) - 1)):(((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) >= 0 ? 0 : (((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0)] mem_n;
	reg [(((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) >= 0 ? (FIFO_DEPTH * ((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 1)) - 1 : (FIFO_DEPTH * (1 - ((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0))) + ((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) - 1)):(((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) >= 0 ? 0 : (((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0)] mem_q;
	assign usage_o = status_cnt_q[ADDR_DEPTH - 1:0];
	generate
		if (DEPTH == 0) begin : genblk1
			assign empty_o = ~push_i;
			assign full_o = ~pop_i;
		end
		else begin : genblk1
			assign full_o = status_cnt_q == FIFO_DEPTH[ADDR_DEPTH:0];
			assign empty_o = (status_cnt_q == 0) & ~(FALL_THROUGH & push_i);
		end
	endgenerate
	always @(*) begin : read_write_comb
		if (_sv2v_0)
			;
		read_pointer_n = read_pointer_q;
		write_pointer_n = write_pointer_q;
		status_cnt_n = status_cnt_q;
		data_o = (DEPTH == 0 ? data_i : mem_q[(((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) >= 0 ? 0 : (((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) + (read_pointer_q * (((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) >= 0 ? (((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 1 : 1 - ((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0)))+:(((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) >= 0 ? (((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 1 : 1 - ((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0))]);
		mem_n = mem_q;
		gate_clock = 1'b1;
		if (push_i && ~full_o) begin
			mem_n[(((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) >= 0 ? 0 : (((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) + (write_pointer_q * (((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) >= 0 ? (((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 1 : 1 - ((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0)))+:(((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0) >= 0 ? (((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 1 : 1 - ((((64 + dtype_dtype_ariane_pkg_FETCH_WIDTH) + 68) + dtype_dtype_ariane_pkg_INSTR_PER_FETCH) + 0))] = data_i;
			gate_clock = 1'b0;
			if (write_pointer_q == (FIFO_DEPTH[ADDR_DEPTH - 1:0] - 1))
				write_pointer_n = 1'sb0;
			else
				write_pointer_n = write_pointer_q + 1;
			status_cnt_n = status_cnt_q + 1;
		end
		if (pop_i && ~empty_o) begin
			if (read_pointer_n == (FIFO_DEPTH[ADDR_DEPTH - 1:0] - 1))
				read_pointer_n = 1'sb0;
			else
				read_pointer_n = read_pointer_q + 1;
			status_cnt_n = status_cnt_q - 1;
		end
		if (((push_i && pop_i) && ~full_o) && ~empty_o)
			status_cnt_n = status_cnt_q;
		if (((FALL_THROUGH && (status_cnt_q == 0)) && push_i) && pop_i) begin
			data_o = data_i;
			status_cnt_n = status_cnt_q;
			read_pointer_n = read_pointer_q;
			write_pointer_n = write_pointer_q;
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			read_pointer_q <= 1'sb0;
			write_pointer_q <= 1'sb0;
			status_cnt_q <= 1'sb0;
		end
		else if (flush_i) begin
			read_pointer_q <= 1'sb0;
			write_pointer_q <= 1'sb0;
			status_cnt_q <= 1'sb0;
		end
		else begin
			read_pointer_q <= read_pointer_n;
			write_pointer_q <= write_pointer_n;
			status_cnt_q <= status_cnt_n;
		end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni)
			mem_q <= 1'sb0;
		else if (!gate_clock)
			mem_q <= mem_n;
	initial _sv2v_0 = 0;
endmodule
module lzc (
	in_i,
	cnt_o,
	empty_o
);
	parameter [31:0] WIDTH = 2;
	parameter [31:0] MODE = 0;
	input wire [WIDTH - 1:0] in_i;
	output wire [$clog2(WIDTH) - 1:0] cnt_o;
	output wire empty_o;
	localparam signed [31:0] NUM_LEVELS = $clog2(WIDTH);
	wire [(WIDTH * NUM_LEVELS) - 1:0] index_lut;
	wire [(2 ** NUM_LEVELS) - 1:0] sel_nodes;
	wire [((2 ** NUM_LEVELS) * NUM_LEVELS) - 1:0] index_nodes;
	wire [WIDTH - 1:0] in_tmp;
	function automatic [WIDTH - 1:0] _sv2v_strm_5A843;
		input reg [(0 + WIDTH) - 1:0] inp;
		reg [(0 + WIDTH) - 1:0] _sv2v_strm_5EA55_inp;
		reg [(0 + WIDTH) - 1:0] _sv2v_strm_5EA55_out;
		integer _sv2v_strm_5EA55_idx;
		begin
			_sv2v_strm_5EA55_inp = {inp};
			for (_sv2v_strm_5EA55_idx = 0; _sv2v_strm_5EA55_idx <= ((0 + WIDTH) - 1); _sv2v_strm_5EA55_idx = _sv2v_strm_5EA55_idx + 1)
				_sv2v_strm_5EA55_out[((0 + WIDTH) - 1) - _sv2v_strm_5EA55_idx-:1] = _sv2v_strm_5EA55_inp[_sv2v_strm_5EA55_idx+:1];
			_sv2v_strm_5A843 = ((0 + WIDTH) <= WIDTH ? _sv2v_strm_5EA55_out << (WIDTH - (0 + WIDTH)) : _sv2v_strm_5EA55_out >> ((0 + WIDTH) - WIDTH));
		end
	endfunction
	assign in_tmp = (MODE ? _sv2v_strm_5A843({in_i}) : in_i);
	genvar _gv_j_1;
	generate
		for (_gv_j_1 = 0; _gv_j_1 < WIDTH; _gv_j_1 = _gv_j_1 + 1) begin : g_index_lut
			localparam j = _gv_j_1;
			assign index_lut[j * NUM_LEVELS+:NUM_LEVELS] = j;
		end
	endgenerate
	genvar _gv_level_1;
	generate
		for (_gv_level_1 = 0; _gv_level_1 < NUM_LEVELS; _gv_level_1 = _gv_level_1 + 1) begin : g_levels
			localparam level = _gv_level_1;
			if (level == (NUM_LEVELS - 1)) begin : g_last_level
				genvar _gv_k_2;
				for (_gv_k_2 = 0; _gv_k_2 < (2 ** level); _gv_k_2 = _gv_k_2 + 1) begin : g_level
					localparam k = _gv_k_2;
					if ((k * 2) < (WIDTH - 1)) begin : genblk1
						assign sel_nodes[((2 ** level) - 1) + k] = in_tmp[k * 2] | in_tmp[(k * 2) + 1];
						assign index_nodes[(((2 ** level) - 1) + k) * NUM_LEVELS+:NUM_LEVELS] = (in_tmp[k * 2] == 1'b1 ? index_lut[(k * 2) * NUM_LEVELS+:NUM_LEVELS] : index_lut[((k * 2) + 1) * NUM_LEVELS+:NUM_LEVELS]);
					end
					if ((k * 2) == (WIDTH - 1)) begin : genblk2
						assign sel_nodes[((2 ** level) - 1) + k] = in_tmp[k * 2];
						assign index_nodes[(((2 ** level) - 1) + k) * NUM_LEVELS+:NUM_LEVELS] = index_lut[(k * 2) * NUM_LEVELS+:NUM_LEVELS];
					end
					if ((k * 2) > (WIDTH - 1)) begin : genblk3
						assign sel_nodes[((2 ** level) - 1) + k] = 1'b0;
						assign index_nodes[(((2 ** level) - 1) + k) * NUM_LEVELS+:NUM_LEVELS] = 1'sb0;
					end
				end
			end
			else begin : genblk1
				genvar _gv_l_1;
				for (_gv_l_1 = 0; _gv_l_1 < (2 ** level); _gv_l_1 = _gv_l_1 + 1) begin : g_level
					localparam l = _gv_l_1;
					assign sel_nodes[((2 ** level) - 1) + l] = sel_nodes[((2 ** (level + 1)) - 1) + (l * 2)] | sel_nodes[(((2 ** (level + 1)) - 1) + (l * 2)) + 1];
					assign index_nodes[(((2 ** level) - 1) + l) * NUM_LEVELS+:NUM_LEVELS] = (sel_nodes[((2 ** (level + 1)) - 1) + (l * 2)] == 1'b1 ? index_nodes[(((2 ** (level + 1)) - 1) + (l * 2)) * NUM_LEVELS+:NUM_LEVELS] : index_nodes[((((2 ** (level + 1)) - 1) + (l * 2)) + 1) * NUM_LEVELS+:NUM_LEVELS]);
				end
			end
		end
	endgenerate
	assign cnt_o = (NUM_LEVELS > 0 ? index_nodes[0+:NUM_LEVELS] : {$clog2(WIDTH) {1'sb0}});
	assign empty_o = (NUM_LEVELS > 0 ? ~sel_nodes[0] : ~(|in_i));
endmodule
module rrarbiter (
	clk_i,
	rst_ni,
	flush_i,
	en_i,
	req_i,
	ack_o,
	vld_o,
	idx_o
);
	parameter [31:0] NUM_REQ = 13;
	parameter [31:0] LOCK_IN = 0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire en_i;
	input wire [NUM_REQ - 1:0] req_i;
	output wire [NUM_REQ - 1:0] ack_o;
	output wire vld_o;
	output wire [$clog2(NUM_REQ) - 1:0] idx_o;
	localparam SEL_WIDTH = $clog2(NUM_REQ);
	wire [SEL_WIDTH - 1:0] arb_sel_d;
	reg [SEL_WIDTH - 1:0] arb_sel_q;
	wire [SEL_WIDTH - 1:0] arb_sel_lock_d;
	reg [SEL_WIDTH - 1:0] arb_sel_lock_q;
	wire [NUM_REQ - 1:0] mask_lut [NUM_REQ - 1:0];
	wire [NUM_REQ - 1:0] mask;
	wire [NUM_REQ - 1:0] masked_lower;
	wire [NUM_REQ - 1:0] masked_upper;
	wire [SEL_WIDTH - 1:0] lower_idx;
	wire [SEL_WIDTH - 1:0] upper_idx;
	wire [SEL_WIDTH - 1:0] next_idx;
	wire no_lower_ones;
	wire lock_d;
	reg lock_q;
	assign idx_o = arb_sel_d;
	assign vld_o = |req_i & en_i;
	generate
		if (LOCK_IN > 0) begin : g_lock_in
			assign lock_d = |req_i & ~en_i;
			assign arb_sel_lock_d = arb_sel_d;
		end
		else begin : genblk1
			assign lock_d = 1'sb0;
			assign arb_sel_lock_d = 1'sb0;
		end
		if ((NUM_REQ == 2) && !LOCK_IN) begin : g_rrlogic
			assign arb_sel_d = (arb_sel_q | (~arb_sel_q & ~req_i[0])) & req_i[1];
			assign ack_o[0] = ((~arb_sel_q | (arb_sel_q & ~req_i[1])) & req_i[0]) & en_i;
			assign ack_o[1] = arb_sel_d & en_i;
		end
		else begin : genblk2
			assign mask = mask_lut[arb_sel_q];
			lzc #(.WIDTH(NUM_REQ)) i_lower_ff1(
				.in_i(masked_lower),
				.cnt_o(lower_idx),
				.empty_o(no_lower_ones)
			);
			lzc #(.WIDTH(NUM_REQ)) i_upper_ff1(
				.in_i(masked_upper),
				.cnt_o(upper_idx),
				.empty_o()
			);
			assign next_idx = (no_lower_ones ? upper_idx : lower_idx);
			assign arb_sel_d = (lock_q ? arb_sel_lock_q : (next_idx < NUM_REQ ? next_idx : $unsigned(NUM_REQ - 1)));
		end
	endgenerate
	genvar _gv_k_3;
	generate
		for (_gv_k_3 = 0; (_gv_k_3 < NUM_REQ) && ((NUM_REQ > 2) || LOCK_IN); _gv_k_3 = _gv_k_3 + 1) begin : g_mask
			localparam k = _gv_k_3;
			assign mask_lut[k] = $unsigned((2 ** (k + 1)) - 1);
			assign masked_lower[k] = ~mask[k] & req_i[k];
			assign masked_upper[k] = mask[k] & req_i[k];
			assign ack_o[k] = (arb_sel_d == k) && vld_o;
		end
	endgenerate
	always @(posedge clk_i or negedge rst_ni) begin : p_regs
		if (~rst_ni) begin
			arb_sel_q <= 1'sb0;
			lock_q <= 1'b0;
			arb_sel_lock_q <= 1'sb0;
		end
		else if (flush_i) begin
			arb_sel_q <= 1'sb0;
			lock_q <= 1'b0;
			arb_sel_lock_q <= 1'sb0;
		end
		else begin
			lock_q <= lock_d;
			arb_sel_lock_q <= arb_sel_lock_d;
			if (vld_o)
				arb_sel_q <= arb_sel_d;
		end
	end
endmodule
module cdc_2phase_5E31A (
	src_rst_ni,
	src_clk_i,
	src_data_i,
	src_valid_i,
	src_ready_o,
	dst_rst_ni,
	dst_clk_i,
	dst_data_o,
	dst_valid_o,
	dst_ready_i
);
	input wire src_rst_ni;
	input wire src_clk_i;
	input wire [40:0] src_data_i;
	input wire src_valid_i;
	output wire src_ready_o;
	input wire dst_rst_ni;
	input wire dst_clk_i;
	output wire [40:0] dst_data_o;
	output wire dst_valid_o;
	input wire dst_ready_i;
	(* dont_touch = "true" *) wire async_req;
	(* dont_touch = "true" *) wire async_ack;
	(* dont_touch = "true" *) wire [40:0] async_data;
	cdc_2phase_src_350EA i_src(
		.rst_ni(src_rst_ni),
		.clk_i(src_clk_i),
		.data_i(src_data_i),
		.valid_i(src_valid_i),
		.ready_o(src_ready_o),
		.async_req_o(async_req),
		.async_ack_i(async_ack),
		.async_data_o(async_data)
	);
	cdc_2phase_dst_9D2F9 i_dst(
		.rst_ni(dst_rst_ni),
		.clk_i(dst_clk_i),
		.data_o(dst_data_o),
		.valid_o(dst_valid_o),
		.ready_i(dst_ready_i),
		.async_req_i(async_req),
		.async_ack_o(async_ack),
		.async_data_i(async_data)
	);
endmodule
module cdc_2phase_D553F (
	src_rst_ni,
	src_clk_i,
	src_data_i,
	src_valid_i,
	src_ready_o,
	dst_rst_ni,
	dst_clk_i,
	dst_data_o,
	dst_valid_o,
	dst_ready_i
);
	input wire src_rst_ni;
	input wire src_clk_i;
	input wire [33:0] src_data_i;
	input wire src_valid_i;
	output wire src_ready_o;
	input wire dst_rst_ni;
	input wire dst_clk_i;
	output wire [33:0] dst_data_o;
	output wire dst_valid_o;
	input wire dst_ready_i;
	(* dont_touch = "true" *) wire async_req;
	(* dont_touch = "true" *) wire async_ack;
	(* dont_touch = "true" *) wire [33:0] async_data;
	cdc_2phase_src_58398 i_src(
		.rst_ni(src_rst_ni),
		.clk_i(src_clk_i),
		.data_i(src_data_i),
		.valid_i(src_valid_i),
		.ready_o(src_ready_o),
		.async_req_o(async_req),
		.async_ack_i(async_ack),
		.async_data_o(async_data)
	);
	cdc_2phase_dst_22E3E i_dst(
		.rst_ni(dst_rst_ni),
		.clk_i(dst_clk_i),
		.data_o(dst_data_o),
		.valid_o(dst_valid_o),
		.ready_i(dst_ready_i),
		.async_req_i(async_req),
		.async_ack_o(async_ack),
		.async_data_i(async_data)
	);
endmodule
module cdc_2phase_src_350EA (
	rst_ni,
	clk_i,
	data_i,
	valid_i,
	ready_o,
	async_req_o,
	async_ack_i,
	async_data_o
);
	input wire rst_ni;
	input wire clk_i;
	input wire [40:0] data_i;
	input wire valid_i;
	output wire ready_o;
	output wire async_req_o;
	input wire async_ack_i;
	output wire [40:0] async_data_o;
	(* dont_touch = "true" *) reg req_src_q;
	(* dont_touch = "true" *) reg ack_src_q;
	(* dont_touch = "true" *) reg ack_q;
	(* dont_touch = "true" *) reg [40:0] data_src_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			req_src_q <= 0;
			data_src_q <= 1'sb0;
		end
		else if (valid_i && ready_o) begin
			req_src_q <= ~req_src_q;
			data_src_q <= data_i;
		end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			ack_src_q <= 0;
			ack_q <= 0;
		end
		else begin
			ack_src_q <= async_ack_i;
			ack_q <= ack_src_q;
		end
	assign ready_o = req_src_q == ack_q;
	assign async_req_o = req_src_q;
	assign async_data_o = data_src_q;
endmodule
module cdc_2phase_src_58398 (
	rst_ni,
	clk_i,
	data_i,
	valid_i,
	ready_o,
	async_req_o,
	async_ack_i,
	async_data_o
);
	input wire rst_ni;
	input wire clk_i;
	input wire [33:0] data_i;
	input wire valid_i;
	output wire ready_o;
	output wire async_req_o;
	input wire async_ack_i;
	output wire [33:0] async_data_o;
	(* dont_touch = "true" *) reg req_src_q;
	(* dont_touch = "true" *) reg ack_src_q;
	(* dont_touch = "true" *) reg ack_q;
	(* dont_touch = "true" *) reg [33:0] data_src_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			req_src_q <= 0;
			data_src_q <= 1'sb0;
		end
		else if (valid_i && ready_o) begin
			req_src_q <= ~req_src_q;
			data_src_q <= data_i;
		end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			ack_src_q <= 0;
			ack_q <= 0;
		end
		else begin
			ack_src_q <= async_ack_i;
			ack_q <= ack_src_q;
		end
	assign ready_o = req_src_q == ack_q;
	assign async_req_o = req_src_q;
	assign async_data_o = data_src_q;
endmodule
module cdc_2phase_dst_22E3E (
	rst_ni,
	clk_i,
	data_o,
	valid_o,
	ready_i,
	async_req_i,
	async_ack_o,
	async_data_i
);
	input wire rst_ni;
	input wire clk_i;
	output wire [33:0] data_o;
	output wire valid_o;
	input wire ready_i;
	input wire async_req_i;
	output wire async_ack_o;
	input wire [33:0] async_data_i;
	(* dont_touch = "true" *) (* async_reg = "true" *) reg req_dst_q;
	(* dont_touch = "true" *) (* async_reg = "true" *) reg req_q0;
	(* dont_touch = "true" *) (* async_reg = "true" *) reg req_q1;
	(* dont_touch = "true" *) (* async_reg = "true" *) reg ack_dst_q;
	(* dont_touch = "true" *) reg [33:0] data_dst_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			ack_dst_q <= 0;
		else if (valid_o && ready_i)
			ack_dst_q <= ~ack_dst_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			data_dst_q <= 1'sb0;
		else if ((req_q0 != req_q1) && !valid_o)
			data_dst_q <= async_data_i;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			req_dst_q <= 0;
			req_q0 <= 0;
			req_q1 <= 0;
		end
		else begin
			req_dst_q <= async_req_i;
			req_q0 <= req_dst_q;
			req_q1 <= req_q0;
		end
	assign valid_o = ack_dst_q != req_q1;
	assign data_o = data_dst_q;
	assign async_ack_o = ack_dst_q;
endmodule
module cdc_2phase_dst_9D2F9 (
	rst_ni,
	clk_i,
	data_o,
	valid_o,
	ready_i,
	async_req_i,
	async_ack_o,
	async_data_i
);
	input wire rst_ni;
	input wire clk_i;
	output wire [40:0] data_o;
	output wire valid_o;
	input wire ready_i;
	input wire async_req_i;
	output wire async_ack_o;
	input wire [40:0] async_data_i;
	(* dont_touch = "true" *) (* async_reg = "true" *) reg req_dst_q;
	(* dont_touch = "true" *) (* async_reg = "true" *) reg req_q0;
	(* dont_touch = "true" *) (* async_reg = "true" *) reg req_q1;
	(* dont_touch = "true" *) (* async_reg = "true" *) reg ack_dst_q;
	(* dont_touch = "true" *) reg [40:0] data_dst_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			ack_dst_q <= 0;
		else if (valid_o && ready_i)
			ack_dst_q <= ~ack_dst_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			data_dst_q <= 1'sb0;
		else if ((req_q0 != req_q1) && !valid_o)
			data_dst_q <= async_data_i;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			req_dst_q <= 0;
			req_q0 <= 0;
			req_q1 <= 0;
		end
		else begin
			req_dst_q <= async_req_i;
			req_q0 <= req_dst_q;
			req_q1 <= req_q0;
		end
	assign valid_o = ack_dst_q != req_q1;
	assign data_o = data_dst_q;
	assign async_ack_o = ack_dst_q;
endmodule
module pipe_reg_simple_218FF (
	clk_i,
	rst_ni,
	d_i,
	d_o
);
	parameter [31:0] Depth = 1;
	input wire clk_i;
	input wire rst_ni;
	input wire [196:0] d_i;
	output reg [196:0] d_o;
	generate
		if (Depth == 0) begin : genblk1
			wire [197:1] sv2v_tmp_E0E3B;
			assign sv2v_tmp_E0E3B = d_i;
			always @(*) d_o = sv2v_tmp_E0E3B;
		end
		else if (Depth == 1) begin : genblk1
			always @(posedge clk_i or negedge rst_ni)
				if (~rst_ni)
					d_o <= 1'sb0;
				else
					d_o <= d_i;
		end
		else if (Depth > 1) begin : genblk1
			wire [(Depth * 197) - 1:0] reg_d;
			reg [(Depth * 197) - 1:0] reg_q;
			wire [197:1] sv2v_tmp_C6BED;
			assign sv2v_tmp_C6BED = reg_q[(Depth - 1) * 197+:197];
			always @(*) d_o = sv2v_tmp_C6BED;
			assign reg_d = {reg_q[197 * (((Depth - 2) >= 0 ? Depth - 2 : ((Depth - 2) + ((Depth - 2) >= 0 ? Depth - 1 : 3 - Depth)) - 1) - (((Depth - 2) >= 0 ? Depth - 1 : 3 - Depth) - 1))+:197 * ((Depth - 2) >= 0 ? Depth - 1 : 3 - Depth)], d_i};
			always @(posedge clk_i or negedge rst_ni)
				if (~rst_ni)
					reg_q <= 1'sb0;
				else
					reg_q <= reg_d;
		end
	endgenerate
endmodule
module SyncSpRamBeNx64 (
	Clk_CI,
	Rst_RBI,
	CSel_SI,
	WrEn_SI,
	BEn_SI,
	WrData_DI,
	Addr_DI,
	RdData_DO
);
	parameter ADDR_WIDTH = 10;
	parameter DATA_DEPTH = 1024;
	parameter OUT_REGS = 0;
	parameter SIM_INIT = 0;
	input wire Clk_CI;
	input wire Rst_RBI;
	input wire CSel_SI;
	input wire WrEn_SI;
	input wire [7:0] BEn_SI;
	input wire [63:0] WrData_DI;
	input wire [ADDR_WIDTH - 1:0] Addr_DI;
	output wire [63:0] RdData_DO;
	localparam DATA_BYTES = 8;
	reg [63:0] RdData_DN;
	reg [63:0] RdData_DP;
	reg [63:0] Mem_DP [DATA_DEPTH - 1:0];
	always @(posedge Clk_CI) begin : sv2v_autoblock_1
		reg [63:0] val;
		if ((Rst_RBI == 1'b0) && (SIM_INIT > 0)) begin : sv2v_autoblock_2
			reg signed [31:0] k;
			for (k = 0; k < DATA_DEPTH; k = k + 1)
				begin
					if (SIM_INIT == 1)
						val = 1'sb0;
					else
						val = 64'hdeadbeefdeadbeef;
					Mem_DP[k] = val;
				end
		end
		else if (CSel_SI) begin
			if (WrEn_SI) begin
				if (BEn_SI[0])
					Mem_DP[Addr_DI][7:0] <= WrData_DI[7:0];
				if (BEn_SI[1])
					Mem_DP[Addr_DI][15:8] <= WrData_DI[15:8];
				if (BEn_SI[2])
					Mem_DP[Addr_DI][23:16] <= WrData_DI[23:16];
				if (BEn_SI[3])
					Mem_DP[Addr_DI][31:24] <= WrData_DI[31:24];
				if (BEn_SI[4])
					Mem_DP[Addr_DI][39:32] <= WrData_DI[39:32];
				if (BEn_SI[5])
					Mem_DP[Addr_DI][47:40] <= WrData_DI[47:40];
				if (BEn_SI[6])
					Mem_DP[Addr_DI][55:48] <= WrData_DI[55:48];
				if (BEn_SI[7])
					Mem_DP[Addr_DI][63:56] <= WrData_DI[63:56];
			end
			RdData_DN <= Mem_DP[Addr_DI];
		end
	end
	generate
		if (OUT_REGS > 0) begin : g_outreg
			always @(posedge Clk_CI or negedge Rst_RBI)
				if (Rst_RBI == 1'b0)
					RdData_DP <= 0;
				else
					RdData_DP <= RdData_DN;
		end
		if (OUT_REGS == 0) begin : g_oureg_byp
			wire [64:1] sv2v_tmp_31451;
			assign sv2v_tmp_31451 = RdData_DN;
			always @(*) RdData_DP = sv2v_tmp_31451;
		end
	endgenerate
	assign RdData_DO = RdData_DP;
endmodule
module cluster_clock_inverter (
	clk_i,
	clk_o
);
	input wire clk_i;
	output wire clk_o;
	assign clk_o = ~clk_i;
endmodule
module pulp_clock_mux2 (
	clk0_i,
	clk1_i,
	clk_sel_i,
	clk_o
);
	reg _sv2v_0;
	input wire clk0_i;
	input wire clk1_i;
	input wire clk_sel_i;
	output reg clk_o;
	always @(*) begin
		if (_sv2v_0)
			;
		if (clk_sel_i == 1'b0)
			clk_o = clk0_i;
		else
			clk_o = clk1_i;
	end
	initial _sv2v_0 = 0;
endmodule
module axi_adapter (
	clk_i,
	rst_ni,
	req_i,
	type_i,
	gnt_o,
	gnt_id_o,
	addr_i,
	we_i,
	wdata_i,
	be_i,
	size_i,
	id_i,
	valid_o,
	rdata_o,
	id_o,
	critical_word_o,
	critical_word_valid_o,
	axi_req_o,
	axi_resp_i
);
	reg _sv2v_0;
	parameter [31:0] DATA_WIDTH = 256;
	parameter [0:0] CRITICAL_WORD_FIRST = 0;
	parameter [31:0] AXI_ID_WIDTH = 10;
	parameter [31:0] CACHELINE_BYTE_OFFSET = 8;
	input wire clk_i;
	input wire rst_ni;
	input wire req_i;
	input wire type_i;
	output reg gnt_o;
	output reg [AXI_ID_WIDTH - 1:0] gnt_id_o;
	input wire [63:0] addr_i;
	input wire we_i;
	input wire [((DATA_WIDTH / 64) * 64) - 1:0] wdata_i;
	input wire [((DATA_WIDTH / 64) * 8) - 1:0] be_i;
	input wire [1:0] size_i;
	input wire [AXI_ID_WIDTH - 1:0] id_i;
	output reg valid_o;
	output reg [((DATA_WIDTH / 64) * 64) - 1:0] rdata_o;
	output reg [AXI_ID_WIDTH - 1:0] id_o;
	output reg [63:0] critical_word_o;
	output reg critical_word_valid_o;
	localparam ariane_axi_AddrWidth = 64;
	localparam ariane_axi_IdWidth = 4;
	localparam ariane_axi_DataWidth = 64;
	localparam ariane_axi_StrbWidth = 8;
	output reg [277:0] axi_req_o;
	input wire [81:0] axi_resp_i;
	localparam BURST_SIZE = (DATA_WIDTH / 64) - 1;
	localparam ADDR_INDEX = ($clog2(DATA_WIDTH / 64) > 0 ? $clog2(DATA_WIDTH / 64) : 1);
	reg [3:0] state_q;
	reg [3:0] state_d;
	reg [ADDR_INDEX - 1:0] cnt_d;
	reg [ADDR_INDEX - 1:0] cnt_q;
	reg [((DATA_WIDTH / 64) * 64) - 1:0] cache_line_d;
	reg [((DATA_WIDTH / 64) * 64) - 1:0] cache_line_q;
	reg [(DATA_WIDTH / 64) - 1:0] addr_offset_d;
	reg [(DATA_WIDTH / 64) - 1:0] addr_offset_q;
	reg [AXI_ID_WIDTH - 1:0] id_d;
	reg [AXI_ID_WIDTH - 1:0] id_q;
	reg [ADDR_INDEX - 1:0] index;
	always @(*) begin : axi_fsm
		if (_sv2v_0)
			;
		axi_req_o[174] = 1'b0;
		axi_req_o[273-:64] = addr_i;
		axi_req_o[191-:3] = 3'b000;
		axi_req_o[184-:4] = 4'b0000;
		axi_req_o[209-:8] = 8'b00000000;
		axi_req_o[201-:3] = {1'b0, size_i};
		axi_req_o[198-:2] = (type_i == 1'd0 ? 2'b00 : 2'b01);
		axi_req_o[196] = 1'b0;
		axi_req_o[195-:4] = 4'b0000;
		axi_req_o[188-:4] = 4'b0000;
		axi_req_o[277-:4] = id_i;
		axi_req_o[180-:6] = 1'sb0;
		axi_req_o[1] = 1'b0;
		axi_req_o[94-:64] = (CRITICAL_WORD_FIRST || (type_i == 1'd0) ? addr_i : {addr_i[63:CACHELINE_BYTE_OFFSET], {{CACHELINE_BYTE_OFFSET} {1'b0}}});
		axi_req_o[12-:3] = 3'b000;
		axi_req_o[5-:4] = 4'b0000;
		axi_req_o[30-:8] = 8'b00000000;
		axi_req_o[22-:3] = {1'b0, size_i};
		axi_req_o[19-:2] = (type_i == 1'd0 ? 2'b00 : (CRITICAL_WORD_FIRST ? 2'b10 : 2'b01));
		axi_req_o[17] = 1'b0;
		axi_req_o[16-:4] = 4'b0000;
		axi_req_o[9-:4] = 4'b0000;
		axi_req_o[98-:4] = id_i;
		axi_req_o[100] = 1'b0;
		axi_req_o[173-:64] = wdata_i[0+:64];
		axi_req_o[109-:8] = be_i[0+:8];
		axi_req_o[101] = 1'b0;
		axi_req_o[99] = 1'b0;
		axi_req_o[0] = 1'b0;
		gnt_o = 1'b0;
		gnt_id_o = id_i;
		valid_o = 1'b0;
		id_o = axi_resp_i[70-:4];
		critical_word_o = axi_resp_i[66-:64];
		critical_word_valid_o = 1'b0;
		rdata_o = cache_line_q;
		state_d = state_q;
		cnt_d = cnt_q;
		cache_line_d = cache_line_q;
		addr_offset_d = addr_offset_q;
		id_d = id_q;
		index = 1'sb0;
		case (state_q)
			4'd0: begin
				cnt_d = 1'sb0;
				if (req_i) begin
					if (we_i) begin
						axi_req_o[174] = 1'b1;
						axi_req_o[100] = 1'b1;
						if (type_i == 1'd0) begin
							axi_req_o[101] = 1'b1;
							gnt_o = axi_resp_i[81] & axi_resp_i[79];
							case ({axi_resp_i[81], axi_resp_i[79]})
								2'b11: state_d = 4'd1;
								2'b01: state_d = 4'd2;
								2'b10: state_d = 4'd3;
								default: state_d = 4'd0;
							endcase
						end
						else begin
							axi_req_o[209-:8] = BURST_SIZE;
							axi_req_o[173-:64] = wdata_i[0+:64];
							axi_req_o[109-:8] = be_i[0+:8];
							if (axi_resp_i[79])
								cnt_d = BURST_SIZE - 1;
							else
								cnt_d = BURST_SIZE;
							case ({axi_resp_i[81], axi_resp_i[79]})
								2'b11: state_d = 4'd3;
								2'b01: state_d = 4'd4;
								2'b10: state_d = 4'd3;
								default:
									;
							endcase
						end
					end
					else begin
						axi_req_o[1] = 1'b1;
						gnt_o = axi_resp_i[80];
						if (type_i != 1'd0) begin
							axi_req_o[30-:8] = BURST_SIZE;
							cnt_d = BURST_SIZE;
						end
						if (axi_resp_i[80]) begin
							state_d = (type_i == 1'd0 ? 4'd6 : 4'd7);
							addr_offset_d = addr_i[ADDR_INDEX + 2:3];
						end
					end
				end
			end
			4'd2: begin
				axi_req_o[174] = 1'b1;
				if (axi_resp_i[81]) begin
					gnt_o = 1'b1;
					state_d = 4'd1;
				end
			end
			4'd4: begin
				axi_req_o[100] = 1'b1;
				axi_req_o[101] = cnt_q == {ADDR_INDEX {1'sb0}};
				if (type_i == 1'd0) begin
					axi_req_o[173-:64] = wdata_i[0+:64];
					axi_req_o[109-:8] = be_i[0+:8];
				end
				else begin
					axi_req_o[173-:64] = wdata_i[(BURST_SIZE - cnt_q) * 64+:64];
					axi_req_o[109-:8] = be_i[(BURST_SIZE - cnt_q) * 8+:8];
				end
				axi_req_o[174] = 1'b1;
				axi_req_o[209-:8] = BURST_SIZE;
				case ({axi_resp_i[81], axi_resp_i[79]})
					2'b01:
						if (cnt_q == 0)
							state_d = 4'd5;
						else
							cnt_d = cnt_q - 1;
					2'b10: state_d = 4'd3;
					2'b11:
						if (cnt_q == 0) begin
							state_d = 4'd1;
							gnt_o = 1'b1;
						end
						else begin
							state_d = 4'd3;
							cnt_d = cnt_q - 1;
						end
					default:
						;
				endcase
			end
			4'd5: begin
				axi_req_o[174] = 1'b1;
				axi_req_o[209-:8] = BURST_SIZE;
				if (axi_resp_i[81]) begin
					state_d = 4'd1;
					gnt_o = 1'b1;
				end
			end
			4'd3: begin
				axi_req_o[100] = 1'b1;
				if (type_i != 1'd0) begin
					axi_req_o[173-:64] = wdata_i[(BURST_SIZE - cnt_q) * 64+:64];
					axi_req_o[109-:8] = be_i[(BURST_SIZE - cnt_q) * 8+:8];
				end
				if (cnt_q == {ADDR_INDEX {1'sb0}}) begin
					axi_req_o[101] = 1'b1;
					if (axi_resp_i[79]) begin
						state_d = 4'd1;
						gnt_o = 1'b1;
					end
				end
				else if (axi_resp_i[79])
					cnt_d = cnt_q - 1;
			end
			4'd1: begin
				axi_req_o[99] = 1'b1;
				id_o = axi_resp_i[77-:4];
				if (axi_resp_i[78]) begin
					state_d = 4'd0;
					valid_o = 1'b1;
				end
			end
			4'd7, 4'd6: begin
				if (CRITICAL_WORD_FIRST)
					index = addr_offset_q + (BURST_SIZE - cnt_q);
				else
					index = BURST_SIZE - cnt_q;
				axi_req_o[0] = 1'b1;
				if (axi_resp_i[71]) begin
					if (CRITICAL_WORD_FIRST) begin
						if ((state_q == 4'd7) && (cnt_q == BURST_SIZE)) begin
							critical_word_valid_o = 1'b1;
							critical_word_o = axi_resp_i[66-:64];
						end
					end
					else if (index == addr_offset_q) begin
						critical_word_valid_o = 1'b1;
						critical_word_o = axi_resp_i[66-:64];
					end
					if (axi_resp_i[0]) begin
						id_d = axi_resp_i[70-:4];
						state_d = 4'd8;
					end
					if (state_q == 4'd7)
						cache_line_d[index * 64+:64] = axi_resp_i[66-:64];
					else
						cache_line_d[0+:64] = axi_resp_i[66-:64];
					cnt_d = cnt_q - 1;
				end
			end
			4'd8: begin
				valid_o = 1'b1;
				state_d = 4'd0;
				id_o = id_q;
			end
		endcase
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			state_q <= 4'd0;
			cnt_q <= 1'sb0;
			cache_line_q <= 1'sb0;
			addr_offset_q <= 1'sb0;
			id_q <= 1'sb0;
		end
		else begin
			state_q <= state_d;
			cnt_q <= cnt_d;
			cache_line_q <= cache_line_d;
			addr_offset_q <= addr_offset_d;
			id_q <= id_d;
		end
	initial _sv2v_0 = 0;
endmodule
module alu (
	clk_i,
	rst_ni,
	fu_data_i,
	result_o,
	alu_branch_res_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [205:0] fu_data_i;
	output reg [63:0] result_o;
	output reg alu_branch_res_o;
	wire [63:0] operand_a_rev;
	wire [31:0] operand_a_rev32;
	wire [64:0] operand_b_neg;
	wire [65:0] adder_result_ext_o;
	reg less;
	genvar _gv_k_4;
	generate
		for (_gv_k_4 = 0; _gv_k_4 < 64; _gv_k_4 = _gv_k_4 + 1) begin : genblk1
			localparam k = _gv_k_4;
			assign operand_a_rev[k] = fu_data_i[194 - (0 + k)];
		end
		for (_gv_k_4 = 0; _gv_k_4 < 32; _gv_k_4 = _gv_k_4 + 1) begin : genblk2
			localparam k = _gv_k_4;
			assign operand_a_rev32[k] = fu_data_i[194 - (32 + k)];
		end
	endgenerate
	reg adder_op_b_negate;
	wire adder_z_flag;
	wire [64:0] adder_in_a;
	wire [64:0] adder_in_b;
	wire [63:0] adder_result;
	always @(*) begin
		if (_sv2v_0)
			;
		adder_op_b_negate = 1'b0;
		(* full_case, parallel_case *)
		case (fu_data_i[201-:7])
			7'd17, 7'd18, 7'd1, 7'd3: adder_op_b_negate = 1'b1;
			default:
				;
		endcase
	end
	assign adder_in_a = {fu_data_i[194-:64], 1'b1};
	assign operand_b_neg = {fu_data_i[130-:64], 1'b0} ^ {65 {adder_op_b_negate}};
	assign adder_in_b = operand_b_neg;
	assign adder_result_ext_o = $unsigned(adder_in_a) + $unsigned(adder_in_b);
	assign adder_result = adder_result_ext_o[64:1];
	assign adder_z_flag = ~|adder_result;
	always @(*) begin : branch_resolve
		if (_sv2v_0)
			;
		alu_branch_res_o = 1'b1;
		case (fu_data_i[201-:7])
			7'd17: alu_branch_res_o = adder_z_flag;
			7'd18: alu_branch_res_o = ~adder_z_flag;
			7'd13, 7'd14: alu_branch_res_o = less;
			7'd15, 7'd16: alu_branch_res_o = ~less;
			default: alu_branch_res_o = 1'b1;
		endcase
	end
	wire shift_left;
	wire shift_arithmetic;
	wire [63:0] shift_amt;
	wire [63:0] shift_op_a;
	wire [31:0] shift_op_a32;
	wire [63:0] shift_result;
	wire [31:0] shift_result32;
	wire [64:0] shift_right_result;
	wire [32:0] shift_right_result32;
	wire [63:0] shift_left_result;
	wire [31:0] shift_left_result32;
	assign shift_amt = fu_data_i[130-:64];
	assign shift_left = (fu_data_i[201-:7] == 7'd9) | (fu_data_i[201-:7] == 7'd11);
	assign shift_arithmetic = (fu_data_i[201-:7] == 7'd7) | (fu_data_i[201-:7] == 7'd12);
	wire [64:0] shift_op_a_64;
	wire [32:0] shift_op_a_32;
	assign shift_op_a = (shift_left ? operand_a_rev : fu_data_i[194-:64]);
	assign shift_op_a32 = (shift_left ? operand_a_rev32 : fu_data_i[162:131]);
	assign shift_op_a_64 = {shift_arithmetic & shift_op_a[63], shift_op_a};
	assign shift_op_a_32 = {shift_arithmetic & shift_op_a[31], shift_op_a32};
	assign shift_right_result = $unsigned($signed(shift_op_a_64) >>> shift_amt[5:0]);
	assign shift_right_result32 = $unsigned($signed(shift_op_a_32) >>> shift_amt[4:0]);
	genvar _gv_j_2;
	generate
		for (_gv_j_2 = 0; _gv_j_2 < 64; _gv_j_2 = _gv_j_2 + 1) begin : genblk3
			localparam j = _gv_j_2;
			assign shift_left_result[j] = shift_right_result[63 - j];
		end
		for (_gv_j_2 = 0; _gv_j_2 < 32; _gv_j_2 = _gv_j_2 + 1) begin : genblk4
			localparam j = _gv_j_2;
			assign shift_left_result32[j] = shift_right_result32[31 - j];
		end
	endgenerate
	assign shift_result = (shift_left ? shift_left_result : shift_right_result[63:0]);
	assign shift_result32 = (shift_left ? shift_left_result32 : shift_right_result32[31:0]);
	always @(*) begin : sv2v_autoblock_1
		reg sgn;
		if (_sv2v_0)
			;
		sgn = 1'b0;
		if (((fu_data_i[201-:7] == 7'd20) || (fu_data_i[201-:7] == 7'd13)) || (fu_data_i[201-:7] == 7'd15))
			sgn = 1'b1;
		less = $signed({sgn & fu_data_i[194], fu_data_i[194-:64]}) < $signed({sgn & fu_data_i[130], fu_data_i[130-:64]});
	end
	always @(*) begin
		if (_sv2v_0)
			;
		result_o = 1'sb0;
		(* full_case, parallel_case *)
		case (fu_data_i[201-:7])
			7'd6: result_o = fu_data_i[194-:64] & fu_data_i[130-:64];
			7'd5: result_o = fu_data_i[194-:64] | fu_data_i[130-:64];
			7'd4: result_o = fu_data_i[194-:64] ^ fu_data_i[130-:64];
			7'd0, 7'd1: result_o = adder_result;
			7'd2, 7'd3: result_o = {{32 {adder_result[31]}}, adder_result[31:0]};
			7'd9, 7'd8, 7'd7: result_o = shift_result;
			7'd11, 7'd10, 7'd12: result_o = {{32 {shift_result32[31]}}, shift_result32[31:0]};
			7'd20, 7'd21: result_o = {63'b000000000000000000000000000000000000000000000000000000000000000, less};
			default:
				;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module fpu_wrap (
	clk_i,
	rst_ni,
	flush_i,
	fpu_valid_i,
	fpu_ready_o,
	fu_data_i,
	fpu_fmt_i,
	fpu_rm_i,
	fpu_frm_i,
	fpu_prec_i,
	fpu_trans_id_o,
	result_o,
	fpu_valid_o,
	fpu_exception_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire fpu_valid_i;
	output reg fpu_ready_o;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [205:0] fu_data_i;
	input wire [1:0] fpu_fmt_i;
	input wire [2:0] fpu_rm_i;
	input wire [2:0] fpu_frm_i;
	input wire [6:0] fpu_prec_i;
	output wire [2:0] fpu_trans_id_o;
	localparam [0:0] ariane_pkg_RVD = 1'b0;
	localparam [0:0] ariane_pkg_RVF = 1'b0;
	localparam [0:0] ariane_pkg_XF16 = 1'b0;
	localparam [0:0] ariane_pkg_XF16ALT = 1'b0;
	localparam [0:0] ariane_pkg_XF8 = 1'b0;
	localparam ariane_pkg_FLEN = (ariane_pkg_RVD ? 64 : (ariane_pkg_RVF ? 32 : (ariane_pkg_XF16 ? 16 : (ariane_pkg_XF16ALT ? 16 : (ariane_pkg_XF8 ? 8 : 0)))));
	output wire [ariane_pkg_FLEN - 1:0] result_o;
	output wire fpu_valid_o;
	output wire [128:0] fpu_exception_o;
	localparam [0:0] ariane_pkg_FP_PRESENT = (((ariane_pkg_RVF | ariane_pkg_RVD) | ariane_pkg_XF16) | ariane_pkg_XF16ALT) | ariane_pkg_XF8;
	localparam [30:0] ariane_pkg_LAT_COMP_FP16 = 'd3;
	localparam [30:0] ariane_pkg_LAT_COMP_FP16ALT = 'd3;
	localparam [30:0] ariane_pkg_LAT_COMP_FP32 = 'd3;
	localparam [30:0] ariane_pkg_LAT_COMP_FP64 = 'd4;
	localparam [30:0] ariane_pkg_LAT_COMP_FP8 = 'd2;
	localparam [30:0] ariane_pkg_LAT_CONV = 'd2;
	localparam [30:0] ariane_pkg_LAT_DIVSQRT = 'd2;
	localparam [30:0] ariane_pkg_LAT_NONCOMP = 'd1;
	localparam [0:0] ariane_pkg_XFVEC = 1'b0;
	generate
		if (ariane_pkg_FP_PRESENT) begin : fpu_gen
			wire [ariane_pkg_FLEN - 1:0] operand_a_i;
			wire [ariane_pkg_FLEN - 1:0] operand_b_i;
			wire [ariane_pkg_FLEN - 1:0] operand_c_i;
			assign operand_a_i = fu_data_i[130 + ariane_pkg_FLEN:131];
			assign operand_b_i = fu_data_i[66 + ariane_pkg_FLEN:67];
			assign operand_c_i = fu_data_i[2 + ariane_pkg_FLEN:3];
			localparam OPBITS = 4;
			localparam FMTBITS = 3;
			localparam IFMTBITS = 2;
			integer OP_NUMBITS;
			integer FMT_NUMBITS;
			integer IFMT_NUMBITS;
			wire [3:0] OP_FMADD;
			wire [3:0] OP_FNMSUB;
			wire [3:0] OP_ADD;
			wire [3:0] OP_MUL;
			wire [3:0] OP_DIV;
			wire [3:0] OP_SQRT;
			wire [3:0] OP_SGNJ;
			wire [3:0] OP_MINMAX;
			wire [3:0] OP_CMP;
			wire [3:0] OP_CLASS;
			wire [3:0] OP_F2I;
			wire [3:0] OP_I2F;
			wire [3:0] OP_F2F;
			wire [3:0] OP_CPKAB;
			wire [3:0] OP_CPKCD;
			wire [2:0] FMT_FP32;
			wire [2:0] FMT_FP64;
			wire [2:0] FMT_FP16;
			wire [2:0] FMT_FP8;
			wire [2:0] FMT_FP16ALT;
			wire [2:0] FMT_CUST1;
			wire [2:0] FMT_CUST2;
			wire [2:0] FMT_CUST3;
			wire [1:0] IFMT_INT8;
			wire [1:0] IFMT_INT16;
			wire [1:0] IFMT_INT32;
			wire [1:0] IFMT_INT64;
			fpnew_pkg_constants i_fpnew_constants(
				.OP_NUMBITS(OP_NUMBITS),
				.OP_FMADD(OP_FMADD),
				.OP_FNMSUB(OP_FNMSUB),
				.OP_ADD(OP_ADD),
				.OP_MUL(OP_MUL),
				.OP_DIV(OP_DIV),
				.OP_SQRT(OP_SQRT),
				.OP_SGNJ(OP_SGNJ),
				.OP_MINMAX(OP_MINMAX),
				.OP_CMP(OP_CMP),
				.OP_CLASS(OP_CLASS),
				.OP_F2I(OP_F2I),
				.OP_I2F(OP_I2F),
				.OP_F2F(OP_F2F),
				.OP_CPKAB(OP_CPKAB),
				.OP_CPKCD(OP_CPKCD),
				.FMT_NUMBITS(FMT_NUMBITS),
				.FMT_FP32(FMT_FP32),
				.FMT_FP64(FMT_FP64),
				.FMT_FP16(FMT_FP16),
				.FMT_FP8(FMT_FP8),
				.FMT_FP16ALT(FMT_FP16ALT),
				.FMT_CUST1(FMT_CUST1),
				.FMT_CUST2(FMT_CUST2),
				.FMT_CUST3(FMT_CUST3),
				.IFMT_NUMBITS(IFMT_NUMBITS),
				.IFMT_INT8(IFMT_INT8),
				.IFMT_INT16(IFMT_INT16),
				.IFMT_INT32(IFMT_INT32),
				.IFMT_INT64(IFMT_INT64)
			);
			reg [ariane_pkg_FLEN - 1:0] operand_a_d;
			reg [ariane_pkg_FLEN - 1:0] operand_a_q;
			wire [ariane_pkg_FLEN - 1:0] operand_a;
			reg [ariane_pkg_FLEN - 1:0] operand_b_d;
			reg [ariane_pkg_FLEN - 1:0] operand_b_q;
			wire [ariane_pkg_FLEN - 1:0] operand_b;
			reg [ariane_pkg_FLEN - 1:0] operand_c_d;
			reg [ariane_pkg_FLEN - 1:0] operand_c_q;
			wire [ariane_pkg_FLEN - 1:0] operand_c;
			reg [3:0] fpu_op_d;
			reg [3:0] fpu_op_q;
			wire [3:0] fpu_op;
			reg fpu_op_mod_d;
			reg fpu_op_mod_q;
			wire fpu_op_mod;
			reg [2:0] fpu_fmt_d;
			reg [2:0] fpu_fmt_q;
			wire [2:0] fpu_fmt;
			reg [2:0] fpu_fmt2_d;
			reg [2:0] fpu_fmt2_q;
			wire [2:0] fpu_fmt2;
			reg [1:0] fpu_ifmt_d;
			reg [1:0] fpu_ifmt_q;
			wire [1:0] fpu_ifmt;
			reg [2:0] fpu_rm_d;
			reg [2:0] fpu_rm_q;
			wire [2:0] fpu_rm;
			reg fpu_vec_op_d;
			reg fpu_vec_op_q;
			wire fpu_vec_op;
			reg [2:0] fpu_tag_d;
			reg [2:0] fpu_tag_q;
			wire [2:0] fpu_tag;
			wire fpu_in_ready;
			reg fpu_in_valid;
			wire fpu_out_ready;
			wire fpu_out_valid;
			wire [4:0] fpu_status;
			reg state_q;
			reg state_d;
			reg hold_inputs;
			reg use_hold;
			always @(*) begin : input_translation
				reg vec_replication;
				reg replicate_c;
				reg check_ah;
				if (_sv2v_0)
					;
				operand_a_d = operand_a_i;
				operand_b_d = operand_b_i;
				operand_c_d = operand_c_i;
				fpu_op_d = OP_SGNJ;
				fpu_op_mod_d = 1'b0;
				fpu_fmt_d = FMT_FP32;
				fpu_fmt2_d = FMT_FP32;
				fpu_ifmt_d = IFMT_INT32;
				fpu_rm_d = fpu_rm_i;
				fpu_vec_op_d = fu_data_i[205-:4] == 4'd8;
				fpu_tag_d = fu_data_i[2-:ariane_pkg_TRANS_ID_BITS];
				vec_replication = fpu_rm_i[0];
				replicate_c = 1'b0;
				check_ah = 1'b0;
				if (!((3'b000 <= fpu_rm_i) && (3'b100 >= fpu_rm_i)))
					fpu_rm_d = fpu_frm_i;
				if (fpu_vec_op_d)
					fpu_rm_d = fpu_frm_i;
				(* full_case, parallel_case *)
				case (fpu_fmt_i)
					2'b00: fpu_fmt_d = FMT_FP32;
					2'b01: fpu_fmt_d = (fpu_vec_op_d ? FMT_FP16ALT : FMT_FP64);
					2'b10:
						if (!fpu_vec_op_d && (fpu_rm_i == 3'b101))
							fpu_fmt_d = FMT_FP16ALT;
						else
							fpu_fmt_d = FMT_FP16;
					default: fpu_fmt_d = FMT_FP8;
				endcase
				(* full_case, parallel_case *)
				case (fu_data_i[201-:7])
					7'd88: begin
						fpu_op_d = OP_ADD;
						replicate_c = 1'b1;
					end
					7'd89: begin
						fpu_op_d = OP_ADD;
						fpu_op_mod_d = 1'b1;
						replicate_c = 1'b1;
					end
					7'd90: fpu_op_d = OP_MUL;
					7'd91: fpu_op_d = OP_DIV;
					7'd92: begin
						fpu_op_d = OP_MINMAX;
						fpu_rm_d = {1'b0, fpu_rm_i[1:0]};
						check_ah = 1'b1;
					end
					7'd93: fpu_op_d = OP_SQRT;
					7'd94: fpu_op_d = OP_FMADD;
					7'd95: begin
						fpu_op_d = OP_FMADD;
						fpu_op_mod_d = 1'b1;
					end
					7'd96: fpu_op_d = OP_FNMSUB;
					7'd97: begin
						fpu_op_d = OP_FNMSUB;
						fpu_op_mod_d = 1'b1;
					end
					7'd98: begin
						fpu_op_d = OP_F2I;
						if (fpu_vec_op_d) begin
							fpu_op_mod_d = fpu_rm_i[0];
							vec_replication = 1'b0;
							(* full_case, parallel_case *)
							case (fpu_fmt_i)
								2'b00: fpu_ifmt_d = IFMT_INT32;
								2'b01, 2'b10: fpu_ifmt_d = IFMT_INT16;
								2'b11: fpu_ifmt_d = IFMT_INT8;
							endcase
						end
						else begin
							fpu_op_mod_d = operand_c_i[0];
							if (operand_c_i[1])
								fpu_ifmt_d = IFMT_INT64;
							else
								fpu_ifmt_d = IFMT_INT32;
						end
					end
					7'd99: begin
						fpu_op_d = OP_I2F;
						if (fpu_vec_op_d) begin
							fpu_op_mod_d = fpu_rm_i[0];
							vec_replication = 1'b0;
							(* full_case, parallel_case *)
							case (fpu_fmt_i)
								2'b00: fpu_ifmt_d = IFMT_INT32;
								2'b01, 2'b10: fpu_ifmt_d = IFMT_INT16;
								2'b11: fpu_ifmt_d = IFMT_INT8;
							endcase
						end
						else begin
							fpu_op_mod_d = operand_c_i[0];
							if (operand_c_i[1])
								fpu_ifmt_d = IFMT_INT64;
							else
								fpu_ifmt_d = IFMT_INT32;
						end
					end
					7'd100: begin
						fpu_op_d = OP_F2F;
						if (fpu_vec_op_d) begin
							vec_replication = 1'b0;
							(* full_case, parallel_case *)
							case (operand_c_i[1:0])
								2'b00: fpu_fmt2_d = FMT_FP32;
								2'b01: fpu_fmt2_d = FMT_FP16ALT;
								2'b10: fpu_fmt2_d = FMT_FP16;
								2'b11: fpu_fmt2_d = FMT_FP8;
							endcase
						end
						else
							(* full_case, parallel_case *)
							case (operand_c_i[2:0])
								3'b000: fpu_fmt2_d = FMT_FP32;
								3'b001: fpu_fmt2_d = FMT_FP64;
								3'b010: fpu_fmt2_d = FMT_FP16;
								3'b110: fpu_fmt2_d = FMT_FP16ALT;
								3'b011: fpu_fmt2_d = FMT_FP8;
							endcase
					end
					7'd101: begin
						fpu_op_d = OP_SGNJ;
						fpu_rm_d = {1'b0, fpu_rm_i[1:0]};
						check_ah = 1'b1;
					end
					7'd102: begin
						fpu_op_d = OP_SGNJ;
						fpu_rm_d = 3'b011;
						fpu_op_mod_d = 1'b1;
						check_ah = 1'b1;
						vec_replication = 1'b0;
					end
					7'd103: begin
						fpu_op_d = OP_SGNJ;
						fpu_rm_d = 3'b011;
						check_ah = 1'b1;
						vec_replication = 1'b0;
					end
					7'd104: begin
						fpu_op_d = OP_CMP;
						fpu_rm_d = {1'b0, fpu_rm_i[1:0]};
						check_ah = 1'b1;
					end
					7'd105: begin
						fpu_op_d = OP_CLASS;
						fpu_rm_d = {1'b0, fpu_rm_i[1:0]};
						check_ah = 1'b1;
					end
					7'd106: begin
						fpu_op_d = OP_MINMAX;
						fpu_rm_d = 3'b000;
					end
					7'd107: begin
						fpu_op_d = OP_MINMAX;
						fpu_rm_d = 3'b001;
					end
					7'd108: begin
						fpu_op_d = OP_SGNJ;
						fpu_rm_d = 3'b000;
					end
					7'd109: begin
						fpu_op_d = OP_SGNJ;
						fpu_rm_d = 3'b001;
					end
					7'd110: begin
						fpu_op_d = OP_SGNJ;
						fpu_rm_d = 3'b010;
					end
					7'd111: begin
						fpu_op_d = OP_CMP;
						fpu_rm_d = 3'b010;
					end
					7'd112: begin
						fpu_op_d = OP_CMP;
						fpu_op_mod_d = 1'b1;
						fpu_rm_d = 3'b010;
					end
					7'd113: begin
						fpu_op_d = OP_CMP;
						fpu_rm_d = 3'b001;
					end
					7'd114: begin
						fpu_op_d = OP_CMP;
						fpu_op_mod_d = 1'b1;
						fpu_rm_d = 3'b001;
					end
					7'd115: begin
						fpu_op_d = OP_CMP;
						fpu_rm_d = 3'b000;
					end
					7'd116: begin
						fpu_op_d = OP_CMP;
						fpu_op_mod_d = 1'b1;
						fpu_rm_d = 3'b000;
					end
					7'd117: begin
						fpu_op_d = OP_CPKAB;
						fpu_op_mod_d = fpu_rm_i[0];
						vec_replication = 1'b0;
						fpu_fmt2_d = FMT_FP32;
					end
					7'd118: begin
						fpu_op_d = OP_CPKCD;
						fpu_op_mod_d = fpu_rm_i[0];
						vec_replication = 1'b0;
						fpu_fmt2_d = FMT_FP64;
					end
					7'd117: begin
						fpu_op_d = OP_CPKAB;
						fpu_op_mod_d = fpu_rm_i[0];
						vec_replication = 1'b0;
						fpu_fmt2_d = FMT_FP64;
					end
					7'd118: begin
						fpu_op_d = OP_CPKCD;
						fpu_op_mod_d = fpu_rm_i[0];
						vec_replication = 1'b0;
						fpu_fmt2_d = FMT_FP64;
					end
					default:
						;
				endcase
				if (!fpu_vec_op_d && check_ah) begin
					if (fpu_rm_i[2])
						fpu_fmt_d = FMT_FP16ALT;
				end
				if (fpu_vec_op_d && vec_replication) begin
					if (replicate_c)
						(* full_case, parallel_case *)
						case (fpu_fmt_d)
							FMT_FP32: operand_c_d = (ariane_pkg_RVD ? {2 {operand_c_i[31:0]}} : operand_c_i);
							FMT_FP16, FMT_FP16ALT: operand_c_d = (ariane_pkg_RVD ? {4 {operand_c_i[15:0]}} : {2 {operand_c_i[15:0]}});
							FMT_FP8: operand_c_d = (ariane_pkg_RVD ? {8 {operand_c_i[7:0]}} : {4 {operand_c_i[7:0]}});
						endcase
					else
						(* full_case, parallel_case *)
						case (fpu_fmt_d)
							FMT_FP32: operand_b_d = (ariane_pkg_RVD ? {2 {operand_b_i[31:0]}} : operand_b_i);
							FMT_FP16, FMT_FP16ALT: operand_b_d = (ariane_pkg_RVD ? {4 {operand_b_i[15:0]}} : {2 {operand_b_i[15:0]}});
							FMT_FP8: operand_b_d = (ariane_pkg_RVD ? {8 {operand_b_i[7:0]}} : {4 {operand_b_i[7:0]}});
						endcase
				end
			end
			always @(*) begin : p_inputFSM
				if (_sv2v_0)
					;
				fpu_ready_o = 1'b0;
				fpu_in_valid = 1'b0;
				hold_inputs = 1'b0;
				use_hold = 1'b0;
				state_d = state_q;
				(* full_case, parallel_case *)
				case (state_q)
					1'd0: begin
						fpu_ready_o = 1'b1;
						fpu_in_valid = fpu_valid_i;
						if (fpu_valid_i & ~fpu_in_ready) begin
							fpu_ready_o = 1'b0;
							hold_inputs = 1'b1;
							state_d = 1'd1;
						end
					end
					1'd1: begin
						fpu_in_valid = 1'b1;
						use_hold = 1'b1;
						if (fpu_in_ready) begin
							fpu_ready_o = 1'b1;
							state_d = 1'd0;
						end
					end
					default:
						;
				endcase
				if (flush_i)
					state_d = 1'd0;
			end
			always @(posedge clk_i or negedge rst_ni) begin : fp_hold_reg
				if (~rst_ni) begin
					state_q <= 1'd0;
					operand_a_q <= 1'sb0;
					operand_b_q <= 1'sb0;
					operand_c_q <= 1'sb0;
					fpu_op_q <= 1'sb0;
					fpu_op_mod_q <= 1'sb0;
					fpu_fmt_q <= 1'sb0;
					fpu_fmt2_q <= 1'sb0;
					fpu_ifmt_q <= 1'sb0;
					fpu_rm_q <= 1'sb0;
					fpu_vec_op_q <= 1'sb0;
					fpu_tag_q <= 1'sb0;
				end
				else begin
					state_q <= state_d;
					if (hold_inputs) begin
						operand_a_q <= operand_a_d;
						operand_b_q <= operand_b_d;
						operand_c_q <= operand_c_d;
						fpu_op_q <= fpu_op_d;
						fpu_op_mod_q <= fpu_op_mod_d;
						fpu_fmt_q <= fpu_fmt_d;
						fpu_fmt2_q <= fpu_fmt2_d;
						fpu_ifmt_q <= fpu_ifmt_d;
						fpu_rm_q <= fpu_rm_d;
						fpu_vec_op_q <= fpu_vec_op_d;
						fpu_tag_q <= fpu_tag_d;
					end
				end
			end
			assign operand_a = (use_hold ? operand_a_q : operand_a_d);
			assign operand_b = (use_hold ? operand_b_q : operand_b_d);
			assign operand_c = (use_hold ? operand_c_q : operand_c_d);
			assign fpu_op = (use_hold ? fpu_op_q : fpu_op_d);
			assign fpu_op_mod = (use_hold ? fpu_op_mod_q : fpu_op_mod_d);
			assign fpu_fmt = (use_hold ? fpu_fmt_q : fpu_fmt_d);
			assign fpu_fmt2 = (use_hold ? fpu_fmt2_q : fpu_fmt2_d);
			assign fpu_ifmt = (use_hold ? fpu_ifmt_q : fpu_ifmt_d);
			assign fpu_rm = (use_hold ? fpu_rm_q : fpu_rm_d);
			assign fpu_vec_op = (use_hold ? fpu_vec_op_q : fpu_vec_op_d);
			assign fpu_tag = (use_hold ? fpu_tag_q : fpu_tag_d);
			fpnew_top #(
				.WIDTH(ariane_pkg_FLEN),
				.TAG_WIDTH(ariane_pkg_TRANS_ID_BITS),
				.RV64(1'b1),
				.RVF(ariane_pkg_RVF),
				.RVD(ariane_pkg_RVD),
				.Xf16(ariane_pkg_XF16),
				.Xf16alt(ariane_pkg_XF16ALT),
				.Xf8(ariane_pkg_XF8),
				.Xfvec(ariane_pkg_XFVEC),
				.LATENCY_COMP_F(ariane_pkg_LAT_COMP_FP32),
				.LATENCY_COMP_D(ariane_pkg_LAT_COMP_FP64),
				.LATENCY_COMP_Xf16(ariane_pkg_LAT_COMP_FP16),
				.LATENCY_COMP_Xf16alt(ariane_pkg_LAT_COMP_FP16ALT),
				.LATENCY_COMP_Xf8(ariane_pkg_LAT_COMP_FP8),
				.LATENCY_DIVSQRT(ariane_pkg_LAT_DIVSQRT),
				.LATENCY_NONCOMP(ariane_pkg_LAT_NONCOMP),
				.LATENCY_CONV(ariane_pkg_LAT_CONV)
			) fpnew_top_i(
				.Clk_CI(clk_i),
				.Reset_RBI(rst_ni),
				.A_DI(operand_a),
				.B_DI(operand_b),
				.C_DI(operand_c),
				.RoundMode_SI(fpu_rm),
				.Op_SI(fpu_op),
				.OpMod_SI(fpu_op_mod),
				.VectorialOp_SI(fpu_vec_op),
				.FpFmt_SI(fpu_fmt),
				.FpFmt2_SI(fpu_fmt2),
				.IntFmt_SI(fpu_ifmt),
				.Tag_DI(fpu_tag),
				.PrecCtl_SI(fpu_prec_i),
				.InValid_SI(fpu_in_valid),
				.InReady_SO(fpu_in_ready),
				.Flush_SI(flush_i),
				.Z_DO(result_o),
				.Status_DO(fpu_status),
				.Tag_DO(fpu_trans_id_o),
				.OutValid_SO(fpu_out_valid),
				.OutReady_SI(fpu_out_ready)
			);
			assign fpu_exception_o[128-:64] = {59'h000000000000000, fpu_status};
			assign fpu_exception_o[0] = 1'b0;
			assign fpu_out_ready = 1'b1;
			assign fpu_valid_o = fpu_out_valid;
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
module branch_unit (
	fu_data_i,
	pc_i,
	is_compressed_instr_i,
	fu_valid_i,
	branch_valid_i,
	branch_comp_res_i,
	branch_result_o,
	branch_predict_i,
	resolved_branch_o,
	resolve_branch_o,
	branch_exception_o
);
	reg _sv2v_0;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [205:0] fu_data_i;
	input wire [63:0] pc_i;
	input wire is_compressed_instr_i;
	input wire fu_valid_i;
	input wire branch_valid_i;
	input wire branch_comp_res_i;
	output reg [63:0] branch_result_o;
	input wire [67:0] branch_predict_i;
	output reg [133:0] resolved_branch_o;
	output reg resolve_branch_o;
	output reg [128:0] branch_exception_o;
	reg [63:0] target_address;
	reg [63:0] next_pc;
	always @(*) begin : mispredict_handler
		reg [63:0] jump_base;
		if (_sv2v_0)
			;
		jump_base = (fu_data_i[201-:7] == 7'd19 ? fu_data_i[194-:64] : pc_i);
		resolve_branch_o = 1'b0;
		resolved_branch_o[69-:64] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
		resolved_branch_o[4] = 1'b0;
		resolved_branch_o[3] = branch_valid_i;
		resolved_branch_o[5] = 1'b0;
		resolved_branch_o[2] = 1'b0;
		resolved_branch_o[1-:2] = branch_predict_i[1-:2];
		next_pc = pc_i + (is_compressed_instr_i ? 64'h0000000000000002 : 64'h0000000000000004);
		target_address = $unsigned($signed(jump_base) + $signed(fu_data_i[66-:64]));
		if (fu_data_i[201-:7] == 7'd19)
			target_address[0] = 1'b0;
		branch_result_o = next_pc;
		resolved_branch_o[133-:64] = (is_compressed_instr_i || (pc_i[1] == 1'b0) ? pc_i : {pc_i[63:2], 2'b00} + 64'h0000000000000004);
		if (branch_valid_i) begin
			resolved_branch_o[69-:64] = (branch_comp_res_i ? target_address : next_pc);
			resolved_branch_o[4] = branch_comp_res_i;
			if (target_address[0] == 1'b0) begin
				if (branch_predict_i[67]) begin
					if (branch_predict_i[2] != branch_comp_res_i)
						resolved_branch_o[5] = 1'b1;
					if (branch_predict_i[2] && (target_address != branch_predict_i[66-:64]))
						resolved_branch_o[5] = 1'b1;
				end
				else if (branch_comp_res_i)
					resolved_branch_o[5] = 1'b1;
			end
			resolve_branch_o = 1'b1;
		end
		else if ((fu_valid_i && branch_predict_i[67]) && branch_predict_i[2]) begin
			resolved_branch_o[5] = 1'b1;
			resolved_branch_o[69-:64] = next_pc;
			resolved_branch_o[2] = 1'b1;
			resolved_branch_o[3] = 1'b1;
			resolve_branch_o = 1'b1;
		end
	end
	localparam [63:0] riscv_INSTR_ADDR_MISALIGNED = 0;
	always @(*) begin : exception_handling
		if (_sv2v_0)
			;
		branch_exception_o[128-:64] = riscv_INSTR_ADDR_MISALIGNED;
		branch_exception_o[0] = 1'b0;
		branch_exception_o[64-:64] = pc_i;
		if (branch_valid_i && (target_address[0] != 1'b0))
			branch_exception_o[0] = 1'b1;
	end
	initial _sv2v_0 = 0;
endmodule
module compressed_decoder (
	instr_i,
	instr_o,
	illegal_instr_o,
	is_compressed_o
);
	reg _sv2v_0;
	input wire [31:0] instr_i;
	output reg [31:0] instr_o;
	output reg illegal_instr_o;
	output reg is_compressed_o;
	localparam riscv_OpcodeBranch = 7'b1100011;
	localparam riscv_OpcodeC0 = 2'b00;
	localparam riscv_OpcodeC0Addi4spn = 3'b000;
	localparam riscv_OpcodeC0Fld = 3'b001;
	localparam riscv_OpcodeC0Fsd = 3'b101;
	localparam riscv_OpcodeC0Ld = 3'b011;
	localparam riscv_OpcodeC0Lw = 3'b010;
	localparam riscv_OpcodeC0Sd = 3'b111;
	localparam riscv_OpcodeC0Sw = 3'b110;
	localparam riscv_OpcodeC1 = 2'b01;
	localparam riscv_OpcodeC1Addi = 3'b000;
	localparam riscv_OpcodeC1Addiw = 3'b001;
	localparam riscv_OpcodeC1Beqz = 3'b110;
	localparam riscv_OpcodeC1Bnez = 3'b111;
	localparam riscv_OpcodeC1J = 3'b101;
	localparam riscv_OpcodeC1Li = 3'b010;
	localparam riscv_OpcodeC1LuiAddi16sp = 3'b011;
	localparam riscv_OpcodeC1MiscAlu = 3'b100;
	localparam riscv_OpcodeC2 = 2'b10;
	localparam riscv_OpcodeC2Fldsp = 3'b001;
	localparam riscv_OpcodeC2Fsdsp = 3'b101;
	localparam riscv_OpcodeC2JalrMvAdd = 3'b100;
	localparam riscv_OpcodeC2Ldsp = 3'b011;
	localparam riscv_OpcodeC2Lwsp = 3'b010;
	localparam riscv_OpcodeC2Sdsp = 3'b111;
	localparam riscv_OpcodeC2Slli = 3'b000;
	localparam riscv_OpcodeC2Swsp = 3'b110;
	localparam riscv_OpcodeJal = 7'b1101111;
	localparam riscv_OpcodeJalr = 7'b1100111;
	localparam riscv_OpcodeLoad = 7'b0000011;
	localparam riscv_OpcodeLoadFp = 7'b0000111;
	localparam riscv_OpcodeLui = 7'b0110111;
	localparam riscv_OpcodeOp = 7'b0110011;
	localparam riscv_OpcodeOp32 = 7'b0111011;
	localparam riscv_OpcodeOpImm = 7'b0010011;
	localparam riscv_OpcodeOpImm32 = 7'b0011011;
	localparam riscv_OpcodeStore = 7'b0100011;
	localparam riscv_OpcodeStoreFp = 7'b0100111;
	always @(*) begin
		if (_sv2v_0)
			;
		illegal_instr_o = 1'b0;
		instr_o = 1'sb0;
		is_compressed_o = 1'b1;
		instr_o = instr_i;
		(* full_case, parallel_case *)
		case (instr_i[1:0])
			riscv_OpcodeC0:
				(* full_case, parallel_case *)
				case (instr_i[15:13])
					riscv_OpcodeC0Addi4spn: begin
						instr_o = {2'b00, instr_i[10:7], instr_i[12:11], instr_i[5], instr_i[6], 12'h041, instr_i[4:2], riscv_OpcodeOpImm};
						if (instr_i[12:5] == 8'b00000000)
							illegal_instr_o = 1'b1;
					end
					riscv_OpcodeC0Fld: instr_o = {4'b0000, instr_i[6:5], instr_i[12:10], 5'b00001, instr_i[9:7], 5'b01101, instr_i[4:2], riscv_OpcodeLoadFp};
					riscv_OpcodeC0Lw: instr_o = {5'b00000, instr_i[5], instr_i[12:10], instr_i[6], 4'b0001, instr_i[9:7], 5'b01001, instr_i[4:2], riscv_OpcodeLoad};
					riscv_OpcodeC0Ld: instr_o = {4'b0000, instr_i[6:5], instr_i[12:10], 5'b00001, instr_i[9:7], 5'b01101, instr_i[4:2], riscv_OpcodeLoad};
					riscv_OpcodeC0Fsd: instr_o = {4'b0000, instr_i[6:5], instr_i[12], 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b011, instr_i[11:10], 3'b000, riscv_OpcodeStoreFp};
					riscv_OpcodeC0Sw: instr_o = {5'b00000, instr_i[5], instr_i[12], 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b010, instr_i[11:10], instr_i[6], 2'b00, riscv_OpcodeStore};
					riscv_OpcodeC0Sd: instr_o = {4'b0000, instr_i[6:5], instr_i[12], 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b011, instr_i[11:10], 3'b000, riscv_OpcodeStore};
					default: illegal_instr_o = 1'b1;
				endcase
			riscv_OpcodeC1:
				(* full_case, parallel_case *)
				case (instr_i[15:13])
					riscv_OpcodeC1Addi: instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], instr_i[11:7], 3'b000, instr_i[11:7], riscv_OpcodeOpImm};
					riscv_OpcodeC1Addiw:
						if (instr_i[11:7] != 5'h00)
							instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], instr_i[11:7], 3'b000, instr_i[11:7], riscv_OpcodeOpImm32};
						else
							illegal_instr_o = 1'b1;
					riscv_OpcodeC1Li: begin
						instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], 8'b00000000, instr_i[11:7], riscv_OpcodeOpImm};
						if (instr_i[11:7] == 5'b00000)
							illegal_instr_o = 1'b1;
					end
					riscv_OpcodeC1LuiAddi16sp: begin
						instr_o = {{15 {instr_i[12]}}, instr_i[6:2], instr_i[11:7], riscv_OpcodeLui};
						if (instr_i[11:7] == 5'h02)
							instr_o = {{3 {instr_i[12]}}, instr_i[4:3], instr_i[5], instr_i[2], instr_i[6], 17'h00202, riscv_OpcodeOpImm};
						else if (instr_i[11:7] == 5'b00000)
							illegal_instr_o = 1'b1;
						if ({instr_i[12], instr_i[6:2]} == 6'b000000)
							illegal_instr_o = 1'b1;
					end
					riscv_OpcodeC1MiscAlu:
						(* full_case, parallel_case *)
						case (instr_i[11:10])
							2'b00, 2'b01: begin
								instr_o = {1'b0, instr_i[10], 4'b0000, instr_i[12], instr_i[6:2], 2'b01, instr_i[9:7], 5'b10101, instr_i[9:7], riscv_OpcodeOpImm};
								if ({instr_i[12], instr_i[6:2]} == 6'b000000)
									illegal_instr_o = 1'b1;
							end
							2'b10: instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], 2'b01, instr_i[9:7], 5'b11101, instr_i[9:7], riscv_OpcodeOpImm};
							2'b11:
								(* full_case, parallel_case *)
								case ({instr_i[12], instr_i[6:5]})
									3'b000: instr_o = {9'b010000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b00001, instr_i[9:7], riscv_OpcodeOp};
									3'b001: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b10001, instr_i[9:7], riscv_OpcodeOp};
									3'b010: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b11001, instr_i[9:7], riscv_OpcodeOp};
									3'b011: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b11101, instr_i[9:7], riscv_OpcodeOp};
									3'b100: instr_o = {9'b010000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b00001, instr_i[9:7], riscv_OpcodeOp32};
									3'b101: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b00001, instr_i[9:7], riscv_OpcodeOp32};
									3'b110, 3'b111: begin
										illegal_instr_o = 1'b1;
										instr_o = {16'b0000000000000000, instr_i};
									end
								endcase
						endcase
					riscv_OpcodeC1J: instr_o = {instr_i[12], instr_i[8], instr_i[10:9], instr_i[6], instr_i[7], instr_i[2], instr_i[11], instr_i[5:3], {9 {instr_i[12]}}, 4'b0000, ~instr_i[15], riscv_OpcodeJal};
					riscv_OpcodeC1Beqz, riscv_OpcodeC1Bnez: instr_o = {{4 {instr_i[12]}}, instr_i[6:5], instr_i[2], 7'b0000001, instr_i[9:7], 2'b00, instr_i[13], instr_i[11:10], instr_i[4:3], instr_i[12], riscv_OpcodeBranch};
				endcase
			riscv_OpcodeC2:
				(* full_case, parallel_case *)
				case (instr_i[15:13])
					riscv_OpcodeC2Slli: begin
						instr_o = {6'b000000, instr_i[12], instr_i[6:2], instr_i[11:7], 3'b001, instr_i[11:7], riscv_OpcodeOpImm};
						if (instr_i[11:7] == 5'b00000)
							illegal_instr_o = 1'b1;
						if ({instr_i[12], instr_i[6:2]} == 6'b000000)
							illegal_instr_o = 1'b1;
					end
					riscv_OpcodeC2Fldsp: begin
						instr_o = {3'b000, instr_i[4:2], instr_i[12], instr_i[6:5], 11'h013, instr_i[11:7], riscv_OpcodeLoadFp};
						if (instr_i[11:7] == 5'b00000)
							illegal_instr_o = 1'b1;
					end
					riscv_OpcodeC2Lwsp: begin
						instr_o = {4'b0000, instr_i[3:2], instr_i[12], instr_i[6:4], 10'h012, instr_i[11:7], riscv_OpcodeLoad};
						if (instr_i[11:7] == 5'b00000)
							illegal_instr_o = 1'b1;
					end
					riscv_OpcodeC2Ldsp: begin
						instr_o = {3'b000, instr_i[4:2], instr_i[12], instr_i[6:5], 11'h013, instr_i[11:7], riscv_OpcodeLoad};
						if (instr_i[11:7] == 5'b00000)
							illegal_instr_o = 1'b1;
					end
					riscv_OpcodeC2JalrMvAdd:
						if (instr_i[12] == 1'b0) begin
							instr_o = {7'b0000000, instr_i[6:2], 8'b00000000, instr_i[11:7], riscv_OpcodeOp};
							if (instr_i[6:2] == 5'b00000) begin
								instr_o = {12'b000000000000, instr_i[11:7], 8'b00000000, riscv_OpcodeJalr};
								illegal_instr_o = (instr_i[11:7] != {5 {1'sb0}} ? 1'b0 : 1'b1);
							end
						end
						else begin
							instr_o = {7'b0000000, instr_i[6:2], instr_i[11:7], 3'b000, instr_i[11:7], riscv_OpcodeOp};
							if (instr_i[11:7] == 5'b00000) begin
								instr_o = 32'h00100073;
								if (instr_i[6:2] != 5'b00000)
									illegal_instr_o = 1'b1;
							end
							else if (instr_i[6:2] == 5'b00000)
								instr_o = {12'b000000000000, instr_i[11:7], 8'b00000001, riscv_OpcodeJalr};
						end
					riscv_OpcodeC2Fsdsp: instr_o = {3'b000, instr_i[9:7], instr_i[12], instr_i[6:2], 8'h13, instr_i[11:10], 3'b000, riscv_OpcodeStoreFp};
					riscv_OpcodeC2Swsp: instr_o = {4'b0000, instr_i[8:7], instr_i[12], instr_i[6:2], 8'h12, instr_i[11:9], 2'b00, riscv_OpcodeStore};
					riscv_OpcodeC2Sdsp: instr_o = {3'b000, instr_i[9:7], instr_i[12], instr_i[6:2], 8'h13, instr_i[11:10], 3'b000, riscv_OpcodeStore};
					default: illegal_instr_o = 1'b1;
				endcase
			default: is_compressed_o = 1'b0;
		endcase
		if (illegal_instr_o && is_compressed_o)
			instr_o = instr_i;
	end
	initial _sv2v_0 = 0;
endmodule
module controller (
	clk_i,
	rst_ni,
	set_pc_commit_o,
	flush_if_o,
	flush_unissued_instr_o,
	flush_id_o,
	flush_ex_o,
	flush_icache_o,
	flush_dcache_o,
	flush_dcache_ack_i,
	flush_tlb_o,
	halt_csr_i,
	halt_o,
	eret_i,
	ex_valid_i,
	set_debug_pc_i,
	resolved_branch_i,
	flush_csr_i,
	fence_i_i,
	fence_i,
	sfence_vma_i,
	flush_commit_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	output reg set_pc_commit_o;
	output reg flush_if_o;
	output reg flush_unissued_instr_o;
	output reg flush_id_o;
	output reg flush_ex_o;
	output reg flush_icache_o;
	output reg flush_dcache_o;
	input wire flush_dcache_ack_i;
	output reg flush_tlb_o;
	input wire halt_csr_i;
	output reg halt_o;
	input wire eret_i;
	input wire ex_valid_i;
	input wire set_debug_pc_i;
	input wire [133:0] resolved_branch_i;
	input wire flush_csr_i;
	input wire fence_i_i;
	input wire fence_i;
	input wire sfence_vma_i;
	input wire flush_commit_i;
	reg fence_active_d;
	reg fence_active_q;
	reg flush_dcache;
	always @(*) begin : flush_ctrl
		if (_sv2v_0)
			;
		fence_active_d = fence_active_q;
		set_pc_commit_o = 1'b0;
		flush_if_o = 1'b0;
		flush_unissued_instr_o = 1'b0;
		flush_id_o = 1'b0;
		flush_ex_o = 1'b0;
		flush_dcache = 1'b0;
		flush_icache_o = 1'b0;
		flush_tlb_o = 1'b0;
		if (resolved_branch_i[5]) begin
			flush_unissued_instr_o = 1'b1;
			flush_if_o = 1'b1;
		end
		if (fence_i) begin
			set_pc_commit_o = 1'b1;
			flush_if_o = 1'b1;
			flush_unissued_instr_o = 1'b1;
			flush_id_o = 1'b1;
			flush_ex_o = 1'b1;
			flush_dcache = 1'b1;
			fence_active_d = 1'b1;
		end
		if (fence_i_i) begin
			set_pc_commit_o = 1'b1;
			flush_if_o = 1'b1;
			flush_unissued_instr_o = 1'b1;
			flush_id_o = 1'b1;
			flush_ex_o = 1'b1;
			flush_icache_o = 1'b1;
			flush_dcache = 1'b1;
			fence_active_d = 1'b1;
		end
		if (flush_dcache_ack_i && fence_active_q)
			fence_active_d = 1'b0;
		else if (fence_active_q)
			flush_dcache = 1'b1;
		if (sfence_vma_i) begin
			set_pc_commit_o = 1'b1;
			flush_if_o = 1'b1;
			flush_unissued_instr_o = 1'b1;
			flush_id_o = 1'b1;
			flush_ex_o = 1'b1;
			flush_tlb_o = 1'b1;
		end
		if (flush_csr_i || flush_commit_i) begin
			set_pc_commit_o = 1'b1;
			flush_if_o = 1'b1;
			flush_unissued_instr_o = 1'b1;
			flush_id_o = 1'b1;
			flush_ex_o = 1'b1;
		end
		if ((ex_valid_i || eret_i) || set_debug_pc_i) begin
			set_pc_commit_o = 1'b0;
			flush_if_o = 1'b1;
			flush_unissued_instr_o = 1'b1;
			flush_id_o = 1'b1;
			flush_ex_o = 1'b1;
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		halt_o = halt_csr_i || fence_active_q;
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			fence_active_q <= 1'b0;
			flush_dcache_o <= 1'b0;
		end
		else begin
			fence_active_q <= fence_active_d;
			flush_dcache_o <= flush_dcache;
		end
	initial _sv2v_0 = 0;
`ifdef FORMAL
`ifdef FORMAL_P32
	always @(posedge clk_i) if (rst_ni) HACK_DAC19_p32: assert (!(halt_o) || ex_valid_i);
`endif
`endif
endmodule
module csr_buffer (
	clk_i,
	rst_ni,
	flush_i,
	fu_data_i,
	csr_ready_o,
	csr_valid_i,
	csr_result_o,
	csr_commit_i,
	csr_addr_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [205:0] fu_data_i;
	output reg csr_ready_o;
	input wire csr_valid_i;
	output wire [63:0] csr_result_o;
	input wire csr_commit_i;
	output wire [11:0] csr_addr_o;
	reg [12:0] csr_reg_n;
	reg [12:0] csr_reg_q;
	assign csr_result_o = fu_data_i[194-:64];
	assign csr_addr_o = csr_reg_q[12-:12];
	always @(*) begin : write
		if (_sv2v_0)
			;
		csr_reg_n = csr_reg_q;
		csr_ready_o = 1'b1;
		if ((csr_reg_q[0] || csr_valid_i) && ~csr_commit_i)
			csr_ready_o = 1'b0;
		if (csr_valid_i) begin
			csr_reg_n[12-:12] = fu_data_i[78:67];
			csr_reg_n[0] = 1'b1;
		end
		if (csr_commit_i && ~csr_valid_i)
			csr_reg_n[0] = 1'b0;
		if (flush_i)
			csr_reg_n[0] = 1'b0;
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni)
			csr_reg_q <= 13'h0000;
		else
			csr_reg_q <= csr_reg_n;
	initial _sv2v_0 = 0;
endmodule
module csr_regfile (
	clk_i,
	rst_ni,
	time_irq_i,
	flush_o,
	halt_csr_o,
	commit_instr_i,
	commit_ack_i,
	boot_addr_i,
	hart_id_i,
	ex_i,
	csr_op_i,
	csr_addr_i,
	csr_wdata_i,
	csr_rdata_o,
	dirty_fp_state_i,
	csr_write_fflags_i,
	pc_i,
	csr_exception_o,
	epc_o,
	eret_o,
	trap_vector_base_o,
	priv_lvl_o,
	fs_o,
	fflags_o,
	frm_o,
	fprec_o,
	en_translation_o,
	en_ld_st_translation_o,
	ld_st_priv_lvl_o,
	sum_o,
	mxr_o,
	satp_ppn_o,
	asid_o,
	irq_i,
	ipi_i,
	debug_req_i,
	set_debug_pc_o,
	tvm_o,
	tw_o,
	tsr_o,
	debug_mode_o,
	single_step_o,
	icache_en_o,
	dcache_en_o,
	perf_addr_o,
	perf_data_o,
	perf_data_i,
	perf_we_o,
	umode_i
);
	reg _sv2v_0;
	parameter signed [31:0] ASID_WIDTH = 1;
	parameter [31:0] NR_COMMIT_PORTS = 2;
	input wire clk_i;
	input wire rst_ni;
	input wire time_irq_i;
	output reg flush_o;
	output wire halt_csr_o;
	localparam ariane_pkg_REG_ADDR_SIZE = 6;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [(NR_COMMIT_PORTS * 362) - 1:0] commit_instr_i;
	input wire [NR_COMMIT_PORTS - 1:0] commit_ack_i;
	input wire [63:0] boot_addr_i;
	input wire [63:0] hart_id_i;
	input wire [128:0] ex_i;
	input wire [6:0] csr_op_i;
	input wire [11:0] csr_addr_i;
	input wire [63:0] csr_wdata_i;
	output reg [63:0] csr_rdata_o;
	input wire dirty_fp_state_i;
	input wire csr_write_fflags_i;
	input wire [63:0] pc_i;
	output reg [128:0] csr_exception_o;
	output reg [63:0] epc_o;
	output reg eret_o;
	output reg [63:0] trap_vector_base_o;
	output wire [1:0] priv_lvl_o;
	output wire [1:0] fs_o;
	output wire [4:0] fflags_o;
	output wire [2:0] frm_o;
	output wire [6:0] fprec_o;
	output wire en_translation_o;
	output reg en_ld_st_translation_o;
	output reg [1:0] ld_st_priv_lvl_o;
	output wire sum_o;
	output wire mxr_o;
	output wire [43:0] satp_ppn_o;
	output wire [ASID_WIDTH - 1:0] asid_o;
	input wire [1:0] irq_i;
	input wire ipi_i;
	input wire debug_req_i;
	output reg set_debug_pc_o;
	output wire tvm_o;
	output wire tw_o;
	output wire tsr_o;
	output wire debug_mode_o;
	output wire single_step_o;
	output wire icache_en_o;
	output wire dcache_en_o;
	output reg [11:0] perf_addr_o;
	output reg [63:0] perf_data_o;
	input wire [63:0] perf_data_i;
	output reg perf_we_o;
	input wire umode_i;
	reg read_access_exception;
	reg update_access_exception;
	reg csr_we;
	reg csr_read;
	reg [63:0] csr_wdata;
	reg [63:0] csr_rdata;
	reg [1:0] trap_to_priv_lvl;
	reg en_ld_st_translation_d;
	reg en_ld_st_translation_q;
	wire mprv;
	reg mret;
	reg sret;
	reg dret;
	reg dirty_fp_state_csr;
	localparam [11:0] riscv_PERF_BRANCH_JUMP = 12'h008;
	localparam [11:0] riscv_PERF_CALL = 12'h009;
	localparam [11:0] riscv_PERF_DTLB_MISS = 12'h003;
	localparam [11:0] riscv_PERF_EXCEPTION = 12'h006;
	localparam [11:0] riscv_PERF_EXCEPTION_RET = 12'h007;
	localparam [11:0] riscv_PERF_ITLB_MISS = 12'h002;
	localparam [11:0] riscv_PERF_L1_DCACHE_MISS = 12'h001;
	localparam [11:0] riscv_PERF_L1_ICACHE_MISS = 12'h000;
	localparam [11:0] riscv_PERF_LOAD = 12'h004;
	localparam [11:0] riscv_PERF_MIS_PREDICT = 12'h00b;
	localparam [11:0] riscv_PERF_RET = 12'h00a;
	localparam [11:0] riscv_PERF_STORE = 12'h005;
	wire [11:0] csr_addr;
	assign csr_addr = csr_addr_i;
	reg [63:0] mstatus_q;
	assign fs_o = mstatus_q[14-:2];
	reg [1:0] priv_lvl_d;
	reg [1:0] priv_lvl_q;
	reg debug_mode_q;
	reg debug_mode_d;
	reg [63:0] mstatus_d;
	reg [63:0] satp_q;
	reg [63:0] satp_d;
	reg [31:0] dcsr_q;
	reg [31:0] dcsr_d;
	reg mtvec_rst_load_q;
	reg [63:0] dpc_q;
	reg [63:0] dpc_d;
	reg [63:0] dscratch0_q;
	reg [63:0] dscratch0_d;
	reg [63:0] dscratch1_q;
	reg [63:0] dscratch1_d;
	reg [63:0] mtvec_q;
	reg [63:0] mtvec_d;
	reg [63:0] medeleg_q;
	reg [63:0] medeleg_d;
	reg [63:0] mideleg_q;
	reg [63:0] mideleg_d;
	reg [63:0] mip_q;
	reg [63:0] mip_d;
	reg [63:0] mie_q;
	reg [63:0] mie_d;
	reg [63:0] mscratch_q;
	reg [63:0] mscratch_d;
	reg [63:0] mepc_q;
	reg [63:0] mepc_d;
	reg [63:0] mcause_q;
	reg [63:0] mcause_d;
	reg [63:0] mtval_q;
	reg [63:0] mtval_d;
	reg [63:0] stvec_q;
	reg [63:0] stvec_d;
	reg [63:0] sscratch_q;
	reg [63:0] sscratch_d;
	reg [63:0] sepc_q;
	reg [63:0] sepc_d;
	reg [63:0] scause_q;
	reg [63:0] scause_d;
	reg [63:0] stval_q;
	reg [63:0] stval_d;
	reg [63:0] dcache_q;
	reg [63:0] dcache_d;
	reg [63:0] icache_q;
	reg [63:0] icache_d;
	reg wfi_d;
	reg wfi_q;
	reg [63:0] cycle_q;
	reg [63:0] cycle_d;
	reg [63:0] instret_q;
	reg [63:0] instret_d;
	reg [31:0] fcsr_q;
	reg [31:0] fcsr_d;
	localparam [63:0] ariane_pkg_ARIANE_MARCHID = 64'd3;
	localparam [0:0] ariane_pkg_XF16 = 1'b0;
	localparam [0:0] ariane_pkg_XF16ALT = 1'b0;
	localparam [0:0] ariane_pkg_XF8 = 1'b0;
	localparam [0:0] ariane_pkg_XFVEC = 1'b0;
	localparam [0:0] ariane_pkg_NSX = ((ariane_pkg_XF16 | ariane_pkg_XF16ALT) | ariane_pkg_XF8) | ariane_pkg_XFVEC;
	localparam [0:0] ariane_pkg_RVA = 1'b1;
	localparam [0:0] ariane_pkg_RVD = 1'b0;
	localparam [0:0] ariane_pkg_RVF = 1'b0;
	localparam [63:0] ariane_pkg_ISA_CODE = ((((((((((ariane_pkg_RVA << 0) | 4) | (ariane_pkg_RVD << 3)) | (ariane_pkg_RVF << 5)) | 256) | 4096) | 0) | 262144) | 1048576) | (ariane_pkg_NSX << 23)) | 65'sd9223372036854775808;
	localparam [63:0] riscv_SSTATUS64_SD = 64'h8000000000000000;
	localparam [63:0] riscv_SSTATUS_FS = 64'h0000000000006000;
	localparam [63:0] riscv_SSTATUS_MXR = 64'h0000000000080000;
	localparam [63:0] riscv_SSTATUS_SIE = 64'h0000000000000002;
	localparam [63:0] riscv_SSTATUS_SPIE = 64'h0000000000000020;
	localparam [63:0] riscv_SSTATUS_SPP = 64'h0000000000000100;
	localparam [63:0] riscv_SSTATUS_SUM = 64'h0000000000040000;
	localparam [63:0] riscv_SSTATUS_UIE = 64'h0000000000000001;
	localparam [63:0] riscv_SSTATUS_UPIE = 64'h0000000000000010;
	localparam [63:0] riscv_SSTATUS_UXL = 64'h0000000300000000;
	localparam [63:0] riscv_SSTATUS_XS = 64'h0000000000018000;
	localparam [63:0] ariane_pkg_SMODE_STATUS_READ_MASK = ((((((((((riscv_SSTATUS_UIE | riscv_SSTATUS_SIE) | riscv_SSTATUS_SPIE) | riscv_SSTATUS_SPP) | riscv_SSTATUS_FS) | riscv_SSTATUS_XS) | riscv_SSTATUS_SUM) | riscv_SSTATUS_MXR) | riscv_SSTATUS_UPIE) | riscv_SSTATUS_SPIE) | riscv_SSTATUS_UXL) | riscv_SSTATUS64_SD;
	always @(*) begin : csr_read_process
		if (_sv2v_0)
			;
		read_access_exception = 1'b0;
		csr_rdata = 64'b0000000000000000000000000000000000000000000000000000000000000000;
		perf_addr_o = csr_addr[11-:12];
		if (csr_read)
			(* full_case, parallel_case *)
			case (csr_addr[11-:12])
				12'h001:
					if (mstatus_q[14-:2] == 2'b00)
						read_access_exception = 1'b1;
					else
						csr_rdata = {59'b00000000000000000000000000000000000000000000000000000000000, fcsr_q[4-:5]};
				12'h002:
					if (mstatus_q[14-:2] == 2'b00)
						read_access_exception = 1'b1;
					else
						csr_rdata = {61'b0000000000000000000000000000000000000000000000000000000000000, fcsr_q[7-:3]};
				12'h003:
					if (mstatus_q[14-:2] == 2'b00)
						read_access_exception = 1'b1;
					else
						csr_rdata = {56'b00000000000000000000000000000000000000000000000000000000, fcsr_q[7-:3], fcsr_q[4-:5]};
				12'h800:
					if (mstatus_q[14-:2] == 2'b00)
						read_access_exception = 1'b1;
					else
						csr_rdata = {57'b000000000000000000000000000000000000000000000000000000000, fcsr_q[14-:7]};
				12'h7b0: csr_rdata = {32'b00000000000000000000000000000000, dcsr_q};
				12'h7b1: csr_rdata = dpc_q;
				12'h7b2: csr_rdata = dscratch0_q;
				12'h7b3: csr_rdata = dscratch1_q;
				12'h7a0:
					;
				12'h7a1:
					;
				12'h7a2:
					;
				12'h7a3:
					;
				12'h100: csr_rdata = mstatus_q & ariane_pkg_SMODE_STATUS_READ_MASK;
				12'h104: csr_rdata = mie_q & mideleg_q;
				12'h144: csr_rdata = mip_q & mideleg_q;
				12'h105: csr_rdata = stvec_q;
				12'h106: csr_rdata = 64'b0000000000000000000000000000000000000000000000000000000000000000;
				12'h140: csr_rdata = sscratch_q;
				12'h141: csr_rdata = sepc_q;
				12'h142: csr_rdata = scause_q;
				12'h143: csr_rdata = stval_q;
				12'h180: csr_rdata = satp_q;
				12'h300: csr_rdata = mstatus_q;
				12'h301: csr_rdata = ariane_pkg_ISA_CODE;
				12'h302: csr_rdata = medeleg_q;
				12'h303: csr_rdata = mideleg_q;
				12'h304: csr_rdata = mie_q;
				12'h305: csr_rdata = mtvec_q;
				12'h306: csr_rdata = 64'b0000000000000000000000000000000000000000000000000000000000000000;
				12'h340: csr_rdata = mscratch_q;
				12'h341: csr_rdata = mepc_q;
				12'h342: csr_rdata = mcause_q;
				12'h343: csr_rdata = mtval_q;
				12'h344: csr_rdata = mip_q;
				12'hf11: csr_rdata = 64'b0000000000000000000000000000000000000000000000000000000000000000;
				12'hf12: csr_rdata = ariane_pkg_ARIANE_MARCHID;
				12'hf13: csr_rdata = 64'b0000000000000000000000000000000000000000000000000000000000000000;
				12'hf14: csr_rdata = hart_id_i;
				12'hb00: csr_rdata = cycle_q;
				12'hb02: csr_rdata = instret_q;
				12'h701: csr_rdata = dcache_q;
				12'h700: csr_rdata = icache_q;
				12'hc00: csr_rdata = cycle_q;
				12'hc02: csr_rdata = instret_q;
				riscv_PERF_L1_ICACHE_MISS + 12'hc03, riscv_PERF_L1_DCACHE_MISS + 12'hc03, riscv_PERF_ITLB_MISS + 12'hc03, riscv_PERF_DTLB_MISS + 12'hc03, riscv_PERF_LOAD + 12'hc03, riscv_PERF_STORE + 12'hc03, riscv_PERF_EXCEPTION + 12'hc03, riscv_PERF_EXCEPTION_RET + 12'hc03, riscv_PERF_BRANCH_JUMP + 12'hc03, riscv_PERF_CALL + 12'hc03, riscv_PERF_RET + 12'hc03, riscv_PERF_MIS_PREDICT + 12'hc03: csr_rdata = perf_data_i;
				default: read_access_exception = 1'b1;
			endcase
	end
	reg [63:0] mask;
	localparam [0:0] ariane_pkg_ENABLE_CYCLE_COUNT = 1'b1;
	localparam [0:0] ariane_pkg_FP_PRESENT = (((ariane_pkg_RVF | ariane_pkg_RVD) | ariane_pkg_XF16) | ariane_pkg_XF16ALT) | ariane_pkg_XF8;
	localparam [3:0] ariane_pkg_MODE_OFF = 4'h0;
	localparam [3:0] ariane_pkg_MODE_SV39 = 4'h8;
	localparam [63:0] ariane_pkg_SMODE_STATUS_WRITE_MASK = ((((riscv_SSTATUS_SIE | riscv_SSTATUS_SPIE) | riscv_SSTATUS_SPP) | riscv_SSTATUS_FS) | riscv_SSTATUS_SUM) | riscv_SSTATUS_MXR;
	localparam [0:0] ariane_pkg_ZERO_TVAL = 1'b0;
	localparam [2:0] dm_CauseBreakpoint = 3'h1;
	localparam [2:0] dm_CauseRequest = 3'h3;
	localparam [2:0] dm_CauseSingleStep = 3'h4;
	localparam [63:0] riscv_BREAKPOINT = 3;
	localparam [63:0] riscv_ENV_CALL_MMODE = 11;
	localparam [63:0] riscv_ENV_CALL_SMODE = 9;
	localparam [63:0] riscv_ENV_CALL_UMODE = 8;
	localparam [63:0] riscv_ILLEGAL_INSTR = 2;
	localparam [63:0] riscv_INSTR_ADDR_MISALIGNED = 0;
	localparam [63:0] riscv_INSTR_PAGE_FAULT = 12;
	localparam [31:0] riscv_IRQ_M_EXT = 11;
	localparam [31:0] riscv_IRQ_M_SOFT = 3;
	localparam [31:0] riscv_IRQ_M_TIMER = 7;
	localparam [63:0] riscv_LOAD_PAGE_FAULT = 13;
	localparam [63:0] riscv_MIP_MSIP = 8;
	localparam [63:0] riscv_MIP_MTIP = 128;
	localparam [31:0] riscv_IRQ_S_EXT = 9;
	localparam [63:0] riscv_MIP_SEIP = 512;
	localparam [31:0] riscv_IRQ_S_SOFT = 1;
	localparam [63:0] riscv_MIP_SSIP = 2;
	localparam [31:0] riscv_IRQ_S_TIMER = 5;
	localparam [63:0] riscv_MIP_STIP = 32;
	localparam [63:0] riscv_STORE_PAGE_FAULT = 15;
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	always @(*) begin : csr_update
		reg [63:0] sapt;
		reg [63:0] instret;
		if (_sv2v_0)
			;
		sapt = satp_q;
		instret = instret_q;
		cycle_d = cycle_q;
		instret_d = instret_q;
		if (!debug_mode_q) begin
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < NR_COMMIT_PORTS; i = i + 1)
					if (commit_ack_i[i] && !ex_i[0])
						instret = instret + 1;
			end
			instret_d = instret;
			if (ariane_pkg_ENABLE_CYCLE_COUNT)
				cycle_d = cycle_q + 1'b1;
			else
				cycle_d = instret;
		end
		eret_o = 1'b0;
		flush_o = 1'b0;
		update_access_exception = 1'b0;
		set_debug_pc_o = 1'b0;
		perf_we_o = 1'b0;
		perf_data_o = 'b0;
		fcsr_d = fcsr_q;
		priv_lvl_d = priv_lvl_q;
		debug_mode_d = debug_mode_q;
		dcsr_d = dcsr_q;
		dpc_d = dpc_q;
		dscratch0_d = dscratch0_q;
		dscratch1_d = dscratch1_q;
		mstatus_d = mstatus_q;
		if (mtvec_rst_load_q)
			mtvec_d = boot_addr_i + 'h40;
		else
			mtvec_d = mtvec_q;
		medeleg_d = medeleg_q;
		mideleg_d = mideleg_q;
		mip_d = mip_q;
		mie_d = mie_q;
		mepc_d = mepc_q;
		mcause_d = mcause_q;
		mscratch_d = mscratch_q;
		mtval_d = mtval_q;
		dcache_d = dcache_q;
		icache_d = icache_q;
		sepc_d = sepc_q;
		scause_d = scause_q;
		stvec_d = stvec_q;
		sscratch_d = sscratch_q;
		stval_d = stval_q;
		satp_d = satp_q;
		en_ld_st_translation_d = en_ld_st_translation_q;
		dirty_fp_state_csr = 1'b0;
		if (csr_we)
			(* full_case, parallel_case *)
			case (csr_addr[11-:12])
				12'h001:
					if (mstatus_q[14-:2] == 2'b00)
						update_access_exception = 1'b1;
					else begin
						dirty_fp_state_csr = 1'b1;
						fcsr_d[4-:5] = csr_wdata[4:0];
						flush_o = 1'b1;
					end
				12'h002:
					if (mstatus_q[14-:2] == 2'b00)
						update_access_exception = 1'b1;
					else begin
						dirty_fp_state_csr = 1'b1;
						fcsr_d[7-:3] = csr_wdata[2:0];
						flush_o = 1'b1;
					end
				12'h003:
					if (mstatus_q[14-:2] == 2'b00)
						update_access_exception = 1'b1;
					else begin
						dirty_fp_state_csr = 1'b1;
						fcsr_d[7:0] = csr_wdata[7:0];
						flush_o = 1'b1;
					end
				12'h800:
					if (mstatus_q[14-:2] == 2'b00)
						update_access_exception = 1'b1;
					else begin
						dirty_fp_state_csr = 1'b1;
						fcsr_d[14-:7] = csr_wdata[6:0];
						flush_o = 1'b1;
					end
				12'h7b0: begin
					dcsr_d = csr_wdata[31:0];
					dcsr_d[31-:4] = 4'h4;
					dcsr_d[1-:2] = priv_lvl_q;
					dcsr_d[3] = 1'b0;
					dcsr_d[10] = 1'b0;
					dcsr_d[9] = 1'b0;
				end
				12'h7b1: dpc_d = csr_wdata;
				12'h7b2: dscratch0_d = csr_wdata;
				12'h7b3: dscratch1_d = csr_wdata;
				12'h7a0:
					;
				12'h7a1:
					;
				12'h7a2:
					;
				12'h7a3:
					;
				12'h100: begin
					mask = ariane_pkg_SMODE_STATUS_WRITE_MASK;
					mstatus_d = (mstatus_q & ~mask) | (csr_wdata & mask);
					if (!ariane_pkg_FP_PRESENT)
						mstatus_d[14-:2] = 2'b00;
					mstatus_d[63] = &mstatus_q[16-:2] | &mstatus_q[14-:2];
					flush_o = 1'b1;
				end
				12'h104: mie_d = (mie_q & ~mideleg_q) | (csr_wdata & mideleg_q);
				12'h144: begin
					mask = riscv_MIP_SSIP & mideleg_q;
					mip_d = (mip_q & ~mask) | (csr_wdata & mask);
				end
				12'h106:
					;
				12'h105: stvec_d = {csr_wdata[63:2], 1'b0, csr_wdata[0]};
				12'h140: sscratch_d = csr_wdata;
				12'h141: sepc_d = {csr_wdata[63:1], 1'b0};
				12'h142: scause_d = csr_wdata;
				12'h143: stval_d = csr_wdata;
				12'h180: begin
					sapt = csr_wdata;
					sapt[59-:16] = sapt[59-:16] & {{16 - ASID_WIDTH {1'b0}}, {ASID_WIDTH {1'b1}}};
					if ((sapt[63-:4] == ariane_pkg_MODE_OFF) || (sapt[63-:4] == ariane_pkg_MODE_SV39))
						satp_d = sapt;
				end
				12'h300: begin
					mstatus_d = csr_wdata;
					mstatus_d[63] = &mstatus_q[16-:2] | &mstatus_q[14-:2];
					mstatus_d[16-:2] = 2'b00;
					if (!ariane_pkg_FP_PRESENT)
						mstatus_d[14-:2] = 2'b00;
					mstatus_d[4] = 1'b0;
					mstatus_d[0] = 1'b0;
					flush_o = 1'b1;
				end
				12'h301:
					;
				12'h302: begin
					mask = 45321;
					medeleg_d = (medeleg_q & ~mask) | (csr_wdata & mask);
				end
				12'h303: begin
					mask = (riscv_MIP_SSIP | riscv_MIP_STIP) | riscv_MIP_SEIP;
					mideleg_d = (mideleg_q & ~mask) | (csr_wdata & mask);
				end
				12'h304: begin
					mask = (((riscv_MIP_SSIP | riscv_MIP_STIP) | riscv_MIP_SEIP) | riscv_MIP_MSIP) | riscv_MIP_MTIP;
					mie_d = (mie_q & ~mask) | (csr_wdata & mask);
				end
				12'h305: begin
					mtvec_d = {csr_wdata[63:2], 1'b0, csr_wdata[0]};
					if (csr_wdata[0])
						mtvec_d = {csr_wdata[63:8], 7'b0000000, csr_wdata[0]};
				end
				12'h306:
					;
				12'h340: mscratch_d = csr_wdata;
				12'h341: mepc_d = {csr_wdata[63:1], 1'b0};
				12'h342: mcause_d = csr_wdata;
				12'h343: mtval_d = csr_wdata;
				12'h344: begin
					mask = (riscv_MIP_SSIP | riscv_MIP_STIP) | riscv_MIP_SEIP;
					mip_d = (mip_q & ~mask) | (csr_wdata & mask);
				end
				12'hb00: cycle_d = csr_wdata;
				12'hb02: instret = csr_wdata;
				12'h701: dcache_d = csr_wdata[0];
				12'h700: icache_d = csr_wdata[0];
				riscv_PERF_L1_ICACHE_MISS + 12'hc03, riscv_PERF_L1_DCACHE_MISS + 12'hc03, riscv_PERF_ITLB_MISS + 12'hc03, riscv_PERF_DTLB_MISS + 12'hc03, riscv_PERF_LOAD + 12'hc03, riscv_PERF_STORE + 12'hc03, riscv_PERF_EXCEPTION + 12'hc03, riscv_PERF_EXCEPTION_RET + 12'hc03, riscv_PERF_BRANCH_JUMP + 12'hc03, riscv_PERF_CALL + 12'hc03, riscv_PERF_RET + 12'hc03, riscv_PERF_MIS_PREDICT + 12'hc03: begin
					perf_data_o = csr_wdata;
					perf_we_o = 1'b1;
				end
				default: update_access_exception = 1'b1;
			endcase
		mstatus_d[35-:2] = 2'b10;
		mstatus_d[33-:2] = 2'b10;
		if (ariane_pkg_FP_PRESENT && (dirty_fp_state_csr || dirty_fp_state_i))
			mstatus_d[14-:2] = 2'b11;
		if (csr_write_fflags_i)
			fcsr_d[4-:5] = csr_wdata_i[4:0] | fcsr_q[4-:5];
		mip_d[riscv_IRQ_M_EXT] = irq_i[0];
		mip_d[riscv_IRQ_M_SOFT] = ipi_i;
		mip_d[riscv_IRQ_M_TIMER] = time_irq_i;
		trap_to_priv_lvl = 2'b11;
		if (!debug_mode_q && ex_i[0]) begin
			flush_o = 1'b0;
			if ((ex_i[128] && mideleg_q[ex_i[70:65]]) || (~ex_i[128] && medeleg_q[ex_i[70:65]]))
				trap_to_priv_lvl = (priv_lvl_o == 2'b11 ? 2'b11 : 2'b01);
			if (trap_to_priv_lvl == 2'b01) begin
				mstatus_d[1] = 1'b0;
				mstatus_d[5] = mstatus_q[1];
				mstatus_d[8] = priv_lvl_q[0];
				scause_d = ex_i[128-:64];
				sepc_d = pc_i;
				stval_d = ex_i[64-:64];
			end
			else begin
				mstatus_d[3] = 1'b0;
				mstatus_d[7] = mstatus_q[3];
				mstatus_d[12-:2] = priv_lvl_q;
				mcause_d = ex_i[128-:64];
				mepc_d = pc_i;
				mtval_d = ex_i[64-:64];
			end
			priv_lvl_d = trap_to_priv_lvl;
		end
		if (!debug_mode_q) begin
			dcsr_d[1-:2] = priv_lvl_o;
			if (ex_i[0] && (ex_i[128-:64] == riscv_BREAKPOINT)) begin
				(* full_case, parallel_case *)
				case (priv_lvl_o)
					2'b11: begin
						debug_mode_d = dcsr_q[15];
						set_debug_pc_o = dcsr_q[15];
					end
					2'b01: begin
						debug_mode_d = dcsr_q[13];
						set_debug_pc_o = dcsr_q[13];
					end
					2'b00: begin
						debug_mode_d = dcsr_q[12];
						set_debug_pc_o = dcsr_q[12];
					end
					default:
						;
				endcase
				dpc_d = pc_i;
				dcsr_d[8-:3] = dm_CauseBreakpoint;
			end
			if (debug_req_i && commit_instr_i[201]) begin
				dpc_d = pc_i;
				debug_mode_d = 1'b1;
				set_debug_pc_o = 1'b1;
				dcsr_d[8-:3] = dm_CauseRequest;
			end
			if (dcsr_q[2] && commit_ack_i[0]) begin
				if (commit_instr_i[294-:4] == 4'd4)
					dpc_d = commit_instr_i[67-:64];
				else if (ex_i[0])
					dpc_d = trap_vector_base_o;
				else if (eret_o)
					dpc_d = epc_o;
				else
					dpc_d = commit_instr_i[361-:64] + (commit_instr_i[0] ? 'h2 : 'h4);
				debug_mode_d = 1'b1;
				set_debug_pc_o = 1'b1;
				dcsr_d[8-:3] = dm_CauseSingleStep;
			end
		end
		if ((debug_mode_q && ex_i[0]) && (ex_i[128-:64] == riscv_BREAKPOINT))
			set_debug_pc_o = 1'b1;
		if ((mprv && (satp_q[63-:4] == ariane_pkg_MODE_SV39)) && (mstatus_q[12-:2] != 2'b11))
			en_ld_st_translation_d = 1'b1;
		else
			en_ld_st_translation_d = en_translation_o;
		ld_st_priv_lvl_o = (mprv ? mstatus_q[12-:2] : priv_lvl_o);
		en_ld_st_translation_o = en_ld_st_translation_q;
		if (mret) begin
			eret_o = 1'b1;
			mstatus_d[3] = mstatus_q[7];
			priv_lvl_d = mstatus_q[12-:2];
			mstatus_d[12-:2] = 2'b00;
			mstatus_d[7] = 1'b1;
		end
		if (sret) begin
			eret_o = 1'b1;
			mstatus_d[1] = mstatus_q[5];
			priv_lvl_d = sv2v_cast_2({1'b0, mstatus_q[8]});
			mstatus_d[8] = 1'b0;
			mstatus_d[5] = 1'b1;
		end
		if (dret) begin
			eret_o = 1'b1;
			priv_lvl_d = sv2v_cast_2(dcsr_q[1-:2]);
			debug_mode_d = 1'b0;
		end
	end
	always @(*) begin : csr_op_logic
		if (_sv2v_0)
			;
		csr_wdata = csr_wdata_i;
		csr_we = 1'b1;
		csr_read = 1'b1;
		mret = 1'b0;
		sret = 1'b0;
		dret = 1'b0;
		(* full_case, parallel_case *)
		case (csr_op_i)
			7'd30: csr_wdata = csr_wdata_i;
			7'd32: csr_wdata = csr_wdata_i | csr_rdata;
			7'd33: csr_wdata = ~csr_wdata_i & csr_rdata;
			7'd31: csr_we = 1'b0;
			7'd23: begin
				csr_we = 1'b0;
				csr_read = 1'b0;
				sret = 1'b1;
			end
			7'd22: begin
				csr_we = 1'b0;
				csr_read = 1'b0;
				mret = 1'b1;
			end
			7'd24: begin
				csr_we = 1'b0;
				csr_read = 1'b0;
				dret = 1'b1;
			end
			default: begin
				csr_we = 1'b0;
				csr_read = 1'b0;
			end
		endcase
		if (ex_i[0]) begin
			mret = 1'b0;
			sret = 1'b0;
			dret = 1'b0;
		end
	end
	reg interrupt_global_enable;
	localparam [63:0] riscv_M_EXT_INTERRUPT = 65'sd9223372036854775808 | riscv_IRQ_M_EXT;
	localparam [63:0] riscv_M_SW_INTERRUPT = 65'sd9223372036854775808 | riscv_IRQ_M_SOFT;
	localparam [63:0] riscv_M_TIMER_INTERRUPT = 65'sd9223372036854775808 | riscv_IRQ_M_TIMER;
	localparam [63:0] riscv_S_EXT_INTERRUPT = 65'sd9223372036854775808 | riscv_IRQ_S_EXT;
	localparam [63:0] riscv_S_SW_INTERRUPT = 65'sd9223372036854775808 | riscv_IRQ_S_SOFT;
	localparam [63:0] riscv_S_TIMER_INTERRUPT = 65'sd9223372036854775808 | riscv_IRQ_S_TIMER;
	always @(*) begin : exception_ctrl
		reg [63:0] interrupt_cause;
		if (_sv2v_0)
			;
		interrupt_cause = 1'sb0;
		wfi_d = wfi_q;
		csr_exception_o = 129'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
		if (mie_q[riscv_S_TIMER_INTERRUPT[5:0]] && mip_q[riscv_S_TIMER_INTERRUPT[5:0]])
			interrupt_cause = riscv_S_TIMER_INTERRUPT;
		if (mie_q[riscv_S_SW_INTERRUPT[5:0]] && mip_q[riscv_S_SW_INTERRUPT[5:0]])
			interrupt_cause = riscv_S_SW_INTERRUPT;
		if (mie_q[riscv_S_EXT_INTERRUPT[5:0]] && (mip_q[riscv_S_EXT_INTERRUPT[5:0]] | irq_i[1]))
			interrupt_cause = riscv_S_EXT_INTERRUPT;
		if (mip_q[riscv_M_TIMER_INTERRUPT[5:0]] && mie_q[riscv_M_TIMER_INTERRUPT[5:0]])
			interrupt_cause = riscv_M_TIMER_INTERRUPT;
		if (mip_q[riscv_M_SW_INTERRUPT[5:0]] && mie_q[riscv_M_SW_INTERRUPT[5:0]])
			interrupt_cause = riscv_M_SW_INTERRUPT;
		if (mip_q[riscv_M_EXT_INTERRUPT[5:0]] && mie_q[riscv_M_EXT_INTERRUPT[5:0]])
			interrupt_cause = riscv_M_EXT_INTERRUPT;
		interrupt_global_enable = (~debug_mode_q & (~dcsr_q[2] | dcsr_q[11])) & ((mstatus_q[3] & (priv_lvl_o == 2'b11)) | (priv_lvl_o != 2'b11));
		if (interrupt_cause[63] && interrupt_global_enable) begin
			csr_exception_o[128-:64] = interrupt_cause;
			if (mideleg_q[interrupt_cause[5:0]]) begin
				if ((mstatus_q[1] && (priv_lvl_o == 2'b01)) || (priv_lvl_o == 2'b00))
					csr_exception_o[0] = 1'b1;
			end
			else
				csr_exception_o[0] = 1'b1;
		end
		if (csr_we || csr_read) begin
			if ((sv2v_cast_2(priv_lvl_o & csr_addr[9-:2]) != csr_addr[9-:2]) && (csr_addr[11-:12] != 12'h341)) begin
				csr_exception_o[128-:64] = riscv_ILLEGAL_INSTR;
				csr_exception_o[0] = 1'b1;
			end
			if ((csr_addr_i[11:4] == 8'h7b) && !debug_mode_q) begin
				csr_exception_o[128-:64] = riscv_ILLEGAL_INSTR;
				csr_exception_o[0] = 1'b1;
			end
		end
		if (update_access_exception || read_access_exception) begin
			csr_exception_o[128-:64] = riscv_ILLEGAL_INSTR;
			csr_exception_o[0] = 1'b1;
		end
		if ((|mip_q || debug_req_i) || irq_i[1])
			wfi_d = 1'b0;
		else if ((!debug_mode_q && (csr_op_i == 7'd26)) && !ex_i[0])
			wfi_d = 1'b1;
	end
	localparam [63:0] dm_HaltAddress = 64'h0000000000000800;
	localparam [63:0] dm_ExceptionAddress = 2056;
	always @(*) begin : priv_output
		if (_sv2v_0)
			;
		trap_vector_base_o = {mtvec_q[63:2], 2'b00};
		if (trap_to_priv_lvl == 2'b01)
			trap_vector_base_o = {stvec_q[63:2], 2'b00};
		if (debug_mode_q)
			trap_vector_base_o = dm_ExceptionAddress;
		if ((mtvec_q[0] || stvec_q[0]) && csr_exception_o[128])
			trap_vector_base_o[7:2] = csr_exception_o[70:65];
		epc_o = mepc_q;
		if (sret)
			epc_o = sepc_q;
		if (dret)
			epc_o = dpc_q;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		csr_rdata_o = csr_rdata;
		(* full_case, parallel_case *)
		case (csr_addr[11-:12])
			12'h344: csr_rdata_o = csr_rdata | (irq_i[1] << riscv_IRQ_S_EXT);
			12'h144: csr_rdata_o = csr_rdata | ((irq_i[1] & mideleg_q[riscv_IRQ_S_EXT]) << riscv_IRQ_S_EXT);
			default:
				;
		endcase
	end
	assign priv_lvl_o = (debug_mode_q || umode_i ? 2'b11 : priv_lvl_q);
	assign fflags_o = fcsr_q[4-:5];
	assign frm_o = fcsr_q[7-:3];
	assign fprec_o = fcsr_q[14-:7];
	assign satp_ppn_o = satp_q[43-:44];
	assign asid_o = satp_q[43 + ASID_WIDTH:44];
	assign sum_o = mstatus_q[18];
	assign en_translation_o = ((satp_q[63-:4] == 4'h8) && (priv_lvl_o != 2'b11) ? 1'b1 : 1'b0);
	assign mxr_o = mstatus_q[19];
	assign tvm_o = mstatus_q[20];
	assign tw_o = mstatus_q[21];
	assign tsr_o = mstatus_q[22];
	assign halt_csr_o = wfi_q;
	assign icache_en_o = icache_q[0] & ~debug_mode_q;
	assign dcache_en_o = dcache_q[0];
	assign mprv = (debug_mode_q && !dcsr_q[4] ? 1'b0 : mstatus_q[17]);
	assign debug_mode_o = debug_mode_q;
	assign single_step_o = dcsr_q[2];
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			priv_lvl_q <= 2'b11;
			fcsr_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			debug_mode_q <= 1'b0;
			dcsr_q <= 1'sb0;
			dcsr_q[1-:2] <= 2'b11;
			dpc_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			dscratch0_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			dscratch1_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			mstatus_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			mtvec_rst_load_q <= 1'b1;
			mtvec_q <= 1'sb0;
			medeleg_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			mideleg_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			mip_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			mie_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			mepc_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			mcause_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			mscratch_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			mtval_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			dcache_q <= 64'b0000000000000000000000000000000000000000000000000000000000000001;
			icache_q <= 64'b0000000000000000000000000000000000000000000000000000000000000001;
			sepc_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			scause_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			stvec_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			sscratch_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			stval_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			satp_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			cycle_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			instret_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			en_ld_st_translation_q <= 1'b0;
			wfi_q <= 1'b0;
		end
		else begin
			priv_lvl_q <= priv_lvl_d;
			fcsr_q <= fcsr_d;
			debug_mode_q <= debug_mode_d;
			dcsr_q <= dcsr_d;
			dpc_q <= dpc_d;
			dscratch0_q <= dscratch0_d;
			dscratch1_q <= dscratch1_d;
			mstatus_q <= mstatus_d;
			mtvec_rst_load_q <= 1'b0;
			mtvec_q <= mtvec_d;
			medeleg_q <= medeleg_d;
			mideleg_q <= mideleg_d;
			mip_q <= mip_d;
			mie_q <= mie_d;
			mepc_q <= mepc_d;
			mcause_q <= mcause_d;
			mscratch_q <= mscratch_d;
			mtval_q <= mtval_d;
			dcache_q <= dcache_d;
			icache_q <= icache_d;
			sepc_q <= sepc_d;
			scause_q <= scause_d;
			stvec_q <= stvec_d;
			sscratch_q <= sscratch_d;
			stval_q <= stval_d;
			satp_q <= satp_d;
			cycle_q <= cycle_d;
			instret_q <= instret_d;
			en_ld_st_translation_q <= en_ld_st_translation_d;
			wfi_q <= wfi_d;
		end
	initial _sv2v_0 = 0;
`ifdef FORMAL
	reg [63:0] past_instret_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) past_instret_q <= 64'b0;
		else         past_instret_q <= instret_q;
	always @(posedge clk_i) begin
		if (rst_ni) begin
`ifdef FORMAL_P5
			HACK_DAC19_p5:  assert (!(debug_mode_q && umode_i) || (2'b11 != 2'b0));
`endif
`ifdef FORMAL_P9
			HACK_DAC19_p9:  assert (!((csr_we || csr_read) && (csr_addr == 12'h341)) || csr_exception_o[0]);
`endif
`ifdef FORMAL_P24
			HACK_DAC19_p24: assert (!(tvm_o) || (csr_rdata_o != satp_q));
`endif
`ifdef FORMAL_P25
			HACK_DAC19_p25: assert (!(tvm_o) || (satp_d != csr_wdata_i));
`endif
`ifdef FORMAL_P29
			HACK_DAC19_p29: assert (!(instret_q != past_instret_q) || debug_mode_q);
`endif
		end
	end
`endif
endmodule
module decoder (
	pc_i,
	is_compressed_i,
	compressed_instr_i,
	is_illegal_i,
	instruction_i,
	branch_predict_i,
	ex_i,
	priv_lvl_i,
	debug_mode_i,
	fs_i,
	frm_i,
	tvm_i,
	tw_i,
	tsr_i,
	instruction_o,
	is_control_flow_instr_o
);
	reg _sv2v_0;
	input wire [63:0] pc_i;
	input wire is_compressed_i;
	input wire [15:0] compressed_instr_i;
	input wire is_illegal_i;
	input wire [31:0] instruction_i;
	input wire [67:0] branch_predict_i;
	input wire [128:0] ex_i;
	input wire [1:0] priv_lvl_i;
	input wire debug_mode_i;
	input wire [1:0] fs_i;
	input wire [2:0] frm_i;
	input wire tvm_i;
	input wire tw_i;
	input wire tsr_i;
	localparam ariane_pkg_REG_ADDR_SIZE = 6;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	output reg [361:0] instruction_o;
	output reg is_control_flow_instr_o;
	reg illegal_instr;
	reg ecall;
	reg ebreak;
	reg check_fprm;
	wire [31:0] instr;
	assign instr = instruction_i;
	reg [3:0] imm_select;
	reg [63:0] imm_i_type;
	reg [63:0] imm_s_type;
	reg [63:0] imm_sb_type;
	reg [63:0] imm_u_type;
	reg [63:0] imm_uj_type;
	reg [63:0] imm_bi_type;
	localparam [0:0] ariane_pkg_ENABLE_WFI = 1'b1;
	localparam [0:0] ariane_pkg_RVD = 1'b0;
	localparam [0:0] ariane_pkg_RVF = 1'b0;
	localparam [0:0] ariane_pkg_XF16 = 1'b0;
	localparam [0:0] ariane_pkg_XF16ALT = 1'b0;
	localparam [0:0] ariane_pkg_XF8 = 1'b0;
	localparam [0:0] ariane_pkg_FP_PRESENT = (((ariane_pkg_RVF | ariane_pkg_RVD) | ariane_pkg_XF16) | ariane_pkg_XF16ALT) | ariane_pkg_XF8;
	localparam [0:0] ariane_pkg_RVA = 1'b1;
	localparam ariane_pkg_FLEN = (ariane_pkg_RVD ? 64 : (ariane_pkg_RVF ? 32 : (ariane_pkg_XF16 ? 16 : (ariane_pkg_XF16ALT ? 16 : (ariane_pkg_XF8 ? 8 : 0)))));
	localparam [0:0] ariane_pkg_XFVEC = 1'b0;
	localparam [0:0] ariane_pkg_RVFVEC = (ariane_pkg_RVF & ariane_pkg_XFVEC) & (ariane_pkg_FLEN > 32);
	localparam [0:0] ariane_pkg_XF16ALTVEC = (ariane_pkg_XF16ALT & ariane_pkg_XFVEC) & (ariane_pkg_FLEN > 16);
	localparam [0:0] ariane_pkg_XF16VEC = (ariane_pkg_XF16 & ariane_pkg_XFVEC) & (ariane_pkg_FLEN > 16);
	localparam [0:0] ariane_pkg_XF8VEC = (ariane_pkg_XF8 & ariane_pkg_XFVEC) & (ariane_pkg_FLEN > 8);
	localparam riscv_OpcodeAmo = 7'b0101111;
	localparam riscv_OpcodeAuipc = 7'b0010111;
	localparam riscv_OpcodeBranch = 7'b1100011;
	localparam riscv_OpcodeJal = 7'b1101111;
	localparam riscv_OpcodeJalr = 7'b1100111;
	localparam riscv_OpcodeLoad = 7'b0000011;
	localparam riscv_OpcodeLoadFp = 7'b0000111;
	localparam riscv_OpcodeLui = 7'b0110111;
	localparam riscv_OpcodeMadd = 7'b1000011;
	localparam riscv_OpcodeMiscMem = 7'b0001111;
	localparam riscv_OpcodeMsub = 7'b1000111;
	localparam riscv_OpcodeNmadd = 7'b1001111;
	localparam riscv_OpcodeNmsub = 7'b1001011;
	localparam riscv_OpcodeOp = 7'b0110011;
	localparam riscv_OpcodeOp32 = 7'b0111011;
	localparam riscv_OpcodeOpFp = 7'b1010011;
	localparam riscv_OpcodeOpImm = 7'b0010011;
	localparam riscv_OpcodeOpImm32 = 7'b0011011;
	localparam riscv_OpcodeStore = 7'b0100011;
	localparam riscv_OpcodeStoreFp = 7'b0100111;
	localparam riscv_OpcodeSystem = 7'b1110011;
	always @(*) begin : decoder
		if (_sv2v_0)
			;
		imm_select = 4'd0;
		is_control_flow_instr_o = 1'b0;
		illegal_instr = 1'b0;
		instruction_o[361-:64] = pc_i;
		instruction_o[297-:3] = 5'b00000;
		instruction_o[294-:4] = 4'd0;
		instruction_o[290-:7] = 7'd0;
		instruction_o[283-:6] = 1'sb0;
		instruction_o[277-:6] = 1'sb0;
		instruction_o[271-:6] = 1'sb0;
		instruction_o[198] = 1'b0;
		instruction_o[297-:3] = 1'sb0;
		instruction_o[0] = is_compressed_i;
		instruction_o[199] = 1'b0;
		instruction_o[68-:68] = branch_predict_i;
		ecall = 1'b0;
		ebreak = 1'b0;
		check_fprm = 1'b0;
		if (~ex_i[0])
			case (instr[6-:7])
				riscv_OpcodeSystem: begin
					instruction_o[294-:4] = 4'd6;
					instruction_o[282:278] = instr[19-:5];
					instruction_o[270:266] = instr[11-:5];
					(* full_case, parallel_case *)
					case (instr[14-:3])
						3'b000: begin
							if ((instr[19-:5] != {5 {1'sb0}}) || (instr[11-:5] != {5 {1'sb0}}))
								illegal_instr = 1'b1;
							case (instr[31-:12])
								12'b000000000000: ecall = 1'b1;
								12'b000000000001: ebreak = 1'b1;
								12'b000100000010: begin
									instruction_o[290-:7] = 7'd23;
									if (priv_lvl_i == 2'b00) begin
										illegal_instr = 1'b1;
										instruction_o[290-:7] = 7'd0;
									end
									if ((priv_lvl_i == 2'b01) && tsr_i) begin
										illegal_instr = 1'b1;
										instruction_o[290-:7] = 7'd0;
									end
								end
								12'b001100000010: begin
									instruction_o[290-:7] = 7'd22;
									if (|{priv_lvl_i == 2'b00, priv_lvl_i == 2'b01})
										illegal_instr = 1'b1;
								end
								12'b011110110010: begin
									instruction_o[290-:7] = 7'd24;
									illegal_instr = (!debug_mode_i ? 1'b1 : 1'b0);
								end
								12'b000100000101: begin
									if (ariane_pkg_ENABLE_WFI)
										instruction_o[290-:7] = 7'd26;
									if ((priv_lvl_i == 2'b01) && tw_i) begin
										illegal_instr = 1'b1;
										instruction_o[290-:7] = 7'd0;
									end
									if (priv_lvl_i == 2'b00) begin
										illegal_instr = 1'b1;
										instruction_o[290-:7] = 7'd0;
									end
								end
								default:
									if (instr[31:25] == 7'b0001001) begin
										illegal_instr = (|{priv_lvl_i == 2'b11, priv_lvl_i == 2'b01} ? 1'b0 : 1'b1);
										instruction_o[290-:7] = 7'd29;
										if ((priv_lvl_i == 2'b01) && tvm_i)
											illegal_instr = 1'b1;
									end
							endcase
						end
						3'b001: begin
							imm_select = 4'd1;
							instruction_o[290-:7] = 7'd30;
						end
						3'b010: begin
							imm_select = 4'd1;
							if (instr[19-:5] == 5'b00000)
								instruction_o[290-:7] = 7'd31;
							else
								instruction_o[290-:7] = 7'd32;
						end
						3'b011: begin
							imm_select = 4'd1;
							if (instr[19-:5] == 5'b00000)
								instruction_o[290-:7] = 7'd31;
							else
								instruction_o[290-:7] = 7'd33;
						end
						3'b101: begin
							instruction_o[282:278] = instr[19-:5];
							imm_select = 4'd1;
							instruction_o[199] = 1'b1;
							instruction_o[290-:7] = 7'd30;
						end
						3'b110: begin
							instruction_o[282:278] = instr[19-:5];
							imm_select = 4'd1;
							instruction_o[199] = 1'b1;
							if (instr[19-:5] == 5'b00000)
								instruction_o[290-:7] = 7'd31;
							else
								instruction_o[290-:7] = 7'd32;
						end
						3'b111: begin
							instruction_o[282:278] = instr[19-:5];
							imm_select = 4'd1;
							instruction_o[199] = 1'b1;
							if (instr[19-:5] == 5'b00000)
								instruction_o[290-:7] = 7'd31;
							else
								instruction_o[290-:7] = 7'd33;
						end
						default: illegal_instr = 1'b1;
					endcase
				end
				riscv_OpcodeMiscMem: begin
					instruction_o[294-:4] = 4'd6;
					instruction_o[283-:6] = 1'sb0;
					instruction_o[277-:6] = 1'sb0;
					instruction_o[271-:6] = 1'sb0;
					case (instr[14-:3])
						3'b000: instruction_o[290-:7] = 7'd27;
						3'b001: begin
							if (instr[31:20] != {12 {1'sb0}})
								illegal_instr = 1'b1;
							instruction_o[290-:7] = 7'd28;
						end
						default: illegal_instr = 1'b1;
					endcase
					if (((instr[19-:5] != {5 {1'sb0}}) || (instr[11-:5] != {5 {1'sb0}})) || (instr[31:28] != {4 {1'sb0}}))
						illegal_instr = 1'b1;
				end
				riscv_OpcodeOp:
					if (instr[31-:2] == 2'b10) begin
						if ((ariane_pkg_FP_PRESENT && ariane_pkg_XFVEC) && (fs_i != 2'b00)) begin : sv2v_autoblock_1
							reg allow_replication;
							instruction_o[294-:4] = 4'd8;
							instruction_o[282:278] = instr[19-:5];
							instruction_o[276:272] = instr[24-:5];
							instruction_o[270:266] = instr[11-:5];
							check_fprm = 1'b1;
							allow_replication = 1'b1;
							(* full_case, parallel_case *)
							case (instr[29-:5])
								5'b00001: begin
									instruction_o[290-:7] = 7'd88;
									instruction_o[283-:6] = 1'sb0;
									instruction_o[277-:6] = instr[19-:5];
									imm_select = 4'd1;
								end
								5'b00010: begin
									instruction_o[290-:7] = 7'd89;
									instruction_o[283-:6] = 1'sb0;
									instruction_o[277-:6] = instr[19-:5];
									imm_select = 4'd1;
								end
								5'b00011: instruction_o[290-:7] = 7'd90;
								5'b00100: instruction_o[290-:7] = 7'd91;
								5'b00101: begin
									instruction_o[290-:7] = 7'd106;
									check_fprm = 1'b0;
								end
								5'b00110: begin
									instruction_o[290-:7] = 7'd107;
									check_fprm = 1'b0;
								end
								5'b00111: begin
									instruction_o[290-:7] = 7'd93;
									allow_replication = 1'b0;
									if (instr[24-:5] != 5'b00000)
										illegal_instr = 1'b1;
								end
								5'b01000: begin
									instruction_o[290-:7] = 7'd94;
									imm_select = 4'd2;
								end
								5'b01001: begin
									instruction_o[290-:7] = 7'd95;
									imm_select = 4'd2;
								end
								5'b01100:
									(* full_case, parallel_case *)
									if (instr[24-:5] == 5'b00000) begin
										instruction_o[277-:6] = instr[19-:5];
										if (instr[14])
											instruction_o[290-:7] = 7'd102;
										else
											instruction_o[290-:7] = 7'd103;
										check_fprm = 1'b0;
									end
									else if (instr[24-:5] == 5'b00001) begin
										instruction_o[290-:7] = 7'd105;
										check_fprm = 1'b0;
										allow_replication = 1'b0;
									end
									else if (instr[24-:5] == 5'b00010)
										instruction_o[290-:7] = 7'd98;
									else if (instr[24-:5] == 5'b00011)
										instruction_o[290-:7] = 7'd99;
									else if ((instr[24-:5] | 5'b00011) == 5'b00111) begin
										instruction_o[290-:7] = 7'd100;
										instruction_o[277-:6] = instr[11-:5];
										imm_select = 4'd1;
										(* full_case, parallel_case *)
										case (instr[21:20])
											2'b00:
												if (~ariane_pkg_RVFVEC)
													illegal_instr = 1'b1;
											2'b01:
												if (~ariane_pkg_XF16ALTVEC)
													illegal_instr = 1'b1;
											2'b10:
												if (~ariane_pkg_XF16VEC)
													illegal_instr = 1'b1;
											2'b11:
												if (~ariane_pkg_XF8VEC)
													illegal_instr = 1'b1;
											default: illegal_instr = 1'b1;
										endcase
									end
									else
										illegal_instr = 1'b1;
								5'b01101: begin
									check_fprm = 1'b0;
									instruction_o[290-:7] = 7'd108;
								end
								5'b01110: begin
									check_fprm = 1'b0;
									instruction_o[290-:7] = 7'd109;
								end
								5'b01111: begin
									check_fprm = 1'b0;
									instruction_o[290-:7] = 7'd110;
								end
								5'b10000: begin
									check_fprm = 1'b0;
									instruction_o[290-:7] = 7'd111;
								end
								5'b10001: begin
									check_fprm = 1'b0;
									instruction_o[290-:7] = 7'd112;
								end
								5'b10010: begin
									check_fprm = 1'b0;
									instruction_o[290-:7] = 7'd113;
								end
								5'b10011: begin
									check_fprm = 1'b0;
									instruction_o[290-:7] = 7'd114;
								end
								5'b10100: begin
									check_fprm = 1'b0;
									instruction_o[290-:7] = 7'd115;
								end
								5'b10101: begin
									check_fprm = 1'b0;
									instruction_o[290-:7] = 7'd116;
								end
								5'b11000: begin
									instruction_o[290-:7] = 7'd117;
									imm_select = 4'd2;
									if (~ariane_pkg_RVF)
										illegal_instr = 1'b1;
									(* full_case, parallel_case *)
									case (instr[13-:2])
										2'b00: begin
											if (~ariane_pkg_RVFVEC)
												illegal_instr = 1'b1;
											if (instr[14])
												illegal_instr = 1'b1;
										end
										2'b01:
											if (~ariane_pkg_XF16ALTVEC)
												illegal_instr = 1'b1;
										2'b10:
											if (~ariane_pkg_XF16VEC)
												illegal_instr = 1'b1;
										2'b11:
											if (~ariane_pkg_XF8VEC)
												illegal_instr = 1'b1;
										default: illegal_instr = 1'b1;
									endcase
								end
								5'b11001: begin
									instruction_o[290-:7] = 7'd118;
									imm_select = 4'd2;
									if (~ariane_pkg_RVF)
										illegal_instr = 1'b1;
									(* full_case, parallel_case *)
									case (instr[13-:2])
										2'b00: illegal_instr = 1'b1;
										2'b01: illegal_instr = 1'b1;
										2'b10: illegal_instr = 1'b1;
										2'b11:
											if (~ariane_pkg_XF8VEC)
												illegal_instr = 1'b1;
										default: illegal_instr = 1'b1;
									endcase
								end
								5'b11010: begin
									instruction_o[290-:7] = 7'd119;
									imm_select = 4'd2;
									if (~ariane_pkg_RVD)
										illegal_instr = 1'b1;
									(* full_case, parallel_case *)
									case (instr[13-:2])
										2'b00: begin
											if (~ariane_pkg_RVFVEC)
												illegal_instr = 1'b1;
											if (instr[14])
												illegal_instr = 1'b1;
										end
										2'b01:
											if (~ariane_pkg_XF16ALTVEC)
												illegal_instr = 1'b1;
										2'b10:
											if (~ariane_pkg_XF16VEC)
												illegal_instr = 1'b1;
										2'b11:
											if (~ariane_pkg_XF8VEC)
												illegal_instr = 1'b1;
										default: illegal_instr = 1'b1;
									endcase
								end
								5'b11011: begin
									instruction_o[290-:7] = 7'd120;
									imm_select = 4'd2;
									if (~ariane_pkg_RVD)
										illegal_instr = 1'b1;
									(* full_case, parallel_case *)
									case (instr[13-:2])
										2'b00: illegal_instr = 1'b1;
										2'b01: illegal_instr = 1'b1;
										2'b10: illegal_instr = 1'b1;
										2'b11:
											if (~ariane_pkg_XF8VEC)
												illegal_instr = 1'b1;
										default: illegal_instr = 1'b1;
									endcase
								end
								default: illegal_instr = 1'b1;
							endcase
							(* full_case, parallel_case *)
							case (instr[13-:2])
								2'b00:
									if (~ariane_pkg_RVFVEC)
										illegal_instr = 1'b1;
								2'b01:
									if (~ariane_pkg_XF16ALTVEC)
										illegal_instr = 1'b1;
								2'b10:
									if (~ariane_pkg_XF16VEC)
										illegal_instr = 1'b1;
								2'b11:
									if (~ariane_pkg_XF8VEC)
										illegal_instr = 1'b1;
								default: illegal_instr = 1'b1;
							endcase
							if (~allow_replication & instr[14])
								illegal_instr = 1'b1;
							if (check_fprm) begin
								(* full_case, parallel_case *)
								if ((3'b000 <= frm_i) && (3'b100 >= frm_i))
									;
								else
									illegal_instr = 1'b1;
							end
						end
						else
							illegal_instr = 1'b1;
					end
					else begin
						instruction_o[294-:4] = (instr[31-:7] == 7'b0000001 ? 4'd5 : 4'd3);
						instruction_o[283-:6] = instr[19-:5];
						instruction_o[277-:6] = instr[24-:5];
						instruction_o[271-:6] = instr[11-:5];
						(* full_case, parallel_case *)
						case ({instr[31-:7], instr[14-:3]})
							10'b0000000000: instruction_o[290-:7] = 7'd0;
							10'b0100000000: instruction_o[290-:7] = 7'd1;
							10'b0000000010: instruction_o[290-:7] = 7'd20;
							10'b0000000011: instruction_o[290-:7] = 7'd21;
							10'b0000000100: instruction_o[290-:7] = 7'd4;
							10'b0000000110: instruction_o[290-:7] = 7'd5;
							10'b0000000111: instruction_o[290-:7] = 7'd6;
							10'b0000000001: instruction_o[290-:7] = 7'd9;
							10'b0000000101: instruction_o[290-:7] = 7'd8;
							10'b0100000101: instruction_o[290-:7] = 7'd7;
							10'b0000001000: instruction_o[290-:7] = 7'd67;
							10'b0000001001: instruction_o[290-:7] = 7'd68;
							10'b0000001010: instruction_o[290-:7] = 7'd70;
							10'b0000001011: instruction_o[290-:7] = 7'd69;
							10'b0000001100: instruction_o[290-:7] = 7'd72;
							10'b0000001101: instruction_o[290-:7] = 7'd73;
							10'b0000001110: instruction_o[290-:7] = 7'd76;
							10'b0000001111: instruction_o[290-:7] = 7'd77;
							default: illegal_instr = 1'b1;
						endcase
					end
				riscv_OpcodeOp32: begin
					instruction_o[294-:4] = (instr[31-:7] == 7'b0000001 ? 4'd5 : 4'd3);
					instruction_o[282:278] = instr[19-:5];
					instruction_o[276:272] = instr[24-:5];
					instruction_o[270:266] = instr[11-:5];
					(* full_case, parallel_case *)
					case ({instr[31-:7], instr[14-:3]})
						10'b0000000000: instruction_o[290-:7] = 7'd2;
						10'b0100000000: instruction_o[290-:7] = 7'd3;
						10'b0000000001: instruction_o[290-:7] = 7'd11;
						10'b0000000101: instruction_o[290-:7] = 7'd10;
						10'b0100000101: instruction_o[290-:7] = 7'd12;
						10'b0000001000: instruction_o[290-:7] = 7'd71;
						10'b0000001100: instruction_o[290-:7] = 7'd74;
						10'b0000001101: instruction_o[290-:7] = 7'd75;
						10'b0000001110: instruction_o[290-:7] = 7'd78;
						10'b0000001111: instruction_o[290-:7] = 7'd79;
						default: illegal_instr = 1'b1;
					endcase
				end
				riscv_OpcodeOpImm: begin
					instruction_o[294-:4] = 4'd3;
					imm_select = 4'd1;
					instruction_o[282:278] = instr[19-:5];
					instruction_o[270:266] = instr[11-:5];
					(* full_case, parallel_case *)
					case (instr[14-:3])
						3'b000: instruction_o[290-:7] = 7'd0;
						3'b010: instruction_o[290-:7] = 7'd20;
						3'b011: instruction_o[290-:7] = 7'd21;
						3'b100: instruction_o[290-:7] = 7'd4;
						3'b110: instruction_o[290-:7] = 7'd5;
						3'b111: instruction_o[290-:7] = 7'd6;
						3'b001: begin
							instruction_o[290-:7] = 7'd9;
							if (instr[31:26] != 6'b000000)
								illegal_instr = 1'b1;
						end
						3'b101:
							if (instr[31:26] == 6'b000000)
								instruction_o[290-:7] = 7'd8;
							else if (instr[31:26] == 6'b010000)
								instruction_o[290-:7] = 7'd7;
							else
								illegal_instr = 1'b1;
					endcase
				end
				riscv_OpcodeOpImm32: begin
					instruction_o[294-:4] = 4'd3;
					imm_select = 4'd1;
					instruction_o[282:278] = instr[19-:5];
					instruction_o[270:266] = instr[11-:5];
					(* full_case, parallel_case *)
					case (instr[14-:3])
						3'b000: instruction_o[290-:7] = 7'd2;
						3'b001: begin
							instruction_o[290-:7] = 7'd11;
							if (instr[31:25] != 7'b0000000)
								illegal_instr = 1'b1;
						end
						3'b101:
							if (instr[31:25] == 7'b0000000)
								instruction_o[290-:7] = 7'd10;
							else if (instr[31:25] == 7'b0100000)
								instruction_o[290-:7] = 7'd12;
							else
								illegal_instr = 1'b1;
						default: illegal_instr = 1'b1;
					endcase
				end
				riscv_OpcodeStore: begin
					instruction_o[294-:4] = 4'd2;
					imm_select = 4'd2;
					instruction_o[282:278] = instr[19-:5];
					instruction_o[276:272] = instr[24-:5];
					(* full_case, parallel_case *)
					case (instr[14-:3])
						3'b000: instruction_o[290-:7] = 7'd43;
						3'b001: instruction_o[290-:7] = 7'd41;
						3'b010: instruction_o[290-:7] = 7'd38;
						3'b011: instruction_o[290-:7] = 7'd35;
						default: illegal_instr = 1'b1;
					endcase
				end
				riscv_OpcodeLoad: begin
					instruction_o[294-:4] = 4'd1;
					imm_select = 4'd1;
					instruction_o[282:278] = instr[19-:5];
					instruction_o[270:266] = instr[11-:5];
					(* full_case, parallel_case *)
					case (instr[14-:3])
						3'b000: instruction_o[290-:7] = 7'd42;
						3'b001: instruction_o[290-:7] = 7'd39;
						3'b010: instruction_o[290-:7] = 7'd36;
						3'b100: instruction_o[290-:7] = 7'd44;
						3'b101: instruction_o[290-:7] = 7'd40;
						3'b110: instruction_o[290-:7] = 7'd37;
						3'b011: instruction_o[290-:7] = 7'd34;
						default: illegal_instr = 1'b1;
					endcase
				end
				riscv_OpcodeStoreFp:
					if (ariane_pkg_FP_PRESENT && (fs_i != 2'b00)) begin
						instruction_o[294-:4] = 4'd2;
						imm_select = 4'd2;
						instruction_o[283-:6] = instr[19-:5];
						instruction_o[277-:6] = instr[24-:5];
						(* full_case, parallel_case *)
						case (instr[14-:3])
							3'b000:
								if (ariane_pkg_XF8)
									instruction_o[290-:7] = 7'd87;
								else
									illegal_instr = 1'b1;
							3'b001:
								if (ariane_pkg_XF16 | ariane_pkg_XF16ALT)
									instruction_o[290-:7] = 7'd86;
								else
									illegal_instr = 1'b1;
							3'b010:
								if (ariane_pkg_RVF)
									instruction_o[290-:7] = 7'd85;
								else
									illegal_instr = 1'b1;
							3'b011:
								if (ariane_pkg_RVD)
									instruction_o[290-:7] = 7'd84;
								else
									illegal_instr = 1'b1;
							default: illegal_instr = 1'b1;
						endcase
					end
					else
						illegal_instr = 1'b1;
				riscv_OpcodeLoadFp:
					if (ariane_pkg_FP_PRESENT && (fs_i != 2'b00)) begin
						instruction_o[294-:4] = 4'd1;
						imm_select = 4'd1;
						instruction_o[283-:6] = instr[19-:5];
						instruction_o[271-:6] = instr[11-:5];
						(* full_case, parallel_case *)
						case (instr[14-:3])
							3'b000:
								if (ariane_pkg_XF8)
									instruction_o[290-:7] = 7'd83;
								else
									illegal_instr = 1'b1;
							3'b001:
								if (ariane_pkg_XF16 | ariane_pkg_XF16ALT)
									instruction_o[290-:7] = 7'd82;
								else
									illegal_instr = 1'b1;
							3'b010:
								if (ariane_pkg_RVF)
									instruction_o[290-:7] = 7'd81;
								else
									illegal_instr = 1'b1;
							3'b011:
								if (ariane_pkg_RVD)
									instruction_o[290-:7] = 7'd80;
								else
									illegal_instr = 1'b1;
							default: illegal_instr = 1'b1;
						endcase
					end
					else
						illegal_instr = 1'b1;
				riscv_OpcodeMadd, riscv_OpcodeMsub, riscv_OpcodeNmsub, riscv_OpcodeNmadd:
					if (ariane_pkg_FP_PRESENT && (fs_i != 2'b00)) begin
						instruction_o[294-:4] = 4'd7;
						instruction_o[283-:6] = instr[19-:5];
						instruction_o[277-:6] = instr[24-:5];
						instruction_o[271-:6] = instr[11-:5];
						imm_select = 4'd6;
						check_fprm = 1'b1;
						(* full_case, parallel_case *)
						case (instr[6-:7])
							default: instruction_o[290-:7] = 7'd94;
							riscv_OpcodeMsub: instruction_o[290-:7] = 7'd95;
							riscv_OpcodeNmsub: instruction_o[290-:7] = 7'd96;
							riscv_OpcodeNmadd: instruction_o[290-:7] = 7'd97;
						endcase
						(* full_case, parallel_case *)
						case (instr[26-:2])
							2'b00:
								if (~ariane_pkg_RVF)
									illegal_instr = 1'b1;
							2'b01:
								if (~ariane_pkg_RVD)
									illegal_instr = 1'b1;
							2'b10:
								if (~ariane_pkg_XF16 & ~ariane_pkg_XF16ALT)
									illegal_instr = 1'b1;
							2'b11:
								if (~ariane_pkg_XF8)
									illegal_instr = 1'b1;
							default: illegal_instr = 1'b1;
						endcase
						if (check_fprm) begin
							(* full_case, parallel_case *)
							if ((3'b000 <= instr[14-:3]) && (3'b100 >= instr[14-:3]))
								;
							else if (instr[14-:3] == 3'b101) begin
								if (~ariane_pkg_XF16ALT || (instr[26-:2] != 2'b10))
									illegal_instr = 1'b1;
								(* full_case, parallel_case *)
								if ((3'b000 <= frm_i) && (3'b100 >= frm_i))
									;
								else
									illegal_instr = 1'b1;
							end
							else if (instr[14-:3] == 3'b111) begin
								(* full_case, parallel_case *)
								if ((3'b000 <= frm_i) && (3'b100 >= frm_i))
									;
								else
									illegal_instr = 1'b1;
							end
							else
								illegal_instr = 1'b1;
						end
					end
					else
						illegal_instr = 1'b1;
				riscv_OpcodeOpFp:
					if (ariane_pkg_FP_PRESENT && (fs_i != 2'b00)) begin
						instruction_o[294-:4] = 4'd7;
						instruction_o[283-:6] = instr[19-:5];
						instruction_o[277-:6] = instr[24-:5];
						instruction_o[271-:6] = instr[11-:5];
						check_fprm = 1'b1;
						(* full_case, parallel_case *)
						case (instr[31-:5])
							5'b00000: begin
								instruction_o[290-:7] = 7'd88;
								instruction_o[283-:6] = 1'sb0;
								instruction_o[277-:6] = instr[19-:5];
								imm_select = 4'd1;
							end
							5'b00001: begin
								instruction_o[290-:7] = 7'd89;
								instruction_o[283-:6] = 1'sb0;
								instruction_o[277-:6] = instr[19-:5];
								imm_select = 4'd1;
							end
							5'b00010: instruction_o[290-:7] = 7'd90;
							5'b00011: instruction_o[290-:7] = 7'd91;
							5'b01011: begin
								instruction_o[290-:7] = 7'd93;
								if (instr[24-:5] != 5'b00000)
									illegal_instr = 1'b1;
							end
							5'b00100: begin
								instruction_o[290-:7] = 7'd101;
								check_fprm = 1'b0;
								if (ariane_pkg_XF16ALT) begin
									if (!(|{(3'b000 <= instr[14-:3]) && (3'b010 >= instr[14-:3]), (3'b100 <= instr[14-:3]) && (3'b110 >= instr[14-:3])}))
										illegal_instr = 1'b1;
								end
								else if (!((3'b000 <= instr[14-:3]) && (3'b010 >= instr[14-:3])))
									illegal_instr = 1'b1;
							end
							5'b00101: begin
								instruction_o[290-:7] = 7'd92;
								check_fprm = 1'b0;
								if (ariane_pkg_XF16ALT) begin
									if (!(|{(3'b000 <= instr[14-:3]) && (3'b001 >= instr[14-:3]), (3'b100 <= instr[14-:3]) && (3'b101 >= instr[14-:3])}))
										illegal_instr = 1'b1;
								end
								else if (!((3'b000 <= instr[14-:3]) && (3'b001 >= instr[14-:3])))
									illegal_instr = 1'b1;
							end
							5'b01000: begin
								instruction_o[290-:7] = 7'd100;
								instruction_o[277-:6] = instr[19-:5];
								imm_select = 4'd1;
								if (instr[24:23])
									illegal_instr = 1'b1;
								(* full_case, parallel_case *)
								case (instr[22:20])
									3'b000:
										if (~ariane_pkg_RVF)
											illegal_instr = 1'b1;
									3'b001:
										if (~ariane_pkg_RVD)
											illegal_instr = 1'b1;
									3'b010:
										if (~ariane_pkg_XF16)
											illegal_instr = 1'b1;
									3'b110:
										if (~ariane_pkg_XF16ALT)
											illegal_instr = 1'b1;
									3'b011:
										if (~ariane_pkg_XF8)
											illegal_instr = 1'b1;
									default: illegal_instr = 1'b1;
								endcase
							end
							5'b10100: begin
								instruction_o[290-:7] = 7'd104;
								check_fprm = 1'b0;
								if (ariane_pkg_XF16ALT) begin
									if (!(|{(3'b000 <= instr[14-:3]) && (3'b010 >= instr[14-:3]), (3'b100 <= instr[14-:3]) && (3'b110 >= instr[14-:3])}))
										illegal_instr = 1'b1;
								end
								else if (!((3'b000 <= instr[14-:3]) && (3'b010 >= instr[14-:3])))
									illegal_instr = 1'b1;
							end
							5'b11000: begin
								instruction_o[290-:7] = 7'd98;
								imm_select = 4'd1;
								if (instr[24:22])
									illegal_instr = 1'b1;
							end
							5'b11010: begin
								instruction_o[290-:7] = 7'd99;
								imm_select = 4'd1;
								if (instr[24:22])
									illegal_instr = 1'b1;
							end
							5'b11100: begin
								instruction_o[277-:6] = instr[19-:5];
								check_fprm = 1'b0;
								if ((instr[14-:3] == 3'b000) || 1'd0)
									instruction_o[290-:7] = 7'd102;
								else if ((instr[14-:3] == 3'b001) || 1'd0)
									instruction_o[290-:7] = 7'd105;
								else
									illegal_instr = 1'b1;
								if (instr[24-:5] != 5'b00000)
									illegal_instr = 1'b1;
							end
							5'b11110: begin
								instruction_o[290-:7] = 7'd103;
								instruction_o[277-:6] = instr[19-:5];
								check_fprm = 1'b0;
								if (!((instr[14-:3] == 3'b000) || 1'd0))
									illegal_instr = 1'b1;
								if (instr[24-:5] != 5'b00000)
									illegal_instr = 1'b1;
							end
							default: illegal_instr = 1'b1;
						endcase
						(* full_case, parallel_case *)
						case (instr[26-:2])
							2'b00:
								if (~ariane_pkg_RVF)
									illegal_instr = 1'b1;
							2'b01:
								if (~ariane_pkg_RVD)
									illegal_instr = 1'b1;
							2'b10:
								if (~ariane_pkg_XF16 & ~ariane_pkg_XF16ALT)
									illegal_instr = 1'b1;
							2'b11:
								if (~ariane_pkg_XF8)
									illegal_instr = 1'b1;
							default: illegal_instr = 1'b1;
						endcase
						if (check_fprm) begin
							(* full_case, parallel_case *)
							if ((3'b000 <= instr[14-:3]) && (3'b100 >= instr[14-:3]))
								;
							else if (instr[14-:3] == 3'b101) begin
								if (~ariane_pkg_XF16ALT || (instr[26-:2] != 2'b10))
									illegal_instr = 1'b1;
								(* full_case, parallel_case *)
								if ((3'b000 <= frm_i) && (3'b100 >= frm_i))
									;
								else
									illegal_instr = 1'b1;
							end
							else if (instr[14-:3] == 3'b111) begin
								(* full_case, parallel_case *)
								if ((3'b000 <= frm_i) && (3'b100 >= frm_i))
									;
								else
									illegal_instr = 1'b1;
							end
							else
								illegal_instr = 1'b1;
						end
					end
					else
						illegal_instr = 1'b1;
				riscv_OpcodeAmo: begin
					instruction_o[294-:4] = 4'd2;
					instruction_o[282:278] = instr[19-:5];
					instruction_o[276:272] = instr[24-:5];
					instruction_o[270:266] = instr[11-:5];
					if (ariane_pkg_RVA && (instr[14-:3] == 3'h2))
						(* full_case, parallel_case *)
						case (instr[31:27])
							5'h00: instruction_o[290-:7] = 7'd50;
							5'h01: instruction_o[290-:7] = 7'd49;
							5'h02: begin
								instruction_o[290-:7] = 7'd45;
								if (instr[24-:5] != 0)
									illegal_instr = 1'b1;
							end
							5'h03: instruction_o[290-:7] = 7'd47;
							5'h04: instruction_o[290-:7] = 7'd53;
							5'h08: instruction_o[290-:7] = 7'd52;
							5'h0c: instruction_o[290-:7] = 7'd51;
							5'h10: instruction_o[290-:7] = 7'd56;
							5'h14: instruction_o[290-:7] = 7'd54;
							5'h18: instruction_o[290-:7] = 7'd57;
							5'h1c: instruction_o[290-:7] = 7'd55;
							default: illegal_instr = 1'b1;
						endcase
					else if (ariane_pkg_RVA && (instr[14-:3] == 3'h3))
						(* full_case, parallel_case *)
						case (instr[31:27])
							5'h00: instruction_o[290-:7] = 7'd59;
							5'h01: instruction_o[290-:7] = 7'd58;
							5'h02: begin
								instruction_o[290-:7] = 7'd46;
								if (instr[24-:5] != 0)
									illegal_instr = 1'b1;
							end
							5'h03: instruction_o[290-:7] = 7'd48;
							5'h04: instruction_o[290-:7] = 7'd62;
							5'h08: instruction_o[290-:7] = 7'd61;
							5'h0c: instruction_o[290-:7] = 7'd60;
							5'h10: instruction_o[290-:7] = 7'd65;
							5'h14: instruction_o[290-:7] = 7'd63;
							5'h18: instruction_o[290-:7] = 7'd66;
							5'h1c: instruction_o[290-:7] = 7'd64;
							default: illegal_instr = 1'b1;
						endcase
					else
						illegal_instr = 1'b1;
				end
				riscv_OpcodeBranch: begin
					imm_select = 4'd3;
					instruction_o[294-:4] = 4'd4;
					instruction_o[282:278] = instr[19-:5];
					instruction_o[276:272] = instr[24-:5];
					is_control_flow_instr_o = 1'b1;
					case (instr[14-:3])
						3'b000: instruction_o[290-:7] = 7'd17;
						3'b001: instruction_o[290-:7] = 7'd18;
						3'b100: instruction_o[290-:7] = 7'd13;
						3'b101: instruction_o[290-:7] = 7'd15;
						3'b110: instruction_o[290-:7] = 7'd14;
						3'b111: instruction_o[290-:7] = 7'd16;
						default: begin
							is_control_flow_instr_o = 1'b0;
							illegal_instr = 1'b1;
						end
					endcase
				end
				riscv_OpcodeJalr: begin
					instruction_o[294-:4] = 4'd4;
					instruction_o[290-:7] = 7'd19;
					instruction_o[282:278] = instr[19-:5];
					imm_select = 4'd1;
					instruction_o[270:266] = instr[11-:5];
					is_control_flow_instr_o = 1'b1;
					if (instr[14-:3] != 3'b000)
						illegal_instr = 1'b1;
				end
				riscv_OpcodeJal: begin
					instruction_o[294-:4] = 4'd4;
					imm_select = 4'd5;
					instruction_o[270:266] = instr[11-:5];
					is_control_flow_instr_o = 1'b1;
				end
				riscv_OpcodeAuipc: begin
					instruction_o[294-:4] = 4'd3;
					imm_select = 4'd4;
					instruction_o[198] = 1'b1;
					instruction_o[270:266] = instr[11-:5];
				end
				riscv_OpcodeLui: begin
					imm_select = 4'd4;
					instruction_o[294-:4] = 4'd3;
					instruction_o[270:266] = instr[11-:5];
				end
				default: illegal_instr = 1'b1;
			endcase
	end
	function automatic [63:0] ariane_pkg_i_imm;
		input reg [31:0] instruction_i;
		ariane_pkg_i_imm = {{52 {instruction_i[31]}}, instruction_i[31:20]};
	endfunction
	function automatic [63:0] ariane_pkg_sb_imm;
		input reg [31:0] instruction_i;
		ariane_pkg_sb_imm = {{51 {instruction_i[31]}}, instruction_i[31], instruction_i[7], instruction_i[30:25], instruction_i[11:8], 1'b0};
	endfunction
	function automatic [63:0] ariane_pkg_uj_imm;
		input reg [31:0] instruction_i;
		ariane_pkg_uj_imm = {{44 {instruction_i[31]}}, instruction_i[19:12], instruction_i[20], instruction_i[30:21], 1'b0};
	endfunction
	always @(*) begin : sign_extend
		if (_sv2v_0)
			;
		imm_i_type = ariane_pkg_i_imm(instruction_i);
		imm_s_type = {{52 {instruction_i[31]}}, instruction_i[31:25], instruction_i[11:7]};
		imm_sb_type = ariane_pkg_sb_imm(instruction_i);
		imm_u_type = {{32 {instruction_i[31]}}, instruction_i[31:12], 12'b000000000000};
		imm_uj_type = ariane_pkg_uj_imm(instruction_i);
		imm_bi_type = {{59 {instruction_i[24]}}, instruction_i[24:20]};
		case (imm_select)
			4'd1: begin
				instruction_o[265-:64] = imm_i_type;
				instruction_o[200] = 1'b1;
			end
			4'd2: begin
				instruction_o[265-:64] = imm_s_type;
				instruction_o[200] = 1'b1;
			end
			4'd3: begin
				instruction_o[265-:64] = imm_sb_type;
				instruction_o[200] = 1'b1;
			end
			4'd4: begin
				instruction_o[265-:64] = imm_u_type;
				instruction_o[200] = 1'b1;
			end
			4'd5: begin
				instruction_o[265-:64] = imm_uj_type;
				instruction_o[200] = 1'b1;
			end
			4'd6: begin
				instruction_o[265-:64] = {59'b00000000000000000000000000000000000000000000000000000000000, instr[31-:5]};
				instruction_o[200] = 1'b0;
			end
			default: begin
				instruction_o[265-:64] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
				instruction_o[200] = 1'b0;
			end
		endcase
	end
	localparam [63:0] riscv_BREAKPOINT = 3;
	localparam [63:0] riscv_ENV_CALL_MMODE = 11;
	localparam [63:0] riscv_ENV_CALL_SMODE = 9;
	localparam [63:0] riscv_ENV_CALL_UMODE = 8;
	localparam [63:0] riscv_ILLEGAL_INSTR = 2;
	always @(*) begin : exception_handling
		if (_sv2v_0)
			;
		instruction_o[197-:129] = ex_i;
		instruction_o[201] = ex_i[0];
		if (~ex_i[0]) begin
			instruction_o[133-:64] = (is_compressed_i ? {48'b000000000000000000000000000000000000000000000000, compressed_instr_i} : {32'b00000000000000000000000000000000, instruction_i});
			if (illegal_instr || is_illegal_i) begin
				instruction_o[201] = 1'b1;
				instruction_o[69] = 1'b1;
				instruction_o[197-:64] = riscv_ILLEGAL_INSTR;
			end
			else if (ecall) begin
				instruction_o[201] = 1'b1;
				instruction_o[69] = 1'b1;
				case (priv_lvl_i)
					2'b11: instruction_o[197-:64] = riscv_ENV_CALL_MMODE;
					2'b01: instruction_o[197-:64] = riscv_ENV_CALL_SMODE;
					2'b00: instruction_o[197-:64] = riscv_ENV_CALL_UMODE;
					default:
						;
				endcase
			end
			else if (ebreak) begin
				instruction_o[201] = 1'b1;
				instruction_o[69] = 1'b1;
				instruction_o[197-:64] = riscv_BREAKPOINT;
			end
		end
	end
	initial _sv2v_0 = 0;
endmodule
module ex_stage (
	clk_i,
	rst_ni,
	flush_i,
	fu_data_i,
	pc_i,
	is_compressed_instr_i,
	flu_result_o,
	flu_trans_id_o,
	flu_exception_o,
	flu_ready_o,
	flu_valid_o,
	alu_valid_i,
	branch_valid_i,
	branch_predict_i,
	resolved_branch_o,
	resolve_branch_o,
	csr_valid_i,
	csr_addr_o,
	csr_commit_i,
	mult_valid_i,
	lsu_ready_o,
	lsu_valid_i,
	load_valid_o,
	load_result_o,
	load_trans_id_o,
	load_exception_o,
	store_valid_o,
	store_result_o,
	store_trans_id_o,
	store_exception_o,
	lsu_commit_i,
	lsu_commit_ready_o,
	no_st_pending_o,
	amo_valid_commit_i,
	fpu_ready_o,
	fpu_valid_i,
	fpu_fmt_i,
	fpu_rm_i,
	fpu_frm_i,
	fpu_prec_i,
	fpu_trans_id_o,
	fpu_result_o,
	fpu_valid_o,
	fpu_exception_o,
	enable_translation_i,
	en_ld_st_translation_i,
	flush_tlb_i,
	priv_lvl_i,
	ld_st_priv_lvl_i,
	sum_i,
	mxr_i,
	satp_ppn_i,
	asid_i,
	icache_areq_i,
	icache_areq_o,
	dcache_req_ports_i,
	dcache_req_ports_o,
	amo_req_o,
	amo_resp_i,
	itlb_miss_o,
	dtlb_miss_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [205:0] fu_data_i;
	input wire [63:0] pc_i;
	input wire is_compressed_instr_i;
	output reg [63:0] flu_result_o;
	output reg [2:0] flu_trans_id_o;
	output wire [128:0] flu_exception_o;
	output reg flu_ready_o;
	output wire flu_valid_o;
	input wire alu_valid_i;
	input wire branch_valid_i;
	input wire [67:0] branch_predict_i;
	output wire [133:0] resolved_branch_o;
	output wire resolve_branch_o;
	input wire csr_valid_i;
	output wire [11:0] csr_addr_o;
	input wire csr_commit_i;
	input wire mult_valid_i;
	output wire lsu_ready_o;
	input wire lsu_valid_i;
	output wire load_valid_o;
	output wire [63:0] load_result_o;
	output wire [2:0] load_trans_id_o;
	output wire [128:0] load_exception_o;
	output wire store_valid_o;
	output wire [63:0] store_result_o;
	output wire [2:0] store_trans_id_o;
	output wire [128:0] store_exception_o;
	input wire lsu_commit_i;
	output wire lsu_commit_ready_o;
	output wire no_st_pending_o;
	input wire amo_valid_commit_i;
	output wire fpu_ready_o;
	input wire fpu_valid_i;
	input wire [1:0] fpu_fmt_i;
	input wire [2:0] fpu_rm_i;
	input wire [2:0] fpu_frm_i;
	input wire [6:0] fpu_prec_i;
	output wire [2:0] fpu_trans_id_o;
	output wire [63:0] fpu_result_o;
	output wire fpu_valid_o;
	output wire [128:0] fpu_exception_o;
	input wire enable_translation_i;
	input wire en_ld_st_translation_i;
	input wire flush_tlb_i;
	input wire [1:0] priv_lvl_i;
	input wire [1:0] ld_st_priv_lvl_i;
	input wire sum_i;
	input wire mxr_i;
	input wire [43:0] satp_ppn_i;
	localparam ariane_pkg_ASID_WIDTH = 1;
	input wire [0:0] asid_i;
	input wire [64:0] icache_areq_i;
	output wire [193:0] icache_areq_o;
	input wire [197:0] dcache_req_ports_i;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	output wire [(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (3 * ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78)) - 1 : (3 * (1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77))) + ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 76)):(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? 0 : (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77)] dcache_req_ports_o;
	output wire [134:0] amo_req_o;
	input wire [64:0] amo_resp_i;
	output wire itlb_miss_o;
	output wire dtlb_miss_o;
	wire alu_branch_res;
	wire [63:0] alu_result;
	wire [63:0] branch_result;
	wire [63:0] csr_result;
	wire [63:0] mult_result;
	wire csr_ready;
	wire mult_ready;
	wire [2:0] mult_trans_id;
	wire mult_valid;
	wire [205:0] alu_data;
	assign alu_data = (alu_valid_i | branch_valid_i ? fu_data_i : {206 {1'sb0}});
	alu alu_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.fu_data_i(alu_data),
		.result_o(alu_result),
		.alu_branch_res_o(alu_branch_res)
	);
	branch_unit branch_unit_i(
		.fu_data_i(fu_data_i),
		.pc_i(pc_i),
		.is_compressed_instr_i(is_compressed_instr_i),
		.fu_valid_i((((alu_valid_i || lsu_valid_i) || csr_valid_i) || mult_valid_i) || fpu_valid_i),
		.branch_valid_i(branch_valid_i),
		.branch_comp_res_i(alu_branch_res),
		.branch_result_o(branch_result),
		.branch_predict_i(branch_predict_i),
		.resolved_branch_o(resolved_branch_o),
		.resolve_branch_o(resolve_branch_o),
		.branch_exception_o(flu_exception_o)
	);
	csr_buffer csr_buffer_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.fu_data_i(fu_data_i),
		.csr_valid_i(csr_valid_i),
		.csr_ready_o(csr_ready),
		.csr_result_o(csr_result),
		.csr_commit_i(csr_commit_i),
		.csr_addr_o(csr_addr_o)
	);
	assign flu_valid_o = ((alu_valid_i | branch_valid_i) | csr_valid_i) | mult_valid;
	always @(*) begin
		if (_sv2v_0)
			;
		flu_result_o = branch_result;
		flu_trans_id_o = fu_data_i[2-:ariane_pkg_TRANS_ID_BITS];
		if (alu_valid_i)
			flu_result_o = alu_result;
		else if (csr_valid_i)
			flu_result_o = csr_result;
		else if (mult_valid) begin
			flu_result_o = mult_result;
			flu_trans_id_o = mult_trans_id;
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		flu_ready_o = csr_ready & mult_ready;
	end
	wire [205:0] mult_data;
	assign mult_data = (mult_valid_i ? fu_data_i : {206 {1'sb0}});
	mult i_mult(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.mult_valid_i(mult_valid_i),
		.fu_data_i(mult_data),
		.result_o(mult_result),
		.mult_valid_o(mult_valid),
		.mult_ready_o(mult_ready),
		.mult_trans_id_o(mult_trans_id)
	);
	localparam [0:0] ariane_pkg_RVD = 1'b0;
	localparam [0:0] ariane_pkg_RVF = 1'b0;
	localparam [0:0] ariane_pkg_XF16 = 1'b0;
	localparam [0:0] ariane_pkg_XF16ALT = 1'b0;
	localparam [0:0] ariane_pkg_XF8 = 1'b0;
	localparam [0:0] ariane_pkg_FP_PRESENT = (((ariane_pkg_RVF | ariane_pkg_RVD) | ariane_pkg_XF16) | ariane_pkg_XF16ALT) | ariane_pkg_XF8;
	generate
		if (ariane_pkg_FP_PRESENT) begin : fpu_gen
			wire [205:0] fpu_data;
			assign fpu_data = (fpu_valid_i ? fu_data_i : {206 {1'sb0}});
			fpu_wrap fpu_i(
				.clk_i(clk_i),
				.rst_ni(rst_ni),
				.flush_i(flush_i),
				.fpu_valid_i(fpu_valid_i),
				.fpu_ready_o(fpu_ready_o),
				.fu_data_i(fpu_data),
				.fpu_fmt_i(fpu_fmt_i),
				.fpu_rm_i(fpu_rm_i),
				.fpu_frm_i(fpu_frm_i),
				.fpu_prec_i(fpu_prec_i),
				.fpu_trans_id_o(fpu_trans_id_o),
				.result_o(fpu_result_o),
				.fpu_valid_o(fpu_valid_o),
				.fpu_exception_o(fpu_exception_o)
			);
		end
		else begin : no_fpu_gen
			assign fpu_ready_o = 1'sb0;
			assign fpu_trans_id_o = 1'sb0;
			assign fpu_result_o = 1'sb0;
			assign fpu_valid_o = 1'sb0;
			assign fpu_exception_o = 1'sb0;
		end
	endgenerate
	wire [205:0] lsu_data;
	assign lsu_data = (lsu_valid_i ? fu_data_i : {206 {1'sb0}});
	load_store_unit lsu_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.no_st_pending_o(no_st_pending_o),
		.fu_data_i(lsu_data),
		.lsu_ready_o(lsu_ready_o),
		.lsu_valid_i(lsu_valid_i),
		.load_trans_id_o(load_trans_id_o),
		.load_result_o(load_result_o),
		.load_valid_o(load_valid_o),
		.load_exception_o(load_exception_o),
		.store_trans_id_o(store_trans_id_o),
		.store_result_o(store_result_o),
		.store_valid_o(store_valid_o),
		.store_exception_o(store_exception_o),
		.commit_i(lsu_commit_i),
		.commit_ready_o(lsu_commit_ready_o),
		.enable_translation_i(enable_translation_i),
		.en_ld_st_translation_i(en_ld_st_translation_i),
		.icache_areq_i(icache_areq_i),
		.icache_areq_o(icache_areq_o),
		.priv_lvl_i(priv_lvl_i),
		.ld_st_priv_lvl_i(ld_st_priv_lvl_i),
		.sum_i(sum_i),
		.mxr_i(mxr_i),
		.satp_ppn_i(satp_ppn_i),
		.asid_i(asid_i),
		.flush_tlb_i(flush_tlb_i),
		.itlb_miss_o(itlb_miss_o),
		.dtlb_miss_o(dtlb_miss_o),
		.dcache_req_ports_i(dcache_req_ports_i),
		.dcache_req_ports_o(dcache_req_ports_o),
		.amo_valid_commit_i(amo_valid_commit_i),
		.amo_req_o(amo_req_o),
		.amo_resp_i(amo_resp_i)
	);
	initial _sv2v_0 = 0;
endmodule
module btb (
	clk_i,
	rst_ni,
	flush_i,
	debug_mode_i,
	vpc_i,
	btb_update_i,
	btb_prediction_o
);
	reg _sv2v_0;
	parameter signed [31:0] NR_ENTRIES = 8;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire debug_mode_i;
	input wire [63:0] vpc_i;
	input wire [129:0] btb_update_i;
	output wire [64:0] btb_prediction_o;
	localparam OFFSET = 1;
	localparam ANTIALIAS_BITS = 8;
	localparam PREDICTION_BITS = $clog2(NR_ENTRIES) + OFFSET;
	reg [(NR_ENTRIES * 65) - 1:0] btb_d;
	reg [(NR_ENTRIES * 65) - 1:0] btb_q;
	wire [$clog2(NR_ENTRIES) - 1:0] index;
	wire [$clog2(NR_ENTRIES) - 1:0] update_pc;
	assign index = vpc_i[PREDICTION_BITS - 1:OFFSET];
	assign update_pc = btb_update_i[PREDICTION_BITS + 64:66];
	assign btb_prediction_o = btb_q[index * 65+:65];
	always @(*) begin : update_branch_predict
		if (_sv2v_0)
			;
		btb_d = btb_q;
		if (btb_update_i[129] && !debug_mode_i) begin
			btb_d[(update_pc * 65) + 64] = 1'b1;
			btb_d[(update_pc * 65) + 63-:64] = btb_update_i[64-:64];
			if (btb_update_i[0])
				btb_d[(update_pc * 65) + 64] = 1'b0;
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NR_ENTRIES; i = i + 1)
				btb_q[i * 65+:65] <= 65'h00000000000000000;
		end
		else if (flush_i) begin : sv2v_autoblock_2
			reg signed [31:0] i;
			for (i = 0; i < NR_ENTRIES; i = i + 1)
				btb_q[(i * 65) + 64] <= 1'b0;
		end
		else
			btb_q <= btb_d;
	initial _sv2v_0 = 0;
endmodule
module bht (
	clk_i,
	rst_ni,
	flush_i,
	debug_mode_i,
	vpc_i,
	bht_update_i,
	bht_prediction_o
);
	reg _sv2v_0;
	parameter [31:0] NR_ENTRIES = 1024;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire debug_mode_i;
	input wire [63:0] vpc_i;
	input wire [66:0] bht_update_i;
	output wire [2:0] bht_prediction_o;
	localparam OFFSET = 2;
	localparam ANTIALIAS_BITS = 8;
	localparam PREDICTION_BITS = $clog2(NR_ENTRIES) + OFFSET;
	reg [(NR_ENTRIES * 3) - 1:0] bht_d;
	reg [(NR_ENTRIES * 3) - 1:0] bht_q;
	wire [$clog2(NR_ENTRIES) - 1:0] index;
	wire [$clog2(NR_ENTRIES) - 1:0] update_pc;
	reg [1:0] saturation_counter;
	assign index = vpc_i[PREDICTION_BITS - 1:OFFSET];
	assign update_pc = bht_update_i[PREDICTION_BITS + 1:4];
	assign bht_prediction_o[2] = bht_q[(index * 3) + 2];
	assign bht_prediction_o[1] = bht_q[(index * 3) + 1-:2] == 2'b10;
	assign bht_prediction_o[0] = bht_q[(index * 3) + 1-:2] == 2'b11;
	always @(*) begin : update_bht
		if (_sv2v_0)
			;
		bht_d = bht_q;
		saturation_counter = bht_q[(update_pc * 3) + 1-:2];
		if (bht_update_i[66] && !debug_mode_i) begin
			bht_d[(update_pc * 3) + 2] = 1'b1;
			if (saturation_counter == 2'b11) begin
				if (~bht_update_i[0])
					bht_d[(update_pc * 3) + 1-:2] = saturation_counter - 1;
			end
			else if (saturation_counter == 2'b00) begin
				if (bht_update_i[0])
					bht_d[(update_pc * 3) + 1-:2] = saturation_counter + 1;
			end
			else if (bht_update_i[0])
				bht_d[(update_pc * 3) + 1-:2] = saturation_counter + 1;
			else
				bht_d[(update_pc * 3) + 1-:2] = saturation_counter - 1;
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin : sv2v_autoblock_1
			reg [31:0] i;
			for (i = 0; i < NR_ENTRIES; i = i + 1)
				bht_q[i * 3+:3] <= 1'sb0;
		end
		else if (flush_i) begin : sv2v_autoblock_2
			reg signed [31:0] i;
			for (i = 0; i < NR_ENTRIES; i = i + 1)
				begin
					bht_q[(i * 3) + 2] <= 1'b0;
					bht_q[(i * 3) + 1-:2] <= 2'b10;
				end
		end
		else
			bht_q <= bht_d;
	initial _sv2v_0 = 0;
endmodule
module ras (
	clk_i,
	rst_ni,
	push_i,
	pop_i,
	data_i,
	data_o
);
	reg _sv2v_0;
	parameter [31:0] DEPTH = 2;
	input wire clk_i;
	input wire rst_ni;
	input wire push_i;
	input wire pop_i;
	input wire [63:0] data_i;
	output wire [64:0] data_o;
	reg [(DEPTH * 65) - 1:0] stack_d;
	reg [(DEPTH * 65) - 1:0] stack_q;
	assign data_o = stack_q[0+:65];
	always @(*) begin
		if (_sv2v_0)
			;
		stack_d = stack_q;
		if (push_i) begin
			stack_d[63-:64] = data_i;
			stack_d[64] = 1'b1;
			stack_d[65 * (((DEPTH - 1) >= 1 ? DEPTH - 1 : ((DEPTH - 1) + ((DEPTH - 1) >= 1 ? DEPTH - 1 : 3 - DEPTH)) - 1) - (((DEPTH - 1) >= 1 ? DEPTH - 1 : 3 - DEPTH) - 1))+:65 * ((DEPTH - 1) >= 1 ? DEPTH - 1 : 3 - DEPTH)] = stack_q[65 * (((DEPTH - 2) >= 0 ? DEPTH - 2 : ((DEPTH - 2) + ((DEPTH - 2) >= 0 ? DEPTH - 1 : 3 - DEPTH)) - 1) - (((DEPTH - 2) >= 0 ? DEPTH - 1 : 3 - DEPTH) - 1))+:65 * ((DEPTH - 2) >= 0 ? DEPTH - 1 : 3 - DEPTH)];
		end
		if (pop_i) begin
			stack_d[65 * (((DEPTH - 2) >= 0 ? DEPTH - 2 : ((DEPTH - 2) + ((DEPTH - 2) >= 0 ? DEPTH - 1 : 3 - DEPTH)) - 1) - (((DEPTH - 2) >= 0 ? DEPTH - 1 : 3 - DEPTH) - 1))+:65 * ((DEPTH - 2) >= 0 ? DEPTH - 1 : 3 - DEPTH)] = stack_q[65 * (((DEPTH - 1) >= 1 ? DEPTH - 1 : ((DEPTH - 1) + ((DEPTH - 1) >= 1 ? DEPTH - 1 : 3 - DEPTH)) - 1) - (((DEPTH - 1) >= 1 ? DEPTH - 1 : 3 - DEPTH) - 1))+:65 * ((DEPTH - 1) >= 1 ? DEPTH - 1 : 3 - DEPTH)];
			stack_d[((DEPTH - 1) * 65) + 64] = 1'b0;
			stack_d[((DEPTH - 1) * 65) + 63-:64] = 'b0;
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni)
			stack_q <= 1'sb0;
		else
			stack_q <= stack_d;
	initial _sv2v_0 = 0;
endmodule
module instr_scan (
	instr_i,
	is_rvc_o,
	rvi_return_o,
	rvi_call_o,
	rvi_branch_o,
	rvi_jalr_o,
	rvi_jump_o,
	rvi_imm_o,
	rvc_branch_o,
	rvc_jump_o,
	rvc_jr_o,
	rvc_return_o,
	rvc_jalr_o,
	rvc_call_o,
	rvc_imm_o
);
	input wire [31:0] instr_i;
	output wire is_rvc_o;
	output wire rvi_return_o;
	output wire rvi_call_o;
	output wire rvi_branch_o;
	output wire rvi_jalr_o;
	output wire rvi_jump_o;
	output wire [63:0] rvi_imm_o;
	output wire rvc_branch_o;
	output wire rvc_jump_o;
	output wire rvc_jr_o;
	output wire rvc_return_o;
	output wire rvc_jalr_o;
	output wire rvc_call_o;
	output wire [63:0] rvc_imm_o;
	assign is_rvc_o = instr_i[1:0] != 2'b11;
	assign rvi_return_o = ((((rvi_jalr_o & ~instr_i[7]) & ~instr_i[19]) & ~instr_i[18]) & ~instr_i[16]) & instr_i[15];
	assign rvi_call_o = (rvi_jalr_o | rvi_jump_o) & instr_i[7];
	function automatic [63:0] ariane_pkg_sb_imm;
		input reg [31:0] instruction_i;
		ariane_pkg_sb_imm = {{51 {instruction_i[31]}}, instruction_i[31], instruction_i[7], instruction_i[30:25], instruction_i[11:8], 1'b0};
	endfunction
	function automatic [63:0] ariane_pkg_uj_imm;
		input reg [31:0] instruction_i;
		ariane_pkg_uj_imm = {{44 {instruction_i[31]}}, instruction_i[19:12], instruction_i[20], instruction_i[30:21], 1'b0};
	endfunction
	assign rvi_imm_o = (instr_i[3] ? ariane_pkg_uj_imm(instr_i) : ariane_pkg_sb_imm(instr_i));
	localparam riscv_OpcodeBranch = 7'b1100011;
	assign rvi_branch_o = (instr_i[6:0] == riscv_OpcodeBranch ? 1'b1 : 1'b0);
	localparam riscv_OpcodeJalr = 7'b1100111;
	assign rvi_jalr_o = (instr_i[6:0] == riscv_OpcodeJalr ? 1'b1 : 1'b0);
	localparam riscv_OpcodeJal = 7'b1101111;
	assign rvi_jump_o = (instr_i[6:0] == riscv_OpcodeJal ? 1'b1 : 1'b0);
	localparam riscv_OpcodeC1 = 2'b01;
	localparam riscv_OpcodeC1J = 3'b101;
	assign rvc_jump_o = ((instr_i[15:13] == riscv_OpcodeC1J) & is_rvc_o) & (instr_i[1:0] == riscv_OpcodeC1);
	localparam riscv_OpcodeC2 = 2'b10;
	localparam riscv_OpcodeC2JalrMvAdd = 3'b100;
	assign rvc_jr_o = ((((instr_i[15:13] == riscv_OpcodeC2JalrMvAdd) & ~instr_i[12]) & (instr_i[6:2] == 5'b00000)) & (instr_i[1:0] == riscv_OpcodeC2)) & is_rvc_o;
	localparam riscv_OpcodeC1Beqz = 3'b110;
	localparam riscv_OpcodeC1Bnez = 3'b111;
	assign rvc_branch_o = (((instr_i[15:13] == riscv_OpcodeC1Beqz) | (instr_i[15:13] == riscv_OpcodeC1Bnez)) & (instr_i[1:0] == riscv_OpcodeC1)) & is_rvc_o;
	assign rvc_return_o = (((~instr_i[11] & ~instr_i[10]) & ~instr_i[8]) & instr_i[7]) & rvc_jr_o;
	assign rvc_jalr_o = (((instr_i[15:13] == riscv_OpcodeC2JalrMvAdd) & instr_i[12]) & (instr_i[6:2] == 5'b00000)) & is_rvc_o;
	assign rvc_call_o = rvc_jalr_o;
	assign rvc_imm_o = (instr_i[14] ? {{56 {instr_i[12]}}, instr_i[6:5], instr_i[2], instr_i[11:10], instr_i[4:3], 1'b0} : {{53 {instr_i[12]}}, instr_i[8], instr_i[10:9], instr_i[6], instr_i[7], instr_i[2], instr_i[11], instr_i[5:3], 1'b0});
endmodule
module frontend (
	clk_i,
	rst_ni,
	flush_i,
	flush_bp_i,
	debug_mode_i,
	boot_addr_i,
	resolved_branch_i,
	set_pc_commit_i,
	pc_commit_i,
	epc_i,
	eret_i,
	trap_vector_base_i,
	ex_valid_i,
	set_debug_pc_i,
	icache_dreq_i,
	icache_dreq_o,
	fetch_entry_o,
	fetch_entry_valid_o,
	fetch_ack_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire flush_bp_i;
	input wire debug_mode_i;
	input wire [63:0] boot_addr_i;
	input wire [133:0] resolved_branch_i;
	input wire set_pc_commit_i;
	input wire [63:0] pc_commit_i;
	input wire [63:0] epc_i;
	input wire eret_i;
	input wire [63:0] trap_vector_base_i;
	input wire ex_valid_i;
	input wire set_debug_pc_i;
	localparam [31:0] ariane_pkg_FETCH_WIDTH = 32;
	input wire [226:0] icache_dreq_i;
	output reg [66:0] icache_dreq_o;
	localparam [31:0] ariane_pkg_INSTR_PER_FETCH = 2;
	output wire [166:0] fetch_entry_o;
	output wire fetch_entry_valid_o;
	input wire fetch_ack_i;
	reg [31:0] icache_data_q;
	reg icache_valid_q;
	reg icache_ex_valid_q;
	reg instruction_valid;
	wire [1:0] instr_is_compressed;
	reg [63:0] icache_vaddr_q;
	wire [2:0] bht_prediction;
	wire [64:0] btb_prediction;
	wire [64:0] ras_predict;
	wire [66:0] bht_update;
	wire [129:0] btb_update;
	reg ras_push;
	reg ras_pop;
	reg [63:0] ras_update;
	wire if_ready;
	reg [63:0] npc_d;
	reg [63:0] npc_q;
	reg npc_rst_load_q;
	wire [1:0] rvi_return;
	wire [1:0] rvi_call;
	wire [1:0] rvi_branch;
	wire [1:0] rvi_jalr;
	wire [1:0] rvi_jump;
	wire [127:0] rvi_imm;
	wire [1:0] is_rvc;
	wire [1:0] rvc_branch;
	wire [1:0] rvc_jump;
	wire [1:0] rvc_jr;
	wire [1:0] rvc_return;
	wire [1:0] rvc_jalr;
	wire [1:0] rvc_call;
	wire [127:0] rvc_imm;
	reg [63:0] instr;
	reg [127:0] addr;
	reg [63:0] bp_vaddr;
	reg bp_valid;
	wire is_mispredict;
	reg [67:0] bp_sbe;
	wire fifo_valid;
	wire fifo_ready;
	wire fifo_empty;
	wire fifo_pop;
	wire s2_eff_kill;
	wire issue_req;
	wire s2_in_flight_d;
	reg s2_in_flight_q;
	localparam [31:0] ariane_pkg_FETCH_FIFO_DEPTH = 8;
	wire [3:0] fifo_credits_d;
	reg [3:0] fifo_credits_q;
	reg [15:0] unaligned_instr_d;
	reg [15:0] unaligned_instr_q;
	reg unaligned_d;
	reg unaligned_q;
	reg [63:0] unaligned_address_d;
	reg [63:0] unaligned_address_q;
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < ariane_pkg_INSTR_PER_FETCH; _gv_i_1 = _gv_i_1 + 1) begin : genblk1
			localparam i = _gv_i_1;
			assign instr_is_compressed[i] = ~&icache_data_q[i * 16+:2];
		end
	endgenerate
	always @(*) begin : re_align
		if (_sv2v_0)
			;
		unaligned_d = unaligned_q;
		unaligned_address_d = unaligned_address_q;
		unaligned_instr_d = unaligned_instr_q;
		instruction_valid = icache_valid_q;
		instr[0+:32] = icache_data_q;
		addr[0+:64] = icache_vaddr_q;
		instr[32+:32] = 1'sb0;
		addr[64+:64] = {icache_vaddr_q[63:2], 2'b10};
		if (icache_valid_q) begin
			if (unaligned_q) begin
				instr[0+:32] = {icache_data_q[15:0], unaligned_instr_q};
				addr[0+:64] = unaligned_address_q;
				unaligned_address_d = {icache_vaddr_q[63:2], 2'b10};
				unaligned_instr_d = icache_data_q[31:16];
				if (instr_is_compressed[1]) begin
					unaligned_d = 1'b0;
					instr[32+:32] = {16'b0000000000000000, icache_data_q[31:16]};
				end
			end
			else if (instr_is_compressed[0]) begin
				if (instr_is_compressed[1])
					instr[32+:32] = {16'b0000000000000000, icache_data_q[31:16]};
				else begin
					unaligned_instr_d = icache_data_q[31:16];
					unaligned_address_d = {icache_vaddr_q[63:2], 2'b10};
					unaligned_d = 1'b1;
				end
			end
		end
		if ((icache_valid_q && icache_vaddr_q[1]) && !instr_is_compressed[1]) begin
			instruction_valid = 1'b0;
			unaligned_d = 1'b1;
			unaligned_address_d = {icache_vaddr_q[63:2], 2'b10};
			unaligned_instr_d = icache_data_q[31:16];
		end
		if (icache_dreq_o[64])
			unaligned_d = 1'b0;
	end
	reg [ariane_pkg_INSTR_PER_FETCH:0] taken;
	always @(*) begin : frontend_ctrl
		reg take_rvi_cf;
		reg take_rvc_cf;
		if (_sv2v_0)
			;
		take_rvi_cf = 1'b0;
		take_rvc_cf = 1'b0;
		ras_pop = 1'b0;
		ras_push = 1'b0;
		ras_update = 1'sb0;
		taken = 1'sb0;
		take_rvi_cf = 1'b0;
		bp_vaddr = 1'sb0;
		bp_valid = 1'b0;
		bp_sbe[1-:2] = 2'd2;
		if (instruction_valid) begin : sv2v_autoblock_1
			reg [31:0] i;
			for (i = 0; i < ariane_pkg_INSTR_PER_FETCH; i = i + 1)
				if (!taken[i]) begin
					ras_push = rvi_call[i] | rvc_call[i];
					ras_update = addr[i * 64+:64] + (rvc_call[i] ? 2 : 4);
					if (rvi_branch[i] || rvc_branch[i]) begin
						bp_sbe[1-:2] = 2'd0;
						if (bht_prediction[2]) begin
							take_rvi_cf = rvi_branch[i] & (bht_prediction[1] | bht_prediction[0]);
							take_rvc_cf = rvc_branch[i] & (bht_prediction[1] | bht_prediction[0]);
						end
						else begin
							take_rvi_cf = rvi_branch[i] & rvi_imm[(i * 64) + 63];
							take_rvc_cf = rvc_branch[i] & rvc_imm[(i * 64) + 63];
						end
					end
					if (rvi_jump[i] || rvc_jump[i]) begin
						take_rvi_cf = rvi_jump[i];
						take_rvc_cf = rvc_jump[i];
					end
					if ((rvi_jalr[i] || rvc_jalr[i]) && ~(rvi_call[i] || rvc_call[i])) begin
						bp_sbe[1-:2] = 2'd1;
						if (btb_prediction[64]) begin
							bp_vaddr = btb_prediction[63-:64];
							taken[i + 1] = 1'b1;
						end
					end
					if ((rvi_return[i] || rvc_return[i]) && ras_predict[64]) begin
						bp_vaddr = ras_predict[63-:64];
						ras_pop = 1'b1;
						taken[i + 1] = 1'b1;
						bp_sbe[1-:2] = 2'd2;
					end
					if (take_rvi_cf) begin
						taken[i + 1] = 1'b1;
						bp_vaddr = addr[i * 64+:64] + rvi_imm[i * 64+:64];
					end
					if (take_rvc_cf) begin
						taken[i + 1] = 1'b1;
						bp_vaddr = addr[i * 64+:64] + rvc_imm[i * 64+:64];
					end
					if (icache_vaddr_q[1]) begin
						taken[1] = 1'b0;
						ras_pop = 1'b0;
						ras_push = 1'b0;
					end
				end
		end
		bp_valid = |taken;
		bp_sbe[67] = bp_valid;
		bp_sbe[66-:64] = bp_vaddr;
		bp_sbe[2] = bp_valid;
	end
	assign is_mispredict = resolved_branch_i[3] & resolved_branch_i[5];
	wire [1:1] sv2v_tmp_992F1;
	assign sv2v_tmp_992F1 = is_mispredict | flush_i;
	always @(*) icache_dreq_o[65] = sv2v_tmp_992F1;
	wire [1:1] sv2v_tmp_95BA0;
	assign sv2v_tmp_95BA0 = icache_dreq_o[65] | bp_valid;
	always @(*) icache_dreq_o[64] = sv2v_tmp_95BA0;
	assign fifo_valid = icache_valid_q;
	assign bht_update[66] = resolved_branch_i[3] & (resolved_branch_i[1-:2] == 2'd0);
	assign bht_update[65-:64] = resolved_branch_i[133-:64];
	assign bht_update[1] = resolved_branch_i[5];
	assign bht_update[0] = resolved_branch_i[4];
	assign btb_update[129] = resolved_branch_i[3] & (resolved_branch_i[1-:2] == 2'd1);
	assign btb_update[128-:64] = resolved_branch_i[133-:64];
	assign btb_update[64-:64] = resolved_branch_i[69-:64];
	assign btb_update[0] = resolved_branch_i[2];
	localparam [63:0] dm_HaltAddress = 64'h0000000000000800;
	always @(*) begin : npc_select
		reg [63:0] fetch_address;
		if (_sv2v_0)
			;
		if (npc_rst_load_q) begin
			npc_d = boot_addr_i;
			fetch_address = boot_addr_i;
		end
		else begin
			fetch_address = npc_q;
			npc_d = npc_q;
		end
		if (bp_valid) begin
			fetch_address = bp_vaddr;
			npc_d = bp_vaddr;
		end
		if (if_ready)
			npc_d = {fetch_address[63:2], 2'b00} + 'h4;
		if (is_mispredict)
			npc_d = resolved_branch_i[69-:64];
		if (eret_i)
			npc_d = epc_i;
		if (ex_valid_i)
			npc_d = trap_vector_base_i;
		if (set_pc_commit_i)
			npc_d = pc_commit_i + 64'h0000000000000004;
		if (set_debug_pc_i)
			npc_d = dm_HaltAddress;
		icache_dreq_o[63-:64] = fetch_address;
	end
	assign fifo_credits_d = (flush_i ? ariane_pkg_FETCH_FIFO_DEPTH : ((fifo_credits_q + fifo_pop) + s2_eff_kill) - issue_req);
	assign s2_eff_kill = s2_in_flight_q & icache_dreq_o[64];
	assign s2_in_flight_d = (flush_i ? 1'b0 : (issue_req ? 1'b1 : (icache_dreq_i[225] ? 1'b0 : s2_in_flight_q)));
	assign issue_req = if_ready & ~icache_dreq_o[65];
	assign fifo_pop = fetch_ack_i & fetch_entry_valid_o;
	assign fifo_ready = |fifo_credits_q;
	assign if_ready = icache_dreq_i[226] & fifo_ready;
	wire [1:1] sv2v_tmp_D2632;
	assign sv2v_tmp_D2632 = fifo_ready;
	always @(*) icache_dreq_o[66] = sv2v_tmp_D2632;
	assign fetch_entry_valid_o = ~fifo_empty;
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			npc_q <= 1'sb0;
			npc_rst_load_q <= 1'b1;
			icache_data_q <= 1'sb0;
			icache_valid_q <= 1'b0;
			icache_vaddr_q <= 'b0;
			icache_ex_valid_q <= 1'b0;
			unaligned_q <= 1'b0;
			unaligned_address_q <= 1'sb0;
			unaligned_instr_q <= 1'sb0;
			fifo_credits_q <= ariane_pkg_FETCH_FIFO_DEPTH;
			s2_in_flight_q <= 1'b0;
		end
		else begin
			npc_rst_load_q <= 1'b0;
			npc_q <= npc_d;
			icache_data_q <= icache_dreq_i[224-:32];
			icache_valid_q <= icache_dreq_i[225];
			icache_vaddr_q <= icache_dreq_i[192-:64];
			icache_ex_valid_q <= icache_dreq_i[0];
			unaligned_q <= unaligned_d;
			unaligned_address_q <= unaligned_address_d;
			unaligned_instr_q <= unaligned_instr_d;
			fifo_credits_q <= fifo_credits_d;
			s2_in_flight_q <= s2_in_flight_d;
		end
	localparam ariane_pkg_RAS_DEPTH = 2;
	ras #(.DEPTH(ariane_pkg_RAS_DEPTH)) i_ras(
		.push_i(ras_push),
		.pop_i(ras_pop),
		.data_i(ras_update),
		.data_o(ras_predict),
		.clk_i(clk_i),
		.rst_ni(rst_ni)
	);
	localparam ariane_pkg_BTB_ENTRIES = 64;
	btb #(.NR_ENTRIES(ariane_pkg_BTB_ENTRIES)) i_btb(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_bp_i),
		.debug_mode_i(debug_mode_i),
		.vpc_i(icache_vaddr_q),
		.btb_update_i(btb_update),
		.btb_prediction_o(btb_prediction)
	);
	localparam ariane_pkg_BHT_ENTRIES = 128;
	bht #(.NR_ENTRIES(ariane_pkg_BHT_ENTRIES)) i_bht(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_bp_i),
		.debug_mode_i(debug_mode_i),
		.vpc_i(icache_vaddr_q),
		.bht_update_i(bht_update),
		.bht_prediction_o(bht_prediction)
	);
	genvar _gv_i_2;
	generate
		for (_gv_i_2 = 0; _gv_i_2 < ariane_pkg_INSTR_PER_FETCH; _gv_i_2 = _gv_i_2 + 1) begin : genblk2
			localparam i = _gv_i_2;
			instr_scan i_instr_scan(
				.instr_i(instr[i * 32+:32]),
				.is_rvc_o(is_rvc[i]),
				.rvi_return_o(rvi_return[i]),
				.rvi_call_o(rvi_call[i]),
				.rvi_branch_o(rvi_branch[i]),
				.rvi_jalr_o(rvi_jalr[i]),
				.rvi_jump_o(rvi_jump[i]),
				.rvi_imm_o(rvi_imm[i * 64+:64]),
				.rvc_branch_o(rvc_branch[i]),
				.rvc_jump_o(rvc_jump[i]),
				.rvc_jr_o(rvc_jr[i]),
				.rvc_return_o(rvc_return[i]),
				.rvc_jalr_o(rvc_jalr[i]),
				.rvc_call_o(rvc_call[i]),
				.rvc_imm_o(rvc_imm[i * 64+:64])
			);
		end
	endgenerate
	fifo_v2_925B0_BA4DE #(
		.dtype_ariane_pkg_FETCH_WIDTH(ariane_pkg_FETCH_WIDTH),
		.dtype_ariane_pkg_INSTR_PER_FETCH(ariane_pkg_INSTR_PER_FETCH),
		.DEPTH(8)
	) i_fetch_fifo(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.testmode_i(1'b0),
		.full_o(),
		.empty_o(fifo_empty),
		.alm_full_o(),
		.alm_empty_o(),
		.data_i({icache_vaddr_q, icache_data_q, bp_sbe, taken[ariane_pkg_INSTR_PER_FETCH:1], icache_ex_valid_q}),
		.push_i(fifo_valid),
		.data_o(fetch_entry_o),
		.pop_i(fifo_pop)
	);
	initial _sv2v_0 = 0;
endmodule
module id_stage (
	clk_i,
	rst_ni,
	flush_i,
	fetch_entry_i,
	fetch_entry_valid_i,
	decoded_instr_ack_o,
	issue_entry_o,
	issue_entry_valid_o,
	is_ctrl_flow_o,
	issue_instr_ack_i,
	priv_lvl_i,
	fs_i,
	frm_i,
	debug_mode_i,
	tvm_i,
	tw_i,
	tsr_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	localparam [31:0] ariane_pkg_FETCH_WIDTH = 32;
	localparam [31:0] ariane_pkg_INSTR_PER_FETCH = 2;
	input wire [166:0] fetch_entry_i;
	input wire fetch_entry_valid_i;
	output wire decoded_instr_ack_o;
	localparam ariane_pkg_REG_ADDR_SIZE = 6;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	output wire [361:0] issue_entry_o;
	output wire issue_entry_valid_o;
	output wire is_ctrl_flow_o;
	input wire issue_instr_ack_i;
	input wire [1:0] priv_lvl_i;
	input wire [1:0] fs_i;
	input wire [2:0] frm_i;
	input wire debug_mode_i;
	input wire tvm_i;
	input wire tw_i;
	input wire tsr_i;
	reg [363:0] issue_n;
	reg [363:0] issue_q;
	wire is_control_flow_instr;
	wire [361:0] decoded_instruction;
	wire [292:0] fetch_entry;
	wire is_illegal;
	wire [31:0] instruction;
	wire is_compressed;
	reg fetch_ack_i;
	wire fetch_entry_valid;
	instr_realigner instr_realigner_i(
		.fetch_entry_i(fetch_entry_i),
		.fetch_entry_valid_i(fetch_entry_valid_i),
		.fetch_ack_o(decoded_instr_ack_o),
		.fetch_entry_o(fetch_entry),
		.fetch_entry_valid_o(fetch_entry_valid),
		.fetch_ack_i(fetch_ack_i),
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i)
	);
	compressed_decoder compressed_decoder_i(
		.instr_i(fetch_entry[228-:32]),
		.instr_o(instruction),
		.illegal_instr_o(is_illegal),
		.is_compressed_o(is_compressed)
	);
	decoder decoder_i(
		.pc_i(fetch_entry[292-:64]),
		.is_compressed_i(is_compressed),
		.compressed_instr_i(fetch_entry[212:197]),
		.instruction_i(instruction),
		.branch_predict_i(fetch_entry[196-:68]),
		.is_illegal_i(is_illegal),
		.ex_i(fetch_entry[128-:129]),
		.instruction_o(decoded_instruction),
		.is_control_flow_instr_o(is_control_flow_instr),
		.fs_i(fs_i),
		.frm_i(frm_i),
		.priv_lvl_i(priv_lvl_i),
		.debug_mode_i(debug_mode_i),
		.tvm_i(tvm_i),
		.tw_i(tw_i),
		.tsr_i(tsr_i)
	);
	assign issue_entry_o = issue_q[362-:362];
	assign issue_entry_valid_o = issue_q[363];
	assign is_ctrl_flow_o = issue_q[0];
	always @(*) begin
		if (_sv2v_0)
			;
		issue_n = issue_q;
		fetch_ack_i = 1'b0;
		if (issue_instr_ack_i)
			issue_n[363] = 1'b0;
		if ((!issue_q[363] || issue_instr_ack_i) && fetch_entry_valid) begin
			fetch_ack_i = 1'b1;
			issue_n = {1'b1, decoded_instruction, is_control_flow_instr};
		end
		if (flush_i)
			issue_n[363] = 1'b0;
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni)
			issue_q <= 1'sb0;
		else
			issue_q <= issue_n;
	initial _sv2v_0 = 0;
endmodule
module instr_realigner (
	clk_i,
	rst_ni,
	flush_i,
	fetch_entry_i,
	fetch_entry_valid_i,
	fetch_ack_o,
	fetch_entry_o,
	fetch_entry_valid_o,
	fetch_ack_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	localparam [31:0] ariane_pkg_FETCH_WIDTH = 32;
	localparam [31:0] ariane_pkg_INSTR_PER_FETCH = 2;
	input wire [166:0] fetch_entry_i;
	input wire fetch_entry_valid_i;
	output reg fetch_ack_o;
	output reg [292:0] fetch_entry_o;
	output reg fetch_entry_valid_o;
	input wire fetch_ack_i;
	reg unaligned_n;
	reg unaligned_q;
	reg [15:0] unaligned_instr_n;
	reg [15:0] unaligned_instr_q;
	reg compressed_n;
	reg compressed_q;
	reg [63:0] unaligned_address_n;
	reg [63:0] unaligned_address_q;
	reg jump_unaligned_half_word;
	wire kill_upper_16_bit;
	assign kill_upper_16_bit = (fetch_entry_i[70] & fetch_entry_i[5]) & fetch_entry_i[1];
	localparam [63:0] riscv_INSTR_PAGE_FAULT = 12;
	always @(*) begin : realign_instr
		if (_sv2v_0)
			;
		unaligned_n = unaligned_q;
		unaligned_instr_n = unaligned_instr_q;
		compressed_n = compressed_q;
		unaligned_address_n = unaligned_address_q;
		fetch_entry_o[292-:64] = fetch_entry_i[166-:64];
		fetch_entry_o[228-:32] = fetch_entry_i[102-:32];
		fetch_entry_o[196-:68] = fetch_entry_i[70-:68];
		fetch_entry_o[0] = fetch_entry_i[0];
		fetch_entry_o[64-:64] = (fetch_entry_i[0] ? fetch_entry_i[166-:64] : {64 {1'sb0}});
		fetch_entry_o[128-:64] = (fetch_entry_i[0] ? riscv_INSTR_PAGE_FAULT : {64 {1'sb0}});
		fetch_entry_valid_o = fetch_entry_valid_i;
		fetch_ack_o = fetch_ack_i;
		jump_unaligned_half_word = 1'b0;
		if (fetch_entry_valid_i && !compressed_q) begin
			if (fetch_entry_i[104] == 1'b0) begin
				if (!unaligned_q) begin
					unaligned_n = 1'b0;
					if (fetch_entry_i[72:71] != 2'b11) begin
						fetch_entry_o[228-:32] = {15'b000000000000000, fetch_entry_i[86:71]};
						if (fetch_entry_i[70] && !fetch_entry_i[1])
							fetch_entry_o[196] = 1'b0;
						if (!kill_upper_16_bit) begin
							if (fetch_entry_i[88:87] != 2'b11) begin
								compressed_n = 1'b1;
								fetch_ack_o = 1'b0;
							end
							else begin
								unaligned_instr_n = fetch_entry_i[102:87];
								unaligned_address_n = {fetch_entry_i[166:105], 2'b10};
								unaligned_n = 1'b1;
							end
						end
					end
				end
				else if (unaligned_q) begin
					fetch_entry_o[292-:64] = unaligned_address_q;
					fetch_entry_o[228-:32] = {fetch_entry_i[86:71], unaligned_instr_q};
					if (!kill_upper_16_bit) begin
						if (fetch_entry_i[88:87] != 2'b11) begin
							compressed_n = 1'b1;
							fetch_ack_o = 1'b0;
							unaligned_n = 1'b0;
							if (fetch_entry_i[70] && !fetch_entry_i[1])
								fetch_entry_o[196] = 1'b0;
						end
						else if (!kill_upper_16_bit) begin
							unaligned_instr_n = fetch_entry_i[102:87];
							unaligned_address_n = {fetch_entry_i[166:105], 2'b10};
							unaligned_n = 1'b1;
						end
					end
					else if (fetch_entry_i[70])
						unaligned_n = 1'b0;
				end
			end
			else if (fetch_entry_i[104] == 1'b1) begin
				unaligned_n = 1'b0;
				if (fetch_entry_i[88:87] != 2'b11)
					fetch_entry_o[228-:32] = {15'b000000000000000, fetch_entry_i[102:87]};
				else begin
					unaligned_instr_n = fetch_entry_i[102:87];
					unaligned_n = 1'b1;
					unaligned_address_n = {fetch_entry_i[166:105], 2'b10};
					fetch_entry_valid_o = 1'b0;
					fetch_ack_o = 1'b1;
					jump_unaligned_half_word = 1'b1;
				end
			end
		end
		if (compressed_q) begin
			fetch_ack_o = fetch_ack_i;
			compressed_n = 1'b0;
			fetch_entry_o[228-:32] = {16'b0000000000000000, fetch_entry_i[102:87]};
			fetch_entry_o[292-:64] = {fetch_entry_i[166:105], 2'b10};
			fetch_entry_valid_o = 1'b1;
		end
		if (!fetch_ack_i && !jump_unaligned_half_word) begin
			unaligned_n = unaligned_q;
			unaligned_instr_n = unaligned_instr_q;
			compressed_n = compressed_q;
			unaligned_address_n = unaligned_address_q;
		end
		if (flush_i) begin
			unaligned_n = 1'b0;
			compressed_n = 1'b0;
		end
		fetch_entry_o[64-:64] = fetch_entry_o[292-:64];
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			unaligned_q <= 1'b0;
			unaligned_instr_q <= 16'b0000000000000000;
			unaligned_address_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			compressed_q <= 1'b0;
		end
		else begin
			unaligned_q <= unaligned_n;
			unaligned_instr_q <= unaligned_instr_n;
			unaligned_address_q <= unaligned_address_n;
			compressed_q <= compressed_n;
		end
	initial _sv2v_0 = 0;
endmodule
module issue_read_operands (
	clk_i,
	rst_ni,
	flush_i,
	issue_instr_i,
	issue_instr_valid_i,
	issue_ack_o,
	rs1_o,
	rs1_i,
	rs1_valid_i,
	rs2_o,
	rs2_i,
	rs2_valid_i,
	rs3_o,
	rs3_i,
	rs3_valid_i,
	rd_clobber_gpr_i,
	rd_clobber_fpr_i,
	fu_data_o,
	pc_o,
	is_compressed_instr_o,
	flu_ready_i,
	alu_valid_o,
	branch_valid_o,
	branch_predict_o,
	lsu_ready_i,
	lsu_valid_o,
	mult_valid_o,
	fpu_ready_i,
	fpu_valid_o,
	fpu_fmt_o,
	fpu_rm_o,
	csr_valid_o,
	waddr_i,
	wdata_i,
	we_gpr_i,
	we_fpr_i
);
	reg _sv2v_0;
	parameter [31:0] NR_COMMIT_PORTS = 2;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	localparam ariane_pkg_REG_ADDR_SIZE = 6;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [361:0] issue_instr_i;
	input wire issue_instr_valid_i;
	output reg issue_ack_o;
	output reg [5:0] rs1_o;
	input wire [63:0] rs1_i;
	input wire rs1_valid_i;
	output reg [5:0] rs2_o;
	input wire [63:0] rs2_i;
	input wire rs2_valid_i;
	output reg [5:0] rs3_o;
	localparam [0:0] ariane_pkg_RVD = 1'b0;
	localparam [0:0] ariane_pkg_RVF = 1'b0;
	localparam [0:0] ariane_pkg_XF16 = 1'b0;
	localparam [0:0] ariane_pkg_XF16ALT = 1'b0;
	localparam [0:0] ariane_pkg_XF8 = 1'b0;
	localparam ariane_pkg_FLEN = (ariane_pkg_RVD ? 64 : (ariane_pkg_RVF ? 32 : (ariane_pkg_XF16 ? 16 : (ariane_pkg_XF16ALT ? 16 : (ariane_pkg_XF8 ? 8 : 0)))));
	input wire [ariane_pkg_FLEN - 1:0] rs3_i;
	input wire rs3_valid_i;
	input wire [259:0] rd_clobber_gpr_i;
	input wire [259:0] rd_clobber_fpr_i;
	output wire [205:0] fu_data_o;
	output reg [63:0] pc_o;
	output reg is_compressed_instr_o;
	input wire flu_ready_i;
	output wire alu_valid_o;
	output wire branch_valid_o;
	output reg [67:0] branch_predict_o;
	input wire lsu_ready_i;
	output wire lsu_valid_o;
	output wire mult_valid_o;
	input wire fpu_ready_i;
	output wire fpu_valid_o;
	output wire [1:0] fpu_fmt_o;
	output wire [2:0] fpu_rm_o;
	output wire csr_valid_o;
	input wire [(NR_COMMIT_PORTS * 5) - 1:0] waddr_i;
	input wire [(NR_COMMIT_PORTS * 64) - 1:0] wdata_i;
	input wire [NR_COMMIT_PORTS - 1:0] we_gpr_i;
	input wire [NR_COMMIT_PORTS - 1:0] we_fpr_i;
	reg stall;
	reg fu_busy;
	wire [63:0] operand_a_regfile;
	wire [63:0] operand_b_regfile;
	wire [ariane_pkg_FLEN - 1:0] operand_c_regfile;
	reg [63:0] operand_a_n;
	reg [63:0] operand_a_q;
	reg [63:0] operand_b_n;
	reg [63:0] operand_b_q;
	reg [63:0] imm_n;
	reg [63:0] imm_q;
	reg alu_valid_n;
	reg alu_valid_q;
	reg mult_valid_n;
	reg mult_valid_q;
	reg fpu_valid_n;
	reg fpu_valid_q;
	reg [1:0] fpu_fmt_n;
	reg [1:0] fpu_fmt_q;
	reg [2:0] fpu_rm_n;
	reg [2:0] fpu_rm_q;
	reg lsu_valid_n;
	reg lsu_valid_q;
	reg csr_valid_n;
	reg csr_valid_q;
	reg branch_valid_n;
	reg branch_valid_q;
	reg [2:0] trans_id_n;
	reg [2:0] trans_id_q;
	reg [6:0] operator_n;
	reg [6:0] operator_q;
	reg [3:0] fu_n;
	reg [3:0] fu_q;
	reg forward_rs1;
	reg forward_rs2;
	reg forward_rs3;
	wire [31:0] orig_instr;
	assign orig_instr = issue_instr_i[101:70];
	assign fu_data_o[194-:64] = operand_a_q;
	assign fu_data_o[130-:64] = operand_b_q;
	assign fu_data_o[205-:4] = fu_q;
	assign fu_data_o[201-:7] = operator_q;
	assign fu_data_o[2-:ariane_pkg_TRANS_ID_BITS] = trans_id_q;
	assign fu_data_o[66-:64] = imm_q;
	assign alu_valid_o = alu_valid_q;
	assign branch_valid_o = branch_valid_q;
	assign lsu_valid_o = lsu_valid_q;
	assign csr_valid_o = csr_valid_q;
	assign mult_valid_o = mult_valid_q;
	assign fpu_valid_o = fpu_valid_q;
	assign fpu_fmt_o = fpu_fmt_q;
	assign fpu_rm_o = fpu_rm_q;
	always @(*) begin : unit_busy
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (issue_instr_i[294-:4])
			4'd0: fu_busy = 1'b0;
			4'd3, 4'd4, 4'd6, 4'd5: fu_busy = ~flu_ready_i;
			4'd7, 4'd8: fu_busy = ~fpu_ready_i;
			4'd1, 4'd2: fu_busy = ~lsu_ready_i;
			default: fu_busy = 1'b0;
		endcase
	end
	localparam [0:0] ariane_pkg_FP_PRESENT = (((ariane_pkg_RVF | ariane_pkg_RVD) | ariane_pkg_XF16) | ariane_pkg_XF16ALT) | ariane_pkg_XF8;
	function automatic ariane_pkg_is_imm_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd88 <= op) && (7'd89 >= op), (7'd94 <= op) && (7'd97 >= op), (7'd117 <= op) && (7'd120 >= op)})
				ariane_pkg_is_imm_fpr = 1'b1;
			else
				ariane_pkg_is_imm_fpr = 1'b0;
		end
		else
			ariane_pkg_is_imm_fpr = 1'b0;
	endfunction
	function automatic ariane_pkg_is_rs1_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd90 <= op) && (7'd97 >= op), op == 7'd98, op == 7'd100, op == 7'd101, op == 7'd102, op == 7'd104, op == 7'd105, (7'd106 <= op) && (7'd120 >= op)})
				ariane_pkg_is_rs1_fpr = 1'b1;
			else
				ariane_pkg_is_rs1_fpr = 1'b0;
		end
		else
			ariane_pkg_is_rs1_fpr = 1'b0;
	endfunction
	function automatic ariane_pkg_is_rs2_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd84 <= op) && (7'd87 >= op), (7'd88 <= op) && (7'd92 >= op), (7'd94 <= op) && (7'd97 >= op), op == 7'd100, (7'd101 <= op) && (7'd102 >= op), op == 7'd104, (7'd106 <= op) && (7'd120 >= op)})
				ariane_pkg_is_rs2_fpr = 1'b1;
			else
				ariane_pkg_is_rs2_fpr = 1'b0;
		end
		else
			ariane_pkg_is_rs2_fpr = 1'b0;
	endfunction
	always @(*) begin : operands_available
		if (_sv2v_0)
			;
		stall = 1'b0;
		forward_rs1 = 1'b0;
		forward_rs2 = 1'b0;
		forward_rs3 = 1'b0;
		rs1_o = issue_instr_i[283-:6];
		rs2_o = issue_instr_i[277-:6];
		rs3_o = issue_instr_i[207:202];
		if (~issue_instr_i[199] && (ariane_pkg_is_rs1_fpr(issue_instr_i[290-:7]) ? rd_clobber_fpr_i[issue_instr_i[283-:6] * 4+:4] != 4'd0 : rd_clobber_gpr_i[issue_instr_i[283-:6] * 4+:4] != 4'd0)) begin
			if (rs1_valid_i && (ariane_pkg_is_rs1_fpr(issue_instr_i[290-:7]) ? 1'b1 : rd_clobber_gpr_i[issue_instr_i[283-:6] * 4+:4] != 4'd6))
				forward_rs1 = 1'b1;
			else
				stall = 1'b1;
		end
		if ((ariane_pkg_is_rs2_fpr(issue_instr_i[290-:7]) ? rd_clobber_fpr_i[issue_instr_i[277-:6] * 4+:4] != 4'd0 : rd_clobber_gpr_i[issue_instr_i[277-:6] * 4+:4] != 4'd0)) begin
			if (rs2_valid_i && (ariane_pkg_is_rs2_fpr(issue_instr_i[290-:7]) ? 1'b1 : rd_clobber_gpr_i[issue_instr_i[277-:6] * 4+:4] != 4'd6))
				forward_rs2 = 1'b1;
			else
				stall = 1'b1;
		end
		if (ariane_pkg_is_imm_fpr(issue_instr_i[290-:7]) && (rd_clobber_fpr_i[issue_instr_i[207:202] * 4+:4] != 4'd0)) begin
			if (rs3_valid_i)
				forward_rs3 = 1'b1;
			else
				stall = 1'b1;
		end
	end
	always @(*) begin : forwarding_operand_select
		if (_sv2v_0)
			;
		operand_a_n = operand_a_regfile;
		operand_b_n = operand_b_regfile;
		imm_n = (ariane_pkg_is_imm_fpr(issue_instr_i[290-:7]) ? operand_c_regfile : issue_instr_i[265-:64]);
		trans_id_n = issue_instr_i[297-:3];
		fu_n = issue_instr_i[294-:4];
		operator_n = issue_instr_i[290-:7];
		if (forward_rs1)
			operand_a_n = rs1_i;
		if (forward_rs2)
			operand_b_n = rs2_i;
		if (forward_rs3)
			imm_n = rs3_i;
		if (issue_instr_i[198])
			operand_a_n = issue_instr_i[361-:64];
		if (issue_instr_i[199])
			operand_a_n = {52'b0000000000000000000000000000000000000000000000000000, issue_instr_i[282:278]};
		if (((issue_instr_i[200] && (issue_instr_i[294-:4] != 4'd2)) && (issue_instr_i[294-:4] != 4'd4)) && !ariane_pkg_is_rs2_fpr(issue_instr_i[290-:7]))
			operand_b_n = issue_instr_i[265-:64];
	end
	always @(*) begin : unit_valid
		if (_sv2v_0)
			;
		alu_valid_n = 1'b0;
		lsu_valid_n = 1'b0;
		mult_valid_n = 1'b0;
		fpu_valid_n = 1'b0;
		fpu_fmt_n = 2'b00;
		fpu_rm_n = 3'b000;
		csr_valid_n = 1'b0;
		branch_valid_n = 1'b0;
		if ((~issue_instr_i[69] && issue_instr_valid_i) && issue_ack_o)
			case (issue_instr_i[294-:4])
				4'd3: alu_valid_n = 1'b1;
				4'd4: branch_valid_n = 1'b1;
				4'd5: mult_valid_n = 1'b1;
				4'd7: begin
					fpu_valid_n = 1'b1;
					fpu_fmt_n = orig_instr[26-:2];
					fpu_rm_n = orig_instr[14-:3];
				end
				4'd8: begin
					fpu_valid_n = 1'b1;
					fpu_fmt_n = orig_instr[13-:2];
					fpu_rm_n = {2'b00, orig_instr[14]};
				end
				4'd1, 4'd2: lsu_valid_n = 1'b1;
				4'd6: csr_valid_n = 1'b1;
				default:
					;
			endcase
		if (flush_i) begin
			alu_valid_n = 1'b0;
			lsu_valid_n = 1'b0;
			mult_valid_n = 1'b0;
			fpu_valid_n = 1'b0;
			csr_valid_n = 1'b0;
			branch_valid_n = 1'b0;
		end
	end
	function automatic ariane_pkg_is_rd_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd80 <= op) && (7'd83 >= op), (7'd88 <= op) && (7'd97 >= op), op == 7'd99, op == 7'd100, op == 7'd101, op == 7'd103, (7'd106 <= op) && (7'd110 >= op), (7'd117 <= op) && (7'd120 >= op)})
				ariane_pkg_is_rd_fpr = 1'b1;
			else
				ariane_pkg_is_rd_fpr = 1'b0;
		end
		else
			ariane_pkg_is_rd_fpr = 1'b0;
	endfunction
	always @(*) begin : issue_scoreboard
		if (_sv2v_0)
			;
		issue_ack_o = 1'b0;
		if (issue_instr_valid_i) begin
			if (~stall && ~fu_busy) begin
				if ((ariane_pkg_is_rd_fpr(issue_instr_i[290-:7]) ? rd_clobber_fpr_i[issue_instr_i[271-:6] * 4+:4] == 4'd0 : rd_clobber_gpr_i[issue_instr_i[271-:6] * 4+:4] == 4'd0))
					issue_ack_o = 1'b1;
				begin : sv2v_autoblock_1
					reg [31:0] i;
					for (i = 0; i < NR_COMMIT_PORTS; i = i + 1)
						if ((ariane_pkg_is_rd_fpr(issue_instr_i[290-:7]) ? we_fpr_i[i] && (waddr_i[i * 5+:5] == issue_instr_i[271-:6]) : we_gpr_i[i] && (waddr_i[i * 5+:5] == issue_instr_i[271-:6])))
							issue_ack_o = 1'b1;
				end
			end
			if (issue_instr_i[69])
				issue_ack_o = 1'b1;
			if (issue_instr_i[294-:4] == 4'd0)
				issue_ack_o = 1'b1;
		end
		if (mult_valid_q && (issue_instr_i[294-:4] != 4'd5))
			issue_ack_o = 1'b0;
	end
	wire [127:0] rdata;
	wire [9:0] raddr_pack;
	wire [(NR_COMMIT_PORTS * 5) - 1:0] waddr_pack;
	wire [(NR_COMMIT_PORTS * 64) - 1:0] wdata_pack;
	wire [NR_COMMIT_PORTS - 1:0] we_pack;
	assign raddr_pack = {issue_instr_i[276:272], issue_instr_i[282:278]};
	assign waddr_pack = {waddr_i[5+:5], waddr_i[0+:5]};
	assign wdata_pack = {wdata_i[64+:64], wdata_i[0+:64]};
	assign we_pack = {we_gpr_i[1], we_gpr_i[0]};
	ariane_regfile #(
		.DATA_WIDTH(64),
		.NR_READ_PORTS(2),
		.NR_WRITE_PORTS(NR_COMMIT_PORTS),
		.ZERO_REG_ZERO(1)
	) i_ariane_regfile(
		.test_en_i(1'b0),
		.raddr_i(raddr_pack),
		.rdata_o(rdata),
		.waddr_i(waddr_pack),
		.wdata_i(wdata_pack),
		.we_i(we_pack),
		.clk_i(clk_i),
		.rst_ni(rst_ni)
	);
	wire [(3 * ariane_pkg_FLEN) - 1:0] fprdata;
	wire [14:0] fp_raddr_pack;
	wire [(NR_COMMIT_PORTS * 64) - 1:0] fp_wdata_pack;
	function automatic [ariane_pkg_FLEN - 1:0] sv2v_cast_E6C52;
		input reg [ariane_pkg_FLEN - 1:0] inp;
		sv2v_cast_E6C52 = inp;
	endfunction
	generate
		if (ariane_pkg_FP_PRESENT) begin : float_regfile_gen
			assign fp_raddr_pack = {issue_instr_i[206:202], issue_instr_i[276:272], issue_instr_i[282:278]};
			assign fp_wdata_pack = {wdata_i[ariane_pkg_FLEN + 63-:ariane_pkg_FLEN], wdata_i[ariane_pkg_FLEN - 1-:ariane_pkg_FLEN]};
			ariane_regfile #(
				.DATA_WIDTH(ariane_pkg_FLEN),
				.NR_READ_PORTS(3),
				.NR_WRITE_PORTS(NR_COMMIT_PORTS),
				.ZERO_REG_ZERO(0)
			) i_ariane_fp_regfile(
				.test_en_i(1'b0),
				.raddr_i(fp_raddr_pack),
				.rdata_o(fprdata),
				.waddr_i(waddr_pack),
				.wdata_i(wdata_pack),
				.we_i(we_fpr_i),
				.clk_i(clk_i),
				.rst_ni(rst_ni)
			);
		end
		else begin : no_fpr_gen
			assign fprdata = {3 {sv2v_cast_E6C52(1'sb0)}};
		end
	endgenerate
	assign operand_a_regfile = (ariane_pkg_is_rs1_fpr(issue_instr_i[290-:7]) ? fprdata[0+:ariane_pkg_FLEN] : rdata[0+:64]);
	assign operand_b_regfile = (ariane_pkg_is_rs2_fpr(issue_instr_i[290-:7]) ? fprdata[ariane_pkg_FLEN+:ariane_pkg_FLEN] : rdata[64+:64]);
	assign operand_c_regfile = fprdata[2 * ariane_pkg_FLEN+:ariane_pkg_FLEN];
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			operand_a_q <= {64 {1'd0}};
			operand_b_q <= {64 {1'd0}};
			imm_q <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			alu_valid_q <= 1'b0;
			branch_valid_q <= 1'b0;
			mult_valid_q <= 1'b0;
			fpu_valid_q <= 1'b0;
			fpu_fmt_q <= 2'b00;
			fpu_rm_q <= 3'b000;
			lsu_valid_q <= 1'b0;
			csr_valid_q <= 1'b0;
			fu_q <= 4'd0;
			operator_q <= 7'd0;
			trans_id_q <= 5'b00000;
			pc_o <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			is_compressed_instr_o <= 1'b0;
			branch_predict_o <= 68'd0;
		end
		else begin
			operand_a_q <= operand_a_n;
			operand_b_q <= operand_b_n;
			imm_q <= imm_n;
			alu_valid_q <= alu_valid_n;
			branch_valid_q <= branch_valid_n;
			mult_valid_q <= mult_valid_n;
			fpu_valid_q <= fpu_valid_n;
			fpu_fmt_q <= fpu_fmt_n;
			fpu_rm_q <= fpu_rm_n;
			lsu_valid_q <= lsu_valid_n;
			csr_valid_q <= csr_valid_n;
			fu_q <= fu_n;
			operator_q <= operator_n;
			trans_id_q <= trans_id_n;
			pc_o <= issue_instr_i[361-:64];
			is_compressed_instr_o <= issue_instr_i[0];
			branch_predict_o <= issue_instr_i[68-:68];
		end
	initial _sv2v_0 = 0;
endmodule
module issue_stage (
	clk_i,
	rst_ni,
	sb_full_o,
	flush_unissued_instr_i,
	flush_i,
	decoded_instr_i,
	decoded_instr_valid_i,
	is_ctrl_flow_i,
	decoded_instr_ack_o,
	fu_data_o,
	pc_o,
	is_compressed_instr_o,
	flu_ready_i,
	alu_valid_o,
	resolve_branch_i,
	lsu_ready_i,
	lsu_valid_o,
	branch_valid_o,
	branch_predict_o,
	mult_valid_o,
	fpu_ready_i,
	fpu_valid_o,
	fpu_fmt_o,
	fpu_rm_o,
	csr_valid_o,
	trans_id_i,
	resolved_branch_i,
	wbdata_i,
	ex_ex_i,
	wb_valid_i,
	waddr_i,
	wdata_i,
	we_gpr_i,
	we_fpr_i,
	commit_instr_o,
	commit_ack_i
);
	parameter [31:0] NR_ENTRIES = 8;
	parameter [31:0] NR_WB_PORTS = 4;
	parameter [31:0] NR_COMMIT_PORTS = 2;
	input wire clk_i;
	input wire rst_ni;
	output wire sb_full_o;
	input wire flush_unissued_instr_i;
	input wire flush_i;
	localparam ariane_pkg_REG_ADDR_SIZE = 6;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [361:0] decoded_instr_i;
	input wire decoded_instr_valid_i;
	input wire is_ctrl_flow_i;
	output wire decoded_instr_ack_o;
	output wire [205:0] fu_data_o;
	output wire [63:0] pc_o;
	output wire is_compressed_instr_o;
	input wire flu_ready_i;
	output wire alu_valid_o;
	input wire resolve_branch_i;
	input wire lsu_ready_i;
	output wire lsu_valid_o;
	output wire branch_valid_o;
	output wire [67:0] branch_predict_o;
	output wire mult_valid_o;
	input wire fpu_ready_i;
	output wire fpu_valid_o;
	output wire [1:0] fpu_fmt_o;
	output wire [2:0] fpu_rm_o;
	output wire csr_valid_o;
	input wire [(NR_WB_PORTS * 3) - 1:0] trans_id_i;
	input wire [133:0] resolved_branch_i;
	input wire [(NR_WB_PORTS * 64) - 1:0] wbdata_i;
	input wire [(NR_WB_PORTS * 129) - 1:0] ex_ex_i;
	input wire [NR_WB_PORTS - 1:0] wb_valid_i;
	input wire [(NR_COMMIT_PORTS * 5) - 1:0] waddr_i;
	input wire [(NR_COMMIT_PORTS * 64) - 1:0] wdata_i;
	input wire [NR_COMMIT_PORTS - 1:0] we_gpr_i;
	input wire [NR_COMMIT_PORTS - 1:0] we_fpr_i;
	output wire [(NR_COMMIT_PORTS * 362) - 1:0] commit_instr_o;
	input wire [NR_COMMIT_PORTS - 1:0] commit_ack_i;
	wire [259:0] rd_clobber_gpr_sb_iro;
	wire [259:0] rd_clobber_fpr_sb_iro;
	wire [5:0] rs1_iro_sb;
	wire [63:0] rs1_sb_iro;
	wire rs1_valid_sb_iro;
	wire [5:0] rs2_iro_sb;
	wire [63:0] rs2_sb_iro;
	wire rs2_valid_iro_sb;
	wire [5:0] rs3_iro_sb;
	localparam [0:0] ariane_pkg_RVD = 1'b0;
	localparam [0:0] ariane_pkg_RVF = 1'b0;
	localparam [0:0] ariane_pkg_XF16 = 1'b0;
	localparam [0:0] ariane_pkg_XF16ALT = 1'b0;
	localparam [0:0] ariane_pkg_XF8 = 1'b0;
	localparam ariane_pkg_FLEN = (ariane_pkg_RVD ? 64 : (ariane_pkg_RVF ? 32 : (ariane_pkg_XF16 ? 16 : (ariane_pkg_XF16ALT ? 16 : (ariane_pkg_XF8 ? 8 : 0)))));
	wire [ariane_pkg_FLEN - 1:0] rs3_sb_iro;
	wire rs3_valid_iro_sb;
	wire [361:0] issue_instr_rename_sb;
	wire issue_instr_valid_rename_sb;
	wire issue_ack_sb_rename;
	wire [361:0] issue_instr_sb_iro;
	wire issue_instr_valid_sb_iro;
	wire issue_ack_iro_sb;
	re_name i_re_name(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.flush_unissied_instr_i(flush_unissued_instr_i),
		.issue_instr_i(decoded_instr_i),
		.issue_instr_valid_i(decoded_instr_valid_i),
		.issue_ack_o(decoded_instr_ack_o),
		.issue_instr_o(issue_instr_rename_sb),
		.issue_instr_valid_o(issue_instr_valid_rename_sb),
		.issue_ack_i(issue_ack_sb_rename)
	);
	scoreboard #(
		.NR_ENTRIES(NR_ENTRIES),
		.NR_WB_PORTS(NR_WB_PORTS)
	) i_scoreboard(
		.sb_full_o(sb_full_o),
		.unresolved_branch_i(1'b0),
		.rd_clobber_gpr_o(rd_clobber_gpr_sb_iro),
		.rd_clobber_fpr_o(rd_clobber_fpr_sb_iro),
		.rs1_i(rs1_iro_sb),
		.rs1_o(rs1_sb_iro),
		.rs1_valid_o(rs1_valid_sb_iro),
		.rs2_i(rs2_iro_sb),
		.rs2_o(rs2_sb_iro),
		.rs2_valid_o(rs2_valid_iro_sb),
		.rs3_i(rs3_iro_sb),
		.rs3_o(rs3_sb_iro),
		.rs3_valid_o(rs3_valid_iro_sb),
		.decoded_instr_i(issue_instr_rename_sb),
		.decoded_instr_valid_i(issue_instr_valid_rename_sb),
		.decoded_instr_ack_o(issue_ack_sb_rename),
		.issue_instr_o(issue_instr_sb_iro),
		.issue_instr_valid_o(issue_instr_valid_sb_iro),
		.issue_ack_i(issue_ack_iro_sb),
		.resolved_branch_i(resolved_branch_i),
		.trans_id_i(trans_id_i),
		.wbdata_i(wbdata_i),
		.ex_i(ex_ex_i),
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_unissued_instr_i(flush_unissued_instr_i),
		.flush_i(flush_i),
		.commit_instr_o(commit_instr_o),
		.commit_ack_i(commit_ack_i),
		.wb_valid_i(wb_valid_i)
	);
	issue_read_operands i_issue_read_operands(
		.flush_i(flush_unissued_instr_i),
		.issue_instr_i(issue_instr_sb_iro),
		.issue_instr_valid_i(issue_instr_valid_sb_iro),
		.issue_ack_o(issue_ack_iro_sb),
		.fu_data_o(fu_data_o),
		.flu_ready_i(flu_ready_i),
		.rs1_o(rs1_iro_sb),
		.rs1_i(rs1_sb_iro),
		.rs1_valid_i(rs1_valid_sb_iro),
		.rs2_o(rs2_iro_sb),
		.rs2_i(rs2_sb_iro),
		.rs2_valid_i(rs2_valid_iro_sb),
		.rs3_o(rs3_iro_sb),
		.rs3_i(rs3_sb_iro),
		.rs3_valid_i(rs3_valid_iro_sb),
		.rd_clobber_gpr_i(rd_clobber_gpr_sb_iro),
		.rd_clobber_fpr_i(rd_clobber_fpr_sb_iro),
		.alu_valid_o(alu_valid_o),
		.branch_valid_o(branch_valid_o),
		.csr_valid_o(csr_valid_o),
		.mult_valid_o(mult_valid_o),
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.pc_o(pc_o),
		.is_compressed_instr_o(is_compressed_instr_o),
		.branch_predict_o(branch_predict_o),
		.lsu_ready_i(lsu_ready_i),
		.lsu_valid_o(lsu_valid_o),
		.fpu_ready_i(fpu_ready_i),
		.fpu_valid_o(fpu_valid_o),
		.fpu_fmt_o(fpu_fmt_o),
		.fpu_rm_o(fpu_rm_o),
		.waddr_i(waddr_i),
		.wdata_i(wdata_i),
		.we_gpr_i(we_gpr_i),
		.we_fpr_i(we_fpr_i)
	);
endmodule
module load_unit (
	clk_i,
	rst_ni,
	flush_i,
	valid_i,
	lsu_ctrl_i,
	pop_ld_o,
	valid_o,
	trans_id_o,
	result_o,
	ex_o,
	translation_req_o,
	vaddr_o,
	paddr_i,
	ex_i,
	dtlb_hit_i,
	page_offset_o,
	page_offset_matches_i,
	req_port_i,
	req_port_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire valid_i;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [150:0] lsu_ctrl_i;
	output reg pop_ld_o;
	output reg valid_o;
	output reg [2:0] trans_id_o;
	output reg [63:0] result_o;
	output wire [128:0] ex_o;
	output reg translation_req_o;
	output wire [63:0] vaddr_o;
	input wire [63:0] paddr_i;
	input wire [128:0] ex_i;
	input wire dtlb_hit_i;
	output wire [11:0] page_offset_o;
	input wire page_offset_matches_i;
	input wire [65:0] req_port_i;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	output reg [(ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77:0] req_port_o;
	reg [2:0] state_d;
	reg [2:0] state_q;
	reg [12:0] load_data_d;
	reg [12:0] load_data_q;
	wire [12:0] in_data;
	assign page_offset_o = lsu_ctrl_i[97:86];
	assign vaddr_o = lsu_ctrl_i[149-:64];
	wire [1:1] sv2v_tmp_94E29;
	assign sv2v_tmp_94E29 = 1'b0;
	always @(*) req_port_o[12] = sv2v_tmp_94E29;
	wire [64:1] sv2v_tmp_AD1D9;
	assign sv2v_tmp_AD1D9 = 1'sb0;
	always @(*) req_port_o[77-:64] = sv2v_tmp_AD1D9;
	assign in_data = {lsu_ctrl_i[2-:ariane_pkg_TRANS_ID_BITS], lsu_ctrl_i[88:86], lsu_ctrl_i[9-:7]};
	wire [12:1] sv2v_tmp_681B0;
	assign sv2v_tmp_681B0 = lsu_ctrl_i[97:86];
	always @(*) req_port_o[133-:12] = sv2v_tmp_681B0;
	wire [44:1] sv2v_tmp_1F9FF;
	assign sv2v_tmp_1F9FF = paddr_i[(ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) - 1:ariane_pkg_DCACHE_INDEX_WIDTH];
	always @(*) req_port_o[121-:44] = sv2v_tmp_1F9FF;
	assign ex_o = ex_i;
	function automatic [1:0] ariane_pkg_extract_transfer_size;
		input reg [6:0] op;
		case (op)
			7'd34, 7'd35, 7'd80, 7'd84, 7'd46, 7'd48, 7'd58, 7'd59, 7'd60, 7'd61, 7'd62, 7'd63, 7'd64, 7'd65, 7'd66: ariane_pkg_extract_transfer_size = 2'b11;
			7'd36, 7'd37, 7'd38, 7'd81, 7'd85, 7'd45, 7'd47, 7'd49, 7'd50, 7'd51, 7'd52, 7'd53, 7'd54, 7'd55, 7'd56, 7'd57: ariane_pkg_extract_transfer_size = 2'b10;
			7'd39, 7'd40, 7'd41, 7'd82, 7'd86: ariane_pkg_extract_transfer_size = 2'b01;
			7'd42, 7'd44, 7'd43, 7'd83, 7'd87: ariane_pkg_extract_transfer_size = 2'b00;
			default: ariane_pkg_extract_transfer_size = 2'b11;
		endcase
	endfunction
	always @(*) begin : load_control
		if (_sv2v_0)
			;
		state_d = state_q;
		load_data_d = load_data_q;
		translation_req_o = 1'b0;
		req_port_o[13] = 1'b0;
		req_port_o[1] = 1'b0;
		req_port_o[0] = 1'b0;
		req_port_o[11-:8] = lsu_ctrl_i[21-:8];
		req_port_o[3-:2] = ariane_pkg_extract_transfer_size(lsu_ctrl_i[9-:7]);
		pop_ld_o = 1'b0;
		case (state_q)
			3'd0:
				if (valid_i) begin
					translation_req_o = 1'b1;
					if (!page_offset_matches_i) begin
						req_port_o[13] = 1'b1;
						if (!req_port_i[65])
							state_d = 3'd1;
						else if (dtlb_hit_i) begin
							state_d = 3'd2;
							pop_ld_o = 1'b1;
						end
						else
							state_d = 3'd4;
					end
					else
						state_d = 3'd3;
				end
			3'd3:
				if (!page_offset_matches_i)
					state_d = 3'd1;
			3'd4: begin
				req_port_o[1] = 1'b1;
				req_port_o[0] = 1'b1;
				state_d = 3'd5;
			end
			3'd5: begin
				translation_req_o = 1'b1;
				if (dtlb_hit_i)
					state_d = 3'd1;
			end
			3'd1: begin
				translation_req_o = 1'b1;
				req_port_o[13] = 1'b1;
				if (req_port_i[65]) begin
					if (dtlb_hit_i) begin
						state_d = 3'd2;
						pop_ld_o = 1'b1;
					end
					else
						state_d = 3'd4;
				end
			end
			3'd2: begin
				req_port_o[0] = 1'b1;
				state_d = 3'd0;
				if (valid_i) begin
					translation_req_o = 1'b1;
					if (!page_offset_matches_i) begin
						req_port_o[13] = 1'b1;
						if (!req_port_i[65])
							state_d = 3'd1;
						else if (dtlb_hit_i) begin
							state_d = 3'd2;
							pop_ld_o = 1'b1;
						end
						else
							state_d = 3'd4;
					end
					else
						state_d = 3'd3;
				end
				if (ex_i[0])
					req_port_o[1] = 1'b1;
			end
			3'd6: begin
				req_port_o[1] = 1'b1;
				req_port_o[0] = 1'b1;
				state_d = 3'd0;
			end
		endcase
		if (ex_i[0] && valid_i) begin
			state_d = 3'd0;
			if (!req_port_i[64])
				pop_ld_o = 1'b1;
		end
		if (pop_ld_o && !ex_i[0])
			load_data_d = in_data;
		if (flush_i)
			state_d = 3'd6;
	end
	always @(*) begin : rvalid_output
		if (_sv2v_0)
			;
		valid_o = 1'b0;
		trans_id_o = load_data_q[12-:3];
		if (req_port_i[64] && (state_q != 3'd6)) begin
			if (!req_port_o[1])
				valid_o = 1'b1;
			if (ex_i[0])
				valid_o = 1'b1;
		end
		if ((valid_i && ex_i[0]) && !req_port_i[64]) begin
			valid_o = 1'b1;
			trans_id_o = lsu_ctrl_i[2-:ariane_pkg_TRANS_ID_BITS];
		end
		else if (state_q == 3'd5)
			valid_o = 1'b0;
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			state_q <= 3'd0;
			load_data_q <= 1'sb0;
		end
		else begin
			state_q <= state_d;
			load_data_q <= load_data_d;
		end
	wire [63:0] shifted_data;
	assign shifted_data = req_port_i[63-:64] >> {load_data_q[9-:3], 3'b000};
	wire [7:0] sign_bits;
	wire [2:0] idx_d;
	reg [2:0] idx_q;
	wire sign_bit;
	wire signed_d;
	reg signed_q;
	wire fp_sign_d;
	reg fp_sign_q;
	assign signed_d = |{load_data_d[6-:7] == 7'd36, load_data_d[6-:7] == 7'd39, load_data_d[6-:7] == 7'd42};
	assign fp_sign_d = |{load_data_d[6-:7] == 7'd81, load_data_d[6-:7] == 7'd82, load_data_d[6-:7] == 7'd83};
	assign idx_d = (|{load_data_d[6-:7] == 7'd36, load_data_d[6-:7] == 7'd81} ? load_data_d[9-:3] + 3 : (|{load_data_d[6-:7] == 7'd39, load_data_d[6-:7] == 7'd82} ? load_data_d[9-:3] + 1 : load_data_d[9-:3]));
	assign sign_bits = {req_port_i[63], req_port_i[55], req_port_i[47], req_port_i[39], req_port_i[31], req_port_i[23], req_port_i[15], req_port_i[7]};
	assign sign_bit = (signed_q & sign_bits[idx_q]) | fp_sign_q;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (load_data_q[6-:7])
			7'd36, 7'd37, 7'd81: result_o = {{32 {sign_bit}}, shifted_data[31:0]};
			7'd39, 7'd40, 7'd82: result_o = {{48 {sign_bit}}, shifted_data[15:0]};
			7'd42, 7'd44, 7'd83: result_o = {{56 {sign_bit}}, shifted_data[7:0]};
			default: result_o = shifted_data;
		endcase
	end
	always @(posedge clk_i or negedge rst_ni) begin : p_regs
		if (~rst_ni) begin
			idx_q <= 0;
			signed_q <= 0;
			fp_sign_q <= 0;
		end
		else begin
			idx_q <= idx_d;
			signed_q <= signed_d;
			fp_sign_q <= fp_sign_d;
		end
	end
	initial _sv2v_0 = 0;
endmodule
module amo_buffer (
	clk_i,
	rst_ni,
	flush_i,
	valid_i,
	ready_o,
	amo_op_i,
	paddr_i,
	data_i,
	data_size_i,
	amo_req_o,
	amo_resp_i,
	amo_valid_commit_i,
	no_st_pending_i
);
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire valid_i;
	output wire ready_o;
	input wire [3:0] amo_op_i;
	input wire [63:0] paddr_i;
	input wire [63:0] data_i;
	input wire [1:0] data_size_i;
	output wire [134:0] amo_req_o;
	input wire [64:0] amo_resp_i;
	input wire amo_valid_commit_i;
	input wire no_st_pending_i;
	wire flush_amo_buffer;
	wire amo_valid;
	wire [133:0] amo_data_in;
	wire [133:0] amo_data_out;
	assign amo_req_o[134] = (no_st_pending_i & amo_valid_commit_i) & amo_valid;
	assign amo_req_o[133-:4] = amo_data_out[133-:4];
	assign amo_req_o[129-:2] = amo_data_out[1-:2];
	assign amo_req_o[127-:64] = amo_data_out[129-:64];
	assign amo_req_o[63-:64] = amo_data_out[65-:64];
	assign amo_data_in[133-:4] = amo_op_i;
	assign amo_data_in[65-:64] = data_i;
	assign amo_data_in[129-:64] = paddr_i;
	assign amo_data_in[1-:2] = data_size_i;
	assign flush_amo_buffer = flush_i & !amo_valid_commit_i;
	fifo_v2_EC778 #(
		.DEPTH(1),
		.ALM_EMPTY_TH(0),
		.ALM_FULL_TH(0)
	) i_amo_fifo(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_amo_buffer),
		.testmode_i(1'b0),
		.full_o(amo_valid),
		.empty_o(ready_o),
		.alm_full_o(),
		.alm_empty_o(),
		.data_i(amo_data_in),
		.push_i(valid_i),
		.data_o(amo_data_out),
		.pop_i(amo_resp_i[64])
	);
endmodule
module store_unit (
	clk_i,
	rst_ni,
	flush_i,
	no_st_pending_o,
	valid_i,
	lsu_ctrl_i,
	pop_st_o,
	commit_i,
	commit_ready_o,
	amo_valid_commit_i,
	valid_o,
	trans_id_o,
	result_o,
	ex_o,
	translation_req_o,
	vaddr_o,
	paddr_i,
	ex_i,
	dtlb_hit_i,
	page_offset_i,
	page_offset_matches_o,
	amo_req_o,
	amo_resp_i,
	req_port_i,
	req_port_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	output wire no_st_pending_o;
	input wire valid_i;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [150:0] lsu_ctrl_i;
	output reg pop_st_o;
	input wire commit_i;
	output wire commit_ready_o;
	input wire amo_valid_commit_i;
	output reg valid_o;
	output wire [2:0] trans_id_o;
	output wire [63:0] result_o;
	output reg [128:0] ex_o;
	output reg translation_req_o;
	output wire [63:0] vaddr_o;
	input wire [63:0] paddr_i;
	input wire [128:0] ex_i;
	input wire dtlb_hit_i;
	input wire [11:0] page_offset_i;
	output wire page_offset_matches_o;
	output wire [134:0] amo_req_o;
	input wire [64:0] amo_resp_i;
	input wire [65:0] req_port_i;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	output wire [(ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77:0] req_port_o;
	assign result_o = 64'b0000000000000000000000000000000000000000000000000000000000000000;
	reg [1:0] state_d;
	reg [1:0] state_q;
	wire st_ready;
	reg st_valid;
	reg st_valid_without_flush;
	wire instr_is_amo;
	function automatic ariane_pkg_is_amo;
		input reg [6:0] op;
		if ((7'd45 <= op) && (7'd66 >= op))
			ariane_pkg_is_amo = 1'b1;
		else
			ariane_pkg_is_amo = 1'b0;
	endfunction
	assign instr_is_amo = ariane_pkg_is_amo(lsu_ctrl_i[9-:7]);
	reg [63:0] st_data_n;
	reg [63:0] st_data_q;
	reg [7:0] st_be_n;
	reg [7:0] st_be_q;
	reg [1:0] st_data_size_n;
	reg [1:0] st_data_size_q;
	reg [3:0] amo_op_d;
	reg [3:0] amo_op_q;
	reg [2:0] trans_id_n;
	reg [2:0] trans_id_q;
	assign vaddr_o = lsu_ctrl_i[149-:64];
	assign trans_id_o = trans_id_q;
	always @(*) begin : store_control
		if (_sv2v_0)
			;
		translation_req_o = 1'b0;
		valid_o = 1'b0;
		st_valid = 1'b0;
		st_valid_without_flush = 1'b0;
		pop_st_o = 1'b0;
		ex_o = ex_i;
		trans_id_n = lsu_ctrl_i[2-:ariane_pkg_TRANS_ID_BITS];
		state_d = state_q;
		case (state_q)
			2'd0:
				if (valid_i) begin
					state_d = 2'd1;
					translation_req_o = 1'b1;
					pop_st_o = 1'b1;
					if (!dtlb_hit_i) begin
						state_d = 2'd2;
						pop_st_o = 1'b0;
					end
					if (!st_ready) begin
						state_d = 2'd3;
						pop_st_o = 1'b0;
					end
				end
			2'd1: begin
				valid_o = 1'b1;
				if (!flush_i)
					st_valid = 1'b1;
				st_valid_without_flush = 1'b1;
				if (valid_i && !instr_is_amo) begin
					translation_req_o = 1'b1;
					state_d = 2'd1;
					pop_st_o = 1'b1;
					if (!dtlb_hit_i) begin
						state_d = 2'd2;
						pop_st_o = 1'b0;
					end
					if (!st_ready) begin
						state_d = 2'd3;
						pop_st_o = 1'b0;
					end
				end
				else
					state_d = 2'd0;
			end
			2'd3: begin
				translation_req_o = 1'b1;
				if (st_ready && dtlb_hit_i)
					state_d = 2'd0;
			end
			2'd2: begin
				translation_req_o = 1'b1;
				if (dtlb_hit_i)
					state_d = 2'd0;
			end
		endcase
		if (ex_i[0] && (state_q != 2'd0)) begin
			pop_st_o = 1'b1;
			st_valid = 1'b0;
			state_d = 2'd0;
			valid_o = 1'b1;
		end
		if (flush_i)
			state_d = 2'd0;
	end
	function automatic [63:0] ariane_pkg_data_align;
		input reg [2:0] addr;
		input reg [63:0] data;
		reg [1:0] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			case (addr)
				3'b000: begin
					ariane_pkg_data_align = data;
					_sv2v_jump = 2'b11;
				end
				3'b001: begin
					ariane_pkg_data_align = {data[55:0], data[63:56]};
					_sv2v_jump = 2'b11;
				end
				3'b010: begin
					ariane_pkg_data_align = {data[47:0], data[63:48]};
					_sv2v_jump = 2'b11;
				end
				3'b011: begin
					ariane_pkg_data_align = {data[39:0], data[63:40]};
					_sv2v_jump = 2'b11;
				end
				3'b100: begin
					ariane_pkg_data_align = {data[31:0], data[63:32]};
					_sv2v_jump = 2'b11;
				end
				3'b101: begin
					ariane_pkg_data_align = {data[23:0], data[63:24]};
					_sv2v_jump = 2'b11;
				end
				3'b110: begin
					ariane_pkg_data_align = {data[15:0], data[63:16]};
					_sv2v_jump = 2'b11;
				end
				3'b111: begin
					ariane_pkg_data_align = {data[7:0], data[63:8]};
					_sv2v_jump = 2'b11;
				end
			endcase
			if (_sv2v_jump == 2'b00) begin
				ariane_pkg_data_align = data;
				_sv2v_jump = 2'b11;
			end
		end
	endfunction
	function automatic [1:0] ariane_pkg_extract_transfer_size;
		input reg [6:0] op;
		case (op)
			7'd34, 7'd35, 7'd80, 7'd84, 7'd46, 7'd48, 7'd58, 7'd59, 7'd60, 7'd61, 7'd62, 7'd63, 7'd64, 7'd65, 7'd66: ariane_pkg_extract_transfer_size = 2'b11;
			7'd36, 7'd37, 7'd38, 7'd81, 7'd85, 7'd45, 7'd47, 7'd49, 7'd50, 7'd51, 7'd52, 7'd53, 7'd54, 7'd55, 7'd56, 7'd57: ariane_pkg_extract_transfer_size = 2'b10;
			7'd39, 7'd40, 7'd41, 7'd82, 7'd86: ariane_pkg_extract_transfer_size = 2'b01;
			7'd42, 7'd44, 7'd43, 7'd83, 7'd87: ariane_pkg_extract_transfer_size = 2'b00;
			default: ariane_pkg_extract_transfer_size = 2'b11;
		endcase
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		st_be_n = lsu_ctrl_i[21-:8];
		st_data_n = (instr_is_amo ? lsu_ctrl_i[85-:64] : ariane_pkg_data_align(lsu_ctrl_i[88:86], lsu_ctrl_i[85-:64]));
		st_data_size_n = ariane_pkg_extract_transfer_size(lsu_ctrl_i[9-:7]);
		case (lsu_ctrl_i[9-:7])
			7'd45, 7'd46: amo_op_d = 4'b0001;
			7'd47, 7'd48: amo_op_d = 4'b0010;
			7'd49, 7'd58: amo_op_d = 4'b0011;
			7'd50, 7'd59: amo_op_d = 4'b0100;
			7'd51, 7'd60: amo_op_d = 4'b0101;
			7'd52, 7'd61: amo_op_d = 4'b0110;
			7'd53, 7'd62: amo_op_d = 4'b0111;
			7'd54, 7'd63: amo_op_d = 4'b1000;
			7'd55, 7'd64: amo_op_d = 4'b1001;
			7'd56, 7'd65: amo_op_d = 4'b1010;
			7'd57, 7'd66: amo_op_d = 4'b1011;
			default: amo_op_d = 4'b0000;
		endcase
	end
	wire store_buffer_valid;
	wire amo_buffer_valid;
	wire store_buffer_ready;
	wire amo_buffer_ready;
	assign store_buffer_valid = st_valid & (amo_op_q == 4'b0000);
	assign amo_buffer_valid = st_valid & (amo_op_q != 4'b0000);
	assign st_ready = store_buffer_ready & amo_buffer_ready;
	store_buffer store_buffer_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.no_st_pending_o(no_st_pending_o),
		.page_offset_i(page_offset_i),
		.page_offset_matches_o(page_offset_matches_o),
		.commit_i(commit_i),
		.commit_ready_o(commit_ready_o),
		.ready_o(store_buffer_ready),
		.valid_i(store_buffer_valid),
		.valid_without_flush_i(st_valid_without_flush),
		.paddr_i(paddr_i),
		.data_i(st_data_q),
		.be_i(st_be_q),
		.data_size_i(st_data_size_q),
		.req_port_i(req_port_i),
		.req_port_o(req_port_o)
	);
	amo_buffer i_amo_buffer(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.valid_i(amo_buffer_valid),
		.ready_o(amo_buffer_ready),
		.paddr_i(paddr_i),
		.amo_op_i(amo_op_q),
		.data_i(st_data_q),
		.data_size_i(st_data_size_q),
		.amo_req_o(amo_req_o),
		.amo_resp_i(amo_resp_i),
		.amo_valid_commit_i(amo_valid_commit_i),
		.no_st_pending_i(no_st_pending_o)
	);
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			state_q <= 2'd0;
			st_be_q <= 1'sb0;
			st_data_q <= 1'sb0;
			st_data_size_q <= 1'sb0;
			trans_id_q <= 1'sb0;
			amo_op_q <= 4'b0000;
		end
		else begin
			state_q <= state_d;
			st_be_q <= st_be_n;
			st_data_q <= st_data_n;
			trans_id_q <= trans_id_n;
			st_data_size_q <= st_data_size_n;
			amo_op_q <= amo_op_d;
		end
	initial _sv2v_0 = 0;
endmodule
module load_store_unit (
	clk_i,
	rst_ni,
	flush_i,
	no_st_pending_o,
	amo_valid_commit_i,
	fu_data_i,
	lsu_ready_o,
	lsu_valid_i,
	load_trans_id_o,
	load_result_o,
	load_valid_o,
	load_exception_o,
	store_trans_id_o,
	store_result_o,
	store_valid_o,
	store_exception_o,
	commit_i,
	commit_ready_o,
	enable_translation_i,
	en_ld_st_translation_i,
	icache_areq_i,
	icache_areq_o,
	priv_lvl_i,
	ld_st_priv_lvl_i,
	sum_i,
	mxr_i,
	satp_ppn_i,
	asid_i,
	flush_tlb_i,
	itlb_miss_o,
	dtlb_miss_o,
	dcache_req_ports_i,
	dcache_req_ports_o,
	amo_req_o,
	amo_resp_i
);
	reg _sv2v_0;
	parameter [31:0] ASID_WIDTH = 1;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	output wire no_st_pending_o;
	input wire amo_valid_commit_i;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [205:0] fu_data_i;
	output wire lsu_ready_o;
	input wire lsu_valid_i;
	output wire [2:0] load_trans_id_o;
	output wire [63:0] load_result_o;
	output wire load_valid_o;
	output wire [128:0] load_exception_o;
	output wire [2:0] store_trans_id_o;
	output wire [63:0] store_result_o;
	output wire store_valid_o;
	output wire [128:0] store_exception_o;
	input wire commit_i;
	output wire commit_ready_o;
	input wire enable_translation_i;
	input wire en_ld_st_translation_i;
	input wire [64:0] icache_areq_i;
	output wire [193:0] icache_areq_o;
	input wire [1:0] priv_lvl_i;
	input wire [1:0] ld_st_priv_lvl_i;
	input wire sum_i;
	input wire mxr_i;
	input wire [43:0] satp_ppn_i;
	input wire [ASID_WIDTH - 1:0] asid_i;
	input wire flush_tlb_i;
	output wire itlb_miss_o;
	output wire dtlb_miss_o;
	input wire [197:0] dcache_req_ports_i;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	output wire [(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (3 * ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78)) - 1 : (3 * (1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77))) + ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 76)):(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? 0 : (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77)] dcache_req_ports_o;
	output wire [134:0] amo_req_o;
	input wire [64:0] amo_resp_i;
	reg data_misaligned;
	wire [150:0] lsu_ctrl;
	wire pop_st;
	wire pop_ld;
	wire [63:0] vaddr_i;
	wire [7:0] be_i;
	assign vaddr_i = $unsigned($signed(fu_data_i[66-:64]) + $signed(fu_data_i[194-:64]));
	reg st_valid_i;
	reg ld_valid_i;
	wire ld_translation_req;
	wire st_translation_req;
	wire [63:0] ld_vaddr;
	wire [63:0] st_vaddr;
	reg translation_req;
	wire translation_valid;
	reg [63:0] mmu_vaddr;
	wire [63:0] mmu_paddr;
	wire [128:0] mmu_exception;
	wire dtlb_hit;
	wire ld_valid;
	wire [2:0] ld_trans_id;
	wire [63:0] ld_result;
	wire st_valid;
	wire [2:0] st_trans_id;
	wire [63:0] st_result;
	wire [11:0] page_offset;
	wire page_offset_matches;
	reg [128:0] misaligned_exception;
	wire [128:0] ld_ex;
	wire [128:0] st_ex;
	mmu #(
		.INSTR_TLB_ENTRIES(16),
		.DATA_TLB_ENTRIES(16),
		.ASID_WIDTH(ASID_WIDTH)
	) i_mmu(
		.misaligned_ex_i(misaligned_exception),
		.lsu_is_store_i(st_translation_req),
		.lsu_req_i(translation_req),
		.lsu_vaddr_i(mmu_vaddr),
		.lsu_valid_o(translation_valid),
		.lsu_paddr_o(mmu_paddr),
		.lsu_exception_o(mmu_exception),
		.lsu_dtlb_hit_o(dtlb_hit),
		.req_port_i(dcache_req_ports_i[0+:66]),
		.req_port_o(dcache_req_ports_o[(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? 0 : (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) + 0+:(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78 : 1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77))]),
		.icache_areq_i(icache_areq_i),
		.icache_areq_o(icache_areq_o),
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.enable_translation_i(enable_translation_i),
		.en_ld_st_translation_i(en_ld_st_translation_i),
		.priv_lvl_i(priv_lvl_i),
		.ld_st_priv_lvl_i(ld_st_priv_lvl_i),
		.sum_i(sum_i),
		.mxr_i(mxr_i),
		.satp_ppn_i(satp_ppn_i),
		.asid_i(asid_i),
		.flush_tlb_i(flush_tlb_i),
		.itlb_miss_o(itlb_miss_o),
		.dtlb_miss_o(dtlb_miss_o)
	);
	store_unit i_store_unit(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i),
		.no_st_pending_o(no_st_pending_o),
		.valid_i(st_valid_i),
		.lsu_ctrl_i(lsu_ctrl),
		.pop_st_o(pop_st),
		.commit_i(commit_i),
		.commit_ready_o(commit_ready_o),
		.amo_valid_commit_i(amo_valid_commit_i),
		.valid_o(st_valid),
		.trans_id_o(st_trans_id),
		.result_o(st_result),
		.ex_o(st_ex),
		.translation_req_o(st_translation_req),
		.vaddr_o(st_vaddr),
		.paddr_i(mmu_paddr),
		.ex_i(mmu_exception),
		.dtlb_hit_i(dtlb_hit),
		.page_offset_i(page_offset),
		.page_offset_matches_o(page_offset_matches),
		.amo_req_o(amo_req_o),
		.amo_resp_i(amo_resp_i),
		.req_port_i(dcache_req_ports_i[132+:66]),
		.req_port_o(dcache_req_ports_o[(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? 0 : (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) + (2 * (((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78 : 1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77)))+:(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78 : 1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77))])
	);
	load_unit i_load_unit(
		.valid_i(ld_valid_i),
		.lsu_ctrl_i(lsu_ctrl),
		.pop_ld_o(pop_ld),
		.valid_o(ld_valid),
		.trans_id_o(ld_trans_id),
		.result_o(ld_result),
		.ex_o(ld_ex),
		.translation_req_o(ld_translation_req),
		.vaddr_o(ld_vaddr),
		.paddr_i(mmu_paddr),
		.ex_i(mmu_exception),
		.dtlb_hit_i(dtlb_hit),
		.page_offset_o(page_offset),
		.page_offset_matches_i(page_offset_matches),
		.req_port_i(dcache_req_ports_i[66+:66]),
		.req_port_o(dcache_req_ports_o[(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? 0 : (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) + (((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78 : 1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77))+:(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78 : 1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77))]),
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i)
	);
	localparam ariane_pkg_NR_LOAD_PIPE_REGS = 1;
	pipe_reg_simple_218FF #(.Depth(ariane_pkg_NR_LOAD_PIPE_REGS)) i_pipe_reg_load(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.d_i({ld_valid, ld_trans_id, ld_result, ld_ex}),
		.d_o({load_valid_o, load_trans_id_o, load_result_o, load_exception_o})
	);
	localparam ariane_pkg_NR_STORE_PIPE_REGS = 0;
	pipe_reg_simple_218FF #(.Depth(ariane_pkg_NR_STORE_PIPE_REGS)) i_pipe_reg_store(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.d_i({st_valid, st_trans_id, st_result, st_ex}),
		.d_o({store_valid_o, store_trans_id_o, store_result_o, store_exception_o})
	);
	always @(*) begin : which_op
		if (_sv2v_0)
			;
		ld_valid_i = 1'b0;
		st_valid_i = 1'b0;
		translation_req = 1'b0;
		mmu_vaddr = 64'b0000000000000000000000000000000000000000000000000000000000000000;
		(* full_case, parallel_case *)
		case (lsu_ctrl[13-:4])
			4'd1: begin
				ld_valid_i = lsu_ctrl[150];
				translation_req = ld_translation_req;
				mmu_vaddr = ld_vaddr;
			end
			4'd2: begin
				st_valid_i = lsu_ctrl[150];
				translation_req = st_translation_req;
				mmu_vaddr = st_vaddr;
			end
			default:
				;
		endcase
	end
	function automatic [7:0] ariane_pkg_be_gen;
		input reg [2:0] addr;
		input reg [1:0] size;
		reg [1:0] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			case (size)
				2'b11: begin
					ariane_pkg_be_gen = 8'b11111111;
					_sv2v_jump = 2'b11;
				end
				2'b10:
					case (addr[2:0])
						3'b000: begin
							ariane_pkg_be_gen = 8'b00001111;
							_sv2v_jump = 2'b11;
						end
						3'b001: begin
							ariane_pkg_be_gen = 8'b00011110;
							_sv2v_jump = 2'b11;
						end
						3'b010: begin
							ariane_pkg_be_gen = 8'b00111100;
							_sv2v_jump = 2'b11;
						end
						3'b011: begin
							ariane_pkg_be_gen = 8'b01111000;
							_sv2v_jump = 2'b11;
						end
						3'b100: begin
							ariane_pkg_be_gen = 8'b11110000;
							_sv2v_jump = 2'b11;
						end
					endcase
				2'b01:
					case (addr[2:0])
						3'b000: begin
							ariane_pkg_be_gen = 8'b00000011;
							_sv2v_jump = 2'b11;
						end
						3'b001: begin
							ariane_pkg_be_gen = 8'b00000110;
							_sv2v_jump = 2'b11;
						end
						3'b010: begin
							ariane_pkg_be_gen = 8'b00001100;
							_sv2v_jump = 2'b11;
						end
						3'b011: begin
							ariane_pkg_be_gen = 8'b00011000;
							_sv2v_jump = 2'b11;
						end
						3'b100: begin
							ariane_pkg_be_gen = 8'b00110000;
							_sv2v_jump = 2'b11;
						end
						3'b101: begin
							ariane_pkg_be_gen = 8'b01100000;
							_sv2v_jump = 2'b11;
						end
						3'b110: begin
							ariane_pkg_be_gen = 8'b11000000;
							_sv2v_jump = 2'b11;
						end
					endcase
				2'b00:
					case (addr[2:0])
						3'b000: begin
							ariane_pkg_be_gen = 8'b00000001;
							_sv2v_jump = 2'b11;
						end
						3'b001: begin
							ariane_pkg_be_gen = 8'b00000010;
							_sv2v_jump = 2'b11;
						end
						3'b010: begin
							ariane_pkg_be_gen = 8'b00000100;
							_sv2v_jump = 2'b11;
						end
						3'b011: begin
							ariane_pkg_be_gen = 8'b00001000;
							_sv2v_jump = 2'b11;
						end
						3'b100: begin
							ariane_pkg_be_gen = 8'b00010000;
							_sv2v_jump = 2'b11;
						end
						3'b101: begin
							ariane_pkg_be_gen = 8'b00100000;
							_sv2v_jump = 2'b11;
						end
						3'b110: begin
							ariane_pkg_be_gen = 8'b01000000;
							_sv2v_jump = 2'b11;
						end
						3'b111: begin
							ariane_pkg_be_gen = 8'b10000000;
							_sv2v_jump = 2'b11;
						end
					endcase
			endcase
			if (_sv2v_jump == 2'b00) begin
				ariane_pkg_be_gen = 8'b00000000;
				_sv2v_jump = 2'b11;
			end
		end
	endfunction
	function automatic [1:0] ariane_pkg_extract_transfer_size;
		input reg [6:0] op;
		case (op)
			7'd34, 7'd35, 7'd80, 7'd84, 7'd46, 7'd48, 7'd58, 7'd59, 7'd60, 7'd61, 7'd62, 7'd63, 7'd64, 7'd65, 7'd66: ariane_pkg_extract_transfer_size = 2'b11;
			7'd36, 7'd37, 7'd38, 7'd81, 7'd85, 7'd45, 7'd47, 7'd49, 7'd50, 7'd51, 7'd52, 7'd53, 7'd54, 7'd55, 7'd56, 7'd57: ariane_pkg_extract_transfer_size = 2'b10;
			7'd39, 7'd40, 7'd41, 7'd82, 7'd86: ariane_pkg_extract_transfer_size = 2'b01;
			7'd42, 7'd44, 7'd43, 7'd83, 7'd87: ariane_pkg_extract_transfer_size = 2'b00;
			default: ariane_pkg_extract_transfer_size = 2'b11;
		endcase
	endfunction
	assign be_i = ariane_pkg_be_gen(vaddr_i[2:0], ariane_pkg_extract_transfer_size(fu_data_i[201-:7]));
	localparam [63:0] riscv_LD_ACCESS_FAULT = 5;
	localparam [63:0] riscv_LD_ADDR_MISALIGNED = 4;
	localparam [63:0] riscv_ST_ACCESS_FAULT = 7;
	localparam [63:0] riscv_ST_ADDR_MISALIGNED = 6;
	always @(*) begin : data_misaligned_detection
		if (_sv2v_0)
			;
		misaligned_exception = 129'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
		data_misaligned = 1'b0;
		if (lsu_ctrl[150])
			case (lsu_ctrl[9-:7])
				7'd34, 7'd35, 7'd80, 7'd84, 7'd46, 7'd48, 7'd58, 7'd59, 7'd60, 7'd61, 7'd62, 7'd63, 7'd64, 7'd65, 7'd66:
					if (lsu_ctrl[88:86] != 3'b000)
						data_misaligned = 1'b1;
				7'd36, 7'd37, 7'd38, 7'd81, 7'd85, 7'd45, 7'd47, 7'd49, 7'd50, 7'd51, 7'd52, 7'd53, 7'd54, 7'd55, 7'd56, 7'd57:
					if (lsu_ctrl[87:86] != 2'b00)
						data_misaligned = 1'b1;
				7'd39, 7'd40, 7'd41, 7'd82, 7'd86:
					if (lsu_ctrl[86] != 1'b0)
						data_misaligned = 1'b1;
				default:
					;
			endcase
		if (data_misaligned) begin
			if (lsu_ctrl[13-:4] == 4'd1)
				misaligned_exception = {riscv_LD_ADDR_MISALIGNED, lsu_ctrl[149-:64], 1'b1};
			else if (lsu_ctrl[13-:4] == 4'd2)
				misaligned_exception = {riscv_ST_ADDR_MISALIGNED, lsu_ctrl[149-:64], 1'b1};
		end
		if (en_ld_st_translation_i && !((&lsu_ctrl[149:124] == 1'b1) || (|lsu_ctrl[149:124] == 1'b0))) begin
			if (lsu_ctrl[13-:4] == 4'd1)
				misaligned_exception = {riscv_LD_ACCESS_FAULT, lsu_ctrl[149-:64], 1'b1};
			else if (lsu_ctrl[13-:4] == 4'd2)
				misaligned_exception = {riscv_ST_ACCESS_FAULT, lsu_ctrl[149-:64], 1'b1};
		end
	end
	wire [150:0] lsu_req_i;
	assign lsu_req_i = {lsu_valid_i, vaddr_i, fu_data_i[130-:64], be_i, fu_data_i[205-:4], fu_data_i[201-:7], fu_data_i[2-:ariane_pkg_TRANS_ID_BITS]};
	lsu_bypass lsu_bypass_i(
		.lsu_req_i(lsu_req_i),
		.lus_req_valid_i(lsu_valid_i),
		.pop_ld_i(pop_ld),
		.pop_st_i(pop_st),
		.lsu_ctrl_o(lsu_ctrl),
		.ready_o(lsu_ready_o),
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_i)
	);
	initial _sv2v_0 = 0;
endmodule
module lsu_bypass (
	clk_i,
	rst_ni,
	flush_i,
	lsu_req_i,
	lus_req_valid_i,
	pop_ld_i,
	pop_st_i,
	lsu_ctrl_o,
	ready_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [150:0] lsu_req_i;
	input wire lus_req_valid_i;
	input wire pop_ld_i;
	input wire pop_st_i;
	output reg [150:0] lsu_ctrl_o;
	output wire ready_o;
	reg [301:0] mem_n;
	reg [301:0] mem_q;
	reg read_pointer_n;
	reg read_pointer_q;
	reg write_pointer_n;
	reg write_pointer_q;
	reg [1:0] status_cnt_n;
	reg [1:0] status_cnt_q;
	wire empty;
	assign empty = status_cnt_q == 0;
	assign ready_o = empty;
	function automatic [150:0] sv2v_cast_20723;
		input reg [150:0] inp;
		sv2v_cast_20723 = inp;
	endfunction
	always @(*) begin : sv2v_autoblock_1
		reg [1:0] status_cnt;
		reg write_pointer;
		reg read_pointer;
		if (_sv2v_0)
			;
		status_cnt = status_cnt_q;
		write_pointer = write_pointer_q;
		read_pointer = read_pointer_q;
		mem_n = mem_q;
		if (lus_req_valid_i) begin
			mem_n[write_pointer_q * 151+:151] = lsu_req_i;
			write_pointer = write_pointer + 1;
			status_cnt = status_cnt + 1;
		end
		if (pop_ld_i) begin
			mem_n[(read_pointer_q * 151) + 150] = 1'b0;
			read_pointer = read_pointer + 1;
			status_cnt = status_cnt - 1;
		end
		if (pop_st_i) begin
			mem_n[(read_pointer_q * 151) + 150] = 1'b0;
			read_pointer = read_pointer + 1;
			status_cnt = status_cnt - 1;
		end
		if (pop_st_i && pop_ld_i)
			mem_n = {2 {sv2v_cast_20723(0)}};
		if (flush_i) begin
			status_cnt = 1'sb0;
			write_pointer = 1'sb0;
			read_pointer = 1'sb0;
			mem_n = {2 {sv2v_cast_20723(0)}};
		end
		read_pointer_n = read_pointer;
		write_pointer_n = write_pointer;
		status_cnt_n = status_cnt;
	end
	always @(*) begin : output_assignments
		if (_sv2v_0)
			;
		if (empty)
			lsu_ctrl_o = lsu_req_i;
		else
			lsu_ctrl_o = mem_q[read_pointer_q * 151+:151];
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			mem_q <= {2 {sv2v_cast_20723(0)}};
			status_cnt_q <= 1'sb0;
			write_pointer_q <= 1'sb0;
			read_pointer_q <= 1'sb0;
		end
		else begin
			mem_q <= mem_n;
			status_cnt_q <= status_cnt_n;
			write_pointer_q <= write_pointer_n;
			read_pointer_q <= read_pointer_n;
		end
	initial _sv2v_0 = 0;
endmodule
module ariane (
	clk_i,
	rst_ni,
	boot_addr_i,
	hart_id_i,
	irq_i,
	ipi_i,
	time_irq_i,
	debug_req_i,
	priv_lvl_o,
	umode_i,
	axi_req_o,
	axi_resp_i
);
	parameter [63:0] CachedAddrBeg = 64'h0000000080000000;
	input wire clk_i;
	input wire rst_ni;
	input wire [63:0] boot_addr_i;
	input wire [63:0] hart_id_i;
	input wire [1:0] irq_i;
	input wire ipi_i;
	input wire time_irq_i;
	input wire debug_req_i;
	output wire [1:0] priv_lvl_o;
	input wire umode_i;
	localparam ariane_axi_AddrWidth = 64;
	localparam ariane_axi_IdWidth = 4;
	localparam ariane_axi_DataWidth = 64;
	localparam ariane_axi_StrbWidth = 8;
	output wire [277:0] axi_req_o;
	input wire [81:0] axi_resp_i;
	wire [1:0] priv_lvl;
	wire [128:0] ex_commit;
	wire [133:0] resolved_branch;
	wire [63:0] pc_commit;
	wire eret;
	localparam ariane_pkg_NR_COMMIT_PORTS = 2;
	wire [1:0] commit_ack;
	wire [63:0] trap_vector_base_commit_pcgen;
	wire [63:0] epc_commit_pcgen;
	localparam [31:0] ariane_pkg_FETCH_WIDTH = 32;
	localparam [31:0] ariane_pkg_INSTR_PER_FETCH = 2;
	wire [166:0] fetch_entry_if_id;
	wire fetch_valid_if_id;
	wire decode_ack_id_if;
	localparam ariane_pkg_REG_ADDR_SIZE = 6;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	wire [361:0] issue_entry_id_issue;
	wire issue_entry_valid_id_issue;
	wire is_ctrl_fow_id_issue;
	wire issue_instr_issue_id;
	wire [205:0] fu_data_id_ex;
	wire [63:0] pc_id_ex;
	wire is_compressed_instr_id_ex;
	wire flu_ready_ex_id;
	wire [2:0] flu_trans_id_ex_id;
	wire flu_valid_ex_id;
	wire [63:0] flu_result_ex_id;
	wire [128:0] flu_exception_ex_id;
	wire alu_valid_id_ex;
	wire branch_valid_id_ex;
	wire [67:0] branch_predict_id_ex;
	wire resolve_branch_ex_id;
	wire lsu_valid_id_ex;
	wire lsu_ready_ex_id;
	wire [2:0] load_trans_id_ex_id;
	wire [63:0] load_result_ex_id;
	wire load_valid_ex_id;
	wire [128:0] load_exception_ex_id;
	wire [63:0] store_result_ex_id;
	wire [2:0] store_trans_id_ex_id;
	wire store_valid_ex_id;
	wire [128:0] store_exception_ex_id;
	wire mult_valid_id_ex;
	wire fpu_ready_ex_id;
	wire fpu_valid_id_ex;
	wire [1:0] fpu_fmt_id_ex;
	wire [2:0] fpu_rm_id_ex;
	wire [2:0] fpu_trans_id_ex_id;
	wire [63:0] fpu_result_ex_id;
	wire fpu_valid_ex_id;
	wire [128:0] fpu_exception_ex_id;
	wire csr_valid_id_ex;
	wire csr_commit_commit_ex;
	wire dirty_fp_state;
	wire lsu_commit_commit_ex;
	wire lsu_commit_ready_ex_commit;
	wire no_st_pending_ex;
	wire no_st_pending_commit;
	wire amo_valid_commit;
	wire [723:0] commit_instr_id_commit;
	wire [9:0] waddr_commit_id;
	wire [127:0] wdata_commit_id;
	wire [1:0] we_gpr_commit_id;
	wire [1:0] we_fpr_commit_id;
	wire [4:0] fflags_csr_commit;
	wire [1:0] fs;
	wire [2:0] frm_csr_id_issue_ex;
	wire [6:0] fprec_csr_ex;
	wire enable_translation_csr_ex;
	wire en_ld_st_translation_csr_ex;
	wire [1:0] ld_st_priv_lvl_csr_ex;
	wire sum_csr_ex;
	wire mxr_csr_ex;
	wire [43:0] satp_ppn_csr_ex;
	wire [0:0] asid_csr_ex;
	wire [11:0] csr_addr_ex_csr;
	wire [6:0] csr_op_commit_csr;
	wire [63:0] csr_wdata_commit_csr;
	wire [63:0] csr_rdata_csr_commit;
	wire [128:0] csr_exception_csr_commit;
	wire tvm_csr_id;
	wire tw_csr_id;
	wire tsr_csr_id;
	wire dcache_en_csr_nbdcache;
	wire csr_write_fflags_commit_cs;
	wire icache_en_csr;
	wire debug_mode;
	wire single_step_csr_commit;
	wire [11:0] addr_csr_perf;
	wire [63:0] data_csr_perf;
	wire [63:0] data_perf_csr;
	wire we_csr_perf;
	wire icache_flush_ctrl_cache;
	wire itlb_miss_ex_perf;
	wire dtlb_miss_ex_perf;
	wire dcache_miss_cache_perf;
	wire icache_miss_cache_perf;
	wire set_pc_ctrl_pcgen;
	wire flush_csr_ctrl;
	wire flush_unissued_instr_ctrl_id;
	wire flush_ctrl_if;
	wire flush_ctrl_id;
	wire flush_ctrl_ex;
	wire flush_tlb_ctrl_ex;
	wire fence_i_commit_controller;
	wire fence_commit_controller;
	wire sfence_vma_commit_controller;
	wire halt_ctrl;
	wire halt_csr_ctrl;
	wire dcache_flush_ctrl_cache;
	wire dcache_flush_ack_cache_ctrl;
	wire set_debug_pc;
	wire flush_commit;
	wire [193:0] icache_areq_ex_cache;
	wire [64:0] icache_areq_cache_ex;
	wire [66:0] icache_dreq_if_cache;
	wire [226:0] icache_dreq_cache_if;
	wire [134:0] amo_req;
	wire [64:0] amo_resp;
	wire sb_full;
	wire debug_req;
	assign debug_req = debug_req_i & ~amo_valid_commit;
	assign priv_lvl_o = priv_lvl;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	wire [(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (3 * ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78)) - 1 : (3 * (1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77))) + ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 76)):(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? 0 : (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77)] dcache_req_ports_ex_cache;
	wire [197:0] dcache_req_ports_cache_ex;
	wire dcache_commit_wbuffer_empty;
	frontend i_frontend(
		.flush_i(flush_ctrl_if),
		.flush_bp_i(1'b0),
		.debug_mode_i(debug_mode),
		.boot_addr_i(boot_addr_i),
		.icache_dreq_i(icache_dreq_cache_if),
		.icache_dreq_o(icache_dreq_if_cache),
		.resolved_branch_i(resolved_branch),
		.pc_commit_i(pc_commit),
		.set_pc_commit_i(set_pc_ctrl_pcgen),
		.set_debug_pc_i(set_debug_pc),
		.epc_i(epc_commit_pcgen),
		.eret_i(eret),
		.trap_vector_base_i(trap_vector_base_commit_pcgen),
		.ex_valid_i(ex_commit[0]),
		.fetch_entry_o(fetch_entry_if_id),
		.fetch_entry_valid_o(fetch_valid_if_id),
		.fetch_ack_i(decode_ack_id_if),
		.clk_i(clk_i),
		.rst_ni(rst_ni)
	);
	id_stage id_stage_i(
		.flush_i(flush_ctrl_if),
		.fetch_entry_i(fetch_entry_if_id),
		.fetch_entry_valid_i(fetch_valid_if_id),
		.decoded_instr_ack_o(decode_ack_id_if),
		.issue_entry_o(issue_entry_id_issue),
		.issue_entry_valid_o(issue_entry_valid_id_issue),
		.is_ctrl_flow_o(is_ctrl_fow_id_issue),
		.issue_instr_ack_i(issue_instr_issue_id),
		.priv_lvl_i(priv_lvl),
		.fs_i(fs),
		.frm_i(frm_csr_id_issue_ex),
		.debug_mode_i(debug_mode),
		.tvm_i(tvm_csr_id),
		.tw_i(tw_csr_id),
		.tsr_i(tsr_csr_id),
		.clk_i(clk_i),
		.rst_ni(rst_ni)
	);
	localparam ariane_pkg_NR_WB_PORTS = 4;
	issue_stage #(
		.NR_ENTRIES(ariane_pkg_NR_SB_ENTRIES),
		.NR_WB_PORTS(ariane_pkg_NR_WB_PORTS)
	) issue_stage_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.sb_full_o(sb_full),
		.flush_unissued_instr_i(flush_unissued_instr_ctrl_id),
		.flush_i(flush_ctrl_id),
		.decoded_instr_i(issue_entry_id_issue),
		.decoded_instr_valid_i(issue_entry_valid_id_issue),
		.is_ctrl_flow_i(is_ctrl_fow_id_issue),
		.decoded_instr_ack_o(issue_instr_issue_id),
		.fu_data_o(fu_data_id_ex),
		.pc_o(pc_id_ex),
		.is_compressed_instr_o(is_compressed_instr_id_ex),
		.flu_ready_i(flu_ready_ex_id),
		.alu_valid_o(alu_valid_id_ex),
		.branch_valid_o(branch_valid_id_ex),
		.branch_predict_o(branch_predict_id_ex),
		.resolve_branch_i(resolve_branch_ex_id),
		.lsu_ready_i(lsu_ready_ex_id),
		.lsu_valid_o(lsu_valid_id_ex),
		.mult_valid_o(mult_valid_id_ex),
		.fpu_ready_i(fpu_ready_ex_id),
		.fpu_valid_o(fpu_valid_id_ex),
		.fpu_fmt_o(fpu_fmt_id_ex),
		.fpu_rm_o(fpu_rm_id_ex),
		.csr_valid_o(csr_valid_id_ex),
		.resolved_branch_i(resolved_branch),
		.trans_id_i({flu_trans_id_ex_id, load_trans_id_ex_id, store_trans_id_ex_id, fpu_trans_id_ex_id}),
		.wbdata_i({flu_result_ex_id, load_result_ex_id, store_result_ex_id, fpu_result_ex_id}),
		.ex_ex_i({flu_exception_ex_id, load_exception_ex_id, store_exception_ex_id, fpu_exception_ex_id}),
		.wb_valid_i({flu_valid_ex_id, load_valid_ex_id, store_valid_ex_id, fpu_valid_ex_id}),
		.waddr_i(waddr_commit_id),
		.wdata_i(wdata_commit_id),
		.we_gpr_i(we_gpr_commit_id),
		.we_fpr_i(we_fpr_commit_id),
		.commit_instr_o(commit_instr_id_commit),
		.commit_ack_i(commit_ack)
	);
	ex_stage ex_stage_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_ctrl_ex),
		.fu_data_i(fu_data_id_ex),
		.pc_i(pc_id_ex),
		.is_compressed_instr_i(is_compressed_instr_id_ex),
		.flu_result_o(flu_result_ex_id),
		.flu_trans_id_o(flu_trans_id_ex_id),
		.flu_valid_o(flu_valid_ex_id),
		.flu_exception_o(flu_exception_ex_id),
		.flu_ready_o(flu_ready_ex_id),
		.alu_valid_i(alu_valid_id_ex),
		.branch_valid_i(branch_valid_id_ex),
		.branch_predict_i(branch_predict_id_ex),
		.resolved_branch_o(resolved_branch),
		.resolve_branch_o(resolve_branch_ex_id),
		.csr_valid_i(csr_valid_id_ex),
		.csr_addr_o(csr_addr_ex_csr),
		.csr_commit_i(csr_commit_commit_ex),
		.mult_valid_i(mult_valid_id_ex),
		.lsu_ready_o(lsu_ready_ex_id),
		.lsu_valid_i(lsu_valid_id_ex),
		.load_result_o(load_result_ex_id),
		.load_trans_id_o(load_trans_id_ex_id),
		.load_valid_o(load_valid_ex_id),
		.load_exception_o(load_exception_ex_id),
		.store_result_o(store_result_ex_id),
		.store_trans_id_o(store_trans_id_ex_id),
		.store_valid_o(store_valid_ex_id),
		.store_exception_o(store_exception_ex_id),
		.lsu_commit_i(lsu_commit_commit_ex),
		.lsu_commit_ready_o(lsu_commit_ready_ex_commit),
		.no_st_pending_o(no_st_pending_ex),
		.fpu_ready_o(fpu_ready_ex_id),
		.fpu_valid_i(fpu_valid_id_ex),
		.fpu_fmt_i(fpu_fmt_id_ex),
		.fpu_rm_i(fpu_rm_id_ex),
		.fpu_frm_i(frm_csr_id_issue_ex),
		.fpu_prec_i(fprec_csr_ex),
		.fpu_trans_id_o(fpu_trans_id_ex_id),
		.fpu_result_o(fpu_result_ex_id),
		.fpu_valid_o(fpu_valid_ex_id),
		.fpu_exception_o(fpu_exception_ex_id),
		.amo_valid_commit_i(amo_valid_commit),
		.amo_req_o(amo_req),
		.amo_resp_i(amo_resp),
		.itlb_miss_o(itlb_miss_ex_perf),
		.dtlb_miss_o(dtlb_miss_ex_perf),
		.enable_translation_i(enable_translation_csr_ex),
		.en_ld_st_translation_i(en_ld_st_translation_csr_ex),
		.flush_tlb_i(flush_tlb_ctrl_ex),
		.priv_lvl_i(priv_lvl),
		.ld_st_priv_lvl_i(ld_st_priv_lvl_csr_ex),
		.sum_i(sum_csr_ex),
		.mxr_i(mxr_csr_ex),
		.satp_ppn_i(satp_ppn_csr_ex),
		.asid_i(asid_csr_ex),
		.icache_areq_i(icache_areq_cache_ex),
		.icache_areq_o(icache_areq_ex_cache),
		.dcache_req_ports_i(dcache_req_ports_cache_ex),
		.dcache_req_ports_o(dcache_req_ports_ex_cache)
	);
	assign no_st_pending_commit = no_st_pending_ex & dcache_commit_wbuffer_empty;
	commit_stage commit_stage_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.halt_i(halt_ctrl),
		.flush_dcache_i(dcache_flush_ctrl_cache),
		.exception_o(ex_commit),
		.dirty_fp_state_o(dirty_fp_state),
		.debug_mode_i(debug_mode),
		.debug_req_i(debug_req),
		.single_step_i(single_step_csr_commit),
		.commit_instr_i(commit_instr_id_commit),
		.commit_ack_o(commit_ack),
		.no_st_pending_i(no_st_pending_commit),
		.waddr_o(waddr_commit_id),
		.wdata_o(wdata_commit_id),
		.we_gpr_o(we_gpr_commit_id),
		.we_fpr_o(we_fpr_commit_id),
		.commit_lsu_o(lsu_commit_commit_ex),
		.commit_lsu_ready_i(lsu_commit_ready_ex_commit),
		.amo_valid_commit_o(amo_valid_commit),
		.amo_resp_i(amo_resp),
		.commit_csr_o(csr_commit_commit_ex),
		.pc_o(pc_commit),
		.csr_op_o(csr_op_commit_csr),
		.csr_wdata_o(csr_wdata_commit_csr),
		.csr_rdata_i(csr_rdata_csr_commit),
		.csr_write_fflags_o(csr_write_fflags_commit_cs),
		.csr_exception_i(csr_exception_csr_commit),
		.fence_i_o(fence_i_commit_controller),
		.fence_o(fence_commit_controller),
		.sfence_vma_o(sfence_vma_commit_controller),
		.flush_commit_o(flush_commit)
	);
	localparam ariane_pkg_ASID_WIDTH = 1;
	csr_regfile #(.ASID_WIDTH(ariane_pkg_ASID_WIDTH)) csr_regfile_i(
		.flush_o(flush_csr_ctrl),
		.halt_csr_o(halt_csr_ctrl),
		.commit_instr_i(commit_instr_id_commit),
		.commit_ack_i(commit_ack),
		.ex_i(ex_commit),
		.csr_op_i(csr_op_commit_csr),
		.csr_write_fflags_i(csr_write_fflags_commit_cs),
		.dirty_fp_state_i(dirty_fp_state),
		.csr_addr_i(csr_addr_ex_csr),
		.csr_wdata_i(csr_wdata_commit_csr),
		.csr_rdata_o(csr_rdata_csr_commit),
		.pc_i(pc_commit),
		.csr_exception_o(csr_exception_csr_commit),
		.epc_o(epc_commit_pcgen),
		.eret_o(eret),
		.set_debug_pc_o(set_debug_pc),
		.trap_vector_base_o(trap_vector_base_commit_pcgen),
		.priv_lvl_o(priv_lvl),
		.fs_o(fs),
		.fflags_o(fflags_csr_commit),
		.frm_o(frm_csr_id_issue_ex),
		.fprec_o(fprec_csr_ex),
		.ld_st_priv_lvl_o(ld_st_priv_lvl_csr_ex),
		.en_translation_o(enable_translation_csr_ex),
		.en_ld_st_translation_o(en_ld_st_translation_csr_ex),
		.sum_o(sum_csr_ex),
		.mxr_o(mxr_csr_ex),
		.satp_ppn_o(satp_ppn_csr_ex),
		.asid_o(asid_csr_ex),
		.tvm_o(tvm_csr_id),
		.tw_o(tw_csr_id),
		.tsr_o(tsr_csr_id),
		.debug_mode_o(debug_mode),
		.single_step_o(single_step_csr_commit),
		.dcache_en_o(dcache_en_csr_nbdcache),
		.icache_en_o(icache_en_csr),
		.perf_addr_o(addr_csr_perf),
		.perf_data_o(data_csr_perf),
		.perf_data_i(data_perf_csr),
		.perf_we_o(we_csr_perf),
		.debug_req_i(debug_req),
		.umode_i(umode_i),
		.ipi_i(ipi_i),
		.irq_i(irq_i),
		.time_irq_i(time_irq_i),
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.boot_addr_i(boot_addr_i),
		.hart_id_i(hart_id_i)
	);
	perf_counters i_perf_counters(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.debug_mode_i(debug_mode),
		.addr_i(addr_csr_perf),
		.we_i(we_csr_perf),
		.data_i(data_csr_perf),
		.data_o(data_perf_csr),
		.commit_instr_i(commit_instr_id_commit),
		.commit_ack_i(commit_ack),
		.l1_icache_miss_i(icache_miss_cache_perf),
		.l1_dcache_miss_i(dcache_miss_cache_perf),
		.itlb_miss_i(itlb_miss_ex_perf),
		.dtlb_miss_i(dtlb_miss_ex_perf),
		.sb_full_i(sb_full),
		.if_empty_i(~fetch_valid_if_id),
		.ex_i(ex_commit),
		.eret_i(eret),
		.resolved_branch_i(resolved_branch)
	);
	controller controller_i(
		.set_pc_commit_o(set_pc_ctrl_pcgen),
		.flush_unissued_instr_o(flush_unissued_instr_ctrl_id),
		.flush_if_o(flush_ctrl_if),
		.flush_id_o(flush_ctrl_id),
		.flush_ex_o(flush_ctrl_ex),
		.flush_tlb_o(flush_tlb_ctrl_ex),
		.flush_dcache_o(dcache_flush_ctrl_cache),
		.flush_dcache_ack_i(dcache_flush_ack_cache_ctrl),
		.halt_csr_i(halt_csr_ctrl),
		.halt_o(halt_ctrl),
		.eret_i(eret),
		.ex_valid_i(ex_commit[0]),
		.set_debug_pc_i(set_debug_pc),
		.flush_csr_i(flush_csr_ctrl),
		.resolved_branch_i(resolved_branch),
		.fence_i_i(fence_i_commit_controller),
		.fence_i(fence_commit_controller),
		.sfence_vma_i(sfence_vma_commit_controller),
		.flush_commit_i(flush_commit),
		.flush_icache_o(icache_flush_ctrl_cache),
		.clk_i(clk_i),
		.rst_ni(rst_ni)
	);
	std_cache_subsystem #(.CACHE_START_ADDR(CachedAddrBeg)) i_cache_subsystem(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.priv_lvl_i(priv_lvl),
		.icache_en_i(icache_en_csr),
		.icache_flush_i(icache_flush_ctrl_cache),
		.icache_miss_o(icache_miss_cache_perf),
		.icache_areq_i(icache_areq_ex_cache),
		.icache_areq_o(icache_areq_cache_ex),
		.icache_dreq_i(icache_dreq_if_cache),
		.icache_dreq_o(icache_dreq_cache_if),
		.dcache_enable_i(dcache_en_csr_nbdcache),
		.dcache_flush_i(dcache_flush_ctrl_cache),
		.dcache_flush_ack_o(dcache_flush_ack_cache_ctrl),
		.amo_req_i(amo_req),
		.amo_resp_o(amo_resp),
		.dcache_miss_o(dcache_miss_cache_perf),
		.wbuffer_empty_o(dcache_commit_wbuffer_empty),
		.dcache_req_ports_i(dcache_req_ports_ex_cache),
		.dcache_req_ports_o(dcache_req_ports_cache_ex),
		.axi_req_o(axi_req_o),
		.axi_resp_i(axi_resp_i)
	);
`ifdef FORMAL
	reg [1:0] past_priv_lvl;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) past_priv_lvl <= 2'b0;
		else         past_priv_lvl <= priv_lvl;
	always @(posedge clk_i) begin
		if (rst_ni) begin
`ifdef FORMAL_P23
			HACK_DAC19_p23: assert (!(amo_valid_commit) || (flush_ctrl_if && flush_ctrl_id && flush_ctrl_ex));
`endif
`ifdef FORMAL_P26
			HACK_DAC19_p26: assert (!(priv_lvl != past_priv_lvl) || (flush_ctrl_if && flush_ctrl_id && flush_ctrl_ex));
`endif
		end
	end
`endif
endmodule
module stream_arbiter_3F5EB_FC9E1 (
	clk_i,
	rst_ni,
	inp_data_i,
	inp_valid_i,
	inp_ready_o,
	oup_data_o,
	oup_valid_o,
	oup_ready_i
);
	parameter signed [31:0] DATA_T_ariane_axi_AddrWidth = 0;
	parameter signed [31:0] DATA_T_ariane_axi_IdWidth = 0;
	parameter integer N_INP = 3;
	input wire clk_i;
	input wire rst_ni;
	input wire [(((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 28) >= 0 ? (N_INP * ((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 29)) - 1 : (N_INP * (1 - ((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 28))) + ((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 27)):(((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 28) >= 0 ? 0 : (DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 28)] inp_data_i;
	input wire [N_INP - 1:0] inp_valid_i;
	output wire [N_INP - 1:0] inp_ready_o;
	output wire [(DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 28:0] oup_data_o;
	output wire oup_valid_o;
	input wire oup_ready_i;
	wire [$clog2(N_INP) - 1:0] idx;
	rrarbiter #(
		.NUM_REQ(N_INP),
		.LOCK_IN(1)
	) i_arbiter(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(1'b0),
		.en_i(oup_ready_i),
		.req_i(inp_valid_i),
		.ack_o(inp_ready_o),
		.vld_o(),
		.idx_o(idx)
	);
	assign oup_valid_o = |inp_valid_i;
	assign oup_data_o = inp_data_i[(((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 28) >= 0 ? 0 : (DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 28) + (idx * (((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 28) >= 0 ? (DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 29 : 1 - ((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 28)))+:(((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 28) >= 0 ? (DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 29 : 1 - ((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 28))];
endmodule
module stream_arbiter_EF48E_89DDB (
	clk_i,
	rst_ni,
	inp_data_i,
	inp_valid_i,
	inp_ready_o,
	oup_data_o,
	oup_valid_o,
	oup_ready_i
);
	parameter signed [31:0] DATA_T_ariane_axi_AddrWidth = 0;
	parameter signed [31:0] DATA_T_ariane_axi_IdWidth = 0;
	parameter integer N_INP = 3;
	input wire clk_i;
	input wire rst_ni;
	input wire [(((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 34) >= 0 ? (N_INP * ((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 35)) - 1 : (N_INP * (1 - ((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 34))) + ((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 33)):(((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 34) >= 0 ? 0 : (DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 34)] inp_data_i;
	input wire [N_INP - 1:0] inp_valid_i;
	output wire [N_INP - 1:0] inp_ready_o;
	output wire [(DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 34:0] oup_data_o;
	output wire oup_valid_o;
	input wire oup_ready_i;
	wire [$clog2(N_INP) - 1:0] idx;
	rrarbiter #(
		.NUM_REQ(N_INP),
		.LOCK_IN(1)
	) i_arbiter(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(1'b0),
		.en_i(oup_ready_i),
		.req_i(inp_valid_i),
		.ack_o(inp_ready_o),
		.vld_o(),
		.idx_o(idx)
	);
	assign oup_valid_o = |inp_valid_i;
	assign oup_data_o = inp_data_i[(((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 34) >= 0 ? 0 : (DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 34) + (idx * (((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 34) >= 0 ? (DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 35 : 1 - ((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 34)))+:(((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 34) >= 0 ? (DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 35 : 1 - ((DATA_T_ariane_axi_IdWidth + DATA_T_ariane_axi_AddrWidth) + 34))];
endmodule
module stream_mux_E5853_401C6 (
	inp_data_i,
	inp_valid_i,
	inp_ready_o,
	inp_sel_i,
	oup_data_o,
	oup_valid_o,
	oup_ready_i
);
	parameter signed [31:0] DATA_T_ariane_axi_DataWidth = 0;
	parameter signed [31:0] DATA_T_ariane_axi_StrbWidth = 0;
	reg _sv2v_0;
	parameter integer N_INP = 3;
	localparam integer LOG_N_INP = $clog2(N_INP);
	input wire [(((DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 0) >= 0 ? (N_INP * ((DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 1)) - 1 : (N_INP * (1 - ((DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 0))) + ((DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) - 1)):(((DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 0) >= 0 ? 0 : (DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 0)] inp_data_i;
	input wire [N_INP - 1:0] inp_valid_i;
	output reg [N_INP - 1:0] inp_ready_o;
	input wire [LOG_N_INP - 1:0] inp_sel_i;
	output wire [(DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 0:0] oup_data_o;
	output wire oup_valid_o;
	input wire oup_ready_i;
	always @(*) begin
		if (_sv2v_0)
			;
		inp_ready_o = 1'sb0;
		inp_ready_o[inp_sel_i] = oup_ready_i;
	end
	assign oup_data_o = inp_data_i[(((DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 0) >= 0 ? 0 : (DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 0) + (inp_sel_i * (((DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 0) >= 0 ? (DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 1 : 1 - ((DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 0)))+:(((DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 0) >= 0 ? (DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 1 : 1 - ((DATA_T_ariane_axi_DataWidth + DATA_T_ariane_axi_StrbWidth) + 0))];
	assign oup_valid_o = inp_valid_i[inp_sel_i];
	initial _sv2v_0 = 0;
endmodule
module stream_demux (
	inp_valid_i,
	inp_ready_o,
	oup_sel_i,
	oup_valid_o,
	oup_ready_i
);
	reg _sv2v_0;
	parameter integer N_OUP = 1;
	localparam integer LOG_N_OUP = $clog2(N_OUP);
	input wire inp_valid_i;
	output wire inp_ready_o;
	input wire [LOG_N_OUP - 1:0] oup_sel_i;
	output reg [N_OUP - 1:0] oup_valid_o;
	input wire [N_OUP - 1:0] oup_ready_i;
	always @(*) begin
		if (_sv2v_0)
			;
		oup_valid_o = 1'sb0;
		oup_valid_o[oup_sel_i] = inp_valid_i;
	end
	assign inp_ready_o = oup_ready_i[oup_sel_i];
	initial _sv2v_0 = 0;
endmodule
module std_cache_subsystem (
	clk_i,
	rst_ni,
	priv_lvl_i,
	icache_en_i,
	icache_flush_i,
	icache_miss_o,
	icache_areq_i,
	icache_areq_o,
	icache_dreq_i,
	icache_dreq_o,
	amo_req_i,
	amo_resp_o,
	dcache_enable_i,
	dcache_flush_i,
	dcache_flush_ack_o,
	dcache_miss_o,
	wbuffer_empty_o,
	dcache_req_ports_i,
	dcache_req_ports_o,
	axi_req_o,
	axi_resp_i
);
	reg _sv2v_0;
	parameter [63:0] CACHE_START_ADDR = 64'h0000000040000000;
	input wire clk_i;
	input wire rst_ni;
	input wire [1:0] priv_lvl_i;
	input wire icache_en_i;
	input wire icache_flush_i;
	output wire icache_miss_o;
	input wire [193:0] icache_areq_i;
	output wire [64:0] icache_areq_o;
	input wire [66:0] icache_dreq_i;
	localparam [31:0] ariane_pkg_FETCH_WIDTH = 32;
	output wire [226:0] icache_dreq_o;
	input wire [134:0] amo_req_i;
	output wire [64:0] amo_resp_o;
	input wire dcache_enable_i;
	input wire dcache_flush_i;
	output wire dcache_flush_ack_o;
	output wire dcache_miss_o;
	output wire wbuffer_empty_o;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	input wire [(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (3 * ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78)) - 1 : (3 * (1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77))) + ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 76)):(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? 0 : (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77)] dcache_req_ports_i;
	output wire [197:0] dcache_req_ports_o;
	localparam ariane_axi_AddrWidth = 64;
	localparam ariane_axi_IdWidth = 4;
	localparam ariane_axi_DataWidth = 64;
	localparam ariane_axi_StrbWidth = 8;
	output wire [277:0] axi_req_o;
	input wire [81:0] axi_resp_i;
	assign wbuffer_empty_o = 1'b1;
	wire [277:0] axi_req_icache;
	wire [81:0] axi_resp_icache;
	wire [277:0] axi_req_bypass;
	wire [81:0] axi_resp_bypass;
	wire [277:0] axi_req_data;
	wire [81:0] axi_resp_data;
	std_icache i_icache(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.priv_lvl_i(priv_lvl_i),
		.flush_i(icache_flush_i),
		.en_i(icache_en_i),
		.miss_o(icache_miss_o),
		.areq_i(icache_areq_i),
		.areq_o(icache_areq_o),
		.dreq_i(icache_dreq_i),
		.dreq_o(icache_dreq_o),
		.axi_req_o(axi_req_icache),
		.axi_resp_i(axi_resp_icache)
	);
	std_nbdcache #(.CACHE_START_ADDR(CACHE_START_ADDR)) i_nbdcache(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.enable_i(dcache_enable_i),
		.flush_i(dcache_flush_i),
		.flush_ack_o(dcache_flush_ack_o),
		.miss_o(dcache_miss_o),
		.axi_bypass_o(axi_req_bypass),
		.axi_bypass_i(axi_resp_bypass),
		.axi_data_o(axi_req_data),
		.axi_data_i(axi_resp_data),
		.req_ports_i(dcache_req_ports_i),
		.req_ports_o(dcache_req_ports_o),
		.amo_req_i(amo_req_i),
		.amo_resp_o(amo_resp_o)
	);
	reg [1:0] w_select;
	wire [1:0] w_select_fifo;
	wire [1:0] w_select_arbiter;
	wire w_fifo_empty;
	stream_arbiter_3F5EB_FC9E1 #(
		.DATA_T_ariane_axi_AddrWidth(ariane_axi_AddrWidth),
		.DATA_T_ariane_axi_IdWidth(ariane_axi_IdWidth),
		.N_INP(3)
	) i_stream_arbiter_ar(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.inp_data_i({axi_req_icache[98-:97], axi_req_bypass[98-:97], axi_req_data[98-:97]}),
		.inp_valid_i({axi_req_icache[1], axi_req_bypass[1], axi_req_data[1]}),
		.inp_ready_o({axi_resp_icache[80], axi_resp_bypass[80], axi_resp_data[80]}),
		.oup_data_o(axi_req_o[98-:97]),
		.oup_valid_o(axi_req_o[1]),
		.oup_ready_i(axi_resp_i[80])
	);
	stream_arbiter_EF48E_89DDB #(
		.DATA_T_ariane_axi_AddrWidth(ariane_axi_AddrWidth),
		.DATA_T_ariane_axi_IdWidth(ariane_axi_IdWidth),
		.N_INP(3)
	) i_stream_arbiter_aw(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.inp_data_i({axi_req_icache[277-:103], axi_req_bypass[277-:103], axi_req_data[277-:103]}),
		.inp_valid_i({axi_req_icache[174], axi_req_bypass[174], axi_req_data[174]}),
		.inp_ready_o({axi_resp_icache[81], axi_resp_bypass[81], axi_resp_data[81]}),
		.oup_data_o(axi_req_o[277-:103]),
		.oup_valid_o(axi_req_o[174]),
		.oup_ready_i(axi_resp_i[81])
	);
	always @(*) begin
		if (_sv2v_0)
			;
		w_select = 0;
		(* full_case, parallel_case *)
		case (axi_req_o[277-:4])
			4'b1100: w_select = 2;
			4'b1000, 4'b1001, 4'b1010, 4'b1011: w_select = 1;
			default: w_select = 0;
		endcase
	end
	fifo_v3 #(
		.DATA_WIDTH(2),
		.DEPTH(4)
	) i_fifo_w_channel(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(1'b0),
		.testmode_i(1'b0),
		.full_o(),
		.empty_o(w_fifo_empty),
		.usage_o(),
		.data_i(w_select),
		.push_i(axi_req_o[174] & axi_resp_i[81]),
		.data_o(w_select_fifo),
		.pop_i((axi_req_o[100] & axi_resp_i[79]) & axi_req_o[101])
	);
	assign w_select_arbiter = (w_fifo_empty ? 0 : w_select_fifo);
	stream_mux_E5853_401C6 #(
		.DATA_T_ariane_axi_DataWidth(ariane_axi_DataWidth),
		.DATA_T_ariane_axi_StrbWidth(ariane_axi_StrbWidth),
		.N_INP(3)
	) i_stream_mux_w(
		.inp_data_i({axi_req_data[173-:73], axi_req_bypass[173-:73], axi_req_icache[173-:73]}),
		.inp_valid_i({axi_req_data[100], axi_req_bypass[100], axi_req_icache[100]}),
		.inp_ready_o({axi_resp_data[79], axi_resp_bypass[79], axi_resp_icache[79]}),
		.inp_sel_i(w_select_arbiter),
		.oup_data_o(axi_req_o[173-:73]),
		.oup_valid_o(axi_req_o[100]),
		.oup_ready_i(axi_resp_i[79])
	);
	assign axi_resp_icache[70-:71] = axi_resp_i[70-:71];
	assign axi_resp_bypass[70-:71] = axi_resp_i[70-:71];
	assign axi_resp_data[70-:71] = axi_resp_i[70-:71];
	reg [1:0] r_select;
	always @(*) begin
		if (_sv2v_0)
			;
		r_select = 0;
		(* full_case, parallel_case *)
		case (axi_resp_i[70-:4])
			4'b1100: r_select = 0;
			4'b1000, 4'b1001, 4'b1010, 4'b1011: r_select = 1;
			4'b0000: r_select = 2;
			default: r_select = 0;
		endcase
	end
	stream_demux #(.N_OUP(3)) i_stream_demux_r(
		.inp_valid_i(axi_resp_i[71]),
		.inp_ready_o(axi_req_o[0]),
		.oup_sel_i(r_select),
		.oup_valid_o({axi_resp_icache[71], axi_resp_bypass[71], axi_resp_data[71]}),
		.oup_ready_i({axi_req_icache[0], axi_req_bypass[0], axi_req_data[0]})
	);
	reg [1:0] b_select;
	assign axi_resp_icache[77-:6] = axi_resp_i[77-:6];
	assign axi_resp_bypass[77-:6] = axi_resp_i[77-:6];
	assign axi_resp_data[77-:6] = axi_resp_i[77-:6];
	always @(*) begin
		if (_sv2v_0)
			;
		b_select = 0;
		(* full_case, parallel_case *)
		case (axi_resp_i[77-:4])
			4'b1100: b_select = 0;
			4'b1000, 4'b1001, 4'b1010, 4'b1011: b_select = 1;
			4'b0000: b_select = 2;
			default: b_select = 0;
		endcase
	end
	stream_demux #(.N_OUP(3)) i_stream_demux_b(
		.inp_valid_i(axi_resp_i[78]),
		.inp_ready_o(axi_req_o[99]),
		.oup_sel_i(b_select),
		.oup_valid_o({axi_resp_icache[78], axi_resp_bypass[78], axi_resp_data[78]}),
		.oup_ready_i({axi_req_icache[99], axi_req_bypass[99], axi_req_data[99]})
	);
	initial _sv2v_0 = 0;
endmodule
module std_icache (
	clk_i,
	rst_ni,
	priv_lvl_i,
	flush_i,
	en_i,
	miss_o,
	areq_i,
	areq_o,
	dreq_i,
	dreq_o,
	axi_req_o,
	axi_resp_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire [1:0] priv_lvl_i;
	input wire flush_i;
	input wire en_i;
	output reg miss_o;
	input wire [193:0] areq_i;
	output reg [64:0] areq_o;
	input wire [66:0] dreq_i;
	localparam [31:0] ariane_pkg_FETCH_WIDTH = 32;
	output reg [226:0] dreq_o;
	localparam ariane_axi_AddrWidth = 64;
	localparam ariane_axi_IdWidth = 4;
	localparam ariane_axi_DataWidth = 64;
	localparam ariane_axi_StrbWidth = 8;
	output reg [277:0] axi_req_o;
	input wire [81:0] axi_resp_i;
	localparam [31:0] ariane_pkg_ICACHE_LINE_WIDTH = 128;
	localparam [31:0] ICACHE_BYTE_OFFSET = 4;
	localparam [31:0] ariane_pkg_ICACHE_INDEX_WIDTH = 12;
	localparam [31:0] ICACHE_NUM_WORD = 2 ** (ariane_pkg_ICACHE_INDEX_WIDTH - ICACHE_BYTE_OFFSET);
	localparam [31:0] NR_AXI_REFILLS = 1;
	reg [3:0] state_d;
	reg [3:0] state_q;
	reg [$clog2(ICACHE_NUM_WORD) - 1:0] cnt_d;
	reg [$clog2(ICACHE_NUM_WORD) - 1:0] cnt_q;
	reg [0:0] burst_cnt_d;
	reg [0:0] burst_cnt_q;
	reg [63:0] vaddr_d;
	reg [63:0] vaddr_q;
	localparam [31:0] ariane_pkg_ICACHE_TAG_WIDTH = 44;
	reg [43:0] tag_d;
	reg [43:0] tag_q;
	localparam [31:0] ariane_pkg_ICACHE_SET_ASSOC = 4;
	reg [3:0] evict_way_d;
	reg [3:0] evict_way_q;
	reg flushing_d;
	reg flushing_q;
	reg [3:0] req;
	reg [3:0] vld_req;
	wire [15:0] data_be;
	reg [15:0] be;
	wire [$clog2(ICACHE_NUM_WORD) - 1:0] addr;
	reg we;
	wire [3:0] hit;
	wire [$clog2(ICACHE_NUM_WORD) - 1:0] idx;
	reg update_lfsr;
	wire [3:0] random_way;
	wire [3:0] way_valid;
	wire [1:0] repl_invalid;
	wire repl_w_random;
	reg [43:0] tag;
	wire [44:0] tag_rdata [3:0];
	reg [44:0] tag_wdata;
	wire [127:0] data_rdata [3:0];
	wire [127:0] data_wdata;
	reg [127:0] wdata;
	genvar _gv_i_3;
	generate
		for (_gv_i_3 = 0; _gv_i_3 < ariane_pkg_ICACHE_SET_ASSOC; _gv_i_3 = _gv_i_3 + 1) begin : sram_block
			localparam i = _gv_i_3;
			localparam sv2v_uu_tag_sram_DATA_WIDTH = 45;
			localparam [5:0] sv2v_uu_tag_sram_ext_be_i_1 = 1'sb1;
			sram #(
				.DATA_WIDTH(45),
				.NUM_WORDS(ICACHE_NUM_WORD)
			) tag_sram(
				.clk_i(clk_i),
				.rst_ni(rst_ni),
				.req_i(vld_req[i]),
				.we_i(we),
				.addr_i(addr),
				.wdata_i(tag_wdata),
				.be_i(sv2v_uu_tag_sram_ext_be_i_1),
				.rdata_o(tag_rdata[i])
			);
			sram #(
				.DATA_WIDTH(ariane_pkg_ICACHE_LINE_WIDTH),
				.NUM_WORDS(ICACHE_NUM_WORD)
			) data_sram(
				.clk_i(clk_i),
				.rst_ni(rst_ni),
				.req_i(req[i]),
				.we_i(we),
				.addr_i(addr),
				.wdata_i(data_wdata),
				.be_i(data_be),
				.rdata_o(data_rdata[i])
			);
		end
	endgenerate
	wire [(ariane_pkg_ICACHE_SET_ASSOC * ariane_pkg_FETCH_WIDTH) - 1:0] cl_sel;
	assign idx = vaddr_q[3:2];
	genvar _gv_i_4;
	generate
		for (_gv_i_4 = 0; _gv_i_4 < ariane_pkg_ICACHE_SET_ASSOC; _gv_i_4 = _gv_i_4 + 1) begin : g_tag_cmpsel
			localparam i = _gv_i_4;
			assign hit[i] = (tag_rdata[i][43-:ariane_pkg_ICACHE_TAG_WIDTH] == tag ? tag_rdata[i][44] : 1'b0);
			assign cl_sel[i * ariane_pkg_FETCH_WIDTH+:ariane_pkg_FETCH_WIDTH] = (hit[i] ? data_rdata[i][{idx, 5'b00000}+:ariane_pkg_FETCH_WIDTH] : {32 {1'sb0}});
			assign way_valid[i] = tag_rdata[i][44];
		end
	endgenerate
	always @(*) begin : p_reduction
		if (_sv2v_0)
			;
		dreq_o[224-:32] = cl_sel[0+:ariane_pkg_FETCH_WIDTH];
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 1; i < ariane_pkg_ICACHE_SET_ASSOC; i = i + 1)
				dreq_o[224-:32] = dreq_o[224-:32] | cl_sel[i * ariane_pkg_FETCH_WIDTH+:ariane_pkg_FETCH_WIDTH];
		end
	end
	wire [1:1] sv2v_tmp_2FA0A;
	assign sv2v_tmp_2FA0A = 1'sb0;
	always @(*) axi_req_o[174] = sv2v_tmp_2FA0A;
	wire [64:1] sv2v_tmp_BD572;
	assign sv2v_tmp_BD572 = 1'sb0;
	always @(*) axi_req_o[273-:64] = sv2v_tmp_BD572;
	wire [3:1] sv2v_tmp_ADBA3;
	assign sv2v_tmp_ADBA3 = 1'sb0;
	always @(*) axi_req_o[191-:3] = sv2v_tmp_ADBA3;
	wire [4:1] sv2v_tmp_3D38A;
	assign sv2v_tmp_3D38A = 1'sb0;
	always @(*) axi_req_o[184-:4] = sv2v_tmp_3D38A;
	wire [8:1] sv2v_tmp_6426F;
	assign sv2v_tmp_6426F = 1'sb0;
	always @(*) axi_req_o[209-:8] = sv2v_tmp_6426F;
	wire [3:1] sv2v_tmp_1D56B;
	assign sv2v_tmp_1D56B = 3'b000;
	always @(*) axi_req_o[201-:3] = sv2v_tmp_1D56B;
	wire [2:1] sv2v_tmp_445FC;
	assign sv2v_tmp_445FC = 2'b00;
	always @(*) axi_req_o[198-:2] = sv2v_tmp_445FC;
	wire [1:1] sv2v_tmp_9CAD9;
	assign sv2v_tmp_9CAD9 = 1'sb0;
	always @(*) axi_req_o[196] = sv2v_tmp_9CAD9;
	wire [4:1] sv2v_tmp_D198A;
	assign sv2v_tmp_D198A = 1'sb0;
	always @(*) axi_req_o[195-:4] = sv2v_tmp_D198A;
	wire [4:1] sv2v_tmp_D4A36;
	assign sv2v_tmp_D4A36 = 1'sb0;
	always @(*) axi_req_o[188-:4] = sv2v_tmp_D4A36;
	wire [4:1] sv2v_tmp_6673C;
	assign sv2v_tmp_6673C = 1'sb0;
	always @(*) axi_req_o[277-:4] = sv2v_tmp_6673C;
	wire [6:1] sv2v_tmp_EA2C8;
	assign sv2v_tmp_EA2C8 = 1'sb0;
	always @(*) axi_req_o[180-:6] = sv2v_tmp_EA2C8;
	wire [1:1] sv2v_tmp_74B92;
	assign sv2v_tmp_74B92 = 1'sb0;
	always @(*) axi_req_o[100] = sv2v_tmp_74B92;
	wire [64:1] sv2v_tmp_A9FD0;
	assign sv2v_tmp_A9FD0 = 1'sb0;
	always @(*) axi_req_o[173-:64] = sv2v_tmp_A9FD0;
	wire [8:1] sv2v_tmp_BD298;
	assign sv2v_tmp_BD298 = 1'sb0;
	always @(*) axi_req_o[109-:8] = sv2v_tmp_BD298;
	wire [1:1] sv2v_tmp_146D2;
	assign sv2v_tmp_146D2 = 1'b0;
	always @(*) axi_req_o[101] = sv2v_tmp_146D2;
	wire [1:1] sv2v_tmp_BACE7;
	assign sv2v_tmp_BACE7 = 1'b0;
	always @(*) axi_req_o[99] = sv2v_tmp_BACE7;
	wire [3:1] sv2v_tmp_25614;
	assign sv2v_tmp_25614 = {2'b10, priv_lvl_i == 2'b11};
	always @(*) axi_req_o[12-:3] = sv2v_tmp_25614;
	wire [4:1] sv2v_tmp_C4175;
	assign sv2v_tmp_C4175 = 1'sb0;
	always @(*) axi_req_o[5-:4] = sv2v_tmp_C4175;
	wire [8:1] sv2v_tmp_7C248;
	assign sv2v_tmp_7C248 = 1;
	always @(*) axi_req_o[30-:8] = sv2v_tmp_7C248;
	wire [3:1] sv2v_tmp_6B7B9;
	assign sv2v_tmp_6B7B9 = 3'b011;
	always @(*) axi_req_o[22-:3] = sv2v_tmp_6B7B9;
	wire [2:1] sv2v_tmp_7D83A;
	assign sv2v_tmp_7D83A = 2'b01;
	always @(*) axi_req_o[19-:2] = sv2v_tmp_7D83A;
	wire [1:1] sv2v_tmp_19F02;
	assign sv2v_tmp_19F02 = 1'sb0;
	always @(*) axi_req_o[17] = sv2v_tmp_19F02;
	wire [4:1] sv2v_tmp_D14C8;
	assign sv2v_tmp_D14C8 = 1'sb0;
	always @(*) axi_req_o[16-:4] = sv2v_tmp_D14C8;
	wire [4:1] sv2v_tmp_5B8C2;
	assign sv2v_tmp_5B8C2 = 1'sb0;
	always @(*) axi_req_o[9-:4] = sv2v_tmp_5B8C2;
	wire [4:1] sv2v_tmp_F5BAA;
	assign sv2v_tmp_F5BAA = 1'sb0;
	always @(*) axi_req_o[98-:4] = sv2v_tmp_F5BAA;
	wire [1:1] sv2v_tmp_BC354;
	assign sv2v_tmp_BC354 = 1'b1;
	always @(*) axi_req_o[0] = sv2v_tmp_BC354;
	assign data_be = be;
	assign data_wdata = wdata;
	wire [129:1] sv2v_tmp_1B0FC;
	assign sv2v_tmp_1B0FC = areq_i[128-:129];
	always @(*) dreq_o[128-:129] = sv2v_tmp_1B0FC;
	assign addr = (state_q == 4'd0 ? cnt_q : vaddr_d[11:ICACHE_BYTE_OFFSET]);
	always @(*) begin : cache_ctrl
		if (_sv2v_0)
			;
		state_d = state_q;
		cnt_d = cnt_q;
		vaddr_d = vaddr_q;
		tag_d = tag_q;
		evict_way_d = evict_way_q;
		flushing_d = flushing_q;
		burst_cnt_d = burst_cnt_q;
		dreq_o[192-:64] = vaddr_q;
		req = 1'sb0;
		vld_req = 1'sb0;
		we = 1'b0;
		be = 1'sb0;
		wdata = 1'sb0;
		tag_wdata = 1'sb0;
		dreq_o[226] = 1'b0;
		tag = areq_i[128 + (ariane_pkg_ICACHE_TAG_WIDTH + ariane_pkg_ICACHE_INDEX_WIDTH):141];
		dreq_o[225] = 1'b0;
		update_lfsr = 1'b0;
		miss_o = 1'b0;
		axi_req_o[1] = 1'b0;
		axi_req_o[94-:64] = 1'sb0;
		areq_o[64] = 1'b0;
		areq_o[63-:64] = vaddr_q;
		case (state_q)
			4'd1: begin
				dreq_o[226] = 1'b1;
				vaddr_d = dreq_i[63-:64];
				if (dreq_i[66]) begin
					req = 1'sb1;
					vld_req = 1'sb1;
					state_d = 4'd2;
				end
				if (flush_i || flushing_q)
					state_d = 4'd0;
				if (dreq_i[65])
					state_d = 4'd1;
			end
			4'd2, 4'd7: begin
				areq_o[64] = 1'b1;
				req = 1'sb1;
				vld_req = 1'sb1;
				if (state_q == 4'd7)
					tag = tag_q;
				if ((|hit && areq_i[193]) && (en_i || (state_q != 4'd2))) begin
					dreq_o[226] = 1'b1;
					dreq_o[225] = 1'b1;
					vaddr_d = dreq_i[63-:64];
					if (dreq_i[66])
						state_d = 4'd2;
					else
						state_d = 4'd1;
					if (dreq_i[65])
						state_d = 4'd1;
				end
				else begin
					state_d = 4'd8;
					evict_way_d = hit;
					tag_d = areq_i[128 + (ariane_pkg_ICACHE_TAG_WIDTH + ariane_pkg_ICACHE_INDEX_WIDTH):141];
					miss_o = en_i;
					if (!(|hit)) begin
						if (repl_w_random) begin
							evict_way_d = random_way;
							update_lfsr = 1'b1;
						end
						else
							evict_way_d[repl_invalid] = 1'b1;
					end
				end
				if (!areq_i[193])
					state_d = 4'd9;
			end
			4'd9, 4'd10: begin
				areq_o[64] = 1'b1;
				if (areq_i[193] && (state_q == 4'd9)) begin
					if (areq_i[0]) begin
						dreq_o[225] = 1'b1;
						state_d = 4'd1;
					end
					else begin
						state_d = 4'd6;
						tag_d = areq_i[128 + (ariane_pkg_ICACHE_TAG_WIDTH + ariane_pkg_ICACHE_INDEX_WIDTH):141];
					end
				end
				else if (areq_i[193])
					state_d = 4'd1;
				if (dreq_i[64])
					state_d = 4'd10;
			end
			4'd8, 4'd4: begin
				axi_req_o[1] = 1'b1;
				axi_req_o[30 + (ariane_pkg_ICACHE_INDEX_WIDTH + ariane_pkg_ICACHE_TAG_WIDTH):31] = {tag_q, vaddr_q[11:ICACHE_BYTE_OFFSET], {ICACHE_BYTE_OFFSET {1'b0}}};
				burst_cnt_d = 1'sb0;
				if (dreq_i[64])
					state_d = 4'd4;
				if (axi_resp_i[80])
					state_d = (dreq_i[64] || (state_q == 4'd4) ? 4'd5 : 4'd3);
			end
			4'd3, 4'd5: begin
				req = evict_way_q;
				vld_req = evict_way_q;
				if (axi_resp_i[71]) begin
					we = 1'b1;
					tag_wdata[43-:ariane_pkg_ICACHE_TAG_WIDTH] = tag_q;
					tag_wdata[44] = 1'b1;
					wdata[burst_cnt_q * 64+:64] = axi_resp_i[66-:64];
					be[burst_cnt_q * 8+:8] = 1'sb1;
					burst_cnt_d = burst_cnt_q + 1;
				end
				if (dreq_i[64])
					state_d = 4'd5;
				if (axi_resp_i[71] && axi_resp_i[0])
					state_d = (dreq_i[64] ? 4'd1 : 4'd6);
				if (((state_q == 4'd5) && axi_resp_i[0]) && axi_resp_i[71])
					state_d = 4'd1;
			end
			4'd6: begin
				req = 1'sb1;
				vld_req = 1'sb1;
				tag = tag_q;
				state_d = 4'd7;
			end
			4'd0: begin
				cnt_d = cnt_q + 1;
				vld_req = 1'sb1;
				we = 1;
				if (cnt_q == (ICACHE_NUM_WORD - 1)) begin
					state_d = 4'd1;
					flushing_d = 1'b0;
				end
			end
			default: state_d = 4'd1;
		endcase
		if ((dreq_i[64] && !(|{state_q == 4'd8, state_q == 4'd3, state_q == 4'd5, state_q == 4'd4, state_q == 4'd9, state_q == 4'd10})) && !dreq_o[226])
			state_d = 4'd1;
		if (dreq_i[64])
			dreq_o[225] = 1'b0;
		if (flush_i) begin
			flushing_d = 1'b1;
			dreq_o[226] = 1'b0;
		end
		if (flushing_q)
			dreq_o[226] = 1'b0;
	end
	lzc #(.WIDTH(ariane_pkg_ICACHE_SET_ASSOC)) i_lzc(
		.in_i(~way_valid),
		.cnt_o(repl_invalid),
		.empty_o(repl_w_random)
	);
	lfsr_8bit #(.WIDTH(ariane_pkg_ICACHE_SET_ASSOC)) i_lfsr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.en_i(update_lfsr),
		.refill_way_oh(random_way),
		.refill_way_bin()
	);
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			state_q <= 4'd0;
			cnt_q <= 1'sb0;
			vaddr_q <= 1'sb0;
			tag_q <= 1'sb0;
			evict_way_q <= 1'sb0;
			flushing_q <= 1'b0;
			burst_cnt_q <= 1'sb0;
		end
		else begin
			state_q <= state_d;
			cnt_q <= cnt_d;
			vaddr_q <= vaddr_d;
			tag_q <= tag_d;
			evict_way_q <= evict_way_d;
			flushing_q <= flushing_d;
			burst_cnt_q <= burst_cnt_d;
		end
	initial _sv2v_0 = 0;
endmodule
module std_nbdcache (
	clk_i,
	rst_ni,
	enable_i,
	flush_i,
	flush_ack_o,
	miss_o,
	amo_req_i,
	amo_resp_o,
	req_ports_i,
	req_ports_o,
	axi_data_o,
	axi_data_i,
	axi_bypass_o,
	axi_bypass_i
);
	parameter [63:0] CACHE_START_ADDR = 64'h0000000080000000;
	input wire clk_i;
	input wire rst_ni;
	input wire enable_i;
	input wire flush_i;
	output wire flush_ack_o;
	output wire miss_o;
	input wire [134:0] amo_req_i;
	output wire [64:0] amo_resp_o;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	input wire [(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (3 * ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78)) - 1 : (3 * (1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77))) + ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 76)):(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? 0 : (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77)] req_ports_i;
	output wire [197:0] req_ports_o;
	localparam ariane_axi_AddrWidth = 64;
	localparam ariane_axi_IdWidth = 4;
	localparam ariane_axi_DataWidth = 64;
	localparam ariane_axi_StrbWidth = 8;
	output wire [277:0] axi_data_o;
	input wire [81:0] axi_data_i;
	output wire [277:0] axi_bypass_o;
	input wire [81:0] axi_bypass_i;
	localparam [31:0] ariane_pkg_DCACHE_SET_ASSOC = 8;
	wire [31:0] req;
	wire [47:0] addr;
	wire [3:0] gnt;
	localparam [31:0] ariane_pkg_DCACHE_LINE_WIDTH = 128;
	wire [(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_SET_ASSOC * ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2)) - 1 : (ariane_pkg_DCACHE_SET_ASSOC * (1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)):(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)] rdata;
	wire [175:0] tag;
	wire [(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (4 * ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2)) - 1 : (4 * (1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)):(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)] wdata;
	wire [3:0] we;
	wire [119:0] be;
	wire [7:0] hit_way;
	wire [2:0] busy;
	wire [167:0] mshr_addr;
	wire [2:0] mshr_addr_matches;
	wire [2:0] mshr_index_matches;
	wire [63:0] critical_word;
	wire critical_word_valid;
	wire [422:0] miss_req;
	wire [2:0] miss_gnt;
	wire [2:0] active_serving;
	wire [2:0] bypass_gnt;
	wire [2:0] bypass_valid;
	wire [191:0] bypass_data;
	wire [7:0] req_ram;
	wire [11:0] addr_ram;
	wire we_ram;
	wire [(ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1:0] wdata_ram;
	wire [(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_SET_ASSOC * ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2)) - 1 : (ariane_pkg_DCACHE_SET_ASSOC * (1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)):(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)] rdata_ram;
	wire [29:0] be_ram;
	genvar _gv_i_5;
	generate
		for (_gv_i_5 = 0; _gv_i_5 < 3; _gv_i_5 = _gv_i_5 + 1) begin : master_ports
			localparam i = _gv_i_5;
			cache_ctrl #(.CACHE_START_ADDR(CACHE_START_ADDR)) i_cache_ctrl(
				.bypass_i(~enable_i),
				.busy_o(busy[i]),
				.req_port_i(req_ports_i[(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? 0 : (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) + (i * (((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78 : 1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77)))+:(((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77) >= 0 ? (ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 78 : 1 - ((ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77))]),
				.req_port_o(req_ports_o[i * 66+:66]),
				.req_o(req[(i + 1) * ariane_pkg_DCACHE_SET_ASSOC+:ariane_pkg_DCACHE_SET_ASSOC]),
				.addr_o(addr[(i + 1) * ariane_pkg_DCACHE_INDEX_WIDTH+:ariane_pkg_DCACHE_INDEX_WIDTH]),
				.gnt_i(gnt[i + 1]),
				.data_i(rdata),
				.tag_o(tag[(i + 1) * ariane_pkg_DCACHE_TAG_WIDTH+:ariane_pkg_DCACHE_TAG_WIDTH]),
				.data_o(wdata[(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) + ((i + 1) * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)))+:(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))]),
				.we_o(we[i + 1]),
				.be_o(be[(i + 1) * 30+:30]),
				.hit_way_i(hit_way),
				.miss_req_o(miss_req[i * 141+:141]),
				.miss_gnt_i(miss_gnt[i]),
				.active_serving_i(active_serving[i]),
				.critical_word_i(critical_word),
				.critical_word_valid_i(critical_word_valid),
				.bypass_gnt_i(bypass_gnt[i]),
				.bypass_valid_i(bypass_valid[i]),
				.bypass_data_i(bypass_data[i * 64+:64]),
				.mshr_addr_o(mshr_addr[i * 56+:56]),
				.mshr_addr_matches_i(mshr_addr_matches[i]),
				.mshr_index_matches_i(mshr_index_matches[i]),
				.clk_i(clk_i),
				.rst_ni(rst_ni),
				.flush_i(flush_i)
			);
		end
	endgenerate
	miss_handler #(.NR_PORTS(3)) i_miss_handler(
		.flush_i(flush_i),
		.busy_i(|busy),
		.amo_req_i(amo_req_i),
		.amo_resp_o(amo_resp_o),
		.miss_req_i(miss_req),
		.miss_gnt_o(miss_gnt),
		.bypass_gnt_o(bypass_gnt),
		.bypass_valid_o(bypass_valid),
		.bypass_data_o(bypass_data),
		.critical_word_o(critical_word),
		.critical_word_valid_o(critical_word_valid),
		.mshr_addr_i(mshr_addr),
		.mshr_addr_matches_o(mshr_addr_matches),
		.mshr_index_matches_o(mshr_index_matches),
		.active_serving_o(active_serving),
		.req_o(req[0+:ariane_pkg_DCACHE_SET_ASSOC]),
		.addr_o(addr[0+:ariane_pkg_DCACHE_INDEX_WIDTH]),
		.data_i(rdata),
		.be_o(be[0+:30]),
		.data_o(wdata[(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) + 0+:(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))]),
		.we_o(we[0]),
		.axi_bypass_o(axi_bypass_o),
		.axi_bypass_i(axi_bypass_i),
		.axi_data_o(axi_data_o),
		.axi_data_i(axi_data_i),
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_ack_o(flush_ack_o),
		.miss_o(miss_o)
	);
	assign tag[0+:ariane_pkg_DCACHE_TAG_WIDTH] = 1'sb0;
	genvar _gv_i_6;
	localparam std_cache_pkg_DCACHE_BYTE_OFFSET = 4;
	localparam std_cache_pkg_DCACHE_NUM_WORDS = 256;
	generate
		for (_gv_i_6 = 0; _gv_i_6 < ariane_pkg_DCACHE_SET_ASSOC; _gv_i_6 = _gv_i_6 + 1) begin : sram_block
			localparam i = _gv_i_6;
			sram #(
				.DATA_WIDTH(ariane_pkg_DCACHE_LINE_WIDTH),
				.NUM_WORDS(std_cache_pkg_DCACHE_NUM_WORDS)
			) data_sram(
				.req_i(req_ram[i]),
				.rst_ni(rst_ni),
				.we_i(we_ram),
				.addr_i(addr_ram[11:std_cache_pkg_DCACHE_BYTE_OFFSET]),
				.wdata_i(wdata_ram[129-:128]),
				.be_i(be_ram[23-:16]),
				.rdata_o(rdata_ram[(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 129 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 128) : ((i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 129 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 128)) + 127)-:128]),
				.clk_i(clk_i)
			);
			sram #(
				.DATA_WIDTH(ariane_pkg_DCACHE_TAG_WIDTH),
				.NUM_WORDS(std_cache_pkg_DCACHE_NUM_WORDS)
			) tag_sram(
				.req_i(req_ram[i]),
				.rst_ni(rst_ni),
				.we_i(we_ram),
				.addr_i(addr_ram[11:std_cache_pkg_DCACHE_BYTE_OFFSET]),
				.wdata_i(wdata_ram[173-:44]),
				.be_i(be_ram[29-:6]),
				.rdata_o(rdata_ram[(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 173 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 172) : ((i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 173 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 172)) + 43)-:44]),
				.clk_i(clk_i)
			);
		end
	endgenerate
	localparam std_cache_pkg_DCACHE_DIRTY_WIDTH = 16;
	wire [63:0] dirty_wdata;
	wire [63:0] dirty_rdata;
	genvar _gv_i_7;
	generate
		for (_gv_i_7 = 0; _gv_i_7 < ariane_pkg_DCACHE_SET_ASSOC; _gv_i_7 = _gv_i_7 + 1) begin : genblk3
			localparam i = _gv_i_7;
			assign dirty_wdata[8 * i] = wdata_ram[0];
			assign dirty_wdata[(8 * i) + 1] = wdata_ram[1];
			assign rdata_ram[(i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)] = dirty_rdata[8 * i];
			assign rdata_ram[(i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 1 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)] = dirty_rdata[(8 * i) + 1];
		end
	endgenerate
	sram #(
		.DATA_WIDTH(64),
		.NUM_WORDS(std_cache_pkg_DCACHE_NUM_WORDS)
	) valid_dirty_sram(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.req_i(|req_ram),
		.we_i(we_ram),
		.addr_i(addr_ram[11:std_cache_pkg_DCACHE_BYTE_OFFSET]),
		.wdata_i(dirty_wdata),
		.be_i(be_ram[7-:ariane_pkg_DCACHE_SET_ASSOC]),
		.rdata_o(dirty_rdata)
	);
	tag_cmp #(
		.NR_PORTS(4),
		.ADDR_WIDTH(ariane_pkg_DCACHE_INDEX_WIDTH),
		.DCACHE_SET_ASSOC(ariane_pkg_DCACHE_SET_ASSOC)
	) i_tag_cmp(
		.req_i(req),
		.gnt_o(gnt),
		.addr_i(addr),
		.wdata_i(wdata),
		.we_i(we),
		.be_i(be),
		.rdata_o(rdata),
		.tag_i(tag),
		.hit_way_o(hit_way),
		.req_o(req_ram),
		.addr_o(addr_ram),
		.wdata_o(wdata_ram),
		.we_o(we_ram),
		.be_o(be_ram),
		.rdata_i(rdata_ram),
		.clk_i(clk_i),
		.rst_ni(rst_ni)
	);
endmodule
module cache_ctrl (
	clk_i,
	rst_ni,
	flush_i,
	bypass_i,
	busy_o,
	req_port_i,
	req_port_o,
	req_o,
	addr_o,
	gnt_i,
	data_o,
	be_o,
	tag_o,
	data_i,
	we_o,
	hit_way_i,
	miss_req_o,
	miss_gnt_i,
	active_serving_i,
	critical_word_i,
	critical_word_valid_i,
	bypass_gnt_i,
	bypass_valid_i,
	bypass_data_i,
	mshr_addr_o,
	mshr_addr_matches_i,
	mshr_index_matches_i
);
	reg _sv2v_0;
	parameter [63:0] CACHE_START_ADDR = 64'h0000000040000000;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire bypass_i;
	output wire busy_o;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	input wire [(ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77:0] req_port_i;
	output reg [65:0] req_port_o;
	localparam [31:0] ariane_pkg_DCACHE_SET_ASSOC = 8;
	output reg [7:0] req_o;
	output reg [11:0] addr_o;
	input wire gnt_i;
	localparam [31:0] ariane_pkg_DCACHE_LINE_WIDTH = 128;
	output reg [(ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1:0] data_o;
	output reg [29:0] be_o;
	output reg [43:0] tag_o;
	input wire [(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_SET_ASSOC * ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2)) - 1 : (ariane_pkg_DCACHE_SET_ASSOC * (1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)):(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)] data_i;
	output reg we_o;
	input wire [7:0] hit_way_i;
	output reg [140:0] miss_req_o;
	input wire miss_gnt_i;
	input wire active_serving_i;
	input wire [63:0] critical_word_i;
	input wire critical_word_valid_i;
	input wire bypass_gnt_i;
	input wire bypass_valid_i;
	input wire [63:0] bypass_data_i;
	output reg [55:0] mshr_addr_o;
	input wire mshr_addr_matches_i;
	input wire mshr_index_matches_i;
	reg [3:0] state_d;
	reg [3:0] state_q;
	reg [7:0] hit_way_d;
	reg [7:0] hit_way_q;
	assign busy_o = state_q != 4'd0;
	reg [(ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 75:0] mem_req_d;
	reg [(ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 75:0] mem_req_q;
	reg [127:0] cl_i;
	always @(*) begin : way_select
		if (_sv2v_0)
			;
		cl_i = 1'sb0;
		begin : sv2v_autoblock_1
			reg [31:0] i;
			for (i = 0; i < ariane_pkg_DCACHE_SET_ASSOC; i = i + 1)
				if (hit_way_i[i])
					cl_i = data_i[(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 129 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 128) : ((i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 129 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 128)) + 127)-:128];
		end
	end
	localparam std_cache_pkg_DCACHE_BYTE_OFFSET = 4;
	always @(*) begin : cache_ctrl_fsm
		reg [6:0] cl_offset;
		if (_sv2v_0)
			;
		cl_offset = mem_req_q[123:123] << 6;
		state_d = state_q;
		mem_req_d = mem_req_q;
		hit_way_d = hit_way_q;
		req_port_o[65] = 1'b0;
		req_port_o[64] = 1'b0;
		req_port_o[63-:64] = 1'sb0;
		miss_req_o = 1'sb0;
		mshr_addr_o = 1'sb0;
		req_o = 1'sb0;
		addr_o = req_port_i[133-:12];
		data_o = 1'sb0;
		be_o = 1'sb0;
		tag_o = 1'sb0;
		we_o = 1'sb0;
		tag_o = 'b0;
		case (state_q)
			4'd0:
				if (req_port_i[13] && !flush_i) begin
					req_o = 1'sb1;
					mem_req_d[131-:12] = req_port_i[133-:12];
					mem_req_d[119-:44] = req_port_i[121-:44];
					mem_req_d[75-:8] = req_port_i[11-:8];
					mem_req_d[67-:2] = req_port_i[3-:2];
					mem_req_d[65] = req_port_i[12];
					mem_req_d[64-:64] = req_port_i[77-:64];
					if (bypass_i) begin
						state_d = (req_port_i[12] ? 4'd5 : 4'd2);
						req_port_o[65] = (req_port_i[12] ? 1'b0 : 1'b1);
						mem_req_d[0] = 1'b1;
					end
					else if (gnt_i) begin
						state_d = 4'd1;
						mem_req_d[0] = 1'b0;
						if (!req_port_i[12])
							req_port_o[65] = 1'b1;
					end
				end
			4'd1, 4'd6: begin
				tag_o = ((state_q == 4'd6) || mem_req_q[65] ? mem_req_q[119-:44] : req_port_i[121-:44]);
				if (req_port_i[13] && !flush_i)
					req_o = 1'sb1;
				if (!req_port_i[1]) begin
					if (|hit_way_i) begin
						if ((req_port_i[13] && !mem_req_q[65]) && !flush_i) begin
							state_d = 4'd1;
							mem_req_d[131-:12] = req_port_i[133-:12];
							mem_req_d[75-:8] = req_port_i[11-:8];
							mem_req_d[67-:2] = req_port_i[3-:2];
							mem_req_d[65] = req_port_i[12];
							mem_req_d[64-:64] = req_port_i[77-:64];
							mem_req_d[119-:44] = req_port_i[121-:44];
							mem_req_d[0] = 1'b0;
							req_port_o[65] = gnt_i;
							if (!gnt_i)
								state_d = 4'd0;
						end
						else
							state_d = 4'd0;
						case (mem_req_q[123])
							1'b0: req_port_o[63-:64] = cl_i[63:0];
							1'b1: req_port_o[63-:64] = cl_i[127:64];
						endcase
						if (!mem_req_q[65])
							req_port_o[64] = 1'b1;
						else begin
							state_d = 4'd3;
							hit_way_d = hit_way_i;
						end
					end
					else begin
						mem_req_d[119-:44] = req_port_i[121-:44];
						state_d = 4'd5;
					end
					mshr_addr_o = {tag_o, mem_req_q[131-:12]};
					if ((mshr_index_matches_i && mem_req_q[65]) || mshr_addr_matches_i) begin
						state_d = 4'd7;
						if (state_q != 4'd6)
							mem_req_d[119-:44] = req_port_i[121-:44];
					end
					if (tag_o < CACHE_START_ADDR[(ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) - 1:ariane_pkg_DCACHE_INDEX_WIDTH]) begin
						mem_req_d[119-:44] = req_port_i[121-:44];
						mem_req_d[0] = 1'b1;
						state_d = 4'd5;
					end
				end
			end
			4'd3: begin
				mshr_addr_o = {mem_req_q[119-:44], mem_req_q[131-:12]};
				if (!mshr_index_matches_i) begin
					req_o = hit_way_q;
					addr_o = mem_req_q[131-:12];
					we_o = 1'b1;
					be_o[7-:ariane_pkg_DCACHE_SET_ASSOC] = hit_way_q;
					be_o[8 + (cl_offset >> 3)+:8] = mem_req_q[75-:8];
					data_o[2 + cl_offset+:64] = mem_req_q[64-:64];
					data_o[0] = 1'b1;
					data_o[1] = 1'b1;
					if (gnt_i) begin
						req_port_o[65] = 1'b1;
						state_d = 4'd0;
					end
				end
				else
					state_d = 4'd7;
			end
			4'd7: begin
				mshr_addr_o = {mem_req_q[119-:44], mem_req_q[131-:12]};
				if (!mshr_index_matches_i) begin
					req_o = 1'sb1;
					addr_o = mem_req_q[131-:12];
					if (gnt_i)
						state_d = 4'd6;
				end
			end
			4'd2:
				if (!req_port_i[1]) begin
					mem_req_d[119-:44] = req_port_i[121-:44];
					state_d = 4'd5;
				end
			4'd5: begin
				mshr_addr_o = {mem_req_q[119-:44], mem_req_q[131-:12]};
				miss_req_o[140] = 1'b1;
				miss_req_o[0] = mem_req_q[0];
				miss_req_o[139-:64] = {mem_req_q[119-:44], mem_req_q[131-:12]};
				miss_req_o[75-:8] = mem_req_q[75-:8];
				miss_req_o[67-:2] = mem_req_q[67-:2];
				miss_req_o[65] = mem_req_q[65];
				miss_req_o[64-:64] = mem_req_q[64-:64];
				if (bypass_gnt_i) begin
					state_d = 4'd4;
					if (mem_req_q[65])
						req_port_o[65] = 1'b1;
				end
				if (miss_gnt_i && !mem_req_q[65])
					state_d = 4'd8;
				else if (miss_gnt_i) begin
					state_d = 4'd0;
					req_port_o[65] = 1'b1;
				end
				if (mshr_addr_matches_i && !active_serving_i)
					state_d = 4'd7;
			end
			4'd8: begin
				if (req_port_i[13])
					req_o = 1'sb1;
				if (critical_word_valid_i) begin
					req_port_o[64] = 1'b1;
					req_port_o[63-:64] = critical_word_i;
					if (req_port_i[13]) begin
						mem_req_d[131-:12] = req_port_i[133-:12];
						mem_req_d[75-:8] = req_port_i[11-:8];
						mem_req_d[67-:2] = req_port_i[3-:2];
						mem_req_d[65] = req_port_i[12];
						mem_req_d[64-:64] = req_port_i[77-:64];
						mem_req_d[119-:44] = req_port_i[121-:44];
						state_d = 4'd0;
						if (gnt_i) begin
							state_d = 4'd1;
							mem_req_d[0] = 1'b0;
							req_port_o[65] = 1'b1;
						end
					end
					else
						state_d = 4'd0;
				end
			end
			4'd4:
				if (bypass_valid_i) begin
					req_port_o[63-:64] = bypass_data_i;
					req_port_o[64] = 1'b1;
					state_d = 4'd0;
				end
		endcase
		if (req_port_i[1]) begin
			state_d = 4'd0;
			req_port_o[64] = 1'b1;
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			state_q <= 4'd0;
			mem_req_q <= 1'sb0;
			hit_way_q <= 1'sb0;
		end
		else begin
			state_q <= state_d;
			mem_req_q <= mem_req_d;
			hit_way_q <= hit_way_d;
		end
	initial _sv2v_0 = 0;
endmodule
module miss_handler (
	clk_i,
	rst_ni,
	flush_i,
	flush_ack_o,
	miss_o,
	busy_i,
	miss_req_i,
	bypass_gnt_o,
	bypass_valid_o,
	bypass_data_o,
	axi_bypass_o,
	axi_bypass_i,
	miss_gnt_o,
	active_serving_o,
	critical_word_o,
	critical_word_valid_o,
	axi_data_o,
	axi_data_i,
	mshr_addr_i,
	mshr_addr_matches_o,
	mshr_index_matches_o,
	amo_req_i,
	amo_resp_o,
	req_o,
	addr_o,
	data_o,
	be_o,
	data_i,
	we_o
);
	reg _sv2v_0;
	parameter [31:0] NR_PORTS = 3;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	output reg flush_ack_o;
	output reg miss_o;
	input wire busy_i;
	input wire [(NR_PORTS * 141) - 1:0] miss_req_i;
	output wire [NR_PORTS - 1:0] bypass_gnt_o;
	output wire [NR_PORTS - 1:0] bypass_valid_o;
	output wire [(NR_PORTS * 64) - 1:0] bypass_data_o;
	localparam ariane_axi_AddrWidth = 64;
	localparam ariane_axi_IdWidth = 4;
	localparam ariane_axi_DataWidth = 64;
	localparam ariane_axi_StrbWidth = 8;
	output wire [277:0] axi_bypass_o;
	input wire [81:0] axi_bypass_i;
	output reg [NR_PORTS - 1:0] miss_gnt_o;
	output reg [NR_PORTS - 1:0] active_serving_o;
	output wire [63:0] critical_word_o;
	output wire critical_word_valid_o;
	output wire [277:0] axi_data_o;
	input wire [81:0] axi_data_i;
	input wire [(NR_PORTS * 56) - 1:0] mshr_addr_i;
	output reg [NR_PORTS - 1:0] mshr_addr_matches_o;
	output reg [NR_PORTS - 1:0] mshr_index_matches_o;
	input wire [134:0] amo_req_i;
	output reg [64:0] amo_resp_o;
	localparam [31:0] ariane_pkg_DCACHE_SET_ASSOC = 8;
	output reg [7:0] req_o;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	output reg [11:0] addr_o;
	localparam [31:0] ariane_pkg_DCACHE_LINE_WIDTH = 128;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	output reg [(ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1:0] data_o;
	output reg [29:0] be_o;
	input wire [(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_SET_ASSOC * ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2)) - 1 : (ariane_pkg_DCACHE_SET_ASSOC * (1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)):(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)] data_i;
	output reg we_o;
	reg [3:0] state_d;
	reg [3:0] state_q;
	reg [131:0] mshr_d;
	reg [131:0] mshr_q;
	reg [11:0] cnt_d;
	reg [11:0] cnt_q;
	reg [7:0] evict_way_d;
	reg [7:0] evict_way_q;
	reg [(ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1:0] evict_cl_d;
	reg [(ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1:0] evict_cl_q;
	reg serve_amo_d;
	reg serve_amo_q;
	reg [NR_PORTS - 1:0] miss_req_valid;
	reg [NR_PORTS - 1:0] miss_req_bypass;
	reg [(NR_PORTS * 64) - 1:0] miss_req_addr;
	reg [(NR_PORTS * 64) - 1:0] miss_req_wdata;
	reg [NR_PORTS - 1:0] miss_req_we;
	reg [(NR_PORTS * 8) - 1:0] miss_req_be;
	reg [(NR_PORTS * 2) - 1:0] miss_req_size;
	reg req_fsm_miss_valid;
	reg [63:0] req_fsm_miss_addr;
	reg [127:0] req_fsm_miss_wdata;
	reg req_fsm_miss_we;
	reg [15:0] req_fsm_miss_be;
	reg req_fsm_miss_req;
	reg [1:0] req_fsm_miss_size;
	wire gnt_miss_fsm;
	wire valid_miss_fsm;
	wire [127:0] data_miss_fsm;
	reg lfsr_enable;
	wire [7:0] lfsr_oh;
	wire [2:0] lfsr_bin;
	reg [3:0] amo_op;
	reg [63:0] amo_operand_a;
	reg [63:0] amo_operand_b;
	wire [63:0] amo_result_o;
	reg [61:0] reservation_d;
	reg [61:0] reservation_q;
	localparam [0:0] ariane_pkg_INVALIDATE_ON_FLUSH = 1'b1;
	function automatic [7:0] ariane_pkg_be_gen;
		input reg [2:0] addr;
		input reg [1:0] size;
		reg [1:0] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			case (size)
				2'b11: begin
					ariane_pkg_be_gen = 8'b11111111;
					_sv2v_jump = 2'b11;
				end
				2'b10:
					case (addr[2:0])
						3'b000: begin
							ariane_pkg_be_gen = 8'b00001111;
							_sv2v_jump = 2'b11;
						end
						3'b001: begin
							ariane_pkg_be_gen = 8'b00011110;
							_sv2v_jump = 2'b11;
						end
						3'b010: begin
							ariane_pkg_be_gen = 8'b00111100;
							_sv2v_jump = 2'b11;
						end
						3'b011: begin
							ariane_pkg_be_gen = 8'b01111000;
							_sv2v_jump = 2'b11;
						end
						3'b100: begin
							ariane_pkg_be_gen = 8'b11110000;
							_sv2v_jump = 2'b11;
						end
					endcase
				2'b01:
					case (addr[2:0])
						3'b000: begin
							ariane_pkg_be_gen = 8'b00000011;
							_sv2v_jump = 2'b11;
						end
						3'b001: begin
							ariane_pkg_be_gen = 8'b00000110;
							_sv2v_jump = 2'b11;
						end
						3'b010: begin
							ariane_pkg_be_gen = 8'b00001100;
							_sv2v_jump = 2'b11;
						end
						3'b011: begin
							ariane_pkg_be_gen = 8'b00011000;
							_sv2v_jump = 2'b11;
						end
						3'b100: begin
							ariane_pkg_be_gen = 8'b00110000;
							_sv2v_jump = 2'b11;
						end
						3'b101: begin
							ariane_pkg_be_gen = 8'b01100000;
							_sv2v_jump = 2'b11;
						end
						3'b110: begin
							ariane_pkg_be_gen = 8'b11000000;
							_sv2v_jump = 2'b11;
						end
					endcase
				2'b00:
					case (addr[2:0])
						3'b000: begin
							ariane_pkg_be_gen = 8'b00000001;
							_sv2v_jump = 2'b11;
						end
						3'b001: begin
							ariane_pkg_be_gen = 8'b00000010;
							_sv2v_jump = 2'b11;
						end
						3'b010: begin
							ariane_pkg_be_gen = 8'b00000100;
							_sv2v_jump = 2'b11;
						end
						3'b011: begin
							ariane_pkg_be_gen = 8'b00001000;
							_sv2v_jump = 2'b11;
						end
						3'b100: begin
							ariane_pkg_be_gen = 8'b00010000;
							_sv2v_jump = 2'b11;
						end
						3'b101: begin
							ariane_pkg_be_gen = 8'b00100000;
							_sv2v_jump = 2'b11;
						end
						3'b110: begin
							ariane_pkg_be_gen = 8'b01000000;
							_sv2v_jump = 2'b11;
						end
						3'b111: begin
							ariane_pkg_be_gen = 8'b10000000;
							_sv2v_jump = 2'b11;
						end
					endcase
			endcase
			if (_sv2v_jump == 2'b00) begin
				ariane_pkg_be_gen = 8'b00000000;
				_sv2v_jump = 2'b11;
			end
		end
	endfunction
	function automatic [63:0] ariane_pkg_data_align;
		input reg [2:0] addr;
		input reg [63:0] data;
		reg [1:0] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			case (addr)
				3'b000: begin
					ariane_pkg_data_align = data;
					_sv2v_jump = 2'b11;
				end
				3'b001: begin
					ariane_pkg_data_align = {data[55:0], data[63:56]};
					_sv2v_jump = 2'b11;
				end
				3'b010: begin
					ariane_pkg_data_align = {data[47:0], data[63:48]};
					_sv2v_jump = 2'b11;
				end
				3'b011: begin
					ariane_pkg_data_align = {data[39:0], data[63:40]};
					_sv2v_jump = 2'b11;
				end
				3'b100: begin
					ariane_pkg_data_align = {data[31:0], data[63:32]};
					_sv2v_jump = 2'b11;
				end
				3'b101: begin
					ariane_pkg_data_align = {data[23:0], data[63:24]};
					_sv2v_jump = 2'b11;
				end
				3'b110: begin
					ariane_pkg_data_align = {data[15:0], data[63:16]};
					_sv2v_jump = 2'b11;
				end
				3'b111: begin
					ariane_pkg_data_align = {data[7:0], data[63:8]};
					_sv2v_jump = 2'b11;
				end
			endcase
			if (_sv2v_jump == 2'b00) begin
				ariane_pkg_data_align = data;
				_sv2v_jump = 2'b11;
			end
		end
	endfunction
	function automatic [63:0] ariane_pkg_sext32;
		input reg [31:0] operand;
		ariane_pkg_sext32 = {{32 {operand[31]}}, operand[31:0]};
	endfunction
	localparam std_cache_pkg_DCACHE_BYTE_OFFSET = 4;
	localparam std_cache_pkg_DCACHE_NUM_WORDS = 256;
	function automatic [7:0] std_cache_pkg_get_victim_cl;
		input reg [7:0] valid_dirty;
		reg [7:0] oh;
		reg [1:0] _sv2v_jump;
		begin
			oh = 1'sb0;
			_sv2v_jump = 2'b00;
			begin : sv2v_autoblock_1
				reg [31:0] i;
				begin : sv2v_autoblock_2
					reg [31:0] _sv2v_value_on_break;
					for (i = 0; i < ariane_pkg_DCACHE_SET_ASSOC; i = i + 1)
						if (_sv2v_jump < 2'b10) begin
							_sv2v_jump = 2'b00;
							if (valid_dirty[i]) begin
								oh[i] = 1'b1;
								std_cache_pkg_get_victim_cl = oh;
								_sv2v_jump = 2'b11;
							end
							_sv2v_value_on_break = i;
						end
					if (!(_sv2v_jump < 2'b10))
						i = _sv2v_value_on_break;
					if (_sv2v_jump != 2'b11)
						_sv2v_jump = 2'b00;
				end
			end
		end
	endfunction
	function automatic [2:0] std_cache_pkg_one_hot_to_bin;
		input reg [7:0] in;
		reg [1:0] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			begin : sv2v_autoblock_3
				reg [31:0] i;
				begin : sv2v_autoblock_4
					reg [31:0] _sv2v_value_on_break;
					for (i = 0; i < ariane_pkg_DCACHE_SET_ASSOC; i = i + 1)
						if (_sv2v_jump < 2'b10) begin
							_sv2v_jump = 2'b00;
							if (in[i]) begin
								std_cache_pkg_one_hot_to_bin = i;
								_sv2v_jump = 2'b11;
							end
							_sv2v_value_on_break = i;
						end
					if (!(_sv2v_jump < 2'b10))
						i = _sv2v_value_on_break;
					if (_sv2v_jump != 2'b11)
						_sv2v_jump = 2'b00;
				end
			end
		end
	endfunction
	always @(*) begin : sv2v_autoblock_5
		reg [1:0] _sv2v_jump;
		_sv2v_jump = 2'b00;
		begin : cache_management
			reg [7:0] evict_way;
			reg [7:0] valid_way;
			if (_sv2v_0)
				;
			begin : sv2v_autoblock_6
				reg [31:0] i;
				for (i = 0; i < ariane_pkg_DCACHE_SET_ASSOC; i = i + 1)
					begin
						evict_way[i] = data_i[(i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 1 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)] & data_i[(i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)];
						valid_way[i] = data_i[(i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 1 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)];
					end
			end
			req_o = 1'sb0;
			addr_o = 1'sb0;
			data_o = 1'sb0;
			be_o = 1'sb0;
			we_o = 1'sb0;
			miss_gnt_o = 1'sb0;
			lfsr_enable = 1'b0;
			req_fsm_miss_valid = 1'b0;
			req_fsm_miss_addr = 1'sb0;
			req_fsm_miss_wdata = 1'sb0;
			req_fsm_miss_we = 1'b0;
			req_fsm_miss_be = 1'sb0;
			req_fsm_miss_req = 1'd1;
			req_fsm_miss_size = 2'b11;
			flush_ack_o = 1'b0;
			miss_o = 1'b0;
			serve_amo_d = serve_amo_q;
			state_d = state_q;
			cnt_d = cnt_q;
			evict_way_d = evict_way_q;
			evict_cl_d = evict_cl_q;
			mshr_d = mshr_q;
			active_serving_o[mshr_q[131-:2]] = mshr_q[129];
			amo_resp_o[64] = 1'b0;
			amo_resp_o[63-:64] = 1'sb0;
			amo_op = amo_req_i[133-:4];
			amo_operand_a = 1'sb0;
			amo_operand_b = 1'sb0;
			reservation_d = reservation_q;
			case (state_q)
				4'd0: begin
					if (amo_req_i[134] && !busy_i) begin
						if (!serve_amo_q) begin
							state_d = 4'd4;
							serve_amo_d = 1'b1;
						end
						else begin
							state_d = 4'd12;
							serve_amo_d = 1'b0;
						end
					end
					if (flush_i && !busy_i) begin
						state_d = 4'd4;
						cnt_d = 1'sb0;
					end
					begin : sv2v_autoblock_7
						reg [31:0] i;
						begin : sv2v_autoblock_8
							reg [31:0] _sv2v_value_on_break;
							for (i = 0; i < NR_PORTS; i = i + 1)
								if (_sv2v_jump < 2'b10) begin
									_sv2v_jump = 2'b00;
									if (miss_req_valid[i] && !miss_req_bypass[i]) begin
										state_d = 4'd7;
										serve_amo_d = 1'b0;
										mshr_d[129] = 1'b1;
										mshr_d[128] = miss_req_we[i];
										mshr_d[131-:2] = i;
										mshr_d[127-:56] = miss_req_addr[(i * 64) + ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) - 1)-:ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH];
										mshr_d[71-:64] = miss_req_wdata[i * 64+:64];
										mshr_d[7-:8] = miss_req_be[i * 8+:8];
										_sv2v_jump = 2'b10;
									end
									_sv2v_value_on_break = i;
								end
							if (!(_sv2v_jump < 2'b10))
								i = _sv2v_value_on_break;
							if (_sv2v_jump != 2'b11)
								_sv2v_jump = 2'b00;
						end
					end
				end
				4'd7: begin
					req_o = 1'sb1;
					addr_o = mshr_q[83:72];
					state_d = 4'd9;
					miss_o = 1'b1;
				end
				4'd9:
					if (&valid_way) begin
						lfsr_enable = 1'b1;
						evict_way_d = lfsr_oh;
						if (data_i[(lfsr_bin * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)]) begin
							state_d = 4'd5;
							evict_cl_d[173-:44] = data_i[(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (lfsr_bin * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 173 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 172) : ((lfsr_bin * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 173 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 172)) + 43)-:44];
							evict_cl_d[129-:128] = data_i[(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (lfsr_bin * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 129 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 128) : ((lfsr_bin * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 129 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 128)) + 127)-:128];
							cnt_d = mshr_q[83:72];
						end
						else
							state_d = 4'd8;
					end
					else begin
						evict_way_d = std_cache_pkg_get_victim_cl(~valid_way);
						state_d = 4'd8;
					end
				4'd8: begin
					req_fsm_miss_valid = 1'b1;
					req_fsm_miss_addr = mshr_q[127-:56];
					if (gnt_miss_fsm) begin
						state_d = 4'd10;
						miss_gnt_o[mshr_q[131-:2]] = 1'b1;
					end
				end
				4'd10: begin : sv2v_autoblock_9
					reg [6:0] cl_offset;
					cl_offset = mshr_q[75:75] << 6;
					if (valid_miss_fsm) begin
						addr_o = mshr_q[83:72];
						req_o = evict_way_q;
						we_o = 1'b1;
						be_o = 1'sb1;
						be_o[7-:ariane_pkg_DCACHE_SET_ASSOC] = evict_way_q;
						data_o[173-:44] = mshr_q[(ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) + 71:84];
						data_o[129-:128] = data_miss_fsm;
						data_o[1] = 1'b1;
						data_o[0] = 1'b0;
						if (mshr_q[128]) begin
							begin : sv2v_autoblock_10
								reg signed [31:0] i;
								for (i = 0; i < 8; i = i + 1)
									if (mshr_q[0 + i])
										data_o[2 + (cl_offset + (i * 8))+:8] = mshr_q[8 + (i * 8)+:8];
							end
							data_o[0] = 1'b1;
						end
						mshr_d[129] = 1'b0;
						state_d = 4'd0;
					end
				end
				4'd3, 4'd5: begin
					req_fsm_miss_valid = 1'b1;
					req_fsm_miss_addr = {evict_cl_q[173-:44], cnt_q[11:std_cache_pkg_DCACHE_BYTE_OFFSET], {{std_cache_pkg_DCACHE_BYTE_OFFSET} {1'b0}}};
					req_fsm_miss_be = 1'sb1;
					req_fsm_miss_we = 1'b1;
					req_fsm_miss_wdata = evict_cl_q[129-:128];
					if (gnt_miss_fsm) begin
						addr_o = cnt_q;
						req_o = 1'b1;
						we_o = 1'b1;
						data_o[1] = (ariane_pkg_INVALIDATE_ON_FLUSH ? 1'b0 : 1'b1);
						be_o[7-:ariane_pkg_DCACHE_SET_ASSOC] = evict_way_q;
						state_d = (state_q == 4'd5 ? 4'd7 : 4'd4);
					end
				end
				4'd4: begin
					req_o = 1'sb1;
					addr_o = cnt_q;
					state_d = 4'd1;
				end
				4'd1:
					if (|evict_way) begin
						evict_way_d = std_cache_pkg_get_victim_cl(evict_way);
						evict_cl_d = data_i[(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) + (std_cache_pkg_one_hot_to_bin(evict_way) * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)))+:(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))];
						state_d = 4'd3;
					end
					else begin
						cnt_d = cnt_q + (1'b1 << std_cache_pkg_DCACHE_BYTE_OFFSET);
						state_d = 4'd4;
						addr_o = cnt_q;
						req_o = 1'b1;
						be_o[7-:ariane_pkg_DCACHE_SET_ASSOC] = (ariane_pkg_INVALIDATE_ON_FLUSH ? {8 {1'sb1}} : {8 {1'sb0}});
						we_o = 1'b1;
						if (cnt_q[11:std_cache_pkg_DCACHE_BYTE_OFFSET] == 255) begin
							flush_ack_o = ~serve_amo_q;
							state_d = 4'd0;
						end
					end
				4'd11: begin
					addr_o = cnt_q;
					req_o = 1'b1;
					we_o = 1'b1;
					be_o[7-:ariane_pkg_DCACHE_SET_ASSOC] = 1'sb1;
					cnt_d = cnt_q + (1'b1 << std_cache_pkg_DCACHE_BYTE_OFFSET);
					if (cnt_q[11:std_cache_pkg_DCACHE_BYTE_OFFSET] == 255)
						state_d = 4'd0;
				end
				4'd12: begin
					req_fsm_miss_valid = 1'b1;
					req_fsm_miss_addr = amo_req_i[127-:64];
					req_fsm_miss_req = 1'd0;
					req_fsm_miss_size = amo_req_i[129-:2];
					if (gnt_miss_fsm)
						state_d = 4'd13;
				end
				4'd13:
					if (valid_miss_fsm) begin
						mshr_d[71-:64] = data_miss_fsm[0+:64];
						state_d = 4'd14;
					end
				4'd14: begin : sv2v_autoblock_11
					reg [63:0] load_data;
					load_data = ariane_pkg_data_align(amo_req_i[66:64], mshr_q[71-:64]);
					if (amo_req_i[129-:2] == 2'b10) begin
						amo_operand_a = ariane_pkg_sext32(load_data[31:0]);
						amo_operand_b = ariane_pkg_sext32(amo_req_i[31:0]);
					end
					else begin
						amo_operand_a = load_data;
						amo_operand_b = amo_req_i[63-:64];
					end
					if ((amo_req_i[133-:4] == 4'b0001) || ((amo_req_i[133-:4] == 4'b0010) && ((reservation_q[0] && (reservation_q[61-:61] != amo_req_i[127:67])) || !reservation_q[0]))) begin
						req_fsm_miss_valid = 1'b0;
						state_d = 4'd0;
						amo_resp_o[64] = 1'b1;
						amo_resp_o[63-:64] = amo_operand_a;
						if (amo_req_i[133-:4] == 4'b0010) begin
							amo_resp_o[63-:64] = 1'b1;
							reservation_d[0] = 1'b0;
						end
					end
					else
						req_fsm_miss_valid = 1'b1;
					req_fsm_miss_we = 1'b1;
					req_fsm_miss_req = 1'd0;
					req_fsm_miss_size = amo_req_i[129-:2];
					req_fsm_miss_addr = amo_req_i[127-:64];
					req_fsm_miss_wdata = ariane_pkg_data_align(amo_req_i[66:64], amo_result_o);
					req_fsm_miss_be = ariane_pkg_be_gen(amo_req_i[66:64], amo_req_i[129-:2]);
					if (amo_req_i[133-:4] == 4'b0001) begin
						reservation_d[61-:61] = amo_req_i[127:67];
						reservation_d[0] = 1'b1;
					end
					if (valid_miss_fsm) begin
						state_d = 4'd0;
						amo_resp_o[64] = 1'b1;
						amo_resp_o[63-:64] = amo_operand_a;
						if (amo_req_i[133-:4] == 4'b0010) begin
							amo_resp_o[63-:64] = 1'b0;
							reservation_d[0] = 1'b0;
						end
					end
				end
			endcase
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		mshr_addr_matches_o = 'b0;
		mshr_index_matches_o = 'b0;
		begin : sv2v_autoblock_12
			reg signed [31:0] i;
			for (i = 0; i < NR_PORTS; i = i + 1)
				begin
					if (mshr_q[129] && (mshr_addr_i[(i * 56) + 55-:52] == mshr_q[127:76]))
						mshr_addr_matches_o[i] = 1'b1;
					if (mshr_q[129] && (mshr_addr_i[(i * 56) + 11-:8] == mshr_q[83:76]))
						mshr_index_matches_o[i] = 1'b1;
				end
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			mshr_q <= 1'sb0;
			state_q <= 4'd11;
			cnt_q <= 1'sb0;
			evict_way_q <= 1'sb0;
			evict_cl_q <= 1'sb0;
			serve_amo_q <= 1'b0;
			reservation_q <= 1'sb0;
		end
		else begin
			mshr_q <= mshr_d;
			state_q <= state_d;
			cnt_q <= cnt_d;
			evict_way_q <= evict_way_d;
			evict_cl_q <= evict_cl_d;
			serve_amo_q <= serve_amo_d;
			reservation_q <= reservation_d;
		end
	wire req_fsm_bypass_valid;
	wire [63:0] req_fsm_bypass_addr;
	wire [63:0] req_fsm_bypass_wdata;
	wire req_fsm_bypass_we;
	wire [7:0] req_fsm_bypass_be;
	wire [1:0] req_fsm_bypass_size;
	wire gnt_bypass_fsm;
	wire valid_bypass_fsm;
	wire [63:0] data_bypass_fsm;
	wire [$clog2(NR_PORTS) - 1:0] id_fsm_bypass;
	wire [3:0] id_bypass_fsm;
	wire [3:0] gnt_id_bypass_fsm;
	arbiter #(
		.NR_PORTS(NR_PORTS),
		.DATA_WIDTH(64)
	) i_bypass_arbiter(
		.data_req_i(miss_req_valid & miss_req_bypass),
		.address_i(miss_req_addr),
		.data_wdata_i(miss_req_wdata),
		.data_we_i(miss_req_we),
		.data_be_i(miss_req_be),
		.data_size_i(miss_req_size),
		.data_gnt_o(bypass_gnt_o),
		.data_rvalid_o(bypass_valid_o),
		.data_rdata_o(bypass_data_o),
		.id_i(id_bypass_fsm[$clog2(NR_PORTS) - 1:0]),
		.id_o(id_fsm_bypass),
		.gnt_id_i(gnt_id_bypass_fsm[$clog2(NR_PORTS) - 1:0]),
		.address_o(req_fsm_bypass_addr),
		.data_wdata_o(req_fsm_bypass_wdata),
		.data_req_o(req_fsm_bypass_valid),
		.data_we_o(req_fsm_bypass_we),
		.data_be_o(req_fsm_bypass_be),
		.data_size_o(req_fsm_bypass_size),
		.data_gnt_i(gnt_bypass_fsm),
		.data_rvalid_i(valid_bypass_fsm),
		.data_rdata_i(data_bypass_fsm),
		.clk_i(clk_i),
		.rst_ni(rst_ni)
	);
	axi_adapter #(
		.DATA_WIDTH(64),
		.AXI_ID_WIDTH(4),
		.CACHELINE_BYTE_OFFSET(std_cache_pkg_DCACHE_BYTE_OFFSET)
	) i_bypass_axi_adapter(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.req_i(req_fsm_bypass_valid),
		.type_i(1'd0),
		.gnt_o(gnt_bypass_fsm),
		.addr_i(req_fsm_bypass_addr),
		.we_i(req_fsm_bypass_we),
		.wdata_i(req_fsm_bypass_wdata),
		.be_i(req_fsm_bypass_be),
		.size_i(req_fsm_bypass_size),
		.id_i({2'b10, id_fsm_bypass}),
		.valid_o(valid_bypass_fsm),
		.rdata_o(data_bypass_fsm),
		.gnt_id_o(gnt_id_bypass_fsm),
		.id_o(id_bypass_fsm),
		.critical_word_o(),
		.critical_word_valid_o(),
		.axi_req_o(axi_bypass_o),
		.axi_resp_i(axi_bypass_i)
	);
	axi_adapter #(
		.DATA_WIDTH(ariane_pkg_DCACHE_LINE_WIDTH),
		.AXI_ID_WIDTH(4),
		.CACHELINE_BYTE_OFFSET(std_cache_pkg_DCACHE_BYTE_OFFSET)
	) i_miss_axi_adapter(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.req_i(req_fsm_miss_valid),
		.type_i(req_fsm_miss_req),
		.gnt_o(gnt_miss_fsm),
		.addr_i(req_fsm_miss_addr),
		.we_i(req_fsm_miss_we),
		.wdata_i(req_fsm_miss_wdata),
		.be_i(req_fsm_miss_be),
		.size_i(req_fsm_miss_size),
		.id_i(4'b1100),
		.gnt_id_o(),
		.valid_o(valid_miss_fsm),
		.rdata_o(data_miss_fsm),
		.id_o(),
		.critical_word_o(critical_word_o),
		.critical_word_valid_o(critical_word_valid_o),
		.axi_req_o(axi_data_o),
		.axi_resp_i(axi_data_i)
	);
	lfsr_8bit #(.WIDTH(ariane_pkg_DCACHE_SET_ASSOC)) i_lfsr(
		.en_i(lfsr_enable),
		.refill_way_oh(lfsr_oh),
		.refill_way_bin(lfsr_bin),
		.clk_i(clk_i),
		.rst_ni(rst_ni)
	);
	amo_alu i_amo_alu(
		.amo_op_i(amo_op),
		.amo_operand_a_i(amo_operand_a),
		.amo_operand_b_i(amo_operand_b),
		.amo_result_o(amo_result_o)
	);
	always @(*) begin : sv2v_autoblock_13
		reg [140:0] miss_req;
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_14
			reg [31:0] i;
			for (i = 0; i < NR_PORTS; i = i + 1)
				begin
					miss_req = miss_req_i[i * 141+:141];
					miss_req_valid[i] = miss_req[140];
					miss_req_bypass[i] = miss_req[0];
					miss_req_addr[i * 64+:64] = miss_req[139-:64];
					miss_req_wdata[i * 64+:64] = miss_req[64-:64];
					miss_req_we[i] = miss_req[65];
					miss_req_be[i * 8+:8] = miss_req[75-:8];
					miss_req_size[i * 2+:2] = miss_req[67-:2];
				end
		end
	end
	initial _sv2v_0 = 0;
endmodule
module arbiter (
	clk_i,
	rst_ni,
	data_req_i,
	address_i,
	data_wdata_i,
	data_we_i,
	data_be_i,
	data_size_i,
	data_gnt_o,
	data_rvalid_o,
	data_rdata_o,
	id_i,
	id_o,
	gnt_id_i,
	data_req_o,
	address_o,
	data_wdata_o,
	data_we_o,
	data_be_o,
	data_size_o,
	data_gnt_i,
	data_rvalid_i,
	data_rdata_i
);
	reg _sv2v_0;
	parameter [31:0] NR_PORTS = 3;
	parameter [31:0] DATA_WIDTH = 64;
	input wire clk_i;
	input wire rst_ni;
	input wire [NR_PORTS - 1:0] data_req_i;
	input wire [(NR_PORTS * 64) - 1:0] address_i;
	input wire [(NR_PORTS * DATA_WIDTH) - 1:0] data_wdata_i;
	input wire [NR_PORTS - 1:0] data_we_i;
	input wire [(NR_PORTS * (DATA_WIDTH / 8)) - 1:0] data_be_i;
	input wire [(NR_PORTS * 2) - 1:0] data_size_i;
	output reg [NR_PORTS - 1:0] data_gnt_o;
	output reg [NR_PORTS - 1:0] data_rvalid_o;
	output reg [(NR_PORTS * DATA_WIDTH) - 1:0] data_rdata_o;
	input wire [$clog2(NR_PORTS) - 1:0] id_i;
	output reg [$clog2(NR_PORTS) - 1:0] id_o;
	input wire [$clog2(NR_PORTS) - 1:0] gnt_id_i;
	output reg data_req_o;
	output reg [63:0] address_o;
	output reg [DATA_WIDTH - 1:0] data_wdata_o;
	output reg data_we_o;
	output reg [(DATA_WIDTH / 8) - 1:0] data_be_o;
	output reg [1:0] data_size_o;
	input wire data_gnt_i;
	input wire data_rvalid_i;
	input wire [DATA_WIDTH - 1:0] data_rdata_i;
	reg [1:0] state_d;
	reg [1:0] state_q;
	reg [(($clog2(NR_PORTS) + 130) + (DATA_WIDTH / 8)) + 0:0] req_d;
	reg [(($clog2(NR_PORTS) + 130) + (DATA_WIDTH / 8)) + 0:0] req_q;
	always @(*) begin : sv2v_autoblock_1
		reg [1:0] _sv2v_jump;
		_sv2v_jump = 2'b00;
		begin : sv2v_autoblock_2
			reg [$clog2(NR_PORTS) - 1:0] request_index;
			if (_sv2v_0)
				;
			request_index = 0;
			state_d = state_q;
			req_d = req_q;
			data_req_o = 1'b0;
			address_o = req_q[130 + ((DATA_WIDTH / 8) + 0)-:((130 + ((DATA_WIDTH / 8) + 0)) >= (66 + ((DATA_WIDTH / 8) + 1)) ? ((130 + ((DATA_WIDTH / 8) + 0)) - (66 + ((DATA_WIDTH / 8) + 1))) + 1 : ((66 + ((DATA_WIDTH / 8) + 1)) - (130 + ((DATA_WIDTH / 8) + 0))) + 1)];
			data_wdata_o = req_q[66 + ((DATA_WIDTH / 8) + 0)-:((66 + ((DATA_WIDTH / 8) + 0)) >= (2 + ((DATA_WIDTH / 8) + 1)) ? ((66 + ((DATA_WIDTH / 8) + 0)) - (2 + ((DATA_WIDTH / 8) + 1))) + 1 : ((2 + ((DATA_WIDTH / 8) + 1)) - (66 + ((DATA_WIDTH / 8) + 0))) + 1)];
			data_be_o = req_q[(DATA_WIDTH / 8) + 0-:(((DATA_WIDTH / 8) + 0) >= 1 ? (DATA_WIDTH / 8) + 0 : 2 - ((DATA_WIDTH / 8) + 0))];
			data_size_o = req_q[2 + ((DATA_WIDTH / 8) + 0)-:((2 + ((DATA_WIDTH / 8) + 0)) >= ((DATA_WIDTH / 8) + 1) ? ((2 + ((DATA_WIDTH / 8) + 0)) - ((DATA_WIDTH / 8) + 1)) + 1 : (((DATA_WIDTH / 8) + 1) - (2 + ((DATA_WIDTH / 8) + 0))) + 1)];
			data_we_o = req_q[0];
			id_o = req_q[$clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))-:(($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))) >= (130 + ((DATA_WIDTH / 8) + 1)) ? (($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))) - (130 + ((DATA_WIDTH / 8) + 1))) + 1 : ((130 + ((DATA_WIDTH / 8) + 1)) - ($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0)))) + 1)];
			data_gnt_o = 1'sb0;
			data_rvalid_o = 1'sb0;
			data_rdata_o = 1'sb0;
			data_rdata_o[req_q[$clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))-:(($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))) >= (130 + ((DATA_WIDTH / 8) + 1)) ? (($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))) - (130 + ((DATA_WIDTH / 8) + 1))) + 1 : ((130 + ((DATA_WIDTH / 8) + 1)) - ($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0)))) + 1)] * DATA_WIDTH+:DATA_WIDTH] = data_rdata_i;
			case (state_q)
				2'd0: begin
					begin : sv2v_autoblock_3
						reg [31:0] i;
						begin : sv2v_autoblock_4
							reg [31:0] _sv2v_value_on_break;
							for (i = 0; i < NR_PORTS; i = i + 1)
								if (_sv2v_jump < 2'b10) begin
									_sv2v_jump = 2'b00;
									if (data_req_i[i] == 1'b1) begin
										data_req_o = data_req_i[i];
										data_gnt_o[i] = data_req_i[i];
										request_index = i[$clog2(NR_PORTS) - 1:0];
										req_d[130 + ((DATA_WIDTH / 8) + 0)-:((130 + ((DATA_WIDTH / 8) + 0)) >= (66 + ((DATA_WIDTH / 8) + 1)) ? ((130 + ((DATA_WIDTH / 8) + 0)) - (66 + ((DATA_WIDTH / 8) + 1))) + 1 : ((66 + ((DATA_WIDTH / 8) + 1)) - (130 + ((DATA_WIDTH / 8) + 0))) + 1)] = address_i[i * 64+:64];
										req_d[$clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))-:(($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))) >= (130 + ((DATA_WIDTH / 8) + 1)) ? (($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))) - (130 + ((DATA_WIDTH / 8) + 1))) + 1 : ((130 + ((DATA_WIDTH / 8) + 1)) - ($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0)))) + 1)] = i[((($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))) >= (130 + ((DATA_WIDTH / 8) + 1)) ? (($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))) - (130 + ((DATA_WIDTH / 8) + 1))) + 1 : ((130 + ((DATA_WIDTH / 8) + 1)) - ($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0)))) + 1) * 1) - 1:0];
										req_d[66 + ((DATA_WIDTH / 8) + 0)-:((66 + ((DATA_WIDTH / 8) + 0)) >= (2 + ((DATA_WIDTH / 8) + 1)) ? ((66 + ((DATA_WIDTH / 8) + 0)) - (2 + ((DATA_WIDTH / 8) + 1))) + 1 : ((2 + ((DATA_WIDTH / 8) + 1)) - (66 + ((DATA_WIDTH / 8) + 0))) + 1)] = data_wdata_i[i * DATA_WIDTH+:DATA_WIDTH];
										req_d[2 + ((DATA_WIDTH / 8) + 0)-:((2 + ((DATA_WIDTH / 8) + 0)) >= ((DATA_WIDTH / 8) + 1) ? ((2 + ((DATA_WIDTH / 8) + 0)) - ((DATA_WIDTH / 8) + 1)) + 1 : (((DATA_WIDTH / 8) + 1) - (2 + ((DATA_WIDTH / 8) + 0))) + 1)] = data_size_i[i * 2+:2];
										req_d[(DATA_WIDTH / 8) + 0-:(((DATA_WIDTH / 8) + 0) >= 1 ? (DATA_WIDTH / 8) + 0 : 2 - ((DATA_WIDTH / 8) + 0))] = data_be_i[i * (DATA_WIDTH / 8)+:DATA_WIDTH / 8];
										req_d[0] = data_we_i[i];
										state_d = 2'd2;
										_sv2v_jump = 2'b10;
									end
									_sv2v_value_on_break = i;
								end
							if (!(_sv2v_jump < 2'b10))
								i = _sv2v_value_on_break;
							if (_sv2v_jump != 2'b11)
								_sv2v_jump = 2'b00;
						end
					end
					if (_sv2v_jump == 2'b00) begin
						address_o = address_i[request_index * 64+:64];
						data_wdata_o = data_wdata_i[request_index * DATA_WIDTH+:DATA_WIDTH];
						data_be_o = data_be_i[request_index * (DATA_WIDTH / 8)+:DATA_WIDTH / 8];
						data_size_o = data_size_i[request_index * 2+:2];
						data_we_o = data_we_i[request_index];
						id_o = request_index;
					end
				end
				2'd2: begin
					data_req_o = 1'b1;
					if (data_rvalid_i) begin
						data_rvalid_o[req_q[$clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))-:(($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))) >= (130 + ((DATA_WIDTH / 8) + 1)) ? (($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0))) - (130 + ((DATA_WIDTH / 8) + 1))) + 1 : ((130 + ((DATA_WIDTH / 8) + 1)) - ($clog2(NR_PORTS) + (130 + ((DATA_WIDTH / 8) + 0)))) + 1)]] = 1'b1;
						state_d = 2'd0;
					end
				end
				default:
					;
			endcase
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			state_q <= 2'd0;
			req_q <= 1'sb0;
		end
		else begin
			state_q <= state_d;
			req_q <= req_d;
		end
	initial _sv2v_0 = 0;
endmodule
module tag_cmp (
	clk_i,
	rst_ni,
	req_i,
	gnt_o,
	addr_i,
	wdata_i,
	we_i,
	be_i,
	rdata_o,
	tag_i,
	hit_way_o,
	req_o,
	addr_o,
	wdata_o,
	we_o,
	be_o,
	rdata_i
);
	reg _sv2v_0;
	parameter [31:0] NR_PORTS = 3;
	parameter [31:0] ADDR_WIDTH = 64;
	localparam [31:0] ariane_pkg_DCACHE_LINE_WIDTH = 128;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	localparam [31:0] ariane_pkg_DCACHE_SET_ASSOC = 8;
	parameter [31:0] DCACHE_SET_ASSOC = 8;
	input wire clk_i;
	input wire rst_ni;
	input wire [(NR_PORTS * DCACHE_SET_ASSOC) - 1:0] req_i;
	output reg [NR_PORTS - 1:0] gnt_o;
	input wire [(NR_PORTS * ADDR_WIDTH) - 1:0] addr_i;
	input wire [(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (NR_PORTS * ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2)) - 1 : (NR_PORTS * (1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)):(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)] wdata_i;
	input wire [NR_PORTS - 1:0] we_i;
	input wire [(NR_PORTS * 30) - 1:0] be_i;
	output wire [(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (DCACHE_SET_ASSOC * ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2)) - 1 : (DCACHE_SET_ASSOC * (1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)):(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)] rdata_o;
	input wire [(NR_PORTS * ariane_pkg_DCACHE_TAG_WIDTH) - 1:0] tag_i;
	output wire [DCACHE_SET_ASSOC - 1:0] hit_way_o;
	output reg [DCACHE_SET_ASSOC - 1:0] req_o;
	output reg [ADDR_WIDTH - 1:0] addr_o;
	output reg [(ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1:0] wdata_o;
	output reg we_o;
	output reg [29:0] be_o;
	input wire [(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (DCACHE_SET_ASSOC * ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2)) - 1 : (DCACHE_SET_ASSOC * (1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)):(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)] rdata_i;
	assign rdata_o = rdata_i;
	reg [NR_PORTS - 1:0] id_d;
	reg [NR_PORTS - 1:0] id_q;
	reg [43:0] sel_tag;
	always @(*) begin : tag_sel
		if (_sv2v_0)
			;
		sel_tag = 1'sb0;
		begin : sv2v_autoblock_1
			reg [31:0] i;
			for (i = 0; i < NR_PORTS; i = i + 1)
				if (id_q[i])
					sel_tag = tag_i[i * ariane_pkg_DCACHE_TAG_WIDTH+:ariane_pkg_DCACHE_TAG_WIDTH];
		end
	end
	genvar _gv_j_3;
	generate
		for (_gv_j_3 = 0; _gv_j_3 < DCACHE_SET_ASSOC; _gv_j_3 = _gv_j_3 + 1) begin : tag_cmp
			localparam j = _gv_j_3;
			assign hit_way_o[j] = (sel_tag == rdata_i[(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (j * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 173 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 172) : ((j * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 173 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) - 172)) + 43)-:44] ? rdata_i[(j * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 1 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 0)] : 1'b0);
		end
	endgenerate
	always @(*) begin : sv2v_autoblock_2
		reg [1:0] _sv2v_jump;
		_sv2v_jump = 2'b00;
		if (_sv2v_0)
			;
		gnt_o = 1'sb0;
		id_d = 1'sb0;
		wdata_o = 1'sb0;
		req_o = 1'sb0;
		addr_o = 1'sb0;
		be_o = 1'sb0;
		we_o = 1'sb0;
		begin : sv2v_autoblock_3
			reg [31:0] i;
			begin : sv2v_autoblock_4
				reg [31:0] _sv2v_value_on_break;
				for (i = 0; i < NR_PORTS; i = i + 1)
					if (_sv2v_jump < 2'b10) begin
						_sv2v_jump = 2'b00;
						req_o = req_i[i * DCACHE_SET_ASSOC+:DCACHE_SET_ASSOC];
						id_d = 1'b1 << i;
						gnt_o[i] = 1'b1;
						addr_o = addr_i[i * ADDR_WIDTH+:ADDR_WIDTH];
						be_o = be_i[i * 30+:30];
						we_o = we_i[i];
						wdata_o = wdata_i[(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? 0 : (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) + (i * (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1)))+:(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1) >= 0 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 2 : 1 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_LINE_WIDTH) + 1))];
						if (req_i[i * DCACHE_SET_ASSOC+:DCACHE_SET_ASSOC])
							_sv2v_jump = 2'b10;
						_sv2v_value_on_break = i;
					end
				if (!(_sv2v_jump < 2'b10))
					i = _sv2v_value_on_break;
				if (_sv2v_jump != 2'b11)
					_sv2v_jump = 2'b00;
			end
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni)
			id_q <= 0;
		else
			id_q <= id_d;
	initial _sv2v_0 = 0;
endmodule
module lfsr_8bit (
	clk_i,
	rst_ni,
	en_i,
	refill_way_oh,
	refill_way_bin
);
	reg _sv2v_0;
	parameter [7:0] SEED = 8'b00000000;
	parameter [31:0] WIDTH = 8;
	input wire clk_i;
	input wire rst_ni;
	input wire en_i;
	output reg [WIDTH - 1:0] refill_way_oh;
	output reg [$clog2(WIDTH) - 1:0] refill_way_bin;
	localparam [31:0] LOG_WIDTH = $clog2(WIDTH);
	reg [7:0] shift_d;
	reg [7:0] shift_q;
	always @(*) begin : sv2v_autoblock_1
		reg shift_in;
		if (_sv2v_0)
			;
		shift_in = !(((shift_q[7] ^ shift_q[3]) ^ shift_q[2]) ^ shift_q[1]);
		shift_d = shift_q;
		if (en_i)
			shift_d = {shift_q[6:0], shift_in};
		refill_way_oh = 'b0;
		refill_way_oh[shift_q[LOG_WIDTH - 1:0]] = 1'b1;
		refill_way_bin = shift_q;
	end
	always @(posedge clk_i or negedge rst_ni) begin : proc_
		if (~rst_ni)
			shift_q <= SEED;
		else
			shift_q <= shift_d;
	end
	initial _sv2v_0 = 0;
endmodule
module amo_alu (
	amo_op_i,
	amo_operand_a_i,
	amo_operand_b_i,
	amo_result_o
);
	reg _sv2v_0;
	input wire [3:0] amo_op_i;
	input wire [63:0] amo_operand_a_i;
	input wire [63:0] amo_operand_b_i;
	output reg [63:0] amo_result_o;
	wire [64:0] adder_sum;
	reg [64:0] adder_operand_a;
	reg [64:0] adder_operand_b;
	assign adder_sum = adder_operand_a + adder_operand_b;
	always @(*) begin
		if (_sv2v_0)
			;
		adder_operand_a = $signed(amo_operand_a_i);
		adder_operand_b = $signed(amo_operand_b_i);
		amo_result_o = amo_operand_b_i;
		(* full_case, parallel_case *)
		case (amo_op_i)
			4'b0010:
				;
			4'b0011:
				;
			4'b0100: amo_result_o = adder_sum[63:0];
			4'b0101: amo_result_o = amo_operand_a_i & amo_operand_b_i;
			4'b0110: amo_result_o = amo_operand_a_i | amo_operand_b_i;
			4'b0111: amo_result_o = amo_operand_a_i ^ amo_operand_b_i;
			4'b1000: begin
				adder_operand_b = -$signed(amo_operand_b_i);
				amo_result_o = (adder_sum[64] ? amo_operand_b_i : amo_operand_a_i);
			end
			4'b1010: begin
				adder_operand_b = -$signed(amo_operand_b_i);
				amo_result_o = (adder_sum[64] ? amo_operand_a_i : amo_operand_b_i);
			end
			4'b1001: begin
				adder_operand_a = $unsigned(amo_operand_a_i);
				adder_operand_b = -$unsigned(amo_operand_b_i);
				amo_result_o = (adder_sum[64] ? amo_operand_b_i : amo_operand_a_i);
			end
			4'b1011: begin
				adder_operand_a = $unsigned(amo_operand_a_i);
				adder_operand_b = -$unsigned(amo_operand_b_i);
				amo_result_o = (adder_sum[64] ? amo_operand_a_i : amo_operand_b_i);
			end
			default: amo_result_o = 1'sb0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module mmu (
	clk_i,
	rst_ni,
	flush_i,
	enable_translation_i,
	en_ld_st_translation_i,
	icache_areq_i,
	icache_areq_o,
	misaligned_ex_i,
	lsu_req_i,
	lsu_vaddr_i,
	lsu_is_store_i,
	lsu_dtlb_hit_o,
	lsu_valid_o,
	lsu_paddr_o,
	lsu_exception_o,
	priv_lvl_i,
	ld_st_priv_lvl_i,
	sum_i,
	mxr_i,
	satp_ppn_i,
	asid_i,
	flush_tlb_i,
	itlb_miss_o,
	dtlb_miss_o,
	req_port_i,
	req_port_o
);
	reg _sv2v_0;
	parameter [31:0] INSTR_TLB_ENTRIES = 4;
	parameter [31:0] DATA_TLB_ENTRIES = 4;
	parameter [31:0] ASID_WIDTH = 1;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire enable_translation_i;
	input wire en_ld_st_translation_i;
	input wire [64:0] icache_areq_i;
	output reg [193:0] icache_areq_o;
	input wire [128:0] misaligned_ex_i;
	input wire lsu_req_i;
	input wire [63:0] lsu_vaddr_i;
	input wire lsu_is_store_i;
	output wire lsu_dtlb_hit_o;
	output reg lsu_valid_o;
	output reg [63:0] lsu_paddr_o;
	output reg [128:0] lsu_exception_o;
	input wire [1:0] priv_lvl_i;
	input wire [1:0] ld_st_priv_lvl_i;
	input wire sum_i;
	input wire mxr_i;
	input wire [43:0] satp_ppn_i;
	input wire [ASID_WIDTH - 1:0] asid_i;
	input wire flush_tlb_i;
	output wire itlb_miss_o;
	output wire dtlb_miss_o;
	input wire [65:0] req_port_i;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	output wire [(ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77:0] req_port_o;
	reg iaccess_err;
	reg daccess_err;
	wire ptw_active;
	wire walking_instr;
	wire ptw_error;
	wire [38:0] update_vaddr;
	localparam ariane_pkg_ASID_WIDTH = 1;
	wire [94:0] update_ptw_itlb;
	wire [94:0] update_ptw_dtlb;
	wire itlb_lu_access;
	wire [63:0] itlb_content;
	wire itlb_is_2M;
	wire itlb_is_1G;
	wire itlb_lu_hit;
	wire dtlb_lu_access;
	wire [63:0] dtlb_content;
	wire dtlb_is_2M;
	wire dtlb_is_1G;
	wire dtlb_lu_hit;
	assign itlb_lu_access = icache_areq_i[64];
	assign dtlb_lu_access = lsu_req_i;
	tlb #(
		.TLB_ENTRIES(INSTR_TLB_ENTRIES),
		.ASID_WIDTH(ASID_WIDTH)
	) i_itlb(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_tlb_i),
		.update_i(update_ptw_itlb),
		.lu_access_i(itlb_lu_access),
		.lu_asid_i(asid_i),
		.lu_vaddr_i(icache_areq_i[63-:64]),
		.lu_content_o(itlb_content),
		.lu_is_2M_o(itlb_is_2M),
		.lu_is_1G_o(itlb_is_1G),
		.lu_hit_o(itlb_lu_hit)
	);
	tlb #(
		.TLB_ENTRIES(DATA_TLB_ENTRIES),
		.ASID_WIDTH(ASID_WIDTH)
	) i_dtlb(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(flush_tlb_i),
		.update_i(update_ptw_dtlb),
		.lu_access_i(dtlb_lu_access),
		.lu_asid_i(asid_i),
		.lu_vaddr_i(lsu_vaddr_i),
		.lu_content_o(dtlb_content),
		.lu_is_2M_o(dtlb_is_2M),
		.lu_is_1G_o(dtlb_is_1G),
		.lu_hit_o(dtlb_lu_hit)
	);
	ptw #(.ASID_WIDTH(ASID_WIDTH)) i_ptw(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.ptw_active_o(ptw_active),
		.walking_instr_o(walking_instr),
		.ptw_error_o(ptw_error),
		.enable_translation_i(enable_translation_i),
		.update_vaddr_o(update_vaddr),
		.itlb_update_o(update_ptw_itlb),
		.dtlb_update_o(update_ptw_dtlb),
		.itlb_access_i(itlb_lu_access),
		.itlb_hit_i(itlb_lu_hit),
		.itlb_vaddr_i(icache_areq_i[63-:64]),
		.dtlb_access_i(dtlb_lu_access),
		.dtlb_hit_i(dtlb_lu_hit),
		.dtlb_vaddr_i(lsu_vaddr_i),
		.req_port_i(req_port_i),
		.req_port_o(req_port_o),
		.flush_i(flush_i),
		.en_ld_st_translation_i(en_ld_st_translation_i),
		.lsu_is_store_i(lsu_is_store_i),
		.asid_i(asid_i),
		.satp_ppn_i(satp_ppn_i),
		.mxr_i(mxr_i),
		.itlb_miss_o(itlb_miss_o),
		.dtlb_miss_o(dtlb_miss_o)
	);
	localparam [63:0] riscv_INSTR_ACCESS_FAULT = 1;
	localparam [63:0] riscv_INSTR_PAGE_FAULT = 12;
	always @(*) begin : instr_interface
		if (_sv2v_0)
			;
		icache_areq_o[193] = icache_areq_i[64];
		icache_areq_o[192-:64] = icache_areq_i[63-:64];
		icache_areq_o[128-:129] = 1'sb0;
		iaccess_err = icache_areq_i[64] && (((priv_lvl_i == 2'b00) && ~itlb_content[4]) || ((priv_lvl_i == 2'b01) && itlb_content[4]));
		if (enable_translation_i) begin
			if (icache_areq_i[64] && !((&icache_areq_i[63:38] == 1'b1) || (|icache_areq_i[63:38] == 1'b0)))
				icache_areq_o[128-:129] = {riscv_INSTR_ACCESS_FAULT, icache_areq_i[63-:64], 1'b1};
			icache_areq_o[193] = 1'b0;
			icache_areq_o[192-:64] = {itlb_content[53-:44], icache_areq_i[11:0]};
			if (itlb_is_2M)
				icache_areq_o[149:141] = icache_areq_i[20:12];
			if (itlb_is_1G)
				icache_areq_o[158:141] = icache_areq_i[29:12];
			if (itlb_lu_hit) begin
				icache_areq_o[193] = icache_areq_i[64];
				if (iaccess_err)
					icache_areq_o[128-:129] = {riscv_INSTR_PAGE_FAULT, icache_areq_i[63-:64], 1'b1};
			end
			else if (ptw_active && walking_instr) begin
				icache_areq_o[193] = ptw_error;
				icache_areq_o[128-:129] = {riscv_INSTR_PAGE_FAULT, 25'b0000000000000000000000000, update_vaddr, 1'b1};
			end
		end
	end
	reg [63:0] lsu_vaddr_n;
	reg [63:0] lsu_vaddr_q;
	reg [63:0] dtlb_pte_n;
	reg [63:0] dtlb_pte_q;
	reg [128:0] misaligned_ex_n;
	reg [128:0] misaligned_ex_q;
	reg lsu_req_n;
	reg lsu_req_q;
	reg lsu_is_store_n;
	reg lsu_is_store_q;
	reg dtlb_hit_n;
	reg dtlb_hit_q;
	reg dtlb_is_2M_n;
	reg dtlb_is_2M_q;
	reg dtlb_is_1G_n;
	reg dtlb_is_1G_q;
	assign lsu_dtlb_hit_o = (en_ld_st_translation_i ? dtlb_lu_hit : 1'b1);
	localparam [63:0] riscv_LOAD_PAGE_FAULT = 13;
	localparam [63:0] riscv_STORE_PAGE_FAULT = 15;
	always @(*) begin : data_interface
		if (_sv2v_0)
			;
		lsu_vaddr_n = lsu_vaddr_i;
		lsu_req_n = lsu_req_i;
		misaligned_ex_n = misaligned_ex_i;
		dtlb_pte_n = dtlb_content;
		dtlb_hit_n = dtlb_lu_hit;
		lsu_is_store_n = lsu_is_store_i;
		dtlb_is_2M_n = dtlb_is_2M;
		dtlb_is_1G_n = dtlb_is_1G;
		lsu_paddr_o = lsu_vaddr_q;
		lsu_valid_o = lsu_req_q;
		lsu_exception_o = misaligned_ex_q;
		misaligned_ex_n[0] = misaligned_ex_i[0] & lsu_req_i;
		daccess_err = (((ld_st_priv_lvl_i == 2'b01) && !sum_i) && dtlb_pte_q[4]) || ((ld_st_priv_lvl_i == 2'b00) && !dtlb_pte_q[4]);
		if (en_ld_st_translation_i && !misaligned_ex_q[0]) begin
			lsu_valid_o = 1'b0;
			lsu_paddr_o = {dtlb_pte_q[53-:44], lsu_vaddr_q[11:0]};
			if (dtlb_is_2M_q)
				lsu_paddr_o[20:12] = lsu_vaddr_q[20:12];
			if (dtlb_is_1G_q)
				lsu_paddr_o[29:12] = lsu_vaddr_q[29:12];
			if (dtlb_hit_q && lsu_req_q) begin
				lsu_valid_o = 1'b1;
				if (lsu_is_store_q) begin
					if ((!dtlb_pte_q[2] || daccess_err) || !dtlb_pte_q[7])
						lsu_exception_o = {riscv_STORE_PAGE_FAULT, lsu_vaddr_q, 1'b1};
				end
				else if (daccess_err)
					lsu_exception_o = {riscv_LOAD_PAGE_FAULT, lsu_vaddr_q, 1'b1};
			end
			else if (ptw_active && !walking_instr) begin
				if (ptw_error) begin
					lsu_valid_o = 1'b1;
					if (lsu_is_store_q)
						lsu_exception_o = {riscv_STORE_PAGE_FAULT, 25'b0000000000000000000000000, update_vaddr, 1'b1};
					else
						lsu_exception_o = {riscv_LOAD_PAGE_FAULT, 25'b0000000000000000000000000, update_vaddr, 1'b1};
				end
			end
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			lsu_vaddr_q <= 1'sb0;
			lsu_req_q <= 1'sb0;
			misaligned_ex_q <= 1'sb0;
			dtlb_pte_q <= 1'sb0;
			dtlb_hit_q <= 1'sb0;
			lsu_is_store_q <= 1'sb0;
			dtlb_is_2M_q <= 1'sb0;
			dtlb_is_1G_q <= 1'sb0;
		end
		else begin
			lsu_vaddr_q <= lsu_vaddr_n;
			lsu_req_q <= lsu_req_n;
			misaligned_ex_q <= misaligned_ex_n;
			dtlb_pte_q <= dtlb_pte_n;
			dtlb_hit_q <= dtlb_hit_n;
			lsu_is_store_q <= lsu_is_store_n;
			dtlb_is_2M_q <= dtlb_is_2M_n;
			dtlb_is_1G_q <= dtlb_is_1G_n;
		end
	initial _sv2v_0 = 0;
endmodule
module mult (
	clk_i,
	rst_ni,
	flush_i,
	fu_data_i,
	mult_valid_i,
	result_o,
	mult_valid_o,
	mult_ready_o,
	mult_trans_id_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [205:0] fu_data_i;
	input wire mult_valid_i;
	output wire [63:0] result_o;
	output wire mult_valid_o;
	output wire mult_ready_o;
	output wire [2:0] mult_trans_id_o;
	wire mul_valid;
	wire div_valid;
	wire div_ready_i;
	wire [2:0] mul_trans_id;
	wire [2:0] div_trans_id;
	wire [63:0] mul_result;
	wire [63:0] div_result;
	wire div_valid_op;
	wire mul_valid_op;
	assign mul_valid_op = (~flush_i && mult_valid_i) && |{fu_data_i[201-:7] == 7'd67, fu_data_i[201-:7] == 7'd68, fu_data_i[201-:7] == 7'd69, fu_data_i[201-:7] == 7'd70, fu_data_i[201-:7] == 7'd71};
	assign div_valid_op = (~flush_i && mult_valid_i) && |{fu_data_i[201-:7] == 7'd72, fu_data_i[201-:7] == 7'd73, fu_data_i[201-:7] == 7'd74, fu_data_i[201-:7] == 7'd75, fu_data_i[201-:7] == 7'd76, fu_data_i[201-:7] == 7'd77, fu_data_i[201-:7] == 7'd78, fu_data_i[201-:7] == 7'd79};
	assign div_ready_i = (mul_valid ? 1'b0 : 1'b1);
	assign mult_trans_id_o = (mul_valid ? mul_trans_id : div_trans_id);
	assign result_o = (mul_valid ? mul_result : div_result);
	assign mult_valid_o = div_valid | mul_valid;
	multiplier i_multiplier(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.trans_id_i(fu_data_i[2-:ariane_pkg_TRANS_ID_BITS]),
		.operator_i(fu_data_i[201-:7]),
		.operand_a_i(fu_data_i[194-:64]),
		.operand_b_i(fu_data_i[130-:64]),
		.result_o(mul_result),
		.mult_valid_i(mul_valid_op),
		.mult_valid_o(mul_valid),
		.mult_trans_id_o(mul_trans_id),
		.mult_ready_o()
	);
	reg [63:0] operand_b;
	reg [63:0] operand_a;
	wire [63:0] result;
	wire div_signed;
	wire rem;
	reg word_op_d;
	reg word_op_q;
	assign div_signed = |{fu_data_i[201-:7] == 7'd72, fu_data_i[201-:7] == 7'd74, fu_data_i[201-:7] == 7'd76, fu_data_i[201-:7] == 7'd78};
	assign rem = |{fu_data_i[201-:7] == 7'd76, fu_data_i[201-:7] == 7'd77, fu_data_i[201-:7] == 7'd78, fu_data_i[201-:7] == 7'd79};
	function automatic [63:0] ariane_pkg_sext32;
		input reg [31:0] operand;
		ariane_pkg_sext32 = {{32 {operand[31]}}, operand[31:0]};
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		operand_a = 1'sb0;
		operand_b = 1'sb0;
		word_op_d = word_op_q;
		if (mult_valid_i && |{fu_data_i[201-:7] == 7'd72, fu_data_i[201-:7] == 7'd73, fu_data_i[201-:7] == 7'd74, fu_data_i[201-:7] == 7'd75, fu_data_i[201-:7] == 7'd76, fu_data_i[201-:7] == 7'd77, fu_data_i[201-:7] == 7'd78, fu_data_i[201-:7] == 7'd79}) begin
			if (|{fu_data_i[201-:7] == 7'd74, fu_data_i[201-:7] == 7'd75, fu_data_i[201-:7] == 7'd78, fu_data_i[201-:7] == 7'd79}) begin
				if (div_signed) begin
					operand_a = ariane_pkg_sext32(fu_data_i[162:131]);
					operand_b = ariane_pkg_sext32(fu_data_i[98:67]);
				end
				else begin
					operand_a = fu_data_i[162:131];
					operand_b = fu_data_i[98:67];
				end
				word_op_d = 1'b1;
			end
			else begin
				operand_a = fu_data_i[194-:64];
				operand_b = fu_data_i[130-:64];
				word_op_d = 1'b0;
			end
		end
	end
	serdiv #(.WIDTH(64)) i_div(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.id_i(fu_data_i[2-:ariane_pkg_TRANS_ID_BITS]),
		.op_a_i(operand_a),
		.op_b_i(operand_b),
		.opcode_i({rem, div_signed}),
		.in_vld_i(div_valid_op),
		.in_rdy_o(mult_ready_o),
		.flush_i(flush_i),
		.out_vld_o(div_valid),
		.out_rdy_i(div_ready_i),
		.id_o(div_trans_id),
		.res_o(result)
	);
	assign div_result = (word_op_q ? ariane_pkg_sext32(result) : result);
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni)
			word_op_q <= 1'sb0;
		else
			word_op_q <= word_op_d;
	initial _sv2v_0 = 0;
endmodule
module multiplier (
	clk_i,
	rst_ni,
	trans_id_i,
	mult_valid_i,
	operator_i,
	operand_a_i,
	operand_b_i,
	result_o,
	mult_valid_o,
	mult_ready_o,
	mult_trans_id_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [2:0] trans_id_i;
	input wire mult_valid_i;
	input wire [6:0] operator_i;
	input wire [63:0] operand_a_i;
	input wire [63:0] operand_b_i;
	output reg [63:0] result_o;
	output wire mult_valid_o;
	output wire mult_ready_o;
	output wire [2:0] mult_trans_id_o;
	reg [2:0] trans_id_q;
	reg mult_valid_q;
	wire [6:0] operator_d;
	reg [6:0] operator_q;
	wire [127:0] mult_result_d;
	reg [127:0] mult_result_q;
	reg sign_a;
	reg sign_b;
	wire mult_valid;
	assign mult_valid_o = mult_valid_q;
	assign mult_trans_id_o = trans_id_q;
	assign mult_ready_o = 1'b1;
	assign mult_valid = mult_valid_i && |{operator_i == 7'd67, operator_i == 7'd68, operator_i == 7'd69, operator_i == 7'd70, operator_i == 7'd71};
	wire [127:0] mult_result;
	assign mult_result = $signed({operand_a_i[63] & sign_a, operand_a_i}) * $signed({operand_b_i[63] & sign_b, operand_b_i});
	always @(*) begin
		if (_sv2v_0)
			;
		sign_a = 1'b0;
		sign_b = 1'b0;
		if (operator_i == 7'd68) begin
			sign_a = 1'b1;
			sign_b = 1'b1;
		end
		else if (operator_i == 7'd70)
			sign_a = 1'b1;
		else begin
			sign_a = 1'b0;
			sign_b = 1'b0;
		end
	end
	assign mult_result_d = $signed({operand_a_i[63] & sign_a, operand_a_i}) * $signed({operand_b_i[63] & sign_b, operand_b_i});
	assign operator_d = operator_i;
	function automatic [63:0] ariane_pkg_sext32;
		input reg [31:0] operand;
		ariane_pkg_sext32 = {{32 {operand[31]}}, operand[31:0]};
	endfunction
	always @(*) begin : p_selmux
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (operator_q)
			7'd68, 7'd69, 7'd70: result_o = mult_result_q[127:64];
			7'd71: result_o = ariane_pkg_sext32(mult_result_q[31:0]);
			default: result_o = mult_result_q[63:0];
		endcase
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			mult_valid_q <= 1'sb0;
			trans_id_q <= 1'sb0;
			operator_q <= 7'd67;
			mult_result_q <= 1'sb0;
		end
		else begin
			trans_id_q <= trans_id_i;
			mult_valid_q <= mult_valid;
			operator_q <= operator_d;
			mult_result_q <= mult_result_d;
		end
	initial _sv2v_0 = 0;
endmodule
module serdiv (
	clk_i,
	rst_ni,
	id_i,
	op_a_i,
	op_b_i,
	opcode_i,
	in_vld_i,
	in_rdy_o,
	flush_i,
	out_vld_o,
	out_rdy_i,
	id_o,
	res_o
);
	reg _sv2v_0;
	parameter WIDTH = 64;
	input wire clk_i;
	input wire rst_ni;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [2:0] id_i;
	input wire [WIDTH - 1:0] op_a_i;
	input wire [WIDTH - 1:0] op_b_i;
	input wire [1:0] opcode_i;
	input wire in_vld_i;
	output reg in_rdy_o;
	input wire flush_i;
	output reg out_vld_o;
	input wire out_rdy_i;
	output wire [2:0] id_o;
	output wire [WIDTH - 1:0] res_o;
	reg [1:0] state_d;
	reg [1:0] state_q;
	reg [WIDTH - 1:0] res_q;
	wire [WIDTH - 1:0] res_d;
	reg [WIDTH - 1:0] op_a_q;
	wire [WIDTH - 1:0] op_a_d;
	reg [WIDTH - 1:0] op_b_q;
	wire [WIDTH - 1:0] op_b_d;
	wire op_a_sign;
	wire op_b_sign;
	wire op_b_zero;
	reg op_b_zero_q;
	wire op_b_zero_d;
	reg [2:0] id_q;
	wire [2:0] id_d;
	wire rem_sel_d;
	reg rem_sel_q;
	wire comp_inv_d;
	reg comp_inv_q;
	wire res_inv_d;
	reg res_inv_q;
	wire [WIDTH - 1:0] add_mux;
	wire [WIDTH - 1:0] add_out;
	wire [WIDTH - 1:0] add_tmp;
	wire [WIDTH - 1:0] b_mux;
	wire [WIDTH - 1:0] out_mux;
	reg [$clog2(WIDTH + 1) - 1:0] cnt_q;
	wire [$clog2(WIDTH + 1) - 1:0] cnt_d;
	wire cnt_zero;
	wire [WIDTH - 1:0] lzc_a_input;
	wire [WIDTH - 1:0] lzc_b_input;
	wire [WIDTH - 1:0] op_b;
	wire [$clog2(WIDTH) - 1:0] lzc_a_result;
	wire [$clog2(WIDTH) - 1:0] lzc_b_result;
	wire [$clog2(WIDTH + 1) - 1:0] shift_a;
	wire [$clog2(WIDTH + 1):0] div_shift;
	reg a_reg_en;
	reg b_reg_en;
	reg res_reg_en;
	wire ab_comp;
	wire pm_sel;
	reg load_en;
	wire lzc_a_no_one;
	wire lzc_b_no_one;
	wire div_res_zero_d;
	reg div_res_zero_q;
	assign op_b_zero = op_b_i == 0;
	assign op_a_sign = op_a_i[WIDTH - 1];
	assign op_b_sign = op_b_i[WIDTH - 1];
	assign lzc_a_input = (opcode_i[0] & op_a_sign ? {~op_a_i, 1'b0} : op_a_i);
	assign lzc_b_input = (opcode_i[0] & op_b_sign ? ~op_b_i : op_b_i);
	lzc #(
		.MODE(1),
		.WIDTH(WIDTH)
	) i_lzc_a(
		.in_i(lzc_a_input),
		.cnt_o(lzc_a_result),
		.empty_o(lzc_a_no_one)
	);
	lzc #(
		.MODE(1),
		.WIDTH(WIDTH)
	) i_lzc_b(
		.in_i(lzc_b_input),
		.cnt_o(lzc_b_result),
		.empty_o(lzc_b_no_one)
	);
	assign shift_a = (lzc_a_no_one ? WIDTH : lzc_a_result);
	assign div_shift = (lzc_b_no_one ? WIDTH : lzc_b_result - shift_a);
	assign op_b = op_b_i <<< $unsigned(div_shift);
	assign div_res_zero_d = (load_en ? $signed(div_shift) < 0 : div_res_zero_q);
	assign pm_sel = load_en & ~(opcode_i[0] & (op_a_sign ^ op_b_sign));
	assign add_mux = (load_en ? op_a_i : op_b_q);
	assign b_mux = (load_en ? op_b : {comp_inv_q, op_b_q[WIDTH - 1:1]});
	assign out_mux = (rem_sel_q ? op_a_q : res_q);
	assign res_o = (res_inv_q ? -$signed(out_mux) : out_mux);
	assign ab_comp = ((op_a_q == op_b_q) | ((op_a_q > op_b_q) ^ comp_inv_q)) & (|op_a_q | op_b_zero_q);
	assign add_tmp = (load_en ? 0 : op_a_q);
	assign add_out = (pm_sel ? add_tmp + add_mux : add_tmp - $signed(add_mux));
	assign cnt_zero = cnt_q == 0;
	assign cnt_d = (load_en ? div_shift : (~cnt_zero ? cnt_q - 1 : cnt_q));
	always @(*) begin : p_fsm
		if (_sv2v_0)
			;
		state_d = state_q;
		in_rdy_o = 1'b0;
		out_vld_o = 1'b0;
		load_en = 1'b0;
		a_reg_en = 1'b0;
		b_reg_en = 1'b0;
		res_reg_en = 1'b0;
		(* full_case, parallel_case *)
		case (state_q)
			2'd0: begin
				in_rdy_o = 1'b1;
				if (in_vld_i) begin
					in_rdy_o = 1'b0;
					a_reg_en = 1'b1;
					b_reg_en = 1'b1;
					load_en = 1'b1;
					state_d = 2'd1;
				end
			end
			2'd1: begin
				if (~div_res_zero_q) begin
					a_reg_en = ab_comp;
					b_reg_en = 1'b1;
					res_reg_en = 1'b1;
				end
				if (div_res_zero_q) begin
					out_vld_o = 1'b1;
					state_d = 2'd2;
					if (out_rdy_i)
						state_d = 2'd0;
				end
				else if (cnt_zero)
					state_d = 2'd2;
			end
			2'd2: begin
				out_vld_o = 1'b1;
				if (out_rdy_i)
					state_d = 2'd0;
			end
			default: state_d = 2'd0;
		endcase
		if (flush_i) begin
			in_rdy_o = 1'b0;
			out_vld_o = 1'b0;
			a_reg_en = 1'b0;
			b_reg_en = 1'b0;
			load_en = 1'b0;
			state_d = 2'd0;
		end
	end
	assign rem_sel_d = (load_en ? opcode_i[1] : rem_sel_q);
	assign comp_inv_d = (load_en ? opcode_i[0] & op_b_sign : comp_inv_q);
	assign op_b_zero_d = (load_en ? op_b_zero : op_b_zero_q);
	assign res_inv_d = (load_en ? ((~op_b_zero | opcode_i[1]) & opcode_i[0]) & (op_a_sign ^ op_b_sign) : res_inv_q);
	assign id_d = (load_en ? id_i : id_q);
	assign id_o = id_q;
	assign op_a_d = (a_reg_en ? add_out : op_a_q);
	assign op_b_d = (b_reg_en ? b_mux : op_b_q);
	assign res_d = (load_en ? {WIDTH {1'sb0}} : (res_reg_en ? {res_q[WIDTH - 2:0], ab_comp} : res_q));
	always @(posedge clk_i or negedge rst_ni) begin : p_regs
		if (~rst_ni) begin
			state_q <= 2'd0;
			op_a_q <= 1'sb0;
			op_b_q <= 1'sb0;
			res_q <= 1'sb0;
			cnt_q <= 1'sb0;
			id_q <= 1'sb0;
			rem_sel_q <= 1'b0;
			comp_inv_q <= 1'b0;
			res_inv_q <= 1'b0;
			op_b_zero_q <= 1'b0;
			div_res_zero_q <= 1'b0;
		end
		else begin
			state_q <= state_d;
			op_a_q <= op_a_d;
			op_b_q <= op_b_d;
			res_q <= res_d;
			cnt_q <= cnt_d;
			id_q <= id_d;
			rem_sel_q <= rem_sel_d;
			comp_inv_q <= comp_inv_d;
			res_inv_q <= res_inv_d;
			op_b_zero_q <= op_b_zero_d;
			div_res_zero_q <= div_res_zero_d;
		end
	end
	initial _sv2v_0 = 0;
endmodule
module perf_counters (
	clk_i,
	rst_ni,
	debug_mode_i,
	addr_i,
	we_i,
	data_i,
	data_o,
	commit_instr_i,
	commit_ack_i,
	l1_icache_miss_i,
	l1_dcache_miss_i,
	itlb_miss_i,
	dtlb_miss_i,
	sb_full_i,
	if_empty_i,
	ex_i,
	eret_i,
	resolved_branch_i
);
	reg _sv2v_0;
	parameter [31:0] NR_EXTERNAL_COUNTERS = 1;
	input wire clk_i;
	input wire rst_ni;
	input wire debug_mode_i;
	input wire [11:0] addr_i;
	input wire we_i;
	input wire [63:0] data_i;
	output reg [63:0] data_o;
	localparam ariane_pkg_NR_COMMIT_PORTS = 2;
	localparam ariane_pkg_REG_ADDR_SIZE = 6;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [723:0] commit_instr_i;
	input wire [1:0] commit_ack_i;
	input wire l1_icache_miss_i;
	input wire l1_dcache_miss_i;
	input wire itlb_miss_i;
	input wire dtlb_miss_i;
	input wire sb_full_i;
	input wire if_empty_i;
	input wire [128:0] ex_i;
	input wire eret_i;
	input wire [133:0] resolved_branch_i;
	reg [895:0] perf_counter_d;
	reg [895:0] perf_counter_q;
	localparam [11:0] riscv_PERF_BRANCH_JUMP = 12'h008;
	localparam [11:0] riscv_PERF_CALL = 12'h009;
	localparam [11:0] riscv_PERF_DTLB_MISS = 12'h003;
	localparam [11:0] riscv_PERF_EXCEPTION = 12'h006;
	localparam [11:0] riscv_PERF_EXCEPTION_RET = 12'h007;
	localparam [11:0] riscv_PERF_IF_EMPTY = 12'h00d;
	localparam [11:0] riscv_PERF_ITLB_MISS = 12'h002;
	localparam [11:0] riscv_PERF_L1_DCACHE_MISS = 12'h001;
	localparam [11:0] riscv_PERF_L1_ICACHE_MISS = 12'h000;
	localparam [11:0] riscv_PERF_LOAD = 12'h004;
	localparam [11:0] riscv_PERF_MIS_PREDICT = 12'h00b;
	localparam [11:0] riscv_PERF_RET = 12'h00a;
	localparam [11:0] riscv_PERF_SB_FULL = 12'h00c;
	localparam [11:0] riscv_PERF_STORE = 12'h005;
	always @(*) begin : perf_counters
		if (_sv2v_0)
			;
		perf_counter_d = perf_counter_q;
		data_o = 'b0;
		if (!debug_mode_i) begin
			if (l1_icache_miss_i)
				perf_counter_d[0+:64] = perf_counter_q[0+:64] + 1'b1;
			if (l1_dcache_miss_i)
				perf_counter_d[64+:64] = perf_counter_q[64+:64] + 1'b1;
			if (itlb_miss_i)
				perf_counter_d[128+:64] = perf_counter_q[128+:64] + 1'b1;
			if (dtlb_miss_i)
				perf_counter_d[192+:64] = perf_counter_q[192+:64] + 1'b1;
			begin : sv2v_autoblock_1
				reg [31:0] i;
				for (i = 0; i < 1; i = i + 1)
					if (commit_ack_i[i]) begin
						if (commit_instr_i[(i * 362) + 294-:4] == 4'd1)
							perf_counter_d[256+:64] = perf_counter_q[256+:64] + 1'b1;
						if (commit_instr_i[(i * 362) + 294-:4] == 4'd2)
							perf_counter_d[320+:64] = perf_counter_q[320+:64] + 1'b1;
						if (commit_instr_i[(i * 362) + 294-:4] == 4'd4)
							perf_counter_d[512+:64] = perf_counter_q[512+:64] + 1'b1;
						if (((commit_instr_i[(i * 362) + 294-:4] == 4'd4) && (commit_instr_i[(i * 362) + 290-:7] == {7 {1'sb0}})) && (commit_instr_i[(i * 362) + 271-:6] == 'b1))
							perf_counter_d[576+:64] = perf_counter_q[576+:64] + 1'b1;
						if ((commit_instr_i[(i * 362) + 290-:7] == 7'd19) && (commit_instr_i[(i * 362) + 283-:6] == 'b1))
							perf_counter_d[640+:64] = perf_counter_q[640+:64] + 1'b1;
					end
			end
			if (ex_i[0])
				perf_counter_d[384+:64] = perf_counter_q[384+:64] + 1'b1;
			if (eret_i)
				perf_counter_d[448+:64] = perf_counter_q[448+:64] + 1'b1;
			if (resolved_branch_i[3] && resolved_branch_i[5])
				perf_counter_d[704+:64] = perf_counter_q[704+:64] + 1'b1;
			if (sb_full_i)
				perf_counter_d[768+:64] = perf_counter_q[768+:64] + 1'b1;
			if (if_empty_i)
				perf_counter_d[832+:64] = perf_counter_q[832+:64] + 1'b1;
		end
		if (!we_i)
			data_o = perf_counter_q[addr_i[2:0] * 64+:64];
		else begin
			data_o = perf_counter_q[addr_i[2:0] * 64+:64];
			perf_counter_d[addr_i[2:0] * 64+:64] = data_i;
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni)
			perf_counter_q <= 1'sb0;
		else
			perf_counter_q <= perf_counter_d;
	initial _sv2v_0 = 0;
endmodule
module ptw (
	clk_i,
	rst_ni,
	flush_i,
	ptw_active_o,
	walking_instr_o,
	ptw_error_o,
	enable_translation_i,
	en_ld_st_translation_i,
	lsu_is_store_i,
	req_port_i,
	req_port_o,
	itlb_update_o,
	dtlb_update_o,
	update_vaddr_o,
	asid_i,
	itlb_access_i,
	itlb_hit_i,
	itlb_vaddr_i,
	dtlb_access_i,
	dtlb_hit_i,
	dtlb_vaddr_i,
	satp_ppn_i,
	mxr_i,
	itlb_miss_o,
	dtlb_miss_o
);
	reg _sv2v_0;
	parameter signed [31:0] ASID_WIDTH = 1;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	output wire ptw_active_o;
	output wire walking_instr_o;
	output reg ptw_error_o;
	input wire enable_translation_i;
	input wire en_ld_st_translation_i;
	input wire lsu_is_store_i;
	input wire [65:0] req_port_i;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	output reg [(ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77:0] req_port_o;
	localparam ariane_pkg_ASID_WIDTH = 1;
	output reg [94:0] itlb_update_o;
	output reg [94:0] dtlb_update_o;
	output wire [38:0] update_vaddr_o;
	input wire [ASID_WIDTH - 1:0] asid_i;
	input wire itlb_access_i;
	input wire itlb_hit_i;
	input wire [63:0] itlb_vaddr_i;
	input wire dtlb_access_i;
	input wire dtlb_hit_i;
	input wire [63:0] dtlb_vaddr_i;
	input wire [43:0] satp_ppn_i;
	input wire mxr_i;
	output reg itlb_miss_o;
	output reg dtlb_miss_o;
	reg data_rvalid_q;
	reg [63:0] data_rdata_q;
	wire [63:0] pte;
	assign pte = data_rdata_q;
	reg [2:0] state_q;
	reg [2:0] state_d;
	reg [1:0] ptw_lvl_q;
	reg [1:0] ptw_lvl_n;
	reg is_instr_ptw_q;
	reg is_instr_ptw_n;
	reg global_mapping_q;
	reg global_mapping_n;
	reg tag_valid_n;
	reg tag_valid_q;
	reg [ASID_WIDTH - 1:0] tlb_update_asid_q;
	reg [ASID_WIDTH - 1:0] tlb_update_asid_n;
	reg [63:0] vaddr_q;
	reg [63:0] vaddr_n;
	reg [55:0] ptw_pptr_q;
	reg [55:0] ptw_pptr_n;
	assign update_vaddr_o = vaddr_q;
	assign ptw_active_o = state_q != 3'd0;
	assign walking_instr_o = is_instr_ptw_q;
	wire [12:1] sv2v_tmp_DEBA9;
	assign sv2v_tmp_DEBA9 = ptw_pptr_q[11:0];
	always @(*) req_port_o[133-:12] = sv2v_tmp_DEBA9;
	wire [44:1] sv2v_tmp_18F87;
	assign sv2v_tmp_18F87 = ptw_pptr_q[(ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) - 1:ariane_pkg_DCACHE_INDEX_WIDTH];
	always @(*) req_port_o[121-:44] = sv2v_tmp_18F87;
	wire [1:1] sv2v_tmp_77E14;
	assign sv2v_tmp_77E14 = 1'sb0;
	always @(*) req_port_o[1] = sv2v_tmp_77E14;
	wire [64:1] sv2v_tmp_04386;
	assign sv2v_tmp_04386 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
	always @(*) req_port_o[77-:64] = sv2v_tmp_04386;
	wire [27:1] sv2v_tmp_05395;
	assign sv2v_tmp_05395 = vaddr_q[38:12];
	always @(*) itlb_update_o[91-:27] = sv2v_tmp_05395;
	wire [27:1] sv2v_tmp_CA6F4;
	assign sv2v_tmp_CA6F4 = vaddr_q[38:12];
	always @(*) dtlb_update_o[91-:27] = sv2v_tmp_CA6F4;
	wire [1:1] sv2v_tmp_98420;
	assign sv2v_tmp_98420 = ptw_lvl_q == 2'd1;
	always @(*) itlb_update_o[93] = sv2v_tmp_98420;
	wire [1:1] sv2v_tmp_28501;
	assign sv2v_tmp_28501 = ptw_lvl_q == 2'd0;
	always @(*) itlb_update_o[92] = sv2v_tmp_28501;
	wire [1:1] sv2v_tmp_695A2;
	assign sv2v_tmp_695A2 = ptw_lvl_q == 2'd1;
	always @(*) dtlb_update_o[93] = sv2v_tmp_695A2;
	wire [1:1] sv2v_tmp_530F5;
	assign sv2v_tmp_530F5 = ptw_lvl_q == 2'd0;
	always @(*) dtlb_update_o[92] = sv2v_tmp_530F5;
	wire [1:1] sv2v_tmp_1AD05;
	assign sv2v_tmp_1AD05 = tlb_update_asid_q;
	always @(*) itlb_update_o[64-:1] = sv2v_tmp_1AD05;
	wire [1:1] sv2v_tmp_5EE58;
	assign sv2v_tmp_5EE58 = tlb_update_asid_q;
	always @(*) dtlb_update_o[64-:1] = sv2v_tmp_5EE58;
	wire [64:1] sv2v_tmp_4A99B;
	assign sv2v_tmp_4A99B = pte | (global_mapping_q << 5);
	always @(*) itlb_update_o[63-:64] = sv2v_tmp_4A99B;
	wire [64:1] sv2v_tmp_D5394;
	assign sv2v_tmp_D5394 = pte | (global_mapping_q << 5);
	always @(*) dtlb_update_o[63-:64] = sv2v_tmp_D5394;
	wire [1:1] sv2v_tmp_68ED2;
	assign sv2v_tmp_68ED2 = tag_valid_q;
	always @(*) req_port_o[0] = sv2v_tmp_68ED2;
	always @(*) begin : ptw
		if (_sv2v_0)
			;
		tag_valid_n = 1'b0;
		req_port_o[13] = 1'b0;
		req_port_o[11-:8] = 8'hff;
		req_port_o[3-:2] = 2'b11;
		req_port_o[12] = 1'b0;
		ptw_error_o = 1'b0;
		itlb_update_o[94] = 1'b0;
		dtlb_update_o[94] = 1'b0;
		is_instr_ptw_n = is_instr_ptw_q;
		ptw_lvl_n = ptw_lvl_q;
		ptw_pptr_n = ptw_pptr_q;
		state_d = state_q;
		global_mapping_n = global_mapping_q;
		tlb_update_asid_n = tlb_update_asid_q;
		vaddr_n = vaddr_q;
		itlb_miss_o = 1'b0;
		dtlb_miss_o = 1'b0;
		case (state_q)
			3'd0: begin
				ptw_lvl_n = 2'd0;
				global_mapping_n = 1'b0;
				is_instr_ptw_n = 1'b0;
				if (((enable_translation_i & itlb_access_i) & ~itlb_hit_i) & ~dtlb_access_i) begin
					ptw_pptr_n = {satp_ppn_i, itlb_vaddr_i[38:30], 3'b000};
					is_instr_ptw_n = 1'b1;
					tlb_update_asid_n = asid_i;
					vaddr_n = itlb_vaddr_i;
					state_d = 3'd1;
					itlb_miss_o = 1'b1;
				end
				else if ((en_ld_st_translation_i & dtlb_access_i) & ~dtlb_hit_i) begin
					ptw_pptr_n = {satp_ppn_i, dtlb_vaddr_i[38:30], 3'b000};
					tlb_update_asid_n = asid_i;
					vaddr_n = dtlb_vaddr_i;
					state_d = 3'd1;
					dtlb_miss_o = 1'b1;
				end
			end
			3'd1: begin
				req_port_o[13] = 1'b1;
				if (req_port_i[65]) begin
					tag_valid_n = 1'b1;
					state_d = 3'd2;
				end
			end
			3'd2:
				if (data_rvalid_q) begin
					if (pte[5])
						global_mapping_n = 1'b1;
					if (!pte[0] || (!pte[1] && pte[2]))
						state_d = 3'd4;
					else begin
						state_d = 3'd0;
						if (pte[1] || pte[3]) begin
							if (is_instr_ptw_q) begin
								if (!pte[3] || !pte[6])
									state_d = 3'd4;
								else
									itlb_update_o[94] = 1'b1;
							end
							else begin
								if (pte[6] && (pte[1] || (pte[3] && mxr_i)))
									dtlb_update_o[94] = 1'b1;
								else
									state_d = 3'd4;
								if (lsu_is_store_i && (!pte[2] || !pte[7])) begin
									dtlb_update_o[94] = 1'b0;
									state_d = 3'd4;
								end
							end
							if ((ptw_lvl_q == 2'd0) && (pte[27:10] != {18 {1'sb0}})) begin
								state_d = 3'd4;
								dtlb_update_o[94] = 1'b0;
								itlb_update_o[94] = 1'b0;
							end
							else if ((ptw_lvl_q == 2'd1) && (pte[18:10] != {9 {1'sb0}})) begin
								state_d = 3'd4;
								dtlb_update_o[94] = 1'b0;
								itlb_update_o[94] = 1'b0;
							end
						end
						else begin
							if (ptw_lvl_q == 2'd0) begin
								ptw_lvl_n = 2'd1;
								ptw_pptr_n = {pte[53-:44], vaddr_q[29:21], 3'b000};
							end
							if (ptw_lvl_q == 2'd1) begin
								ptw_lvl_n = 2'd2;
								ptw_pptr_n = {pte[53-:44], vaddr_q[20:12], 3'b000};
							end
							state_d = 3'd1;
							if (ptw_lvl_q == 2'd2) begin
								ptw_lvl_n = 2'd2;
								state_d = 3'd4;
							end
						end
					end
				end
			3'd4: begin
				state_d = 3'd0;
				ptw_error_o = 1'b1;
			end
			3'd3:
				if (data_rvalid_q)
					state_d = 3'd0;
			default: state_d = 3'd0;
		endcase
		if (flush_i) begin
			if (((state_q == 3'd2) && !data_rvalid_q) || ((state_q == 3'd1) && req_port_i[65]))
				state_d = 3'd3;
			else
				state_d = 3'd0;
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			state_q <= 3'd0;
			is_instr_ptw_q <= 1'b0;
			ptw_lvl_q <= 2'd0;
			tag_valid_q <= 1'b0;
			tlb_update_asid_q <= 1'sb0;
			vaddr_q <= 1'sb0;
			ptw_pptr_q <= 1'sb0;
			global_mapping_q <= 1'b0;
			data_rdata_q <= 1'sb0;
			data_rvalid_q <= 1'b0;
		end
		else begin
			state_q <= state_d;
			ptw_pptr_q <= ptw_pptr_n;
			is_instr_ptw_q <= is_instr_ptw_n;
			ptw_lvl_q <= ptw_lvl_n;
			tag_valid_q <= tag_valid_n;
			tlb_update_asid_q <= tlb_update_asid_n;
			vaddr_q <= vaddr_n;
			global_mapping_q <= global_mapping_n;
			data_rdata_q <= req_port_i[63-:64];
			data_rvalid_q <= req_port_i[64];
		end
	initial _sv2v_0 = 0;
endmodule
module ariane_regfile (
	clk_i,
	rst_ni,
	test_en_i,
	raddr_i,
	rdata_o,
	waddr_i,
	wdata_i,
	we_i
);
	reg _sv2v_0;
	parameter [31:0] DATA_WIDTH = 32;
	parameter [31:0] NR_READ_PORTS = 2;
	parameter [31:0] NR_WRITE_PORTS = 2;
	parameter [0:0] ZERO_REG_ZERO = 0;
	input wire clk_i;
	input wire rst_ni;
	input wire test_en_i;
	input wire [(NR_READ_PORTS * 5) - 1:0] raddr_i;
	output wire [(NR_READ_PORTS * DATA_WIDTH) - 1:0] rdata_o;
	input wire [(NR_WRITE_PORTS * 5) - 1:0] waddr_i;
	input wire [(NR_WRITE_PORTS * DATA_WIDTH) - 1:0] wdata_i;
	input wire [NR_WRITE_PORTS - 1:0] we_i;
	localparam ADDR_WIDTH = 5;
	localparam NUM_WORDS = 32;
	reg [(32 * DATA_WIDTH) - 1:0] mem;
	reg [(NR_WRITE_PORTS * 32) - 1:0] we_dec;
	always @(*) begin : we_decoder
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg [31:0] j;
			for (j = 0; j < NR_WRITE_PORTS; j = j + 1)
				begin : sv2v_autoblock_2
					reg [31:0] i;
					for (i = 0; i < NUM_WORDS; i = i + 1)
						if (waddr_i[j * 5+:5] == i)
							we_dec[(j * 32) + i] = we_i[j];
						else
							we_dec[(j * 32) + i] = 1'b0;
				end
		end
	end
	function automatic [DATA_WIDTH - 1:0] sv2v_cast_A81DF;
		input reg [DATA_WIDTH - 1:0] inp;
		sv2v_cast_A81DF = inp;
	endfunction
	always @(posedge clk_i or negedge rst_ni) begin : register_write_behavioral
		if (~rst_ni)
			mem <= {NUM_WORDS {sv2v_cast_A81DF(1'sb0)}};
		else begin : sv2v_autoblock_3
			reg [31:0] j;
			for (j = 0; j < NR_WRITE_PORTS; j = j + 1)
				begin
					begin : sv2v_autoblock_4
						reg [31:0] i;
						for (i = 0; i < NUM_WORDS; i = i + 1)
							if (we_dec[(j * 32) + i])
								mem[i * DATA_WIDTH+:DATA_WIDTH] <= wdata_i[j * DATA_WIDTH+:DATA_WIDTH];
					end
					if (ZERO_REG_ZERO)
						mem[0+:DATA_WIDTH] <= 1'sb0;
				end
		end
	end
	genvar _gv_i_8;
	generate
		for (_gv_i_8 = 0; _gv_i_8 < NR_READ_PORTS; _gv_i_8 = _gv_i_8 + 1) begin : genblk1
			localparam i = _gv_i_8;
			assign rdata_o[i * DATA_WIDTH+:DATA_WIDTH] = mem[raddr_i[i * 5+:5] * DATA_WIDTH+:DATA_WIDTH];
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
module re_name (
	clk_i,
	rst_ni,
	flush_i,
	flush_unissied_instr_i,
	issue_instr_i,
	issue_instr_valid_i,
	issue_ack_o,
	issue_instr_o,
	issue_instr_valid_o,
	issue_ack_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire flush_unissied_instr_i;
	localparam ariane_pkg_REG_ADDR_SIZE = 6;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [361:0] issue_instr_i;
	input wire issue_instr_valid_i;
	output wire issue_ack_o;
	output reg [361:0] issue_instr_o;
	output wire issue_instr_valid_o;
	input wire issue_ack_i;
	assign issue_instr_valid_o = issue_instr_valid_i;
	assign issue_ack_o = issue_ack_i;
	reg [31:0] re_name_table_gpr_n;
	reg [31:0] re_name_table_gpr_q;
	reg [31:0] re_name_table_fpr_n;
	reg [31:0] re_name_table_fpr_q;
	localparam ariane_pkg_ENABLE_RENAME = 1'b0;
	localparam [0:0] ariane_pkg_RVD = 1'b0;
	localparam [0:0] ariane_pkg_RVF = 1'b0;
	localparam [0:0] ariane_pkg_XF16 = 1'b0;
	localparam [0:0] ariane_pkg_XF16ALT = 1'b0;
	localparam [0:0] ariane_pkg_XF8 = 1'b0;
	localparam [0:0] ariane_pkg_FP_PRESENT = (((ariane_pkg_RVF | ariane_pkg_RVD) | ariane_pkg_XF16) | ariane_pkg_XF16ALT) | ariane_pkg_XF8;
	function automatic ariane_pkg_is_imm_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd88 <= op) && (7'd89 >= op), (7'd94 <= op) && (7'd97 >= op), (7'd117 <= op) && (7'd120 >= op)})
				ariane_pkg_is_imm_fpr = 1'b1;
			else
				ariane_pkg_is_imm_fpr = 1'b0;
		end
		else
			ariane_pkg_is_imm_fpr = 1'b0;
	endfunction
	function automatic ariane_pkg_is_rd_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd80 <= op) && (7'd83 >= op), (7'd88 <= op) && (7'd97 >= op), op == 7'd99, op == 7'd100, op == 7'd101, op == 7'd103, (7'd106 <= op) && (7'd110 >= op), (7'd117 <= op) && (7'd120 >= op)})
				ariane_pkg_is_rd_fpr = 1'b1;
			else
				ariane_pkg_is_rd_fpr = 1'b0;
		end
		else
			ariane_pkg_is_rd_fpr = 1'b0;
	endfunction
	function automatic ariane_pkg_is_rs1_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd90 <= op) && (7'd97 >= op), op == 7'd98, op == 7'd100, op == 7'd101, op == 7'd102, op == 7'd104, op == 7'd105, (7'd106 <= op) && (7'd120 >= op)})
				ariane_pkg_is_rs1_fpr = 1'b1;
			else
				ariane_pkg_is_rs1_fpr = 1'b0;
		end
		else
			ariane_pkg_is_rs1_fpr = 1'b0;
	endfunction
	function automatic ariane_pkg_is_rs2_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd84 <= op) && (7'd87 >= op), (7'd88 <= op) && (7'd92 >= op), (7'd94 <= op) && (7'd97 >= op), op == 7'd100, (7'd101 <= op) && (7'd102 >= op), op == 7'd104, (7'd106 <= op) && (7'd120 >= op)})
				ariane_pkg_is_rs2_fpr = 1'b1;
			else
				ariane_pkg_is_rs2_fpr = 1'b0;
		end
		else
			ariane_pkg_is_rs2_fpr = 1'b0;
	endfunction
	always @(*) begin : sv2v_autoblock_1
		reg name_bit_rs1;
		reg name_bit_rs2;
		reg name_bit_rs3;
		reg name_bit_rd;
		if (_sv2v_0)
			;
		re_name_table_gpr_n = re_name_table_gpr_q;
		re_name_table_fpr_n = re_name_table_fpr_q;
		issue_instr_o = issue_instr_i;
		if (issue_ack_i && !flush_unissied_instr_i) begin
			if (ariane_pkg_is_rd_fpr(issue_instr_i[290-:7]))
				re_name_table_fpr_n[issue_instr_i[271-:6]] = re_name_table_fpr_q[issue_instr_i[271-:6]] ^ 1'b1;
			else
				re_name_table_gpr_n[issue_instr_i[271-:6]] = re_name_table_gpr_q[issue_instr_i[271-:6]] ^ 1'b1;
		end
		name_bit_rs1 = (ariane_pkg_is_rs1_fpr(issue_instr_i[290-:7]) ? re_name_table_fpr_q[issue_instr_i[283-:6]] : re_name_table_gpr_q[issue_instr_i[283-:6]]);
		name_bit_rs2 = (ariane_pkg_is_rs2_fpr(issue_instr_i[290-:7]) ? re_name_table_fpr_q[issue_instr_i[277-:6]] : re_name_table_gpr_q[issue_instr_i[277-:6]]);
		name_bit_rs3 = re_name_table_fpr_q[issue_instr_i[206:202]];
		name_bit_rd = (ariane_pkg_is_rd_fpr(issue_instr_i[290-:7]) ? re_name_table_fpr_q[issue_instr_i[271-:6]] ^ 1'b1 : re_name_table_gpr_q[issue_instr_i[271-:6]] ^ (issue_instr_i[271-:6] != {6 {1'sb0}}));
		issue_instr_o[283-:6] = {ariane_pkg_ENABLE_RENAME & name_bit_rs1, issue_instr_i[282:278]};
		issue_instr_o[277-:6] = {ariane_pkg_ENABLE_RENAME & name_bit_rs2, issue_instr_i[276:272]};
		if (ariane_pkg_is_imm_fpr(issue_instr_i[290-:7]))
			issue_instr_o[265-:64] = {ariane_pkg_ENABLE_RENAME & name_bit_rs3, issue_instr_i[206:202]};
		issue_instr_o[271-:6] = {ariane_pkg_ENABLE_RENAME & name_bit_rd, issue_instr_i[270:266]};
		re_name_table_gpr_n[0] = 1'b0;
		if (flush_i) begin
			re_name_table_gpr_n = 1'sb0;
			re_name_table_fpr_n = 1'sb0;
		end
	end
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			re_name_table_gpr_q <= 1'sb0;
			re_name_table_fpr_q <= 1'sb0;
		end
		else begin
			re_name_table_gpr_q <= re_name_table_gpr_n;
			re_name_table_fpr_q <= re_name_table_fpr_n;
		end
	initial _sv2v_0 = 0;
endmodule
module scoreboard (
	clk_i,
	rst_ni,
	sb_full_o,
	flush_unissued_instr_i,
	flush_i,
	unresolved_branch_i,
	rd_clobber_gpr_o,
	rd_clobber_fpr_o,
	rs1_i,
	rs1_o,
	rs1_valid_o,
	rs2_i,
	rs2_o,
	rs2_valid_o,
	rs3_i,
	rs3_o,
	rs3_valid_o,
	commit_instr_o,
	commit_ack_i,
	decoded_instr_i,
	decoded_instr_valid_i,
	decoded_instr_ack_o,
	issue_instr_o,
	issue_instr_valid_o,
	issue_ack_i,
	resolved_branch_i,
	trans_id_i,
	wbdata_i,
	ex_i,
	wb_valid_i
);
	reg _sv2v_0;
	parameter [31:0] NR_ENTRIES = 8;
	parameter [31:0] NR_WB_PORTS = 1;
	parameter [31:0] NR_COMMIT_PORTS = 2;
	input wire clk_i;
	input wire rst_ni;
	output wire sb_full_o;
	input wire flush_unissued_instr_i;
	input wire flush_i;
	input wire unresolved_branch_i;
	localparam ariane_pkg_REG_ADDR_SIZE = 6;
	output reg [259:0] rd_clobber_gpr_o;
	output reg [259:0] rd_clobber_fpr_o;
	input wire [5:0] rs1_i;
	output reg [63:0] rs1_o;
	output reg rs1_valid_o;
	input wire [5:0] rs2_i;
	output reg [63:0] rs2_o;
	output reg rs2_valid_o;
	input wire [5:0] rs3_i;
	localparam [0:0] ariane_pkg_RVD = 1'b0;
	localparam [0:0] ariane_pkg_RVF = 1'b0;
	localparam [0:0] ariane_pkg_XF16 = 1'b0;
	localparam [0:0] ariane_pkg_XF16ALT = 1'b0;
	localparam [0:0] ariane_pkg_XF8 = 1'b0;
	localparam ariane_pkg_FLEN = (ariane_pkg_RVD ? 64 : (ariane_pkg_RVF ? 32 : (ariane_pkg_XF16 ? 16 : (ariane_pkg_XF16ALT ? 16 : (ariane_pkg_XF8 ? 8 : 0)))));
	output reg [ariane_pkg_FLEN - 1:0] rs3_o;
	output reg rs3_valid_o;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	output reg [(NR_COMMIT_PORTS * 362) - 1:0] commit_instr_o;
	input wire [NR_COMMIT_PORTS - 1:0] commit_ack_i;
	input wire [361:0] decoded_instr_i;
	input wire decoded_instr_valid_i;
	output reg decoded_instr_ack_o;
	output reg [361:0] issue_instr_o;
	output reg issue_instr_valid_o;
	input wire issue_ack_i;
	input wire [133:0] resolved_branch_i;
	input wire [(NR_WB_PORTS * 3) - 1:0] trans_id_i;
	input wire [(NR_WB_PORTS * 64) - 1:0] wbdata_i;
	input wire [(NR_WB_PORTS * 129) - 1:0] ex_i;
	input wire [NR_WB_PORTS - 1:0] wb_valid_i;
	localparam [31:0] BITS_ENTRIES = $clog2(NR_ENTRIES);
	reg [(NR_ENTRIES * 363) - 1:0] mem_q;
	reg [(NR_ENTRIES * 363) - 1:0] mem_n;
	reg [BITS_ENTRIES - 1:0] issue_cnt_n;
	reg [BITS_ENTRIES - 1:0] issue_cnt_q;
	reg [BITS_ENTRIES - 1:0] issue_pointer_n;
	reg [BITS_ENTRIES - 1:0] issue_pointer_q;
	reg [BITS_ENTRIES - 1:0] commit_pointer_n;
	reg [BITS_ENTRIES - 1:0] commit_pointer_q;
	wire issue_full;
	assign issue_full = issue_cnt_q == (NR_ENTRIES - 1);
	assign sb_full_o = issue_full;
	always @(*) begin : commit_ports
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg [BITS_ENTRIES - 1:0] i;
			for (i = 0; i < NR_COMMIT_PORTS; i = i + 1)
				commit_instr_o[i * 362+:362] = mem_q[((commit_pointer_q + i) * 363) + 361-:362];
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		issue_instr_o = decoded_instr_i;
		issue_instr_o[297-:3] = issue_pointer_q;
		issue_instr_valid_o = (decoded_instr_valid_i && !unresolved_branch_i) && !issue_full;
		decoded_instr_ack_o = issue_ack_i && !issue_full;
	end
	always @(*) begin : issue_fifo
		reg [BITS_ENTRIES - 1:0] issue_cnt;
		reg [BITS_ENTRIES - 1:0] commit_pointer;
		if (_sv2v_0)
			;
		commit_pointer = commit_pointer_q;
		issue_cnt = issue_cnt_q;
		mem_n = mem_q;
		issue_pointer_n = issue_pointer_q;
		if ((decoded_instr_valid_i && decoded_instr_ack_o) && !flush_unissued_instr_i) begin
			issue_cnt = issue_cnt + 1;
			mem_n[issue_pointer_q * 363+:363] = {1'b1, decoded_instr_i};
			issue_pointer_n = issue_pointer_q + 1'b1;
		end
		begin : sv2v_autoblock_2
			reg [31:0] i;
			for (i = 0; i < NR_WB_PORTS; i = i + 1)
				if (wb_valid_i[i] && mem_n[(trans_id_i[i * 3+:3] * 363) + 362]) begin
					mem_n[(trans_id_i[i * 3+:3] * 363) + 201] = 1'b1;
					mem_n[(trans_id_i[i * 3+:3] * 363) + 265-:64] = wbdata_i[i * 64+:64];
					mem_n[(trans_id_i[i * 3+:3] * 363) + 67-:64] = resolved_branch_i[69-:64];
					if (ex_i[i * 129])
						mem_n[(trans_id_i[i * 3+:3] * 363) + 197-:129] = ex_i[i * 129+:129];
					else if (|{mem_n[(trans_id_i[i * 3+:3] * 363) + 294-:4] == 4'd7, mem_n[(trans_id_i[i * 3+:3] * 363) + 294-:4] == 4'd8})
						mem_n[(trans_id_i[i * 3+:3] * 363) + 197-:64] = ex_i[(i * 129) + 128-:64];
				end
		end
		begin : sv2v_autoblock_3
			reg [BITS_ENTRIES - 1:0] i;
			for (i = 0; i < NR_COMMIT_PORTS; i = i + 1)
				if (commit_ack_i[i]) begin
					issue_cnt = issue_cnt - 1;
					mem_n[((commit_pointer_q + i) * 363) + 362] = 1'b0;
					mem_n[((commit_pointer_q + i) * 363) + 201] = 1'b0;
					commit_pointer = commit_pointer + 1;
				end
		end
		if (flush_i) begin : sv2v_autoblock_4
			reg [31:0] i;
			for (i = 0; i < NR_ENTRIES; i = i + 1)
				begin
					mem_n[(i * 363) + 362] = 1'b0;
					mem_n[(i * 363) + 201] = 1'b0;
					mem_n[(i * 363) + 69] = 1'b0;
					issue_cnt = 1'sb0;
					issue_pointer_n = 1'sb0;
					commit_pointer = 1'sb0;
				end
		end
		issue_cnt_n = issue_cnt;
		commit_pointer_n = commit_pointer;
	end
	localparam [0:0] ariane_pkg_FP_PRESENT = (((ariane_pkg_RVF | ariane_pkg_RVD) | ariane_pkg_XF16) | ariane_pkg_XF16ALT) | ariane_pkg_XF8;
	function automatic ariane_pkg_is_rd_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd80 <= op) && (7'd83 >= op), (7'd88 <= op) && (7'd97 >= op), op == 7'd99, op == 7'd100, op == 7'd101, op == 7'd103, (7'd106 <= op) && (7'd110 >= op), (7'd117 <= op) && (7'd120 >= op)})
				ariane_pkg_is_rd_fpr = 1'b1;
			else
				ariane_pkg_is_rd_fpr = 1'b0;
		end
		else
			ariane_pkg_is_rd_fpr = 1'b0;
	endfunction
	always @(*) begin : clobber_output
		if (_sv2v_0)
			;
		rd_clobber_gpr_o = {65 {4'd0}};
		rd_clobber_fpr_o = {65 {4'd0}};
		begin : sv2v_autoblock_5
			reg [31:0] i;
			for (i = 0; i < NR_ENTRIES; i = i + 1)
				if (mem_q[(i * 363) + 362]) begin
					if (ariane_pkg_is_rd_fpr(mem_q[(i * 363) + 290-:7]))
						rd_clobber_fpr_o[mem_q[(i * 363) + 271-:6] * 4+:4] = mem_q[(i * 363) + 294-:4];
					else
						rd_clobber_gpr_o[mem_q[(i * 363) + 271-:6] * 4+:4] = mem_q[(i * 363) + 294-:4];
				end
		end
		rd_clobber_gpr_o[0+:4] = 4'd0;
	end
	function automatic ariane_pkg_is_imm_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd88 <= op) && (7'd89 >= op), (7'd94 <= op) && (7'd97 >= op), (7'd117 <= op) && (7'd120 >= op)})
				ariane_pkg_is_imm_fpr = 1'b1;
			else
				ariane_pkg_is_imm_fpr = 1'b0;
		end
		else
			ariane_pkg_is_imm_fpr = 1'b0;
	endfunction
	function automatic ariane_pkg_is_rs1_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd90 <= op) && (7'd97 >= op), op == 7'd98, op == 7'd100, op == 7'd101, op == 7'd102, op == 7'd104, op == 7'd105, (7'd106 <= op) && (7'd120 >= op)})
				ariane_pkg_is_rs1_fpr = 1'b1;
			else
				ariane_pkg_is_rs1_fpr = 1'b0;
		end
		else
			ariane_pkg_is_rs1_fpr = 1'b0;
	endfunction
	function automatic ariane_pkg_is_rs2_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd84 <= op) && (7'd87 >= op), (7'd88 <= op) && (7'd92 >= op), (7'd94 <= op) && (7'd97 >= op), op == 7'd100, (7'd101 <= op) && (7'd102 >= op), op == 7'd104, (7'd106 <= op) && (7'd120 >= op)})
				ariane_pkg_is_rs2_fpr = 1'b1;
			else
				ariane_pkg_is_rs2_fpr = 1'b0;
		end
		else
			ariane_pkg_is_rs2_fpr = 1'b0;
	endfunction
	always @(*) begin : sv2v_autoblock_6
		reg [1:0] _sv2v_jump;
		_sv2v_jump = 2'b00;
		begin : read_operands
			if (_sv2v_0)
				;
			rs1_o = 64'b0000000000000000000000000000000000000000000000000000000000000000;
			rs2_o = 64'b0000000000000000000000000000000000000000000000000000000000000000;
			rs3_o = 1'sb0;
			rs1_valid_o = 1'b0;
			rs2_valid_o = 1'b0;
			rs3_valid_o = 1'b0;
			begin : sv2v_autoblock_7
				reg [31:0] i;
				for (i = 0; i < NR_ENTRIES; i = i + 1)
					if (mem_q[(i * 363) + 362]) begin
						if ((mem_q[(i * 363) + 271-:6] == rs1_i) && (ariane_pkg_is_rd_fpr(mem_q[(i * 363) + 290-:7]) == ariane_pkg_is_rs1_fpr(issue_instr_o[290-:7]))) begin
							rs1_o = mem_q[(i * 363) + 265-:64];
							rs1_valid_o = mem_q[(i * 363) + 201];
						end
						else if ((mem_q[(i * 363) + 271-:6] == rs2_i) && (ariane_pkg_is_rd_fpr(mem_q[(i * 363) + 290-:7]) == ariane_pkg_is_rs2_fpr(issue_instr_o[290-:7]))) begin
							rs2_o = mem_q[(i * 363) + 265-:64];
							rs2_valid_o = mem_q[(i * 363) + 201];
						end
						else if ((mem_q[(i * 363) + 271-:6] == rs3_i) && (ariane_pkg_is_rd_fpr(mem_q[(i * 363) + 290-:7]) == ariane_pkg_is_imm_fpr(issue_instr_o[290-:7]))) begin
							rs3_o = mem_q[(i * 363) + 265-:64];
							rs3_valid_o = mem_q[(i * 363) + 201];
						end
					end
			end
			begin : sv2v_autoblock_8
				reg [31:0] j;
				begin : sv2v_autoblock_9
					reg [31:0] _sv2v_value_on_break;
					for (j = 0; j < NR_WB_PORTS; j = j + 1)
						if (_sv2v_jump < 2'b10) begin
							_sv2v_jump = 2'b00;
							if ((((mem_q[(trans_id_i[j * 3+:3] * 363) + 271-:6] == rs1_i) && wb_valid_i[j]) && ~ex_i[j * 129]) && (ariane_pkg_is_rd_fpr(mem_q[(trans_id_i[j * 3+:3] * 363) + 290-:7]) == ariane_pkg_is_rs1_fpr(issue_instr_o[290-:7]))) begin
								rs1_o = wbdata_i[j * 64+:64];
								rs1_valid_o = wb_valid_i[j];
								_sv2v_jump = 2'b10;
							end
							if (_sv2v_jump == 2'b00) begin
								if ((((mem_q[(trans_id_i[j * 3+:3] * 363) + 271-:6] == rs2_i) && wb_valid_i[j]) && ~ex_i[j * 129]) && (ariane_pkg_is_rd_fpr(mem_q[(trans_id_i[j * 3+:3] * 363) + 290-:7]) == ariane_pkg_is_rs2_fpr(issue_instr_o[290-:7]))) begin
									rs2_o = wbdata_i[j * 64+:64];
									rs2_valid_o = wb_valid_i[j];
									_sv2v_jump = 2'b10;
								end
								if (_sv2v_jump == 2'b00) begin
									if ((((mem_q[(trans_id_i[j * 3+:3] * 363) + 271-:6] == rs3_i) && wb_valid_i[j]) && ~ex_i[j * 129]) && (ariane_pkg_is_rd_fpr(mem_q[(trans_id_i[j * 3+:3] * 363) + 290-:7]) == ariane_pkg_is_imm_fpr(issue_instr_o[290-:7]))) begin
										rs3_o = wbdata_i[j * 64+:64];
										rs3_valid_o = wb_valid_i[j];
										_sv2v_jump = 2'b10;
									end
								end
							end
							_sv2v_value_on_break = j;
						end
					if (!(_sv2v_jump < 2'b10))
						j = _sv2v_value_on_break;
					if (_sv2v_jump != 2'b11)
						_sv2v_jump = 2'b00;
				end
			end
			if (_sv2v_jump == 2'b00) begin
				if ((rs1_i == {6 {1'sb0}}) && ~ariane_pkg_is_rs1_fpr(issue_instr_o[290-:7]))
					rs1_valid_o = 1'b0;
				if ((rs2_i == {6 {1'sb0}}) && ~ariane_pkg_is_rs2_fpr(issue_instr_o[290-:7]))
					rs2_valid_o = 1'b0;
			end
		end
	end
	function automatic [361:0] sv2v_cast_5011A;
		input reg [361:0] inp;
		sv2v_cast_5011A = inp;
	endfunction
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			mem_q <= {NR_ENTRIES {{1'sb0, sv2v_cast_5011A(0)}}};
			issue_cnt_q <= 1'sb0;
			commit_pointer_q <= 1'sb0;
			issue_pointer_q <= 1'sb0;
		end
		else begin
			issue_cnt_q <= issue_cnt_n;
			issue_pointer_q <= issue_pointer_n;
			mem_q <= mem_n;
			commit_pointer_q <= commit_pointer_n;
		end
	initial _sv2v_0 = 0;
endmodule
module store_buffer (
	clk_i,
	rst_ni,
	flush_i,
	no_st_pending_o,
	page_offset_i,
	page_offset_matches_o,
	commit_i,
	commit_ready_o,
	ready_o,
	valid_i,
	valid_without_flush_i,
	paddr_i,
	data_i,
	be_i,
	data_size_i,
	req_port_i,
	req_port_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	output reg no_st_pending_o;
	input wire [11:0] page_offset_i;
	output reg page_offset_matches_o;
	input wire commit_i;
	output reg commit_ready_o;
	output reg ready_o;
	input wire valid_i;
	input wire valid_without_flush_i;
	input wire [63:0] paddr_i;
	input wire [63:0] data_i;
	input wire [7:0] be_i;
	input wire [1:0] data_size_i;
	input wire [65:0] req_port_i;
	localparam [31:0] ariane_pkg_DCACHE_INDEX_WIDTH = 12;
	localparam [31:0] ariane_pkg_DCACHE_TAG_WIDTH = 44;
	output reg [(ariane_pkg_DCACHE_INDEX_WIDTH + ariane_pkg_DCACHE_TAG_WIDTH) + 77:0] req_port_o;
	localparam [31:0] ariane_pkg_DEPTH_SPEC = 4;
	reg [555:0] speculative_queue_n;
	reg [555:0] speculative_queue_q;
	localparam [31:0] ariane_pkg_DEPTH_COMMIT = 8;
	reg [1111:0] commit_queue_n;
	reg [1111:0] commit_queue_q;
	reg [2:0] speculative_status_cnt_n;
	reg [2:0] speculative_status_cnt_q;
	reg [3:0] commit_status_cnt_n;
	reg [3:0] commit_status_cnt_q;
	reg [1:0] speculative_read_pointer_n;
	reg [1:0] speculative_read_pointer_q;
	reg [1:0] speculative_write_pointer_n;
	reg [1:0] speculative_write_pointer_q;
	reg [2:0] commit_read_pointer_n;
	reg [2:0] commit_read_pointer_q;
	reg [2:0] commit_write_pointer_n;
	reg [2:0] commit_write_pointer_q;
	always @(*) begin : core_if
		reg [ariane_pkg_DEPTH_SPEC:0] speculative_status_cnt;
		if (_sv2v_0)
			;
		speculative_status_cnt = speculative_status_cnt_q;
		ready_o = (speculative_status_cnt_q < 3) || commit_i;
		speculative_status_cnt_n = speculative_status_cnt_q;
		speculative_read_pointer_n = speculative_read_pointer_q;
		speculative_write_pointer_n = speculative_write_pointer_q;
		speculative_queue_n = speculative_queue_q;
		if (valid_i) begin
			speculative_queue_n[(speculative_write_pointer_q * 139) + 138-:64] = paddr_i;
			speculative_queue_n[(speculative_write_pointer_q * 139) + 74-:64] = data_i;
			speculative_queue_n[(speculative_write_pointer_q * 139) + 10-:8] = be_i;
			speculative_queue_n[(speculative_write_pointer_q * 139) + 2-:2] = data_size_i;
			speculative_queue_n[speculative_write_pointer_q * 139] = 1'b1;
			speculative_write_pointer_n = speculative_write_pointer_q + 1'b1;
			speculative_status_cnt = speculative_status_cnt + 1;
		end
		if (commit_i) begin
			speculative_queue_n[speculative_read_pointer_q * 139] = 1'b0;
			speculative_read_pointer_n = speculative_read_pointer_q + 1'b1;
			speculative_status_cnt = speculative_status_cnt - 1;
		end
		speculative_status_cnt_n = speculative_status_cnt;
		if (flush_i) begin
			begin : sv2v_autoblock_1
				reg [31:0] i;
				for (i = 0; i < ariane_pkg_DEPTH_SPEC; i = i + 1)
					speculative_queue_n[i * 139] = 1'b0;
			end
			speculative_write_pointer_n = speculative_read_pointer_q;
			speculative_status_cnt_n = 'b0;
		end
	end
	wire [1:1] sv2v_tmp_F02E0;
	assign sv2v_tmp_F02E0 = 1'b0;
	always @(*) req_port_o[1] = sv2v_tmp_F02E0;
	wire [1:1] sv2v_tmp_2EFB7;
	assign sv2v_tmp_2EFB7 = 1'b1;
	always @(*) req_port_o[12] = sv2v_tmp_2EFB7;
	wire [1:1] sv2v_tmp_B67F0;
	assign sv2v_tmp_B67F0 = 1'b0;
	always @(*) req_port_o[0] = sv2v_tmp_B67F0;
	wire [12:1] sv2v_tmp_113B6;
	assign sv2v_tmp_113B6 = commit_queue_q[(commit_read_pointer_q * 139) + 86-:12];
	always @(*) req_port_o[133-:12] = sv2v_tmp_113B6;
	wire [44:1] sv2v_tmp_151F0;
	assign sv2v_tmp_151F0 = commit_queue_q[(commit_read_pointer_q * 139) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) + 74) >= 87 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) + 74 : (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) + 74) + (((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) + 74) >= 87 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) - 12 : 88 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) + 74))) - 1)-:(((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) + 74) >= 87 ? (ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) - 12 : 88 - ((ariane_pkg_DCACHE_TAG_WIDTH + ariane_pkg_DCACHE_INDEX_WIDTH) + 74))];
	always @(*) req_port_o[121-:44] = sv2v_tmp_151F0;
	wire [64:1] sv2v_tmp_EBC66;
	assign sv2v_tmp_EBC66 = commit_queue_q[(commit_read_pointer_q * 139) + 74-:64];
	always @(*) req_port_o[77-:64] = sv2v_tmp_EBC66;
	wire [8:1] sv2v_tmp_C219E;
	assign sv2v_tmp_C219E = commit_queue_q[(commit_read_pointer_q * 139) + 10-:8];
	always @(*) req_port_o[11-:8] = sv2v_tmp_C219E;
	wire [2:1] sv2v_tmp_81D41;
	assign sv2v_tmp_81D41 = commit_queue_q[(commit_read_pointer_q * 139) + 2-:2];
	always @(*) req_port_o[3-:2] = sv2v_tmp_81D41;
	always @(*) begin : store_if
		reg [ariane_pkg_DEPTH_COMMIT:0] commit_status_cnt;
		if (_sv2v_0)
			;
		commit_status_cnt = commit_status_cnt_q;
		commit_ready_o = commit_status_cnt_q < ariane_pkg_DEPTH_COMMIT;
		no_st_pending_o = commit_status_cnt_q == 0;
		commit_read_pointer_n = commit_read_pointer_q;
		commit_write_pointer_n = commit_write_pointer_q;
		commit_queue_n = commit_queue_q;
		req_port_o[13] = 1'b0;
		if (commit_queue_q[commit_read_pointer_q * 139]) begin
			req_port_o[13] = 1'b1;
			if (req_port_i[65]) begin
				commit_queue_n[commit_read_pointer_q * 139] = 1'b0;
				commit_read_pointer_n = commit_read_pointer_q + 1'b1;
				commit_status_cnt = commit_status_cnt - 1;
			end
		end
		if (commit_i) begin
			commit_queue_n[commit_write_pointer_q * 139+:139] = speculative_queue_q[speculative_read_pointer_q * 139+:139];
			commit_write_pointer_n = commit_write_pointer_n + 1'b1;
			commit_status_cnt = commit_status_cnt + 1;
		end
		commit_status_cnt_n = commit_status_cnt;
	end
	always @(*) begin : sv2v_autoblock_2
		reg [1:0] _sv2v_jump;
		_sv2v_jump = 2'b00;
		begin : address_checker
			if (_sv2v_0)
				;
			page_offset_matches_o = 1'b0;
			begin : sv2v_autoblock_3
				reg [31:0] i;
				begin : sv2v_autoblock_4
					reg [31:0] _sv2v_value_on_break;
					for (i = 0; i < ariane_pkg_DEPTH_COMMIT; i = i + 1)
						if (_sv2v_jump < 2'b10) begin
							_sv2v_jump = 2'b00;
							if ((page_offset_i[11:3] == commit_queue_q[(i * 139) + 86-:9]) && commit_queue_q[i * 139]) begin
								page_offset_matches_o = 1'b1;
								_sv2v_jump = 2'b10;
							end
							_sv2v_value_on_break = i;
						end
					if (!(_sv2v_jump < 2'b10))
						i = _sv2v_value_on_break;
					if (_sv2v_jump != 2'b11)
						_sv2v_jump = 2'b00;
				end
			end
			if (_sv2v_jump == 2'b00) begin
				begin : sv2v_autoblock_5
					reg [31:0] i;
					begin : sv2v_autoblock_6
						reg [31:0] _sv2v_value_on_break;
						for (i = 0; i < ariane_pkg_DEPTH_SPEC; i = i + 1)
							if (_sv2v_jump < 2'b10) begin
								_sv2v_jump = 2'b00;
								if ((page_offset_i[11:3] == speculative_queue_q[(i * 139) + 86-:9]) && speculative_queue_q[i * 139]) begin
									page_offset_matches_o = 1'b1;
									_sv2v_jump = 2'b10;
								end
								_sv2v_value_on_break = i;
							end
						if (!(_sv2v_jump < 2'b10))
							i = _sv2v_value_on_break;
						if (_sv2v_jump != 2'b11)
							_sv2v_jump = 2'b00;
					end
				end
				if (_sv2v_jump == 2'b00) begin
					if ((page_offset_i[11:3] == paddr_i[11:3]) && valid_without_flush_i)
						page_offset_matches_o = 1'b1;
				end
			end
		end
	end
	always @(posedge clk_i or negedge rst_ni) begin : p_spec
		if (~rst_ni) begin
			speculative_queue_q <= {ariane_pkg_DEPTH_SPEC {139'd0}};
			speculative_read_pointer_q <= 1'sb0;
			speculative_write_pointer_q <= 1'sb0;
			speculative_status_cnt_q <= 1'sb0;
		end
		else begin
			speculative_queue_q <= speculative_queue_n;
			speculative_read_pointer_q <= speculative_read_pointer_n;
			speculative_write_pointer_q <= speculative_write_pointer_n;
			speculative_status_cnt_q <= speculative_status_cnt_n;
		end
	end
	always @(posedge clk_i or negedge rst_ni) begin : p_commit
		if (~rst_ni) begin
			commit_queue_q <= {ariane_pkg_DEPTH_COMMIT {139'd0}};
			commit_read_pointer_q <= 1'sb0;
			commit_write_pointer_q <= 1'sb0;
			commit_status_cnt_q <= 1'sb0;
		end
		else begin
			commit_queue_q <= commit_queue_n;
			commit_read_pointer_q <= commit_read_pointer_n;
			commit_write_pointer_q <= commit_write_pointer_n;
			commit_status_cnt_q <= commit_status_cnt_n;
		end
	end
	initial _sv2v_0 = 0;
endmodule
module tlb (
	clk_i,
	rst_ni,
	flush_i,
	update_i,
	lu_access_i,
	lu_asid_i,
	lu_vaddr_i,
	lu_content_o,
	lu_is_2M_o,
	lu_is_1G_o,
	lu_hit_o
);
	reg _sv2v_0;
	parameter [31:0] TLB_ENTRIES = 4;
	parameter [31:0] ASID_WIDTH = 1;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	localparam ariane_pkg_ASID_WIDTH = 1;
	input wire [94:0] update_i;
	input wire lu_access_i;
	input wire [ASID_WIDTH - 1:0] lu_asid_i;
	input wire [63:0] lu_vaddr_i;
	output reg [63:0] lu_content_o;
	output reg lu_is_2M_o;
	output reg lu_is_1G_o;
	output reg lu_hit_o;
	reg [((ASID_WIDTH + 29) >= 0 ? (TLB_ENTRIES * (ASID_WIDTH + 30)) - 1 : (TLB_ENTRIES * (1 - (ASID_WIDTH + 29))) + (ASID_WIDTH + 28)):((ASID_WIDTH + 29) >= 0 ? 0 : ASID_WIDTH + 29)] tags_q;
	reg [((ASID_WIDTH + 29) >= 0 ? (TLB_ENTRIES * (ASID_WIDTH + 30)) - 1 : (TLB_ENTRIES * (1 - (ASID_WIDTH + 29))) + (ASID_WIDTH + 28)):((ASID_WIDTH + 29) >= 0 ? 0 : ASID_WIDTH + 29)] tags_n;
	reg [(TLB_ENTRIES * 64) - 1:0] content_q;
	reg [(TLB_ENTRIES * 64) - 1:0] content_n;
	reg [8:0] vpn0;
	reg [8:0] vpn1;
	reg [8:0] vpn2;
	reg [TLB_ENTRIES - 1:0] lu_hit;
	reg [TLB_ENTRIES - 1:0] replace_en;
	always @(*) begin : translation
		if (_sv2v_0)
			;
		vpn0 = lu_vaddr_i[20:12];
		vpn1 = lu_vaddr_i[29:21];
		vpn2 = lu_vaddr_i[38:30];
		lu_hit = {TLB_ENTRIES {1'd0}};
		lu_hit_o = 1'b0;
		lu_content_o = 64'h0000000000000000;
		lu_is_1G_o = 1'b0;
		lu_is_2M_o = 1'b0;
		begin : sv2v_autoblock_1
			reg [31:0] i;
			for (i = 0; i < TLB_ENTRIES; i = i + 1)
				if ((tags_q[(i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 0 : ASID_WIDTH + 29)] && (lu_asid_i == tags_q[((ASID_WIDTH + 29) >= 0 ? (i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 29 : (ASID_WIDTH + 29) - (ASID_WIDTH + 29)) : (((i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 29 : (ASID_WIDTH + 29) - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 30 ? ASID_WIDTH + 0 : 31 - (ASID_WIDTH + 29))) - 1)-:((ASID_WIDTH + 29) >= 30 ? ASID_WIDTH + 0 : 31 - (ASID_WIDTH + 29))])) && (vpn2 == tags_q[((ASID_WIDTH + 29) >= 0 ? (i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 29 : ASID_WIDTH + 0) : ((i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 29 : ASID_WIDTH + 0)) + 8)-:9])) begin
					if (tags_q[(i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 1 : ASID_WIDTH + 28)]) begin
						lu_is_1G_o = 1'b1;
						lu_content_o = content_q[i * 64+:64];
						lu_hit_o = 1'b1;
						lu_hit[i] = 1'b1;
					end
					else if (vpn1 == tags_q[((ASID_WIDTH + 29) >= 0 ? (i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 20 : ASID_WIDTH + 9) : ((i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 20 : ASID_WIDTH + 9)) + 8)-:9]) begin
						if (tags_q[(i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 2 : ASID_WIDTH + 27)] || (vpn0 == tags_q[((ASID_WIDTH + 29) >= 0 ? (i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 11 : ASID_WIDTH + 18) : ((i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 11 : ASID_WIDTH + 18)) + 8)-:9])) begin
							lu_is_2M_o = tags_q[(i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 2 : ASID_WIDTH + 27)];
							lu_content_o = content_q[i * 64+:64];
							lu_hit_o = 1'b1;
							lu_hit[i] = 1'b1;
						end
					end
				end
		end
	end
	function automatic [ASID_WIDTH - 1:0] sv2v_cast_CEB87;
		input reg [ASID_WIDTH - 1:0] inp;
		sv2v_cast_CEB87 = inp;
	endfunction
	always @(*) begin : update_flush
		if (_sv2v_0)
			;
		tags_n = tags_q;
		content_n = content_q;
		begin : sv2v_autoblock_2
			reg [31:0] i;
			for (i = 0; i < TLB_ENTRIES; i = i + 1)
				if (flush_i) begin
					if (lu_asid_i == 1'b0)
						tags_n[(i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 0 : ASID_WIDTH + 29)] = 1'b0;
					else if (lu_asid_i == tags_q[((ASID_WIDTH + 29) >= 0 ? (i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 29 : (ASID_WIDTH + 29) - (ASID_WIDTH + 29)) : (((i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 29 : (ASID_WIDTH + 29) - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 30 ? ASID_WIDTH + 0 : 31 - (ASID_WIDTH + 29))) - 1)-:((ASID_WIDTH + 29) >= 30 ? ASID_WIDTH + 0 : 31 - (ASID_WIDTH + 29))])
						tags_n[(i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))) + ((ASID_WIDTH + 29) >= 0 ? 0 : ASID_WIDTH + 29)] = 1'b0;
				end
				else if (update_i[94] & replace_en[i]) begin
					tags_n[((ASID_WIDTH + 29) >= 0 ? 0 : ASID_WIDTH + 29) + (i * ((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29)))+:((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29))] = {sv2v_cast_CEB87(update_i[64-:1]), update_i[91:83], update_i[82:74], update_i[73:65], update_i[93], update_i[92], 1'b1};
					content_n[i * 64+:64] = update_i[63-:64];
				end
		end
	end
	reg [(2 * (TLB_ENTRIES - 1)) - 1:0] plru_tree_q;
	reg [(2 * (TLB_ENTRIES - 1)) - 1:0] plru_tree_n;
	always @(*) begin : plru_replacement
		if (_sv2v_0)
			;
		plru_tree_n = plru_tree_q;
		begin : sv2v_autoblock_3
			reg [31:0] i;
			for (i = 0; i < TLB_ENTRIES; i = i + 1)
				begin : sv2v_autoblock_4
					reg [31:0] idx_base;
					reg [31:0] shift;
					reg [31:0] new_index;
					if (lu_hit[i] & lu_access_i) begin : sv2v_autoblock_5
						reg [31:0] lvl;
						for (lvl = 0; lvl < $clog2(TLB_ENTRIES); lvl = lvl + 1)
							begin
								idx_base = $unsigned((2 ** lvl) - 1);
								shift = $clog2(TLB_ENTRIES) - lvl;
								new_index = ~((i >> (shift - 1)) & 32'b00000000000000000000000000000001);
								plru_tree_n[idx_base + (i >> shift)] = new_index[0];
							end
					end
				end
		end
		begin : sv2v_autoblock_6
			reg [31:0] i;
			for (i = 0; i < TLB_ENTRIES; i = i + 1)
				begin : sv2v_autoblock_7
					reg en;
					reg [31:0] idx_base;
					reg [31:0] shift;
					reg [31:0] new_index;
					en = 1'b1;
					begin : sv2v_autoblock_8
						reg [31:0] lvl;
						for (lvl = 0; lvl < $clog2(TLB_ENTRIES); lvl = lvl + 1)
							begin
								idx_base = $unsigned((2 ** lvl) - 1);
								shift = $clog2(TLB_ENTRIES) - lvl;
								new_index = (i >> (shift - 1)) & 32'b00000000000000000000000000000001;
								if (new_index[0])
									en = en & plru_tree_q[idx_base + (i >> shift)];
								else
									en = en & ~plru_tree_q[idx_base + (i >> shift)];
							end
					end
					replace_en[i] = en;
				end
		end
	end
	function automatic [((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29)) - 1:0] sv2v_cast_C4767;
		input reg [((ASID_WIDTH + 29) >= 0 ? ASID_WIDTH + 30 : 1 - (ASID_WIDTH + 29)) - 1:0] inp;
		sv2v_cast_C4767 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_ni)
		if (~rst_ni) begin
			tags_q <= {TLB_ENTRIES {sv2v_cast_C4767(0)}};
			content_q <= {TLB_ENTRIES {64'd0}};
			plru_tree_q <= {2 * (TLB_ENTRIES - 1) {1'd0}};
		end
		else begin
			tags_q <= tags_n;
			content_q <= content_n;
			plru_tree_q <= plru_tree_n;
		end
	initial _sv2v_0 = 0;
endmodule
module commit_stage (
	clk_i,
	rst_ni,
	halt_i,
	flush_dcache_i,
	exception_o,
	dirty_fp_state_o,
	debug_mode_i,
	debug_req_i,
	single_step_i,
	commit_instr_i,
	commit_ack_o,
	waddr_o,
	wdata_o,
	we_gpr_o,
	we_fpr_o,
	amo_resp_i,
	pc_o,
	csr_op_o,
	csr_wdata_o,
	csr_rdata_i,
	csr_exception_i,
	csr_write_fflags_o,
	commit_lsu_o,
	commit_lsu_ready_i,
	amo_valid_commit_o,
	no_st_pending_i,
	commit_csr_o,
	fence_i_o,
	fence_o,
	flush_commit_o,
	sfence_vma_o
);
	reg _sv2v_0;
	parameter [31:0] NR_COMMIT_PORTS = 2;
	input wire clk_i;
	input wire rst_ni;
	input wire halt_i;
	input wire flush_dcache_i;
	output reg [128:0] exception_o;
	output wire dirty_fp_state_o;
	input wire debug_mode_i;
	input wire debug_req_i;
	input wire single_step_i;
	localparam ariane_pkg_REG_ADDR_SIZE = 6;
	localparam ariane_pkg_NR_SB_ENTRIES = 8;
	localparam ariane_pkg_TRANS_ID_BITS = 3;
	input wire [(NR_COMMIT_PORTS * 362) - 1:0] commit_instr_i;
	output reg [NR_COMMIT_PORTS - 1:0] commit_ack_o;
	output wire [(NR_COMMIT_PORTS * 5) - 1:0] waddr_o;
	output reg [(NR_COMMIT_PORTS * 64) - 1:0] wdata_o;
	output reg [NR_COMMIT_PORTS - 1:0] we_gpr_o;
	output reg [NR_COMMIT_PORTS - 1:0] we_fpr_o;
	input wire [64:0] amo_resp_i;
	output wire [63:0] pc_o;
	output reg [6:0] csr_op_o;
	output reg [63:0] csr_wdata_o;
	input wire [63:0] csr_rdata_i;
	input wire [128:0] csr_exception_i;
	output reg csr_write_fflags_o;
	output reg commit_lsu_o;
	input wire commit_lsu_ready_i;
	output reg amo_valid_commit_o;
	input wire no_st_pending_i;
	output reg commit_csr_o;
	output reg fence_i_o;
	output reg fence_o;
	output reg flush_commit_o;
	output reg sfence_vma_o;
	assign waddr_o[0+:5] = commit_instr_i[270-:5];
	assign waddr_o[5+:5] = commit_instr_i[632-:5];
	assign pc_o = commit_instr_i[361-:64];
	assign dirty_fp_state_o = |we_fpr_o;
	wire instr_0_is_amo;
	function automatic ariane_pkg_is_amo;
		input reg [6:0] op;
		if ((7'd45 <= op) && (7'd66 >= op))
			ariane_pkg_is_amo = 1'b1;
		else
			ariane_pkg_is_amo = 1'b0;
	endfunction
	assign instr_0_is_amo = ariane_pkg_is_amo(commit_instr_i[290-:7]);
	localparam [0:0] ariane_pkg_RVA = 1'b1;
	localparam [0:0] ariane_pkg_RVD = 1'b0;
	localparam [0:0] ariane_pkg_RVF = 1'b0;
	localparam [0:0] ariane_pkg_XF16 = 1'b0;
	localparam [0:0] ariane_pkg_XF16ALT = 1'b0;
	localparam [0:0] ariane_pkg_XF8 = 1'b0;
	localparam [0:0] ariane_pkg_FP_PRESENT = (((ariane_pkg_RVF | ariane_pkg_RVD) | ariane_pkg_XF16) | ariane_pkg_XF16ALT) | ariane_pkg_XF8;
	function automatic ariane_pkg_is_rd_fpr;
		input reg [6:0] op;
		if (ariane_pkg_FP_PRESENT) begin
			(* full_case, parallel_case *)
			if (|{(7'd80 <= op) && (7'd83 >= op), (7'd88 <= op) && (7'd97 >= op), op == 7'd99, op == 7'd100, op == 7'd101, op == 7'd103, (7'd106 <= op) && (7'd110 >= op), (7'd117 <= op) && (7'd120 >= op)})
				ariane_pkg_is_rd_fpr = 1'b1;
			else
				ariane_pkg_is_rd_fpr = 1'b0;
		end
		else
			ariane_pkg_is_rd_fpr = 1'b0;
	endfunction
	always @(*) begin : commit
		if (_sv2v_0)
			;
		commit_ack_o[0] = 1'b0;
		commit_ack_o[1] = 1'b0;
		amo_valid_commit_o = 1'b0;
		we_gpr_o[0] = 1'b0;
		we_gpr_o[1] = 1'b0;
		we_fpr_o = {NR_COMMIT_PORTS {1'b0}};
		commit_lsu_o = 1'b0;
		commit_csr_o = 1'b0;
		wdata_o[0+:64] = (amo_resp_i[64] ? amo_resp_i[63-:64] : commit_instr_i[265-:64]);
		wdata_o[64+:64] = commit_instr_i[627-:64];
		csr_op_o = 7'd0;
		csr_wdata_o = 64'b0000000000000000000000000000000000000000000000000000000000000000;
		fence_i_o = 1'b0;
		fence_o = 1'b0;
		sfence_vma_o = 1'b0;
		csr_write_fflags_o = 1'b0;
		flush_commit_o = 1'b0;
		if (commit_instr_i[201] && !halt_i) begin
			if (!debug_req_i || debug_mode_i) begin
				commit_ack_o[0] = 1'b1;
				if (!exception_o[0]) begin
					if (ariane_pkg_is_rd_fpr(commit_instr_i[290-:7]))
						we_fpr_o[0] = 1'b1;
					else
						we_gpr_o[0] = 1'b1;
					if ((commit_instr_i[294-:4] == 4'd2) && !instr_0_is_amo) begin
						if (commit_lsu_ready_i)
							commit_lsu_o = 1'b1;
						else
							commit_ack_o[0] = 1'b0;
					end
					if (|{commit_instr_i[294-:4] == 4'd7, commit_instr_i[294-:4] == 4'd8}) begin
						csr_wdata_o = {59'b00000000000000000000000000000000000000000000000000000000000, commit_instr_i[138-:5]};
						csr_write_fflags_o = 1'b1;
					end
				end
				if (commit_instr_i[294-:4] == 4'd6) begin
					commit_csr_o = 1'b1;
					wdata_o[0+:64] = csr_rdata_i;
					csr_op_o = commit_instr_i[290-:7];
					csr_wdata_o = commit_instr_i[265-:64];
				end
				if (commit_instr_i[290-:7] == 7'd29) begin
					sfence_vma_o = no_st_pending_i;
					commit_ack_o[0] = no_st_pending_i;
				end
				if ((commit_instr_i[290-:7] == 7'd28) || (flush_dcache_i && (commit_instr_i[294-:4] != 4'd2))) begin
					commit_ack_o[0] = no_st_pending_i;
					fence_i_o = no_st_pending_i;
				end
				if (commit_instr_i[290-:7] == 7'd27) begin
					commit_ack_o[0] = no_st_pending_i;
					fence_o = no_st_pending_i;
				end
			end
			if ((ariane_pkg_RVA && instr_0_is_amo) && !commit_instr_i[69]) begin
				commit_ack_o[0] = amo_resp_i[64];
				amo_valid_commit_o = 1'b1;
				we_gpr_o[0] = amo_resp_i[64];
			end
		end
		if (((((commit_ack_o[0] && commit_instr_i[563]) && !halt_i) && (commit_instr_i[294-:4] != 4'd6)) && !flush_dcache_i) && !single_step_i) begin
			if ((!exception_o[0] && !commit_instr_i[431]) && |{commit_instr_i[656-:4] == 4'd3, commit_instr_i[656-:4] == 4'd1, commit_instr_i[656-:4] == 4'd4, commit_instr_i[656-:4] == 4'd5, commit_instr_i[656-:4] == 4'd7, commit_instr_i[656-:4] == 4'd8}) begin
				if (ariane_pkg_is_rd_fpr(commit_instr_i[652-:7]))
					we_fpr_o[1] = 1'b1;
				else
					we_gpr_o[1] = 1'b1;
				commit_ack_o[1] = 1'b1;
				if (|{commit_instr_i[656-:4] == 4'd7, commit_instr_i[656-:4] == 4'd8}) begin
					if (csr_write_fflags_o)
						csr_wdata_o = {59'b00000000000000000000000000000000000000000000000000000000000, commit_instr_i[138-:5] | commit_instr_i[500-:5]};
					else
						csr_wdata_o = {59'b00000000000000000000000000000000000000000000000000000000000, commit_instr_i[500-:5]};
					csr_write_fflags_o = 1'b1;
				end
			end
		end
	end
	always @(*) begin : exception_handling
		if (_sv2v_0)
			;
		exception_o[0] = 1'b0;
		exception_o[128-:64] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
		exception_o[64-:64] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
		if (commit_instr_i[201]) begin
			if (csr_exception_i[0] && !csr_exception_i[128]) begin
				exception_o = csr_exception_i;
				exception_o[64-:64] = commit_instr_i[133-:64];
			end
			if (commit_instr_i[69])
				exception_o = commit_instr_i[197-:129];
			if ((csr_exception_i[0] && csr_exception_i[128]) && (commit_instr_i[294-:4] != 4'd6)) begin
				exception_o = csr_exception_i;
				exception_o[64-:64] = commit_instr_i[133-:64];
			end
		end
		if (halt_i)
			exception_o[0] = 1'b0;
	end
	initial _sv2v_0 = 0;
`ifdef FORMAL
	always @(posedge clk_i) begin
		if (rst_ni) begin
`ifdef FORMAL_P21
			HACK_DAC19_p21: assert (!(amo_valid_commit_o) || (exception_o != csr_exception_i));
`endif
`ifdef FORMAL_P22
			HACK_DAC19_p22: assert (!(amo_valid_commit_o) || !commit_ack_o[1]);
`endif
		end
	end
`endif
endmodule
module dmi_cdc (
	tck_i,
	trst_ni,
	jtag_dmi_req_i,
	jtag_dmi_ready_o,
	jtag_dmi_valid_i,
	jtag_dmi_resp_o,
	jtag_dmi_valid_o,
	jtag_dmi_ready_i,
	clk_i,
	rst_ni,
	core_dmi_req_o,
	core_dmi_valid_o,
	core_dmi_ready_i,
	core_dmi_resp_i,
	core_dmi_ready_o,
	core_dmi_valid_i
);
	input wire tck_i;
	input wire trst_ni;
	input wire [40:0] jtag_dmi_req_i;
	output wire jtag_dmi_ready_o;
	input wire jtag_dmi_valid_i;
	output wire [33:0] jtag_dmi_resp_o;
	output wire jtag_dmi_valid_o;
	input wire jtag_dmi_ready_i;
	input wire clk_i;
	input wire rst_ni;
	output wire [40:0] core_dmi_req_o;
	output wire core_dmi_valid_o;
	input wire core_dmi_ready_i;
	input wire [33:0] core_dmi_resp_i;
	output wire core_dmi_ready_o;
	input wire core_dmi_valid_i;
	cdc_2phase_5E31A i_cdc_req(
		.src_rst_ni(trst_ni),
		.src_clk_i(tck_i),
		.src_data_i(jtag_dmi_req_i),
		.src_valid_i(jtag_dmi_valid_i),
		.src_ready_o(jtag_dmi_ready_o),
		.dst_rst_ni(rst_ni),
		.dst_clk_i(clk_i),
		.dst_data_o(core_dmi_req_o),
		.dst_valid_o(core_dmi_valid_o),
		.dst_ready_i(core_dmi_ready_i)
	);
	cdc_2phase_D553F i_cdc_resp(
		.src_rst_ni(rst_ni),
		.src_clk_i(clk_i),
		.src_data_i(core_dmi_resp_i),
		.src_valid_i(core_dmi_valid_i),
		.src_ready_o(core_dmi_ready_o),
		.dst_rst_ni(trst_ni),
		.dst_clk_i(tck_i),
		.dst_data_o(jtag_dmi_resp_o),
		.dst_valid_o(jtag_dmi_valid_o),
		.dst_ready_i(jtag_dmi_ready_i)
	);
endmodule
module dmi_jtag (
	clk_i,
	rst_ni,
	testmode_i,
	jtag_key,
	dmi_rst_no,
	dmi_req_o,
	dmi_req_valid_o,
	dmi_req_ready_i,
	dmi_resp_i,
	dmi_resp_ready_o,
	dmi_resp_valid_i,
	tck_i,
	tms_i,
	trst_ni,
	td_i,
	td_o,
	tdo_oe_o,
	umode_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire testmode_i;
	input wire [31:0] jtag_key;
	output wire dmi_rst_no;
	output wire [40:0] dmi_req_o;
	output wire dmi_req_valid_o;
	input wire dmi_req_ready_i;
	input wire [33:0] dmi_resp_i;
	output wire dmi_resp_ready_o;
	input wire dmi_resp_valid_i;
	input wire tck_i;
	input wire tms_i;
	input wire trst_ni;
	input wire td_i;
	output wire td_o;
	output wire tdo_oe_o;
	output reg umode_o;
	assign dmi_rst_no = rst_ni;
	wire test_logic_reset;
	wire shift_dr;
	wire update_dr;
	wire capture_dr;
	wire dmi_access;
	wire dtmcs_select;
	wire dmi_reset;
	wire dmi_tdi;
	wire dmi_tdo;
	wire [40:0] dmi_req;
	wire dmi_req_ready;
	reg dmi_req_valid;
	wire [33:0] dmi_resp;
	wire dmi_resp_valid;
	wire dmi_resp_ready;
	reg [2:0] state_d;
	reg [2:0] state_q;
	reg [40:0] dr_d;
	reg [40:0] dr_q;
	reg [6:0] address_d;
	reg [6:0] address_q;
	reg [31:0] data_d;
	reg [31:0] data_q;
	reg [31:0] pass;
	reg pass_chk;
	wire [40:0] dmi;
	assign dmi = dr_q;
	assign dmi_req[40-:7] = address_q;
	assign dmi_req[31-:32] = data_q;
	assign dmi_req[33-:2] = (state_q == 3'd3 ? 2'h2 : 2'h1);
	assign dmi_resp_ready = 1'b1;
	reg error_dmi_busy;
	reg [1:0] error_d;
	reg [1:0] error_q;
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		error_dmi_busy = 1'b0;
		state_d = state_q;
		address_d = address_q;
		data_d = data_q;
		error_d = error_q;
		dmi_req_valid = 1'b0;
		case (state_q)
			3'd0:
				if ((dmi_access && update_dr) && (error_q == 2'h0)) begin
					address_d = dmi[40-:7];
					data_d = dmi[33-:32];
					if ((sv2v_cast_2(dmi[1-:2]) == 2'h1) && (pass_chk == 1'b1))
						state_d = 3'd1;
					else if (sv2v_cast_2(dmi[1-:2]) == 2'h2)
						state_d = 3'd3;
					else if (sv2v_cast_2(dmi[1-:2]) == 2'h3) begin
						state_d = 3'd1;
						if (data_d == pass)
							pass_chk = 1'b1;
						state_d = 3'd0;
					end
				end
			3'd1: begin
				dmi_req_valid = 1'b1;
				if (dmi_req_ready)
					state_d = 3'd2;
			end
			3'd2:
				if (dmi_resp_valid) begin
					data_d = dmi_resp[33-:32];
					state_d = 3'd0;
				end
			3'd3: begin
				dmi_req_valid = 1'b1;
				if (dmi_req_ready)
					state_d = 3'd0;
			end
			3'd4:
				if (dmi_resp_valid)
					state_d = 3'd0;
		endcase
		if (update_dr && (state_q != 3'd0))
			error_dmi_busy = 1'b1;
		if (capture_dr && |{state_q == 3'd1, state_q == 3'd2})
			error_dmi_busy = 1'b1;
		if (error_dmi_busy)
			error_d = 2'h3;
		if (dmi_reset && dtmcs_select)
			error_d = 2'h0;
		if (pass_chk == 1'b1)
			umode_o = 1'b1;
		else
			umode_o = 1'b0;
	end
	assign dmi_tdo = dr_q[0];
	always @(*) begin
		if (_sv2v_0)
			;
		dr_d = dr_q;
		if (capture_dr) begin
			if (dmi_access) begin
				if ((error_q == 2'h0) && !error_dmi_busy)
					dr_d = {address_q, data_q, 2'h0};
				else if ((error_q == 2'h3) || error_dmi_busy)
					dr_d = {address_q, data_q, 2'h3};
			end
		end
		if (shift_dr) begin
			if (dmi_access)
				dr_d = {dmi_tdi, dr_q[40:1]};
		end
		if (test_logic_reset)
			dr_d = 1'sb0;
	end
	always @(posedge tck_i or negedge trst_ni)
		if (~trst_ni) begin
			dr_q <= 1'sb0;
			state_q <= 3'd0;
			address_q <= 1'sb0;
			data_q <= 1'sb0;
			error_q <= 2'h0;
		end
		else begin
			dr_q <= dr_d;
			state_q <= state_d;
			address_q <= address_d;
			data_q <= data_d;
			error_q <= error_d;
		end
	always @(posedge clk_i)
		if (~rst_ni)
			pass <= jtag_key;
	dmi_jtag_tap #(.IrLength(5)) i_dmi_jtag_tap(
		.tck_i(tck_i),
		.tms_i(tms_i),
		.trst_ni(trst_ni),
		.td_i(td_i),
		.td_o(td_o),
		.tdo_oe_o(tdo_oe_o),
		.testmode_i(testmode_i),
		.test_logic_reset_o(test_logic_reset),
		.shift_dr_o(shift_dr),
		.update_dr_o(update_dr),
		.capture_dr_o(capture_dr),
		.dmi_access_o(dmi_access),
		.dtmcs_select_o(dtmcs_select),
		.dmi_reset_o(dmi_reset),
		.dmi_error_i(error_q),
		.dmi_tdi_o(dmi_tdi),
		.dmi_tdo_i(dmi_tdo)
	);
	dmi_cdc i_dmi_cdc(
		.tck_i(tck_i),
		.trst_ni(trst_ni),
		.jtag_dmi_req_i(dmi_req),
		.jtag_dmi_ready_o(dmi_req_ready),
		.jtag_dmi_valid_i(dmi_req_valid),
		.jtag_dmi_resp_o(dmi_resp),
		.jtag_dmi_valid_o(dmi_resp_valid),
		.jtag_dmi_ready_i(dmi_resp_ready),
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.core_dmi_req_o(dmi_req_o),
		.core_dmi_valid_o(dmi_req_valid_o),
		.core_dmi_ready_i(dmi_req_ready_i),
		.core_dmi_resp_i(dmi_resp_i),
		.core_dmi_ready_o(dmi_resp_ready_o),
		.core_dmi_valid_i(dmi_resp_valid_i)
	);
	initial _sv2v_0 = 0;
endmodule
module dmi_jtag_tap (
	tck_i,
	tms_i,
	trst_ni,
	td_i,
	td_o,
	tdo_oe_o,
	testmode_i,
	test_logic_reset_o,
	shift_dr_o,
	update_dr_o,
	capture_dr_o,
	dmi_access_o,
	dtmcs_select_o,
	dmi_reset_o,
	dmi_error_i,
	dmi_tdi_o,
	dmi_tdo_i
);
	reg _sv2v_0;
	parameter signed [31:0] IrLength = 5;
	input wire tck_i;
	input wire tms_i;
	input wire trst_ni;
	input wire td_i;
	output reg td_o;
	output reg tdo_oe_o;
	input wire testmode_i;
	output reg test_logic_reset_o;
	output reg shift_dr_o;
	output reg update_dr_o;
	output reg capture_dr_o;
	output reg dmi_access_o;
	output reg dtmcs_select_o;
	output wire dmi_reset_o;
	input wire [1:0] dmi_error_i;
	output wire dmi_tdi_o;
	input wire dmi_tdo_i;
	assign dmi_tdi_o = td_i;
	reg [3:0] tap_state_q;
	reg [3:0] tap_state_d;
	reg [IrLength - 1:0] jtag_ir_shift_d;
	reg [IrLength - 1:0] jtag_ir_shift_q;
	reg [IrLength - 1:0] jtag_ir_d;
	reg [IrLength - 1:0] jtag_ir_q;
	reg capture_ir;
	reg shift_ir;
	reg pause_ir;
	reg update_ir;
	function automatic [IrLength - 1:0] sv2v_cast_AD79E;
		input reg [IrLength - 1:0] inp;
		sv2v_cast_AD79E = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		jtag_ir_shift_d = jtag_ir_shift_q;
		jtag_ir_d = jtag_ir_q;
		if (shift_ir)
			jtag_ir_shift_d = {td_i, jtag_ir_shift_q[IrLength - 1:1]};
		if (capture_ir)
			jtag_ir_shift_d = 'b101;
		if (update_ir)
			jtag_ir_d = sv2v_cast_AD79E(jtag_ir_shift_q);
		if (test_logic_reset_o) begin
			jtag_ir_shift_d = 1'sb0;
			jtag_ir_d = sv2v_cast_AD79E('h1);
		end
	end
	always @(posedge tck_i or negedge trst_ni)
		if (~trst_ni) begin
			jtag_ir_shift_q <= 1'sb0;
			jtag_ir_q <= sv2v_cast_AD79E('h1);
		end
		else begin
			jtag_ir_shift_q <= jtag_ir_shift_d;
			jtag_ir_q <= jtag_ir_d;
		end
	localparam IDCODE_VALUE = 32'h249511c3;
	reg [31:0] idcode_d;
	reg [31:0] idcode_q;
	reg idcode_select;
	reg bypass_select;
	reg [31:0] dtmcs_d;
	reg [31:0] dtmcs_q;
	reg bypass_d;
	reg bypass_q;
	assign dmi_reset_o = dtmcs_q[16];
	always @(*) begin
		if (_sv2v_0)
			;
		idcode_d = idcode_q;
		bypass_d = bypass_q;
		dtmcs_d = dtmcs_q;
		if (capture_dr_o) begin
			if (idcode_select)
				idcode_d = IDCODE_VALUE;
			if (bypass_select)
				bypass_d = 1'b0;
			if (dtmcs_select_o)
				dtmcs_d = {20'h00001, dmi_error_i, 10'h071};
		end
		if (shift_dr_o) begin
			if (idcode_select)
				idcode_d = {td_i, idcode_q[31:1]};
			if (bypass_select)
				bypass_d = td_i;
			if (dtmcs_select_o)
				dtmcs_d = {td_i, dtmcs_q[31:1]};
		end
		if (test_logic_reset_o) begin
			idcode_d = IDCODE_VALUE;
			bypass_d = 1'b0;
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		dmi_access_o = 1'b0;
		dtmcs_select_o = 1'b0;
		idcode_select = 1'b0;
		bypass_select = 1'b0;
		case (jtag_ir_q)
			sv2v_cast_AD79E('h0): bypass_select = 1'b1;
			sv2v_cast_AD79E('h1): idcode_select = 1'b1;
			sv2v_cast_AD79E('h10): dtmcs_select_o = 1'b1;
			sv2v_cast_AD79E('h11): dmi_access_o = 1'b1;
			sv2v_cast_AD79E('h1f): bypass_select = 1'b1;
			default: bypass_select = 1'b1;
		endcase
	end
	reg tdo_mux;
	always @(*) begin
		if (_sv2v_0)
			;
		if (shift_ir)
			tdo_mux = jtag_ir_shift_q[0];
		else
			case (jtag_ir_q)
				sv2v_cast_AD79E('h1): tdo_mux = idcode_q[0];
				sv2v_cast_AD79E('h10): tdo_mux = dtmcs_q[0];
				sv2v_cast_AD79E('h11): tdo_mux = dmi_tdo_i;
				default: tdo_mux = bypass_q;
			endcase
	end
	wire tck_n;
	wire tck_ni;
	cluster_clock_inverter i_tck_inv(
		.clk_i(tck_i),
		.clk_o(tck_ni)
	);
	pulp_clock_mux2 i_dft_tck_mux(
		.clk0_i(tck_ni),
		.clk1_i(tck_i),
		.clk_sel_i(testmode_i),
		.clk_o(tck_n)
	);
	always @(posedge tck_n or negedge trst_ni)
		if (~trst_ni) begin
			td_o <= 1'b0;
			tdo_oe_o <= 1'b0;
		end
		else begin
			td_o <= tdo_mux;
			tdo_oe_o <= shift_ir | shift_dr_o;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		test_logic_reset_o = 1'b0;
		capture_dr_o = 1'b0;
		shift_dr_o = 1'b0;
		update_dr_o = 1'b0;
		capture_ir = 1'b0;
		shift_ir = 1'b0;
		pause_ir = 1'b0;
		update_ir = 1'b0;
		case (tap_state_q)
			4'd0: tap_state_d = (tms_i ? 4'd0 : 4'd1);
			4'd1: tap_state_d = (tms_i ? 4'd2 : 4'd1);
			4'd2: tap_state_d = (tms_i ? 4'd9 : 4'd3);
			4'd3: begin
				capture_dr_o = 1'b1;
				tap_state_d = (tms_i ? 4'd5 : 4'd4);
			end
			4'd4: begin
				shift_dr_o = 1'b1;
				tap_state_d = (tms_i ? 4'd5 : 4'd4);
			end
			4'd5: tap_state_d = (tms_i ? 4'd8 : 4'd6);
			4'd6: tap_state_d = (tms_i ? 4'd7 : 4'd6);
			4'd7: tap_state_d = (tms_i ? 4'd8 : 4'd4);
			4'd8: begin
				update_dr_o = 1'b1;
				tap_state_d = (tms_i ? 4'd2 : 4'd1);
			end
			4'd9: tap_state_d = (tms_i ? 4'd0 : 4'd10);
			4'd10: begin
				capture_ir = 1'b1;
				tap_state_d = (tms_i ? 4'd12 : 4'd11);
			end
			4'd11: begin
				shift_ir = 1'b1;
				tap_state_d = (tms_i ? 4'd12 : 4'd11);
			end
			4'd12: tap_state_d = (tms_i ? 4'd15 : 4'd13);
			4'd13: begin
				pause_ir = 1'b1;
				tap_state_d = (tms_i ? 4'd14 : 4'd13);
			end
			4'd14: tap_state_d = (tms_i ? 4'd15 : 4'd11);
			4'd15: begin
				update_ir = 1'b1;
				tap_state_d = (tms_i ? 4'd2 : 4'd1);
			end
			default: tap_state_d = 4'd0;
		endcase
	end
	always @(posedge tck_i or negedge trst_ni)
		if (~trst_ni) begin
			tap_state_q <= 4'd1;
			idcode_q <= IDCODE_VALUE;
			bypass_q <= 1'b0;
			dtmcs_q <= 1'sb0;
		end
		else begin
			tap_state_q <= tap_state_d;
			idcode_q <= idcode_d;
			bypass_q <= bypass_d;
			dtmcs_q <= dtmcs_d;
		end
	initial _sv2v_0 = 0;
endmodule
module connectivity_mapping (
	priv_lvl_i,
	access_ctrl_i,
	connectivity_map_o
);
	parameter NB_MANAGER = 4;
	parameter NB_SUBORDINATE = 4;
	parameter NB_PRIV_LVL = 4;
	parameter PRIV_LVL_WIDTH = 4;
	input wire [PRIV_LVL_WIDTH - 1:0] priv_lvl_i;
	input wire [((NB_SUBORDINATE * NB_MANAGER) * NB_PRIV_LVL) - 1:0] access_ctrl_i;
	output wire [(NB_SUBORDINATE * NB_MANAGER) - 1:0] connectivity_map_o;
	genvar _gv_i_11;
	genvar _gv_j_5;
	generate
		for (_gv_i_11 = 0; _gv_i_11 < NB_SUBORDINATE; _gv_i_11 = _gv_i_11 + 1) begin : genblk1
			localparam i = _gv_i_11;
			for (_gv_j_5 = 0; _gv_j_5 < NB_MANAGER; _gv_j_5 = _gv_j_5 + 1) begin : genblk1
				localparam j = _gv_j_5;
				assign connectivity_map_o[(i * NB_MANAGER) + j] = access_ctrl_i[(((i * NB_MANAGER) + j) * NB_PRIV_LVL) + priv_lvl_i] || ((j == 6) && access_ctrl_i[(((i * NB_MANAGER) + 7) * NB_PRIV_LVL) + priv_lvl_i]);
			end
		end
	endgenerate
endmodule
module axi_node (
	clk,
	rst_n,
	test_en_i,
	slave_awid_i,
	slave_awaddr_i,
	slave_awlen_i,
	slave_awsize_i,
	slave_awburst_i,
	slave_awlock_i,
	slave_awcache_i,
	slave_awprot_i,
	slave_awregion_i,
	slave_awuser_i,
	slave_awqos_i,
	slave_awvalid_i,
	slave_awready_o,
	slave_wdata_i,
	slave_wstrb_i,
	slave_wlast_i,
	slave_wuser_i,
	slave_wvalid_i,
	slave_wready_o,
	slave_bid_o,
	slave_bresp_o,
	slave_bvalid_o,
	slave_buser_o,
	slave_bready_i,
	slave_arid_i,
	slave_araddr_i,
	slave_arlen_i,
	slave_arsize_i,
	slave_arburst_i,
	slave_arlock_i,
	slave_arcache_i,
	slave_arprot_i,
	slave_arregion_i,
	slave_aruser_i,
	slave_arqos_i,
	slave_arvalid_i,
	slave_arready_o,
	slave_rid_o,
	slave_rdata_o,
	slave_rresp_o,
	slave_rlast_o,
	slave_ruser_o,
	slave_rvalid_o,
	slave_rready_i,
	master_awid_o,
	master_awaddr_o,
	master_awlen_o,
	master_awsize_o,
	master_awburst_o,
	master_awlock_o,
	master_awcache_o,
	master_awprot_o,
	master_awregion_o,
	master_awuser_o,
	master_awqos_o,
	master_awvalid_o,
	master_awready_i,
	master_wdata_o,
	master_wstrb_o,
	master_wlast_o,
	master_wuser_o,
	master_wvalid_o,
	master_wready_i,
	master_bid_i,
	master_bresp_i,
	master_buser_i,
	master_bvalid_i,
	master_bready_o,
	master_arid_o,
	master_araddr_o,
	master_arlen_o,
	master_arsize_o,
	master_arburst_o,
	master_arlock_o,
	master_arcache_o,
	master_arprot_o,
	master_arregion_o,
	master_aruser_o,
	master_arqos_o,
	master_arvalid_o,
	master_arready_i,
	master_rid_i,
	master_rdata_i,
	master_rresp_i,
	master_rlast_i,
	master_ruser_i,
	master_rvalid_i,
	master_rready_o,
	cfg_START_ADDR_i,
	cfg_END_ADDR_i,
	cfg_valid_rule_i,
	cfg_connectivity_map_i
);
	parameter AXI_ADDRESS_W = 32;
	parameter AXI_DATA_W = 64;
	parameter AXI_NUMBYTES = AXI_DATA_W / 8;
	parameter AXI_USER_W = 6;
	parameter N_MASTER_PORT = 8;
	parameter N_SLAVE_PORT = 4;
	parameter AXI_ID_IN = 16;
	parameter AXI_ID_OUT = AXI_ID_IN + $clog2(N_SLAVE_PORT);
	parameter FIFO_DEPTH_DW = 8;
	parameter N_REGION = 2;
	input wire clk;
	input wire rst_n;
	input wire test_en_i;
	input wire [(N_SLAVE_PORT * AXI_ID_IN) - 1:0] slave_awid_i;
	input wire [(N_SLAVE_PORT * AXI_ADDRESS_W) - 1:0] slave_awaddr_i;
	input wire [(N_SLAVE_PORT * 8) - 1:0] slave_awlen_i;
	input wire [(N_SLAVE_PORT * 3) - 1:0] slave_awsize_i;
	input wire [(N_SLAVE_PORT * 2) - 1:0] slave_awburst_i;
	input wire [N_SLAVE_PORT - 1:0] slave_awlock_i;
	input wire [(N_SLAVE_PORT * 4) - 1:0] slave_awcache_i;
	input wire [(N_SLAVE_PORT * 3) - 1:0] slave_awprot_i;
	input wire [(N_SLAVE_PORT * 4) - 1:0] slave_awregion_i;
	input wire [(N_SLAVE_PORT * AXI_USER_W) - 1:0] slave_awuser_i;
	input wire [(N_SLAVE_PORT * 4) - 1:0] slave_awqos_i;
	input wire [N_SLAVE_PORT - 1:0] slave_awvalid_i;
	output wire [N_SLAVE_PORT - 1:0] slave_awready_o;
	input wire [(N_SLAVE_PORT * AXI_DATA_W) - 1:0] slave_wdata_i;
	input wire [(N_SLAVE_PORT * AXI_NUMBYTES) - 1:0] slave_wstrb_i;
	input wire [N_SLAVE_PORT - 1:0] slave_wlast_i;
	input wire [(N_SLAVE_PORT * AXI_USER_W) - 1:0] slave_wuser_i;
	input wire [N_SLAVE_PORT - 1:0] slave_wvalid_i;
	output wire [N_SLAVE_PORT - 1:0] slave_wready_o;
	output wire [(N_SLAVE_PORT * AXI_ID_IN) - 1:0] slave_bid_o;
	output wire [(N_SLAVE_PORT * 2) - 1:0] slave_bresp_o;
	output wire [N_SLAVE_PORT - 1:0] slave_bvalid_o;
	output wire [(N_SLAVE_PORT * AXI_USER_W) - 1:0] slave_buser_o;
	input wire [N_SLAVE_PORT - 1:0] slave_bready_i;
	input wire [(N_SLAVE_PORT * AXI_ID_IN) - 1:0] slave_arid_i;
	input wire [(N_SLAVE_PORT * AXI_ADDRESS_W) - 1:0] slave_araddr_i;
	input wire [(N_SLAVE_PORT * 8) - 1:0] slave_arlen_i;
	input wire [(N_SLAVE_PORT * 3) - 1:0] slave_arsize_i;
	input wire [(N_SLAVE_PORT * 2) - 1:0] slave_arburst_i;
	input wire [N_SLAVE_PORT - 1:0] slave_arlock_i;
	input wire [(N_SLAVE_PORT * 4) - 1:0] slave_arcache_i;
	input wire [(N_SLAVE_PORT * 3) - 1:0] slave_arprot_i;
	input wire [(N_SLAVE_PORT * 4) - 1:0] slave_arregion_i;
	input wire [(N_SLAVE_PORT * AXI_USER_W) - 1:0] slave_aruser_i;
	input wire [(N_SLAVE_PORT * 4) - 1:0] slave_arqos_i;
	input wire [N_SLAVE_PORT - 1:0] slave_arvalid_i;
	output wire [N_SLAVE_PORT - 1:0] slave_arready_o;
	output wire [(N_SLAVE_PORT * AXI_ID_IN) - 1:0] slave_rid_o;
	output wire [(N_SLAVE_PORT * AXI_DATA_W) - 1:0] slave_rdata_o;
	output wire [(N_SLAVE_PORT * 2) - 1:0] slave_rresp_o;
	output wire [N_SLAVE_PORT - 1:0] slave_rlast_o;
	output wire [(N_SLAVE_PORT * AXI_USER_W) - 1:0] slave_ruser_o;
	output wire [N_SLAVE_PORT - 1:0] slave_rvalid_o;
	input wire [N_SLAVE_PORT - 1:0] slave_rready_i;
	output wire [(N_MASTER_PORT * AXI_ID_OUT) - 1:0] master_awid_o;
	output wire [(N_MASTER_PORT * AXI_ADDRESS_W) - 1:0] master_awaddr_o;
	output wire [(N_MASTER_PORT * 8) - 1:0] master_awlen_o;
	output wire [(N_MASTER_PORT * 3) - 1:0] master_awsize_o;
	output wire [(N_MASTER_PORT * 2) - 1:0] master_awburst_o;
	output wire [N_MASTER_PORT - 1:0] master_awlock_o;
	output wire [(N_MASTER_PORT * 4) - 1:0] master_awcache_o;
	output wire [(N_MASTER_PORT * 3) - 1:0] master_awprot_o;
	output wire [(N_MASTER_PORT * 4) - 1:0] master_awregion_o;
	output wire [(N_MASTER_PORT * AXI_USER_W) - 1:0] master_awuser_o;
	output wire [(N_MASTER_PORT * 4) - 1:0] master_awqos_o;
	output wire [N_MASTER_PORT - 1:0] master_awvalid_o;
	input wire [N_MASTER_PORT - 1:0] master_awready_i;
	output wire [(N_MASTER_PORT * AXI_DATA_W) - 1:0] master_wdata_o;
	output wire [(N_MASTER_PORT * AXI_NUMBYTES) - 1:0] master_wstrb_o;
	output wire [N_MASTER_PORT - 1:0] master_wlast_o;
	output wire [(N_MASTER_PORT * AXI_USER_W) - 1:0] master_wuser_o;
	output wire [N_MASTER_PORT - 1:0] master_wvalid_o;
	input wire [N_MASTER_PORT - 1:0] master_wready_i;
	input wire [(N_MASTER_PORT * AXI_ID_OUT) - 1:0] master_bid_i;
	input wire [(N_MASTER_PORT * 2) - 1:0] master_bresp_i;
	input wire [(N_MASTER_PORT * AXI_USER_W) - 1:0] master_buser_i;
	input wire [N_MASTER_PORT - 1:0] master_bvalid_i;
	output wire [N_MASTER_PORT - 1:0] master_bready_o;
	output wire [(N_MASTER_PORT * AXI_ID_OUT) - 1:0] master_arid_o;
	output wire [(N_MASTER_PORT * AXI_ADDRESS_W) - 1:0] master_araddr_o;
	output wire [(N_MASTER_PORT * 8) - 1:0] master_arlen_o;
	output wire [(N_MASTER_PORT * 3) - 1:0] master_arsize_o;
	output wire [(N_MASTER_PORT * 2) - 1:0] master_arburst_o;
	output wire [N_MASTER_PORT - 1:0] master_arlock_o;
	output wire [(N_MASTER_PORT * 4) - 1:0] master_arcache_o;
	output wire [(N_MASTER_PORT * 3) - 1:0] master_arprot_o;
	output wire [(N_MASTER_PORT * 4) - 1:0] master_arregion_o;
	output wire [(N_MASTER_PORT * AXI_USER_W) - 1:0] master_aruser_o;
	output wire [(N_MASTER_PORT * 4) - 1:0] master_arqos_o;
	output wire [N_MASTER_PORT - 1:0] master_arvalid_o;
	input wire [N_MASTER_PORT - 1:0] master_arready_i;
	input wire [(N_MASTER_PORT * AXI_ID_OUT) - 1:0] master_rid_i;
	input wire [(N_MASTER_PORT * AXI_DATA_W) - 1:0] master_rdata_i;
	input wire [(N_MASTER_PORT * 2) - 1:0] master_rresp_i;
	input wire [N_MASTER_PORT - 1:0] master_rlast_i;
	input wire [(N_MASTER_PORT * AXI_USER_W) - 1:0] master_ruser_i;
	input wire [N_MASTER_PORT - 1:0] master_rvalid_i;
	output wire [N_MASTER_PORT - 1:0] master_rready_o;
	input wire [((N_REGION * N_MASTER_PORT) * AXI_ADDRESS_W) - 1:0] cfg_START_ADDR_i;
	input wire [((N_REGION * N_MASTER_PORT) * AXI_ADDRESS_W) - 1:0] cfg_END_ADDR_i;
	input wire [(N_REGION * N_MASTER_PORT) - 1:0] cfg_valid_rule_i;
	input wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] cfg_connectivity_map_i;
	genvar _gv_i_12;
	genvar _gv_j_6;
	genvar _gv_k_5;
	wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] arvalid_int;
	wire [(N_MASTER_PORT * N_SLAVE_PORT) - 1:0] arready_int;
	wire [(N_MASTER_PORT * N_SLAVE_PORT) - 1:0] arvalid_int_reverse;
	wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] arready_int_reverse;
	wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] awvalid_int;
	wire [(N_MASTER_PORT * N_SLAVE_PORT) - 1:0] awready_int;
	wire [(N_MASTER_PORT * N_SLAVE_PORT) - 1:0] awvalid_int_reverse;
	wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] awready_int_reverse;
	wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] wvalid_int;
	wire [(N_MASTER_PORT * N_SLAVE_PORT) - 1:0] wready_int;
	wire [(N_MASTER_PORT * N_SLAVE_PORT) - 1:0] wvalid_int_reverse;
	wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] wready_int_reverse;
	wire [(N_MASTER_PORT * N_SLAVE_PORT) - 1:0] bvalid_int;
	wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] bready_int;
	wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] bvalid_int_reverse;
	wire [(N_MASTER_PORT * N_SLAVE_PORT) - 1:0] bready_int_reverse;
	wire [(N_MASTER_PORT * N_SLAVE_PORT) - 1:0] rvalid_int;
	wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] rready_int;
	wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] rvalid_int_reverse;
	wire [(N_MASTER_PORT * N_SLAVE_PORT) - 1:0] rready_int_reverse;
	wire [((N_REGION * N_MASTER_PORT) * AXI_ADDRESS_W) - 1:0] START_ADDR;
	wire [((N_REGION * N_MASTER_PORT) * AXI_ADDRESS_W) - 1:0] END_ADDR;
	wire [(N_REGION * N_MASTER_PORT) - 1:0] valid_rule;
	wire [(N_SLAVE_PORT * N_MASTER_PORT) - 1:0] connectivity_map;
	generate
		for (_gv_i_12 = 0; _gv_i_12 < N_MASTER_PORT; _gv_i_12 = _gv_i_12 + 1) begin : _REVERSING_VALID_READY_MASTER
			localparam i = _gv_i_12;
			for (_gv_j_6 = 0; _gv_j_6 < N_SLAVE_PORT; _gv_j_6 = _gv_j_6 + 1) begin : _REVERSING_VALID_READY_SLAVE
				localparam j = _gv_j_6;
				assign arvalid_int_reverse[(i * N_SLAVE_PORT) + j] = arvalid_int[(j * N_MASTER_PORT) + i];
				assign awvalid_int_reverse[(i * N_SLAVE_PORT) + j] = awvalid_int[(j * N_MASTER_PORT) + i];
				assign wvalid_int_reverse[(i * N_SLAVE_PORT) + j] = wvalid_int[(j * N_MASTER_PORT) + i];
				assign bvalid_int_reverse[(j * N_MASTER_PORT) + i] = bvalid_int[(i * N_SLAVE_PORT) + j];
				assign rvalid_int_reverse[(j * N_MASTER_PORT) + i] = rvalid_int[(i * N_SLAVE_PORT) + j];
				assign arready_int_reverse[(j * N_MASTER_PORT) + i] = arready_int[(i * N_SLAVE_PORT) + j];
				assign awready_int_reverse[(j * N_MASTER_PORT) + i] = awready_int[(i * N_SLAVE_PORT) + j];
				assign wready_int_reverse[(j * N_MASTER_PORT) + i] = wready_int[(i * N_SLAVE_PORT) + j];
				assign bready_int_reverse[(i * N_SLAVE_PORT) + j] = bready_int[(j * N_MASTER_PORT) + i];
				assign rready_int_reverse[(i * N_SLAVE_PORT) + j] = rready_int[(j * N_MASTER_PORT) + i];
			end
		end
		for (_gv_i_12 = 0; _gv_i_12 < N_MASTER_PORT; _gv_i_12 = _gv_i_12 + 1) begin : _REQ_BLOCK_GEN
			localparam i = _gv_i_12;
			axi_request_block #(
				.AXI_ADDRESS_W(AXI_ADDRESS_W),
				.AXI_DATA_W(AXI_DATA_W),
				.AXI_USER_W(AXI_USER_W),
				.N_INIT_PORT(N_MASTER_PORT),
				.N_TARG_PORT(N_SLAVE_PORT),
				.FIFO_DW_DEPTH(FIFO_DEPTH_DW),
				.AXI_ID_IN(AXI_ID_IN)
			) REQ_BLOCK(
				.clk(clk),
				.rst_n(rst_n),
				.test_en_i(test_en_i),
				.awid_i(slave_awid_i),
				.awaddr_i(slave_awaddr_i),
				.awlen_i(slave_awlen_i),
				.awsize_i(slave_awsize_i),
				.awburst_i(slave_awburst_i),
				.awlock_i(slave_awlock_i),
				.awcache_i(slave_awcache_i),
				.awprot_i(slave_awprot_i),
				.awregion_i(slave_awregion_i),
				.awuser_i(slave_awuser_i),
				.awqos_i(slave_awqos_i),
				.awvalid_i(awvalid_int_reverse[i * N_SLAVE_PORT+:N_SLAVE_PORT]),
				.awready_o(awready_int[i * N_SLAVE_PORT+:N_SLAVE_PORT]),
				.wdata_i(slave_wdata_i),
				.wstrb_i(slave_wstrb_i),
				.wlast_i(slave_wlast_i),
				.wuser_i(slave_wuser_i),
				.wvalid_i(wvalid_int_reverse[i * N_SLAVE_PORT+:N_SLAVE_PORT]),
				.wready_o(wready_int[i * N_SLAVE_PORT+:N_SLAVE_PORT]),
				.arid_i(slave_arid_i),
				.araddr_i(slave_araddr_i),
				.arlen_i(slave_arlen_i),
				.arsize_i(slave_arsize_i),
				.arburst_i(slave_arburst_i),
				.arlock_i(slave_arlock_i),
				.arcache_i(slave_arcache_i),
				.arprot_i(slave_arprot_i),
				.arregion_i(slave_arregion_i),
				.aruser_i(slave_aruser_i),
				.arqos_i(slave_arqos_i),
				.arvalid_i(arvalid_int_reverse[i * N_SLAVE_PORT+:N_SLAVE_PORT]),
				.arready_o(arready_int[i * N_SLAVE_PORT+:N_SLAVE_PORT]),
				.bid_i(master_bid_i[i * AXI_ID_OUT+:AXI_ID_OUT]),
				.bvalid_i(master_bvalid_i[i]),
				.bready_o(master_bready_o[i]),
				.bvalid_o(bvalid_int[i * N_SLAVE_PORT+:N_SLAVE_PORT]),
				.bready_i(bready_int_reverse[i * N_SLAVE_PORT+:N_SLAVE_PORT]),
				.rid_i(master_rid_i[i * AXI_ID_OUT+:AXI_ID_OUT]),
				.rvalid_i(master_rvalid_i[i]),
				.rready_o(master_rready_o[i]),
				.rvalid_o(rvalid_int[i * N_SLAVE_PORT+:N_SLAVE_PORT]),
				.rready_i(rready_int_reverse[i * N_SLAVE_PORT+:N_SLAVE_PORT]),
				.awid_o(master_awid_o[i * AXI_ID_OUT+:AXI_ID_OUT]),
				.awaddr_o(master_awaddr_o[i * AXI_ADDRESS_W+:AXI_ADDRESS_W]),
				.awlen_o(master_awlen_o[i * 8+:8]),
				.awsize_o(master_awsize_o[i * 3+:3]),
				.awburst_o(master_awburst_o[i * 2+:2]),
				.awlock_o(master_awlock_o[i]),
				.awcache_o(master_awcache_o[i * 4+:4]),
				.awprot_o(master_awprot_o[i * 3+:3]),
				.awregion_o(master_awregion_o[i * 4+:4]),
				.awuser_o(master_awuser_o[i * AXI_USER_W+:AXI_USER_W]),
				.awqos_o(master_awqos_o[i * 4+:4]),
				.awvalid_o(master_awvalid_o[i]),
				.awready_i(master_awready_i[i]),
				.wdata_o(master_wdata_o[i * AXI_DATA_W+:AXI_DATA_W]),
				.wstrb_o(master_wstrb_o[i * AXI_NUMBYTES+:AXI_NUMBYTES]),
				.wlast_o(master_wlast_o[i]),
				.wuser_o(master_wuser_o[i * AXI_USER_W+:AXI_USER_W]),
				.wvalid_o(master_wvalid_o[i]),
				.wready_i(master_wready_i[i]),
				.arid_o(master_arid_o[i * AXI_ID_OUT+:AXI_ID_OUT]),
				.araddr_o(master_araddr_o[i * AXI_ADDRESS_W+:AXI_ADDRESS_W]),
				.arlen_o(master_arlen_o[i * 8+:8]),
				.arsize_o(master_arsize_o[i * 3+:3]),
				.arburst_o(master_arburst_o[i * 2+:2]),
				.arlock_o(master_arlock_o[i]),
				.arcache_o(master_arcache_o[i * 4+:4]),
				.arprot_o(master_arprot_o[i * 3+:3]),
				.arregion_o(master_arregion_o[i * 4+:4]),
				.aruser_o(master_aruser_o[i * AXI_USER_W+:AXI_USER_W]),
				.arqos_o(master_arqos_o[i * 4+:4]),
				.arvalid_o(master_arvalid_o[i]),
				.arready_i(master_arready_i[i])
			);
		end
		for (_gv_i_12 = 0; _gv_i_12 < N_SLAVE_PORT; _gv_i_12 = _gv_i_12 + 1) begin : _RESP_BLOCK_GEN
			localparam i = _gv_i_12;
			axi_response_block #(
				.AXI_ADDRESS_W(AXI_ADDRESS_W),
				.AXI_DATA_W(AXI_DATA_W),
				.AXI_USER_W(AXI_USER_W),
				.N_INIT_PORT(N_MASTER_PORT),
				.N_TARG_PORT(N_SLAVE_PORT),
				.FIFO_DEPTH_DW(FIFO_DEPTH_DW),
				.AXI_ID_IN(AXI_ID_IN),
				.N_REGION(N_REGION)
			) RESP_BLOCK(
				.clk(clk),
				.rst_n(rst_n),
				.test_en_i(test_en_i),
				.rid_i(master_rid_i),
				.rdata_i(master_rdata_i),
				.rresp_i(master_rresp_i),
				.rlast_i(master_rlast_i),
				.ruser_i(master_ruser_i),
				.rvalid_i(rvalid_int_reverse[i * N_MASTER_PORT+:N_MASTER_PORT]),
				.rready_o(rready_int[i * N_MASTER_PORT+:N_MASTER_PORT]),
				.bid_i(master_bid_i),
				.bresp_i(master_bresp_i),
				.buser_i(master_buser_i),
				.bvalid_i(bvalid_int_reverse[i * N_MASTER_PORT+:N_MASTER_PORT]),
				.bready_o(bready_int[i * N_MASTER_PORT+:N_MASTER_PORT]),
				.rid_o(slave_rid_o[i * AXI_ID_IN+:AXI_ID_IN]),
				.rdata_o(slave_rdata_o[i * AXI_DATA_W+:AXI_DATA_W]),
				.rresp_o(slave_rresp_o[i * 2+:2]),
				.rlast_o(slave_rlast_o[i]),
				.ruser_o(slave_ruser_o[i * AXI_USER_W+:AXI_USER_W]),
				.rvalid_o(slave_rvalid_o[i]),
				.rready_i(slave_rready_i[i]),
				.bid_o(slave_bid_o[i * AXI_ID_IN+:AXI_ID_IN]),
				.bresp_o(slave_bresp_o[i * 2+:2]),
				.buser_o(slave_buser_o[i * AXI_USER_W+:AXI_USER_W]),
				.bvalid_o(slave_bvalid_o[i]),
				.bready_i(slave_bready_i[i]),
				.arvalid_i(slave_arvalid_i[i]),
				.araddr_i(slave_araddr_i[i * AXI_ADDRESS_W+:AXI_ADDRESS_W]),
				.arready_o(slave_arready_o[i]),
				.arlen_i(slave_arlen_i[i * 8+:8]),
				.aruser_i(slave_aruser_i[i * AXI_USER_W+:AXI_USER_W]),
				.arid_i(slave_arid_i[i * AXI_ID_IN+:AXI_ID_IN]),
				.arvalid_o(arvalid_int[i * N_MASTER_PORT+:N_MASTER_PORT]),
				.arready_i(arready_int_reverse[i * N_MASTER_PORT+:N_MASTER_PORT]),
				.awvalid_i(slave_awvalid_i[i]),
				.awaddr_i(slave_awaddr_i[i * AXI_ADDRESS_W+:AXI_ADDRESS_W]),
				.awready_o(slave_awready_o[i]),
				.awuser_i(slave_awuser_i[i * AXI_USER_W+:AXI_USER_W]),
				.awid_i(slave_awid_i[i * AXI_ID_IN+:AXI_ID_IN]),
				.awvalid_o(awvalid_int[i * N_MASTER_PORT+:N_MASTER_PORT]),
				.awready_i(awready_int_reverse[i * N_MASTER_PORT+:N_MASTER_PORT]),
				.wvalid_i(slave_wvalid_i[i]),
				.wlast_i(slave_wlast_i[i]),
				.wready_o(slave_wready_o[i]),
				.wvalid_o(wvalid_int[i * N_MASTER_PORT+:N_MASTER_PORT]),
				.wready_i(wready_int_reverse[i * N_MASTER_PORT+:N_MASTER_PORT]),
				.START_ADDR_i(START_ADDR),
				.END_ADDR_i(END_ADDR),
				.enable_region_i(valid_rule),
				.connectivity_map_i(connectivity_map[i * N_MASTER_PORT+:N_MASTER_PORT])
			);
		end
	endgenerate
	assign START_ADDR = cfg_START_ADDR_i;
	assign END_ADDR = cfg_END_ADDR_i;
	assign connectivity_map = cfg_connectivity_map_i;
	generate
		for (_gv_i_12 = 0; _gv_i_12 < N_REGION; _gv_i_12 = _gv_i_12 + 1) begin : _VALID_RULE_REGION
			localparam i = _gv_i_12;
			for (_gv_j_6 = 0; _gv_j_6 < N_MASTER_PORT; _gv_j_6 = _gv_j_6 + 1) begin : _VALID_RULE_MASTER
				localparam j = _gv_j_6;
				assign valid_rule[(i * N_MASTER_PORT) + j] = cfg_valid_rule_i[(i * N_MASTER_PORT) + j];
			end
		end
	endgenerate
endmodule
module axi_request_block (
	clk,
	rst_n,
	test_en_i,
	awid_i,
	awaddr_i,
	awlen_i,
	awsize_i,
	awburst_i,
	awlock_i,
	awcache_i,
	awprot_i,
	awregion_i,
	awuser_i,
	awqos_i,
	awvalid_i,
	awready_o,
	wdata_i,
	wstrb_i,
	wlast_i,
	wuser_i,
	wvalid_i,
	wready_o,
	arid_i,
	araddr_i,
	arlen_i,
	arsize_i,
	arburst_i,
	arlock_i,
	arcache_i,
	arprot_i,
	arregion_i,
	aruser_i,
	arqos_i,
	arvalid_i,
	arready_o,
	bid_i,
	bvalid_i,
	bready_o,
	bvalid_o,
	bready_i,
	rid_i,
	rvalid_i,
	rready_o,
	rvalid_o,
	rready_i,
	awid_o,
	awaddr_o,
	awlen_o,
	awsize_o,
	awburst_o,
	awlock_o,
	awcache_o,
	awprot_o,
	awregion_o,
	awuser_o,
	awqos_o,
	awvalid_o,
	awready_i,
	wdata_o,
	wstrb_o,
	wlast_o,
	wuser_o,
	wvalid_o,
	wready_i,
	arid_o,
	araddr_o,
	arlen_o,
	arsize_o,
	arburst_o,
	arlock_o,
	arcache_o,
	arprot_o,
	arregion_o,
	aruser_o,
	arqos_o,
	arvalid_o,
	arready_i
);
	parameter AXI_ADDRESS_W = 32;
	parameter AXI_DATA_W = 64;
	parameter AXI_NUMBYTES = AXI_DATA_W / 8;
	parameter AXI_USER_W = 6;
	parameter N_INIT_PORT = 5;
	parameter N_TARG_PORT = 8;
	parameter FIFO_DW_DEPTH = 8;
	parameter AXI_ID_IN = 16;
	parameter LOG_N_TARG = $clog2(N_TARG_PORT);
	parameter AXI_ID_OUT = AXI_ID_IN + LOG_N_TARG;
	input wire clk;
	input wire rst_n;
	input wire test_en_i;
	input wire [(N_TARG_PORT * AXI_ID_IN) - 1:0] awid_i;
	input wire [(N_TARG_PORT * AXI_ADDRESS_W) - 1:0] awaddr_i;
	input wire [(N_TARG_PORT * 8) - 1:0] awlen_i;
	input wire [(N_TARG_PORT * 3) - 1:0] awsize_i;
	input wire [(N_TARG_PORT * 2) - 1:0] awburst_i;
	input wire [N_TARG_PORT - 1:0] awlock_i;
	input wire [(N_TARG_PORT * 4) - 1:0] awcache_i;
	input wire [(N_TARG_PORT * 3) - 1:0] awprot_i;
	input wire [(N_TARG_PORT * 4) - 1:0] awregion_i;
	input wire [(N_TARG_PORT * AXI_USER_W) - 1:0] awuser_i;
	input wire [(N_TARG_PORT * 4) - 1:0] awqos_i;
	input wire [N_TARG_PORT - 1:0] awvalid_i;
	output wire [N_TARG_PORT - 1:0] awready_o;
	input wire [(N_TARG_PORT * AXI_DATA_W) - 1:0] wdata_i;
	input wire [(N_TARG_PORT * AXI_NUMBYTES) - 1:0] wstrb_i;
	input wire [N_TARG_PORT - 1:0] wlast_i;
	input wire [(N_TARG_PORT * AXI_USER_W) - 1:0] wuser_i;
	input wire [N_TARG_PORT - 1:0] wvalid_i;
	output wire [N_TARG_PORT - 1:0] wready_o;
	input wire [(N_TARG_PORT * AXI_ID_IN) - 1:0] arid_i;
	input wire [(N_TARG_PORT * AXI_ADDRESS_W) - 1:0] araddr_i;
	input wire [(N_TARG_PORT * 8) - 1:0] arlen_i;
	input wire [(N_TARG_PORT * 3) - 1:0] arsize_i;
	input wire [(N_TARG_PORT * 2) - 1:0] arburst_i;
	input wire [N_TARG_PORT - 1:0] arlock_i;
	input wire [(N_TARG_PORT * 4) - 1:0] arcache_i;
	input wire [(N_TARG_PORT * 3) - 1:0] arprot_i;
	input wire [(N_TARG_PORT * 4) - 1:0] arregion_i;
	input wire [(N_TARG_PORT * AXI_USER_W) - 1:0] aruser_i;
	input wire [(N_TARG_PORT * 4) - 1:0] arqos_i;
	input wire [N_TARG_PORT - 1:0] arvalid_i;
	output wire [N_TARG_PORT - 1:0] arready_o;
	input wire [AXI_ID_OUT - 1:0] bid_i;
	input wire bvalid_i;
	output wire bready_o;
	output wire [N_TARG_PORT - 1:0] bvalid_o;
	input wire [N_TARG_PORT - 1:0] bready_i;
	input wire [AXI_ID_OUT - 1:0] rid_i;
	input wire rvalid_i;
	output wire rready_o;
	output wire [N_TARG_PORT - 1:0] rvalid_o;
	input wire [N_TARG_PORT - 1:0] rready_i;
	output wire [AXI_ID_OUT - 1:0] awid_o;
	output wire [AXI_ADDRESS_W - 1:0] awaddr_o;
	output wire [7:0] awlen_o;
	output wire [2:0] awsize_o;
	output wire [1:0] awburst_o;
	output wire awlock_o;
	output wire [3:0] awcache_o;
	output wire [2:0] awprot_o;
	output wire [3:0] awregion_o;
	output wire [AXI_USER_W - 1:0] awuser_o;
	output wire [3:0] awqos_o;
	output wire awvalid_o;
	input wire awready_i;
	output wire [AXI_DATA_W - 1:0] wdata_o;
	output wire [AXI_NUMBYTES - 1:0] wstrb_o;
	output wire wlast_o;
	output wire [AXI_USER_W - 1:0] wuser_o;
	output wire wvalid_o;
	input wire wready_i;
	output wire [AXI_ID_OUT - 1:0] arid_o;
	output wire [AXI_ADDRESS_W - 1:0] araddr_o;
	output wire [7:0] arlen_o;
	output wire [2:0] arsize_o;
	output wire [1:0] arburst_o;
	output wire arlock_o;
	output wire [3:0] arcache_o;
	output wire [2:0] arprot_o;
	output wire [3:0] arregion_o;
	output wire [AXI_USER_W - 1:0] aruser_o;
	output wire [3:0] arqos_o;
	output wire arvalid_o;
	input wire arready_i;
	wire push_ID;
	wire [(LOG_N_TARG + N_TARG_PORT) - 1:0] ID;
	wire grant_FIFO_ID;
	axi_AR_allocator #(
		.AXI_ADDRESS_W(AXI_ADDRESS_W),
		.AXI_USER_W(AXI_USER_W),
		.N_TARG_PORT(N_TARG_PORT),
		.AXI_ID_IN(AXI_ID_IN)
	) AR_ALLOCATOR(
		.clk(clk),
		.rst_n(rst_n),
		.arid_i(arid_i),
		.araddr_i(araddr_i),
		.arlen_i(arlen_i),
		.arsize_i(arsize_i),
		.arburst_i(arburst_i),
		.arlock_i(arlock_i),
		.arcache_i(arcache_i),
		.arprot_i(arprot_i),
		.arregion_i(arregion_i),
		.aruser_i(aruser_i),
		.arqos_i(arqos_i),
		.arvalid_i(arvalid_i),
		.arready_o(arready_o),
		.arid_o(arid_o),
		.araddr_o(araddr_o),
		.arlen_o(arlen_o),
		.arsize_o(arsize_o),
		.arburst_o(arburst_o),
		.arlock_o(arlock_o),
		.arcache_o(arcache_o),
		.arprot_o(arprot_o),
		.arregion_o(arregion_o),
		.aruser_o(aruser_o),
		.arqos_o(arqos_o),
		.arvalid_o(arvalid_o),
		.arready_i(arready_i)
	);
	axi_AW_allocator #(
		.AXI_ADDRESS_W(AXI_ADDRESS_W),
		.AXI_USER_W(AXI_USER_W),
		.N_TARG_PORT(N_TARG_PORT),
		.AXI_ID_IN(AXI_ID_IN)
	) AW_ALLOCATOR(
		.clk(clk),
		.rst_n(rst_n),
		.awid_i(awid_i),
		.awaddr_i(awaddr_i),
		.awlen_i(awlen_i),
		.awsize_i(awsize_i),
		.awburst_i(awburst_i),
		.awlock_i(awlock_i),
		.awcache_i(awcache_i),
		.awprot_i(awprot_i),
		.awregion_i(awregion_i),
		.awuser_i(awuser_i),
		.awqos_i(awqos_i),
		.awvalid_i(awvalid_i),
		.awready_o(awready_o),
		.awid_o(awid_o),
		.awaddr_o(awaddr_o),
		.awlen_o(awlen_o),
		.awsize_o(awsize_o),
		.awburst_o(awburst_o),
		.awlock_o(awlock_o),
		.awcache_o(awcache_o),
		.awprot_o(awprot_o),
		.awregion_o(awregion_o),
		.awuser_o(awuser_o),
		.awqos_o(awqos_o),
		.awvalid_o(awvalid_o),
		.awready_i(awready_i),
		.push_ID_o(push_ID),
		.ID_o(ID),
		.grant_FIFO_ID_i(grant_FIFO_ID)
	);
	axi_DW_allocator #(
		.AXI_USER_W(AXI_USER_W),
		.N_TARG_PORT(N_TARG_PORT),
		.FIFO_DEPTH(FIFO_DW_DEPTH),
		.AXI_DATA_W(AXI_DATA_W)
	) DW_ALLOC(
		.clk(clk),
		.rst_n(rst_n),
		.test_en_i(test_en_i),
		.wdata_i(wdata_i),
		.wstrb_i(wstrb_i),
		.wlast_i(wlast_i),
		.wuser_i(wuser_i),
		.wvalid_i(wvalid_i),
		.wready_o(wready_o),
		.wdata_o(wdata_o),
		.wstrb_o(wstrb_o),
		.wlast_o(wlast_o),
		.wuser_o(wuser_o),
		.wvalid_o(wvalid_o),
		.wready_i(wready_i),
		.push_ID_i(push_ID),
		.ID_i(ID),
		.grant_FIFO_ID_o(grant_FIFO_ID)
	);
	axi_address_decoder_BW #(
		.N_TARG_PORT(N_TARG_PORT),
		.AXI_ID_IN(AXI_ID_IN)
	) BW_DECODER(
		.bid_i(bid_i),
		.bvalid_i(bvalid_i),
		.bready_o(bready_o),
		.bvalid_o(bvalid_o),
		.bready_i(bready_i)
	);
	axi_address_decoder_BR #(
		.N_TARG_PORT(N_TARG_PORT),
		.AXI_ID_IN(AXI_ID_IN)
	) BR_DECODER(
		.rid_i(rid_i),
		.rvalid_i(rvalid_i),
		.rready_o(rready_o),
		.rvalid_o(rvalid_o),
		.rready_i(rready_i)
	);
endmodule
module axi_AR_allocator (
	clk,
	rst_n,
	arid_i,
	araddr_i,
	arlen_i,
	arsize_i,
	arburst_i,
	arlock_i,
	arcache_i,
	arprot_i,
	arregion_i,
	aruser_i,
	arqos_i,
	arvalid_i,
	arready_o,
	arid_o,
	araddr_o,
	arlen_o,
	arsize_o,
	arburst_o,
	arlock_o,
	arcache_o,
	arprot_o,
	arregion_o,
	aruser_o,
	arqos_o,
	arvalid_o,
	arready_i
);
	parameter AXI_ADDRESS_W = 32;
	parameter AXI_USER_W = 6;
	parameter N_TARG_PORT = 7;
	parameter LOG_N_TARG = $clog2(N_TARG_PORT);
	parameter AXI_ID_IN = 16;
	parameter AXI_ID_OUT = AXI_ID_IN + $clog2(N_TARG_PORT);
	input wire clk;
	input wire rst_n;
	input wire [(N_TARG_PORT * AXI_ID_IN) - 1:0] arid_i;
	input wire [(N_TARG_PORT * AXI_ADDRESS_W) - 1:0] araddr_i;
	input wire [(N_TARG_PORT * 8) - 1:0] arlen_i;
	input wire [(N_TARG_PORT * 3) - 1:0] arsize_i;
	input wire [(N_TARG_PORT * 2) - 1:0] arburst_i;
	input wire [N_TARG_PORT - 1:0] arlock_i;
	input wire [(N_TARG_PORT * 4) - 1:0] arcache_i;
	input wire [(N_TARG_PORT * 3) - 1:0] arprot_i;
	input wire [(N_TARG_PORT * 4) - 1:0] arregion_i;
	input wire [(N_TARG_PORT * AXI_USER_W) - 1:0] aruser_i;
	input wire [(N_TARG_PORT * 4) - 1:0] arqos_i;
	input wire [N_TARG_PORT - 1:0] arvalid_i;
	output wire [N_TARG_PORT - 1:0] arready_o;
	output wire [AXI_ID_OUT - 1:0] arid_o;
	output wire [AXI_ADDRESS_W - 1:0] araddr_o;
	output wire [7:0] arlen_o;
	output wire [2:0] arsize_o;
	output wire [1:0] arburst_o;
	output wire arlock_o;
	output wire [3:0] arcache_o;
	output wire [2:0] arprot_o;
	output wire [3:0] arregion_o;
	output wire [AXI_USER_W - 1:0] aruser_o;
	output wire [3:0] arqos_o;
	output wire arvalid_o;
	input wire arready_i;
	localparam AUX_WIDTH = (((AXI_ID_IN + AXI_ADDRESS_W) + 25) + AXI_USER_W) + 4;
	wire [(N_TARG_PORT * AUX_WIDTH) - 1:0] AUX_VECTOR_IN;
	wire [AUX_WIDTH - 1:0] AUX_VECTOR_OUT;
	wire [(N_TARG_PORT * (LOG_N_TARG + N_TARG_PORT)) - 1:0] ID_in;
	wire [(LOG_N_TARG + N_TARG_PORT) - 1:0] ID_int;
	genvar _gv_i_13;
	assign {arqos_o, aruser_o, arregion_o, arprot_o, arcache_o, arlock_o, arburst_o, arsize_o, arlen_o, araddr_o, arid_o[AXI_ID_IN - 1:0]} = AUX_VECTOR_OUT;
	assign arid_o[AXI_ID_OUT - 1:AXI_ID_IN] = ID_int[(LOG_N_TARG + N_TARG_PORT) - 1:N_TARG_PORT];
	generate
		for (_gv_i_13 = 0; _gv_i_13 < N_TARG_PORT; _gv_i_13 = _gv_i_13 + 1) begin : AUX_VECTOR_BINDING
			localparam i = _gv_i_13;
			assign AUX_VECTOR_IN[i * AUX_WIDTH+:AUX_WIDTH] = {arqos_i[i * 4+:4], aruser_i[i * AXI_USER_W+:AXI_USER_W], arregion_i[i * 4+:4], arprot_i[i * 3+:3], arcache_i[i * 4+:4], arlock_i[i], arburst_i[i * 2+:2], arsize_i[i * 3+:3], arlen_i[i * 8+:8], araddr_i[i * AXI_ADDRESS_W+:AXI_ADDRESS_W], arid_i[i * AXI_ID_IN+:AXI_ID_IN]};
		end
		for (_gv_i_13 = 0; _gv_i_13 < N_TARG_PORT; _gv_i_13 = _gv_i_13 + 1) begin : ID_VECTOR_BINDING
			localparam i = _gv_i_13;
			assign ID_in[(i * (LOG_N_TARG + N_TARG_PORT)) + (N_TARG_PORT - 1)-:N_TARG_PORT] = 2 ** i;
			assign ID_in[(i * (LOG_N_TARG + N_TARG_PORT)) + (((LOG_N_TARG + N_TARG_PORT) - 1) >= N_TARG_PORT ? (LOG_N_TARG + N_TARG_PORT) - 1 : (((LOG_N_TARG + N_TARG_PORT) - 1) + (((LOG_N_TARG + N_TARG_PORT) - 1) >= N_TARG_PORT ? (((LOG_N_TARG + N_TARG_PORT) - 1) - N_TARG_PORT) + 1 : (N_TARG_PORT - ((LOG_N_TARG + N_TARG_PORT) - 1)) + 1)) - 1)-:(((LOG_N_TARG + N_TARG_PORT) - 1) >= N_TARG_PORT ? (((LOG_N_TARG + N_TARG_PORT) - 1) - N_TARG_PORT) + 1 : (N_TARG_PORT - ((LOG_N_TARG + N_TARG_PORT) - 1)) + 1)] = i;
		end
	endgenerate
	axi_ArbitrationTree #(
		.AUX_WIDTH(AUX_WIDTH),
		.ID_WIDTH(LOG_N_TARG + N_TARG_PORT),
		.N_MASTER(N_TARG_PORT)
	) AW_ARB_TREE(
		.clk(clk),
		.rst_n(rst_n),
		.data_req_i(arvalid_i),
		.data_AUX_i(AUX_VECTOR_IN),
		.data_ID_i(ID_in),
		.data_gnt_o(arready_o),
		.data_req_o(arvalid_o),
		.data_AUX_o(AUX_VECTOR_OUT),
		.data_ID_o(ID_int),
		.data_gnt_i(arready_i),
		.lock(1'b0),
		.SEL_EXCLUSIVE({$clog2(N_TARG_PORT) {1'b0}})
	);
endmodule
module axi_ArbitrationTree (
	clk,
	rst_n,
	data_req_i,
	data_AUX_i,
	data_ID_i,
	data_gnt_o,
	data_req_o,
	data_AUX_o,
	data_ID_o,
	data_gnt_i,
	lock,
	SEL_EXCLUSIVE
);
	reg _sv2v_0;
	parameter AUX_WIDTH = 64;
	parameter ID_WIDTH = 20;
	parameter N_MASTER = 5;
	parameter LOG_MASTER = $clog2(N_MASTER);
	input wire clk;
	input wire rst_n;
	input wire [N_MASTER - 1:0] data_req_i;
	input wire [(N_MASTER * AUX_WIDTH) - 1:0] data_AUX_i;
	input wire [(N_MASTER * ID_WIDTH) - 1:0] data_ID_i;
	output wire [N_MASTER - 1:0] data_gnt_o;
	output wire data_req_o;
	output wire [AUX_WIDTH - 1:0] data_AUX_o;
	output wire [ID_WIDTH - 1:0] data_ID_o;
	input wire data_gnt_i;
	input wire lock;
	input wire [LOG_MASTER - 1:0] SEL_EXCLUSIVE;
	localparam TOTAL_N_MASTER = 2 ** LOG_MASTER;
	localparam N_WIRE = TOTAL_N_MASTER - 2;
	wire [LOG_MASTER - 1:0] RR_FLAG;
	reg [LOG_MASTER - 1:0] RR_FLAG_FLIPPED;
	wire [TOTAL_N_MASTER - 1:0] data_req_int;
	wire [(TOTAL_N_MASTER * AUX_WIDTH) - 1:0] data_AUX_int;
	wire [(TOTAL_N_MASTER * ID_WIDTH) - 1:0] data_ID_int;
	wire [TOTAL_N_MASTER - 1:0] data_gnt_int;
	genvar _gv_j_7;
	genvar _gv_k_6;
	genvar _gv_index_1;
	integer i;
	always @(*) begin
		if (_sv2v_0)
			;
		for (i = 0; i < LOG_MASTER; i = i + 1)
			RR_FLAG_FLIPPED[i] = RR_FLAG[(LOG_MASTER - i) - 1];
	end
	generate
		if (N_MASTER != TOTAL_N_MASTER) begin : ARRAY_INT
			wire [TOTAL_N_MASTER - 1:N_MASTER] dummy_req_int;
			wire [((TOTAL_N_MASTER - 1) >= N_MASTER ? ((((TOTAL_N_MASTER - 1) - N_MASTER) + 1) * AUX_WIDTH) + ((N_MASTER * AUX_WIDTH) - 1) : (((N_MASTER - (TOTAL_N_MASTER - 1)) + 1) * AUX_WIDTH) + (((TOTAL_N_MASTER - 1) * AUX_WIDTH) - 1)):((TOTAL_N_MASTER - 1) >= N_MASTER ? N_MASTER * AUX_WIDTH : (TOTAL_N_MASTER - 1) * AUX_WIDTH)] dummy_AUX_int;
			wire [((TOTAL_N_MASTER - 1) >= N_MASTER ? ((((TOTAL_N_MASTER - 1) - N_MASTER) + 1) * ID_WIDTH) + ((N_MASTER * ID_WIDTH) - 1) : (((N_MASTER - (TOTAL_N_MASTER - 1)) + 1) * ID_WIDTH) + (((TOTAL_N_MASTER - 1) * ID_WIDTH) - 1)):((TOTAL_N_MASTER - 1) >= N_MASTER ? N_MASTER * ID_WIDTH : (TOTAL_N_MASTER - 1) * ID_WIDTH)] dummy_ID_int;
			wire [TOTAL_N_MASTER - 1:N_MASTER] dummy_gnt_int;
			for (_gv_index_1 = N_MASTER; _gv_index_1 < TOTAL_N_MASTER; _gv_index_1 = _gv_index_1 + 1) begin : ZERO_BINDING
				localparam index = _gv_index_1;
				assign dummy_req_int[index] = 1'b0;
				assign dummy_AUX_int[((TOTAL_N_MASTER - 1) >= N_MASTER ? index : N_MASTER - (index - (TOTAL_N_MASTER - 1))) * AUX_WIDTH+:AUX_WIDTH] = 1'sb0;
				assign dummy_ID_int[((TOTAL_N_MASTER - 1) >= N_MASTER ? index : N_MASTER - (index - (TOTAL_N_MASTER - 1))) * ID_WIDTH+:ID_WIDTH] = 1'sb0;
			end
			for (_gv_index_1 = 0; _gv_index_1 < N_MASTER; _gv_index_1 = _gv_index_1 + 1) begin : EXT_PORT
				localparam index = _gv_index_1;
				assign data_req_int[index] = data_req_i[index];
				assign data_AUX_int[index * AUX_WIDTH+:AUX_WIDTH] = data_AUX_i[index * AUX_WIDTH+:AUX_WIDTH];
				assign data_ID_int[index * ID_WIDTH+:ID_WIDTH] = data_ID_i[index * ID_WIDTH+:ID_WIDTH];
				assign data_gnt_o[index] = data_gnt_int[index];
			end
			for (_gv_index_1 = N_MASTER; _gv_index_1 < TOTAL_N_MASTER; _gv_index_1 = _gv_index_1 + 1) begin : DUMMY_PORTS
				localparam index = _gv_index_1;
				assign data_req_int[index] = dummy_req_int[index];
				assign data_AUX_int[index * AUX_WIDTH+:AUX_WIDTH] = dummy_AUX_int[((TOTAL_N_MASTER - 1) >= N_MASTER ? index : N_MASTER - (index - (TOTAL_N_MASTER - 1))) * AUX_WIDTH+:AUX_WIDTH];
				assign data_ID_int[index * ID_WIDTH+:ID_WIDTH] = dummy_ID_int[((TOTAL_N_MASTER - 1) >= N_MASTER ? index : N_MASTER - (index - (TOTAL_N_MASTER - 1))) * ID_WIDTH+:ID_WIDTH];
				assign dummy_gnt_int[index] = data_gnt_int[index];
			end
		end
		else begin : genblk1
			for (_gv_index_1 = 0; _gv_index_1 < N_MASTER; _gv_index_1 = _gv_index_1 + 1) begin : EXT_PORT
				localparam index = _gv_index_1;
				assign data_req_int[index] = data_req_i[index];
				assign data_AUX_int[index * AUX_WIDTH+:AUX_WIDTH] = data_AUX_i[index * AUX_WIDTH+:AUX_WIDTH];
				assign data_ID_int[index * ID_WIDTH+:ID_WIDTH] = data_ID_i[index * ID_WIDTH+:ID_WIDTH];
				assign data_gnt_o[index] = data_gnt_int[index];
			end
		end
		if (TOTAL_N_MASTER == 2) begin : INCR
			axi_FanInPrimitive_Req #(
				.AUX_WIDTH(AUX_WIDTH),
				.ID_WIDTH(ID_WIDTH)
			) FAN_IN_REQ(
				.RR_FLAG(RR_FLAG_FLIPPED),
				.data_AUX0_i(data_AUX_int[0+:AUX_WIDTH]),
				.data_AUX1_i(data_AUX_int[AUX_WIDTH+:AUX_WIDTH]),
				.data_req0_i(data_req_int[0]),
				.data_req1_i(data_req_int[1]),
				.data_ID0_i(data_ID_int[0+:ID_WIDTH]),
				.data_ID1_i(data_ID_int[ID_WIDTH+:ID_WIDTH]),
				.data_gnt0_o(data_gnt_int[0]),
				.data_gnt1_o(data_gnt_int[1]),
				.data_AUX_o(data_AUX_o),
				.data_req_o(data_req_o),
				.data_ID_o(data_ID_o),
				.data_gnt_i(data_gnt_i),
				.lock_EXCLUSIVE(lock),
				.SEL_EXCLUSIVE(SEL_EXCLUSIVE)
			);
		end
		else begin : BINARY_TREE
			wire [AUX_WIDTH - 1:0] data_AUX_LEVEL [N_WIRE - 1:0];
			wire data_req_LEVEL [N_WIRE - 1:0];
			wire [ID_WIDTH - 1:0] data_ID_LEVEL [N_WIRE - 1:0];
			wire data_gnt_LEVEL [N_WIRE - 1:0];
			for (_gv_j_7 = 0; _gv_j_7 < LOG_MASTER; _gv_j_7 = _gv_j_7 + 1) begin : STAGE
				localparam j = _gv_j_7;
				for (_gv_k_6 = 0; _gv_k_6 < (2 ** j); _gv_k_6 = _gv_k_6 + 1) begin : INCR_VERT
					localparam k = _gv_k_6;
					if (j == 0) begin : LAST_NODE
						axi_FanInPrimitive_Req #(
							.AUX_WIDTH(AUX_WIDTH),
							.ID_WIDTH(ID_WIDTH)
						) FAN_IN_REQ(
							.RR_FLAG(RR_FLAG_FLIPPED[(LOG_MASTER - j) - 1]),
							.data_AUX0_i(data_AUX_LEVEL[2 * k]),
							.data_AUX1_i(data_AUX_LEVEL[(2 * k) + 1]),
							.data_req0_i(data_req_LEVEL[2 * k]),
							.data_req1_i(data_req_LEVEL[(2 * k) + 1]),
							.data_ID0_i(data_ID_LEVEL[2 * k]),
							.data_ID1_i(data_ID_LEVEL[(2 * k) + 1]),
							.data_gnt0_o(data_gnt_LEVEL[2 * k]),
							.data_gnt1_o(data_gnt_LEVEL[(2 * k) + 1]),
							.data_AUX_o(data_AUX_o),
							.data_req_o(data_req_o),
							.data_ID_o(data_ID_o),
							.data_gnt_i(data_gnt_i),
							.lock_EXCLUSIVE(lock),
							.SEL_EXCLUSIVE(SEL_EXCLUSIVE[(LOG_MASTER - j) - 1])
						);
					end
					else if (j < (LOG_MASTER - 1)) begin : MIDDLE_NODES
						axi_FanInPrimitive_Req #(
							.AUX_WIDTH(AUX_WIDTH),
							.ID_WIDTH(ID_WIDTH)
						) FAN_IN_REQ(
							.RR_FLAG(RR_FLAG_FLIPPED[(LOG_MASTER - j) - 1]),
							.data_AUX0_i(data_AUX_LEVEL[(((2 ** j) * 2) - 2) + (2 * k)]),
							.data_AUX1_i(data_AUX_LEVEL[((((2 ** j) * 2) - 2) + (2 * k)) + 1]),
							.data_req0_i(data_req_LEVEL[(((2 ** j) * 2) - 2) + (2 * k)]),
							.data_req1_i(data_req_LEVEL[((((2 ** j) * 2) - 2) + (2 * k)) + 1]),
							.data_ID0_i(data_ID_LEVEL[(((2 ** j) * 2) - 2) + (2 * k)]),
							.data_ID1_i(data_ID_LEVEL[((((2 ** j) * 2) - 2) + (2 * k)) + 1]),
							.data_gnt0_o(data_gnt_LEVEL[(((2 ** j) * 2) - 2) + (2 * k)]),
							.data_gnt1_o(data_gnt_LEVEL[((((2 ** j) * 2) - 2) + (2 * k)) + 1]),
							.data_AUX_o(data_AUX_LEVEL[(((2 ** (j - 1)) * 2) - 2) + k]),
							.data_req_o(data_req_LEVEL[(((2 ** (j - 1)) * 2) - 2) + k]),
							.data_ID_o(data_ID_LEVEL[(((2 ** (j - 1)) * 2) - 2) + k]),
							.data_gnt_i(data_gnt_LEVEL[(((2 ** (j - 1)) * 2) - 2) + k]),
							.lock_EXCLUSIVE(lock),
							.SEL_EXCLUSIVE(SEL_EXCLUSIVE[(LOG_MASTER - j) - 1])
						);
					end
					else begin : LEAF_NODES
						axi_FanInPrimitive_Req #(
							.AUX_WIDTH(AUX_WIDTH),
							.ID_WIDTH(ID_WIDTH)
						) FAN_IN_REQ(
							.RR_FLAG(RR_FLAG_FLIPPED[(LOG_MASTER - j) - 1]),
							.data_AUX0_i(data_AUX_int[(2 * k) * AUX_WIDTH+:AUX_WIDTH]),
							.data_AUX1_i(data_AUX_int[((2 * k) + 1) * AUX_WIDTH+:AUX_WIDTH]),
							.data_req0_i(data_req_int[2 * k]),
							.data_req1_i(data_req_int[(2 * k) + 1]),
							.data_ID0_i(data_ID_int[(2 * k) * ID_WIDTH+:ID_WIDTH]),
							.data_ID1_i(data_ID_int[((2 * k) + 1) * ID_WIDTH+:ID_WIDTH]),
							.data_gnt0_o(data_gnt_int[2 * k]),
							.data_gnt1_o(data_gnt_int[(2 * k) + 1]),
							.data_AUX_o(data_AUX_LEVEL[(((2 ** (j - 1)) * 2) - 2) + k]),
							.data_req_o(data_req_LEVEL[(((2 ** (j - 1)) * 2) - 2) + k]),
							.data_ID_o(data_ID_LEVEL[(((2 ** (j - 1)) * 2) - 2) + k]),
							.data_gnt_i(data_gnt_LEVEL[(((2 ** (j - 1)) * 2) - 2) + k]),
							.lock_EXCLUSIVE(lock),
							.SEL_EXCLUSIVE(SEL_EXCLUSIVE[(LOG_MASTER - j) - 1])
						);
					end
				end
			end
		end
	endgenerate
	axi_RR_Flag_Req #(
		.WIDTH(LOG_MASTER),
		.MAX_COUNT(N_MASTER)
	) RR_REQ(
		.clk(clk),
		.rst_n(rst_n),
		.RR_FLAG_o(RR_FLAG),
		.data_req_i(data_req_o),
		.data_gnt_i(data_gnt_i)
	);
	initial _sv2v_0 = 0;
endmodule
module axi_RR_Flag_Req (
	clk,
	rst_n,
	RR_FLAG_o,
	data_req_i,
	data_gnt_i
);
	parameter MAX_COUNT = 8;
	parameter WIDTH = $clog2(MAX_COUNT);
	input wire clk;
	input wire rst_n;
	output reg [WIDTH - 1:0] RR_FLAG_o;
	input wire data_req_i;
	input wire data_gnt_i;
	always @(posedge clk or negedge rst_n) begin : RR_Flag_Req_SEQ
		if (rst_n == 1'b0)
			RR_FLAG_o <= 1'sb0;
		else if (data_req_i & data_gnt_i) begin
			if (RR_FLAG_o < (MAX_COUNT - 1))
				RR_FLAG_o <= RR_FLAG_o + 1'b1;
			else
				RR_FLAG_o <= 1'sb0;
		end
	end
endmodule
module axi_AW_allocator (
	clk,
	rst_n,
	awid_i,
	awaddr_i,
	awlen_i,
	awsize_i,
	awburst_i,
	awlock_i,
	awcache_i,
	awprot_i,
	awregion_i,
	awuser_i,
	awqos_i,
	awvalid_i,
	awready_o,
	awid_o,
	awaddr_o,
	awlen_o,
	awsize_o,
	awburst_o,
	awlock_o,
	awcache_o,
	awprot_o,
	awregion_o,
	awuser_o,
	awqos_o,
	awvalid_o,
	awready_i,
	push_ID_o,
	ID_o,
	grant_FIFO_ID_i
);
	parameter AXI_ADDRESS_W = 32;
	parameter AXI_USER_W = 6;
	parameter N_TARG_PORT = 7;
	parameter LOG_N_TARG = $clog2(N_TARG_PORT);
	parameter AXI_ID_IN = 16;
	parameter AXI_ID_OUT = AXI_ID_IN + $clog2(N_TARG_PORT);
	input wire clk;
	input wire rst_n;
	input wire [(N_TARG_PORT * AXI_ID_IN) - 1:0] awid_i;
	input wire [(N_TARG_PORT * AXI_ADDRESS_W) - 1:0] awaddr_i;
	input wire [(N_TARG_PORT * 8) - 1:0] awlen_i;
	input wire [(N_TARG_PORT * 3) - 1:0] awsize_i;
	input wire [(N_TARG_PORT * 2) - 1:0] awburst_i;
	input wire [N_TARG_PORT - 1:0] awlock_i;
	input wire [(N_TARG_PORT * 4) - 1:0] awcache_i;
	input wire [(N_TARG_PORT * 3) - 1:0] awprot_i;
	input wire [(N_TARG_PORT * 4) - 1:0] awregion_i;
	input wire [(N_TARG_PORT * AXI_USER_W) - 1:0] awuser_i;
	input wire [(N_TARG_PORT * 4) - 1:0] awqos_i;
	input wire [N_TARG_PORT - 1:0] awvalid_i;
	output wire [N_TARG_PORT - 1:0] awready_o;
	output wire [AXI_ID_OUT - 1:0] awid_o;
	output wire [AXI_ADDRESS_W - 1:0] awaddr_o;
	output wire [7:0] awlen_o;
	output wire [2:0] awsize_o;
	output wire [1:0] awburst_o;
	output wire awlock_o;
	output wire [3:0] awcache_o;
	output wire [2:0] awprot_o;
	output wire [3:0] awregion_o;
	output wire [AXI_USER_W - 1:0] awuser_o;
	output wire [3:0] awqos_o;
	output wire awvalid_o;
	input wire awready_i;
	output wire push_ID_o;
	output wire [(LOG_N_TARG + N_TARG_PORT) - 1:0] ID_o;
	input wire grant_FIFO_ID_i;
	localparam AUX_WIDTH = (((AXI_ID_IN + AXI_ADDRESS_W) + 25) + AXI_USER_W) + 4;
	wire [(N_TARG_PORT * AUX_WIDTH) - 1:0] AUX_VECTOR_IN;
	wire [AUX_WIDTH - 1:0] AUX_VECTOR_OUT;
	wire [(N_TARG_PORT * (LOG_N_TARG + N_TARG_PORT)) - 1:0] ID_in;
	wire [N_TARG_PORT - 1:0] awready_int;
	wire awvalid_int;
	genvar _gv_i_14;
	assign {awqos_o, awuser_o, awregion_o, awprot_o, awcache_o, awlock_o, awburst_o, awsize_o, awlen_o, awaddr_o, awid_o[AXI_ID_IN - 1:0]} = AUX_VECTOR_OUT;
	assign awid_o[AXI_ID_OUT - 1:AXI_ID_IN] = ID_o[(LOG_N_TARG + N_TARG_PORT) - 1:N_TARG_PORT];
	assign awready_o = {N_TARG_PORT {grant_FIFO_ID_i}} & awready_int;
	assign awvalid_o = awvalid_int & grant_FIFO_ID_i;
	assign push_ID_o = (awvalid_o & awready_i) & grant_FIFO_ID_i;
	generate
		for (_gv_i_14 = 0; _gv_i_14 < N_TARG_PORT; _gv_i_14 = _gv_i_14 + 1) begin : AUX_VECTOR_BINDING
			localparam i = _gv_i_14;
			assign AUX_VECTOR_IN[i * AUX_WIDTH+:AUX_WIDTH] = {awqos_i[i * 4+:4], awuser_i[i * AXI_USER_W+:AXI_USER_W], awregion_i[i * 4+:4], awprot_i[i * 3+:3], awcache_i[i * 4+:4], awlock_i[i], awburst_i[i * 2+:2], awsize_i[i * 3+:3], awlen_i[i * 8+:8], awaddr_i[i * AXI_ADDRESS_W+:AXI_ADDRESS_W], awid_i[i * AXI_ID_IN+:AXI_ID_IN]};
		end
		for (_gv_i_14 = 0; _gv_i_14 < N_TARG_PORT; _gv_i_14 = _gv_i_14 + 1) begin : ID_VECTOR_BINDING
			localparam i = _gv_i_14;
			assign ID_in[(i * (LOG_N_TARG + N_TARG_PORT)) + (N_TARG_PORT - 1)-:N_TARG_PORT] = 2 ** i;
			assign ID_in[(i * (LOG_N_TARG + N_TARG_PORT)) + (((LOG_N_TARG + N_TARG_PORT) - 1) >= N_TARG_PORT ? (LOG_N_TARG + N_TARG_PORT) - 1 : (((LOG_N_TARG + N_TARG_PORT) - 1) + (((LOG_N_TARG + N_TARG_PORT) - 1) >= N_TARG_PORT ? (((LOG_N_TARG + N_TARG_PORT) - 1) - N_TARG_PORT) + 1 : (N_TARG_PORT - ((LOG_N_TARG + N_TARG_PORT) - 1)) + 1)) - 1)-:(((LOG_N_TARG + N_TARG_PORT) - 1) >= N_TARG_PORT ? (((LOG_N_TARG + N_TARG_PORT) - 1) - N_TARG_PORT) + 1 : (N_TARG_PORT - ((LOG_N_TARG + N_TARG_PORT) - 1)) + 1)] = i;
		end
	endgenerate
	axi_ArbitrationTree #(
		.AUX_WIDTH(AUX_WIDTH),
		.ID_WIDTH(LOG_N_TARG + N_TARG_PORT),
		.N_MASTER(N_TARG_PORT)
	) AW_ARB_TREE(
		.clk(clk),
		.rst_n(rst_n),
		.data_req_i(awvalid_i),
		.data_AUX_i(AUX_VECTOR_IN),
		.data_ID_i(ID_in),
		.data_gnt_o(awready_int),
		.data_req_o(awvalid_int),
		.data_AUX_o(AUX_VECTOR_OUT),
		.data_ID_o(ID_o),
		.data_gnt_i(awready_i),
		.lock(1'b0),
		.SEL_EXCLUSIVE({$clog2(N_TARG_PORT) {1'b0}})
	);
endmodule
module axi_DW_allocator (
	clk,
	rst_n,
	test_en_i,
	wdata_i,
	wstrb_i,
	wlast_i,
	wuser_i,
	wvalid_i,
	wready_o,
	wdata_o,
	wstrb_o,
	wlast_o,
	wuser_o,
	wvalid_o,
	wready_i,
	push_ID_i,
	ID_i,
	grant_FIFO_ID_o
);
	reg _sv2v_0;
	parameter AXI_USER_W = 6;
	parameter N_TARG_PORT = 7;
	parameter LOG_N_TARG = $clog2(N_TARG_PORT);
	parameter FIFO_DEPTH = 8;
	parameter AXI_DATA_W = 64;
	parameter AXI_NUMBYTES = AXI_DATA_W / 8;
	input wire clk;
	input wire rst_n;
	input wire test_en_i;
	input wire [(N_TARG_PORT * AXI_DATA_W) - 1:0] wdata_i;
	input wire [(N_TARG_PORT * AXI_NUMBYTES) - 1:0] wstrb_i;
	input wire [N_TARG_PORT - 1:0] wlast_i;
	input wire [(N_TARG_PORT * AXI_USER_W) - 1:0] wuser_i;
	input wire [N_TARG_PORT - 1:0] wvalid_i;
	output reg [N_TARG_PORT - 1:0] wready_o;
	output wire [AXI_DATA_W - 1:0] wdata_o;
	output wire [AXI_NUMBYTES - 1:0] wstrb_o;
	output wire wlast_o;
	output wire [AXI_USER_W - 1:0] wuser_o;
	output reg wvalid_o;
	input wire wready_i;
	input wire push_ID_i;
	input wire [(LOG_N_TARG + N_TARG_PORT) - 1:0] ID_i;
	output wire grant_FIFO_ID_o;
	localparam AUX_WIDTH = ((AXI_DATA_W + AXI_NUMBYTES) + 1) + AXI_USER_W;
	reg pop_from_ID_FIFO;
	wire valid_ID;
	wire [(LOG_N_TARG + N_TARG_PORT) - 1:0] ID_int;
	wire [LOG_N_TARG - 1:0] ID_int_BIN;
	wire [N_TARG_PORT - 1:0] ID_int_OH;
	wire [AUX_WIDTH - 1:0] AUX_VECTOR_OUT;
	wire [(N_TARG_PORT * AUX_WIDTH) - 1:0] AUX_VECTOR_IN;
	reg CS;
	reg NS;
	genvar _gv_i_15;
	generate
		for (_gv_i_15 = 0; _gv_i_15 < N_TARG_PORT; _gv_i_15 = _gv_i_15 + 1) begin : AUX_VECTOR_BINDING
			localparam i = _gv_i_15;
			assign AUX_VECTOR_IN[i * AUX_WIDTH+:AUX_WIDTH] = {wdata_i[i * AXI_DATA_W+:AXI_DATA_W], wstrb_i[i * AXI_NUMBYTES+:AXI_NUMBYTES], wlast_i[i], wuser_i[i * AXI_USER_W+:AXI_USER_W]};
		end
	endgenerate
	assign {wdata_o, wstrb_o, wlast_o, wuser_o} = AUX_VECTOR_OUT;
	wire empty;
	wire full;
	fifo_v2 #(
		.FALL_THROUGH(1'b0),
		.DATA_WIDTH(LOG_N_TARG + N_TARG_PORT),
		.DEPTH(FIFO_DEPTH)
	) MASTER_ID_FIFO(
		.clk_i(clk),
		.rst_ni(rst_n),
		.flush_i(1'b0),
		.testmode_i(test_en_i),
		.alm_empty_o(),
		.alm_full_o(),
		.data_i(ID_i),
		.push_i(push_ID_i),
		.full_o(full),
		.data_o(ID_int),
		.empty_o(empty),
		.pop_i(pop_from_ID_FIFO)
	);
	assign valid_ID = ~empty;
	assign grant_FIFO_ID_o = ~full;
	assign ID_int_BIN = ID_int[(LOG_N_TARG + N_TARG_PORT) - 1:N_TARG_PORT];
	assign ID_int_OH = ID_int[N_TARG_PORT - 1:0];
	always @(posedge clk or negedge rst_n) begin : UPDATE_STATE_FSM
		if (rst_n == 1'b0)
			CS <= 1'd0;
		else
			CS <= NS;
	end
	always @(*) begin : NEXT_STATE_FSM
		if (_sv2v_0)
			;
		pop_from_ID_FIFO = 1'b0;
		wvalid_o = 1'b0;
		wready_o = 1'sb0;
		case (CS)
			1'd0: begin : _CS_IN_SINGLE_IDLE
				if (valid_ID) begin : _valid_ID
					wvalid_o = wvalid_i[ID_int_BIN];
					wready_o = {N_TARG_PORT {wready_i}} & ID_int_OH;
					if (wvalid_i[ID_int_BIN] & wready_i) begin : _granted_request
						if (wlast_i[ID_int_BIN]) begin : _last_packet
							NS = 1'd0;
							pop_from_ID_FIFO = 1'b1;
						end
						else begin : _payload_packet
							NS = 1'd1;
							pop_from_ID_FIFO = 1'b0;
						end
					end
					else begin : _not_granted_request
						NS = 1'd0;
						pop_from_ID_FIFO = 1'b0;
					end
				end
				else begin : _not_valid_ID
					NS = 1'd0;
					pop_from_ID_FIFO = 1'b0;
					wvalid_o = 1'b0;
					wready_o = 1'sb0;
				end
			end
			1'd1: begin : _CS_IN_BUSRT
				wvalid_o = wvalid_i[ID_int_BIN];
				wready_o = ({N_TARG_PORT {wready_i}} & ID_int_OH) & {N_TARG_PORT {valid_ID}};
				if (wvalid_i[ID_int_BIN] & wready_i) begin
					if (wlast_i[ID_int_BIN]) begin
						NS = 1'd0;
						pop_from_ID_FIFO = 1'b1;
					end
					else begin
						NS = 1'd1;
						pop_from_ID_FIFO = 1'b0;
					end
				end
				else begin
					NS = 1'd1;
					pop_from_ID_FIFO = 1'b0;
				end
			end
			default: begin
				NS = 1'd0;
				pop_from_ID_FIFO = 1'b0;
				wvalid_o = 1'b0;
				wready_o = 1'sb0;
			end
		endcase
	end
	axi_multiplexer #(
		.DATA_WIDTH(AUX_WIDTH),
		.N_IN(N_TARG_PORT)
	) WRITE_DATA_MUX(
		.IN_DATA(AUX_VECTOR_IN),
		.OUT_DATA(AUX_VECTOR_OUT),
		.SEL(ID_int_BIN)
	);
	initial _sv2v_0 = 0;
endmodule
module axi_multiplexer (
	IN_DATA,
	OUT_DATA,
	SEL
);
	parameter DATA_WIDTH = 64;
	parameter N_IN = 16;
	parameter SEL_WIDTH = $clog2(N_IN);
	input wire [(N_IN * DATA_WIDTH) - 1:0] IN_DATA;
	output wire [DATA_WIDTH - 1:0] OUT_DATA;
	input wire [SEL_WIDTH - 1:0] SEL;
	assign OUT_DATA = IN_DATA[SEL * DATA_WIDTH+:DATA_WIDTH];
endmodule
module axi_address_decoder_BW (
	bid_i,
	bvalid_i,
	bready_o,
	bvalid_o,
	bready_i
);
	reg _sv2v_0;
	parameter N_TARG_PORT = 3;
	parameter AXI_ID_IN = 3;
	parameter AXI_ID_OUT = AXI_ID_IN + $clog2(N_TARG_PORT);
	input wire [AXI_ID_OUT - 1:0] bid_i;
	input wire bvalid_i;
	output reg bready_o;
	output reg [N_TARG_PORT - 1:0] bvalid_o;
	input wire [N_TARG_PORT - 1:0] bready_i;
	reg [N_TARG_PORT - 1:0] req_mask;
	wire [$clog2(N_TARG_PORT) - 1:0] ROUTING;
	assign ROUTING = bid_i[(AXI_ID_IN + $clog2(N_TARG_PORT)) - 1:AXI_ID_IN];
	always @(*) begin
		if (_sv2v_0)
			;
		req_mask = 1'sb0;
		req_mask[ROUTING] = 1'b1;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (bvalid_i)
			bvalid_o = {N_TARG_PORT {bvalid_i}} & req_mask;
		else
			bvalid_o = 1'sb0;
		bready_o = |(bready_i & req_mask);
	end
	initial _sv2v_0 = 0;
endmodule
module axi_address_decoder_BR (
	rid_i,
	rvalid_i,
	rready_o,
	rvalid_o,
	rready_i
);
	reg _sv2v_0;
	parameter [31:0] N_TARG_PORT = 8;
	parameter [31:0] AXI_ID_IN = 16;
	parameter [31:0] AXI_ID_OUT = AXI_ID_IN + $clog2(N_TARG_PORT);
	input wire [AXI_ID_OUT - 1:0] rid_i;
	input wire rvalid_i;
	output reg rready_o;
	output reg [N_TARG_PORT - 1:0] rvalid_o;
	input wire [N_TARG_PORT - 1:0] rready_i;
	reg [N_TARG_PORT - 1:0] req_mask;
	wire [$clog2(N_TARG_PORT) - 1:0] ROUTING;
	assign ROUTING = rid_i[(AXI_ID_IN + $clog2(N_TARG_PORT)) - 1:AXI_ID_IN];
	always @(*) begin
		if (_sv2v_0)
			;
		req_mask = 1'sb0;
		req_mask[ROUTING] = 1'b1;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (rvalid_i)
			rvalid_o = {N_TARG_PORT {rvalid_i}} & req_mask;
		else
			rvalid_o = 1'sb0;
		rready_o = |(rready_i & req_mask);
	end
	initial _sv2v_0 = 0;
endmodule
module axi_BW_allocator (
	clk,
	rst_n,
	bid_i,
	bresp_i,
	buser_i,
	bvalid_i,
	bready_o,
	bid_o,
	bresp_o,
	buser_o,
	bvalid_o,
	bready_i,
	incr_req_i,
	full_counter_o,
	outstanding_trans_o,
	sample_awdata_info_i,
	error_req_i,
	error_gnt_o,
	error_user_i,
	error_id_i
);
	reg _sv2v_0;
	parameter AXI_USER_W = 6;
	parameter N_INIT_PORT = 1;
	parameter N_TARG_PORT = 7;
	parameter AXI_DATA_W = 64;
	parameter AXI_ID_IN = 16;
	parameter AXI_ID_OUT = AXI_ID_IN + $clog2(N_TARG_PORT);
	input wire clk;
	input wire rst_n;
	input wire [(N_INIT_PORT * AXI_ID_OUT) - 1:0] bid_i;
	input wire [(N_INIT_PORT * 2) - 1:0] bresp_i;
	input wire [(N_INIT_PORT * AXI_USER_W) - 1:0] buser_i;
	input wire [N_INIT_PORT - 1:0] bvalid_i;
	output wire [N_INIT_PORT - 1:0] bready_o;
	output reg [AXI_ID_IN - 1:0] bid_o;
	output reg [1:0] bresp_o;
	output reg [AXI_USER_W - 1:0] buser_o;
	output reg bvalid_o;
	input wire bready_i;
	input wire incr_req_i;
	output wire full_counter_o;
	output wire outstanding_trans_o;
	input wire sample_awdata_info_i;
	input wire error_req_i;
	output reg error_gnt_o;
	input wire [AXI_USER_W - 1:0] error_user_i;
	input wire [AXI_ID_IN - 1:0] error_id_i;
	localparam AUX_WIDTH = 2 + AXI_USER_W;
	wire [(N_INIT_PORT * AUX_WIDTH) - 1:0] AUX_VECTOR_IN;
	wire [AUX_WIDTH - 1:0] AUX_VECTOR_OUT;
	wire [(N_INIT_PORT * AXI_ID_IN) - 1:0] bid_int;
	genvar _gv_i_17;
	reg [9:0] outstanding_counter;
	wire decr_req;
	reg [AXI_USER_W - 1:0] error_user_S;
	reg [AXI_ID_IN - 1:0] error_id_S;
	reg [1:0] CS;
	reg [1:0] NS;
	wire [AXI_ID_IN - 1:0] bid_ARB_TREE;
	wire [1:0] bresp_ARB_TREE;
	wire [AXI_USER_W - 1:0] buser_ARB_TREE;
	wire bvalid_ARB_TREE;
	reg bready_ARB_TREE;
	assign {buser_ARB_TREE, bresp_ARB_TREE} = AUX_VECTOR_OUT;
	assign outstanding_trans_o = (outstanding_counter == {10 {1'sb0}} ? 1'b0 : 1'b1);
	assign decr_req = bvalid_o & bready_i;
	assign full_counter_o = (outstanding_counter == {10 {1'sb1}} ? 1'b1 : 1'b0);
	always @(posedge clk or negedge rst_n)
		if (rst_n == 1'b0)
			outstanding_counter <= 1'sb0;
		else
			case ({incr_req_i, decr_req})
				2'b00: outstanding_counter <= outstanding_counter;
				2'b01:
					if (outstanding_counter != {10 {1'sb0}})
						outstanding_counter <= outstanding_counter - 1'b1;
					else
						outstanding_counter <= 1'sb0;
				2'b10:
					if (outstanding_counter != {10 {1'sb1}})
						outstanding_counter <= outstanding_counter + 1'b1;
					else
						outstanding_counter <= 1'sb1;
				2'b11: outstanding_counter <= outstanding_counter;
			endcase
	always @(posedge clk or negedge rst_n)
		if (rst_n == 1'b0) begin
			error_user_S <= 1'sb0;
			error_id_S <= 1'sb0;
		end
		else if (sample_awdata_info_i) begin
			error_user_S <= error_user_i;
			error_id_S <= error_id_i;
		end
	always @(posedge clk or negedge rst_n)
		if (rst_n == 1'b0)
			CS <= 2'd0;
		else
			CS <= NS;
	localparam axi_pkg_RESP_DECERR = 2'b11;
	always @(*) begin
		if (_sv2v_0)
			;
		bid_o = bid_ARB_TREE;
		bresp_o = bresp_ARB_TREE;
		buser_o = buser_ARB_TREE;
		bvalid_o = bvalid_ARB_TREE;
		bready_ARB_TREE = bready_i;
		error_gnt_o = 1'b0;
		case (CS)
			2'd0: begin
				bready_ARB_TREE = bready_i;
				error_gnt_o = 1'b0;
				if ((error_req_i == 1'b1) && (outstanding_trans_o == 1'b0))
					NS = 2'd1;
				else
					NS = 2'd0;
			end
			2'd1: begin
				bready_ARB_TREE = 1'b0;
				error_gnt_o = 1'b1;
				bresp_o = axi_pkg_RESP_DECERR;
				bvalid_o = 1'b1;
				buser_o = error_user_S;
				bid_o = error_id_S;
				if (bready_i)
					NS = 2'd0;
				else
					NS = 2'd1;
			end
			default: begin
				NS = 2'd0;
				error_gnt_o = 1'b0;
			end
		endcase
	end
	generate
		for (_gv_i_17 = 0; _gv_i_17 < N_INIT_PORT; _gv_i_17 = _gv_i_17 + 1) begin : AUX_VECTOR_BINDING
			localparam i = _gv_i_17;
			assign AUX_VECTOR_IN[i * AUX_WIDTH+:AUX_WIDTH] = {buser_i[i * AXI_USER_W+:AXI_USER_W], bresp_i[i * 2+:2]};
		end
		for (_gv_i_17 = 0; _gv_i_17 < N_INIT_PORT; _gv_i_17 = _gv_i_17 + 1) begin : BID_VECTOR_BINDING
			localparam i = _gv_i_17;
			assign bid_int[i * AXI_ID_IN+:AXI_ID_IN] = bid_i[(i * AXI_ID_OUT) + (AXI_ID_IN - 1)-:AXI_ID_IN];
		end
		if (N_INIT_PORT == 1) begin : DIRECT_BINDING
			assign bvalid_ARB_TREE = bvalid_i;
			assign AUX_VECTOR_OUT = AUX_VECTOR_IN;
			assign bid_ARB_TREE = bid_int;
			assign bready_o = bready_i;
		end
		else begin : ARB_TREE
			axi_ArbitrationTree #(
				.AUX_WIDTH(AUX_WIDTH),
				.ID_WIDTH(AXI_ID_IN),
				.N_MASTER(N_INIT_PORT)
			) BW_ARB_TREE(
				.clk(clk),
				.rst_n(rst_n),
				.data_req_i(bvalid_i),
				.data_AUX_i(AUX_VECTOR_IN),
				.data_ID_i(bid_int),
				.data_gnt_o(bready_o),
				.data_req_o(bvalid_ARB_TREE),
				.data_AUX_o(AUX_VECTOR_OUT),
				.data_ID_o(bid_ARB_TREE),
				.data_gnt_i(bready_ARB_TREE),
				.lock(1'b0),
				.SEL_EXCLUSIVE({$clog2(N_INIT_PORT) {1'b0}})
			);
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
module axi_response_block (
	clk,
	rst_n,
	test_en_i,
	rid_i,
	rdata_i,
	rresp_i,
	rlast_i,
	ruser_i,
	rvalid_i,
	rready_o,
	bid_i,
	bresp_i,
	buser_i,
	bvalid_i,
	bready_o,
	rid_o,
	rdata_o,
	rresp_o,
	rlast_o,
	ruser_o,
	rvalid_o,
	rready_i,
	bid_o,
	bresp_o,
	buser_o,
	bvalid_o,
	bready_i,
	arvalid_i,
	araddr_i,
	arready_o,
	arid_i,
	arlen_i,
	aruser_i,
	arvalid_o,
	arready_i,
	awvalid_i,
	awaddr_i,
	awready_o,
	awid_i,
	awuser_i,
	awvalid_o,
	awready_i,
	wvalid_i,
	wlast_i,
	wready_o,
	wvalid_o,
	wready_i,
	START_ADDR_i,
	END_ADDR_i,
	enable_region_i,
	connectivity_map_i
);
	parameter AXI_ADDRESS_W = 32;
	parameter AXI_DATA_W = 64;
	parameter AXI_USER_W = 6;
	parameter N_INIT_PORT = 4;
	parameter N_TARG_PORT = 8;
	parameter FIFO_DEPTH_DW = 8;
	parameter AXI_ID_IN = 16;
	parameter AXI_ID_OUT = AXI_ID_IN + $clog2(N_TARG_PORT);
	parameter N_REGION = 2;
	input wire clk;
	input wire rst_n;
	input wire test_en_i;
	input wire [(N_INIT_PORT * AXI_ID_OUT) - 1:0] rid_i;
	input wire [(N_INIT_PORT * AXI_DATA_W) - 1:0] rdata_i;
	input wire [(N_INIT_PORT * 2) - 1:0] rresp_i;
	input wire [N_INIT_PORT - 1:0] rlast_i;
	input wire [(N_INIT_PORT * AXI_USER_W) - 1:0] ruser_i;
	input wire [N_INIT_PORT - 1:0] rvalid_i;
	output wire [N_INIT_PORT - 1:0] rready_o;
	input wire [(N_INIT_PORT * AXI_ID_OUT) - 1:0] bid_i;
	input wire [(N_INIT_PORT * 2) - 1:0] bresp_i;
	input wire [(N_INIT_PORT * AXI_USER_W) - 1:0] buser_i;
	input wire [N_INIT_PORT - 1:0] bvalid_i;
	output wire [N_INIT_PORT - 1:0] bready_o;
	output wire [AXI_ID_IN - 1:0] rid_o;
	output wire [AXI_DATA_W - 1:0] rdata_o;
	output wire [1:0] rresp_o;
	output wire rlast_o;
	output wire [AXI_USER_W - 1:0] ruser_o;
	output wire rvalid_o;
	input wire rready_i;
	output wire [AXI_ID_IN - 1:0] bid_o;
	output wire [1:0] bresp_o;
	output wire [AXI_USER_W - 1:0] buser_o;
	output wire bvalid_o;
	input wire bready_i;
	input wire arvalid_i;
	input wire [AXI_ADDRESS_W - 1:0] araddr_i;
	output wire arready_o;
	input wire [AXI_ID_IN - 1:0] arid_i;
	input wire [7:0] arlen_i;
	input wire [AXI_USER_W - 1:0] aruser_i;
	output wire [N_INIT_PORT - 1:0] arvalid_o;
	input wire [N_INIT_PORT - 1:0] arready_i;
	input wire awvalid_i;
	input wire [AXI_ADDRESS_W - 1:0] awaddr_i;
	output wire awready_o;
	input wire [AXI_ID_IN - 1:0] awid_i;
	input wire [AXI_USER_W - 1:0] awuser_i;
	output wire [N_INIT_PORT - 1:0] awvalid_o;
	input wire [N_INIT_PORT - 1:0] awready_i;
	input wire wvalid_i;
	input wire wlast_i;
	output wire wready_o;
	output wire [N_INIT_PORT - 1:0] wvalid_o;
	input wire [N_INIT_PORT - 1:0] wready_i;
	input wire [((N_REGION * N_INIT_PORT) * AXI_ADDRESS_W) - 1:0] START_ADDR_i;
	input wire [((N_REGION * N_INIT_PORT) * AXI_ADDRESS_W) - 1:0] END_ADDR_i;
	input wire [(N_REGION * N_INIT_PORT) - 1:0] enable_region_i;
	input wire [N_INIT_PORT - 1:0] connectivity_map_i;
	wire push_DEST_DW;
	wire grant_FIFO_DEST_DW;
	wire [N_INIT_PORT - 1:0] DEST_DW;
	wire incr_ar_req;
	wire full_counter_ar;
	wire outstanding_trans_ar;
	wire error_ar_req;
	wire error_ar_gnt;
	wire incr_aw_req;
	wire full_counter_aw;
	wire outstanding_trans_aw;
	wire handle_error_aw;
	wire wdata_error_completed;
	wire sample_awdata_info;
	wire sample_ardata_info;
	wire error_aw_req;
	wire error_aw_gnt;
	axi_BW_allocator #(
		.AXI_USER_W(AXI_USER_W),
		.N_INIT_PORT(N_INIT_PORT),
		.N_TARG_PORT(N_TARG_PORT),
		.AXI_DATA_W(AXI_DATA_W),
		.AXI_ID_IN(AXI_ID_IN)
	) BW_ALLOC(
		.clk(clk),
		.rst_n(rst_n),
		.bid_i(bid_i),
		.bresp_i(bresp_i),
		.buser_i(buser_i),
		.bvalid_i(bvalid_i),
		.bready_o(bready_o),
		.bid_o(bid_o),
		.bresp_o(bresp_o),
		.buser_o(buser_o),
		.bvalid_o(bvalid_o),
		.bready_i(bready_i),
		.incr_req_i(incr_aw_req),
		.full_counter_o(full_counter_aw),
		.outstanding_trans_o(outstanding_trans_aw),
		.sample_awdata_info_i(sample_awdata_info),
		.error_req_i(error_aw_req),
		.error_gnt_o(error_aw_gnt),
		.error_user_i(awuser_i),
		.error_id_i(awid_i)
	);
	axi_BR_allocator #(
		.AXI_USER_W(AXI_USER_W),
		.N_INIT_PORT(N_INIT_PORT),
		.N_TARG_PORT(N_TARG_PORT),
		.AXI_DATA_W(AXI_DATA_W),
		.AXI_ID_IN(AXI_ID_IN)
	) BR_ALLOC(
		.clk(clk),
		.rst_n(rst_n),
		.rid_i(rid_i),
		.rdata_i(rdata_i),
		.rresp_i(rresp_i),
		.rlast_i(rlast_i),
		.ruser_i(ruser_i),
		.rvalid_i(rvalid_i),
		.rready_o(rready_o),
		.rid_o(rid_o),
		.rdata_o(rdata_o),
		.rresp_o(rresp_o),
		.rlast_o(rlast_o),
		.ruser_o(ruser_o),
		.rvalid_o(rvalid_o),
		.rready_i(rready_i),
		.incr_req_i(incr_ar_req),
		.full_counter_o(full_counter_ar),
		.outstanding_trans_o(outstanding_trans_ar),
		.error_req_i(error_ar_req),
		.error_gnt_o(error_ar_gnt),
		.error_len_i(arlen_i),
		.error_user_i(aruser_i),
		.error_id_i(arid_i),
		.sample_ardata_info_i(sample_ardata_info)
	);
	axi_address_decoder_AR #(
		.ADDR_WIDTH(AXI_ADDRESS_W),
		.N_INIT_PORT(N_INIT_PORT),
		.N_REGION(N_REGION)
	) AR_ADDR_DEC(
		.clk(clk),
		.rst_n(rst_n),
		.arvalid_i(arvalid_i),
		.araddr_i(araddr_i),
		.arready_o(arready_o),
		.arvalid_o(arvalid_o),
		.arready_i(arready_i),
		.START_ADDR_i(START_ADDR_i),
		.END_ADDR_i(END_ADDR_i),
		.enable_region_i(enable_region_i),
		.connectivity_map_i(connectivity_map_i),
		.incr_req_o(incr_ar_req),
		.full_counter_i(full_counter_ar),
		.outstanding_trans_i(outstanding_trans_ar),
		.error_req_o(error_ar_req),
		.error_gnt_i(error_ar_gnt),
		.sample_ardata_info_o(sample_ardata_info)
	);
	axi_address_decoder_AW #(
		.ADDR_WIDTH(AXI_ADDRESS_W),
		.N_INIT_PORT(N_INIT_PORT),
		.N_REGION(N_REGION)
	) AW_ADDR_DEC(
		.clk(clk),
		.rst_n(rst_n),
		.awvalid_i(awvalid_i),
		.awaddr_i(awaddr_i),
		.awready_o(awready_o),
		.awvalid_o(awvalid_o),
		.awready_i(awready_i),
		.grant_FIFO_DEST_i(grant_FIFO_DEST_DW),
		.DEST_o(DEST_DW),
		.push_DEST_o(push_DEST_DW),
		.START_ADDR_i(START_ADDR_i),
		.END_ADDR_i(END_ADDR_i),
		.enable_region_i(enable_region_i),
		.connectivity_map_i(connectivity_map_i),
		.incr_req_o(incr_aw_req),
		.full_counter_i(full_counter_aw),
		.outstanding_trans_i(outstanding_trans_aw),
		.error_req_o(error_aw_req),
		.error_gnt_i(error_aw_gnt),
		.handle_error_o(handle_error_aw),
		.wdata_error_completed_i(wdata_error_completed),
		.sample_awdata_info_o(sample_awdata_info)
	);
	axi_address_decoder_DW #(
		.N_INIT_PORT(N_INIT_PORT),
		.FIFO_DEPTH(FIFO_DEPTH_DW)
	) DW_ADDR_DEC(
		.clk(clk),
		.rst_n(rst_n),
		.test_en_i(test_en_i),
		.wvalid_i(wvalid_i),
		.wlast_i(wlast_i),
		.wready_o(wready_o),
		.wvalid_o(wvalid_o),
		.wready_i(wready_i),
		.grant_FIFO_DEST_o(grant_FIFO_DEST_DW),
		.DEST_i(DEST_DW),
		.push_DEST_i(push_DEST_DW),
		.handle_error_i(handle_error_aw),
		.wdata_error_completed_o(wdata_error_completed)
	);
endmodule
module axi_BR_allocator (
	clk,
	rst_n,
	rid_i,
	rdata_i,
	rresp_i,
	rlast_i,
	ruser_i,
	rvalid_i,
	rready_o,
	rid_o,
	rdata_o,
	rresp_o,
	rlast_o,
	ruser_o,
	rvalid_o,
	rready_i,
	incr_req_i,
	full_counter_o,
	outstanding_trans_o,
	error_req_i,
	error_gnt_o,
	error_len_i,
	error_user_i,
	error_id_i,
	sample_ardata_info_i
);
	reg _sv2v_0;
	parameter AXI_USER_W = 6;
	parameter N_INIT_PORT = 1;
	parameter N_TARG_PORT = 7;
	parameter AXI_DATA_W = 64;
	parameter AXI_ID_IN = 16;
	parameter LOG_N_TARG = $clog2(N_TARG_PORT);
	parameter LOG_N_INIT = $clog2(N_INIT_PORT);
	parameter AXI_ID_OUT = AXI_ID_IN + $clog2(N_TARG_PORT);
	input wire clk;
	input wire rst_n;
	input wire [(N_INIT_PORT * AXI_ID_OUT) - 1:0] rid_i;
	input wire [(N_INIT_PORT * AXI_DATA_W) - 1:0] rdata_i;
	input wire [(N_INIT_PORT * 2) - 1:0] rresp_i;
	input wire [N_INIT_PORT - 1:0] rlast_i;
	input wire [(N_INIT_PORT * AXI_USER_W) - 1:0] ruser_i;
	input wire [N_INIT_PORT - 1:0] rvalid_i;
	output wire [N_INIT_PORT - 1:0] rready_o;
	output reg [AXI_ID_IN - 1:0] rid_o;
	output reg [AXI_DATA_W - 1:0] rdata_o;
	output reg [1:0] rresp_o;
	output reg rlast_o;
	output reg [AXI_USER_W - 1:0] ruser_o;
	output reg rvalid_o;
	input wire rready_i;
	input wire incr_req_i;
	output wire full_counter_o;
	output wire outstanding_trans_o;
	input wire error_req_i;
	output reg error_gnt_o;
	input wire [7:0] error_len_i;
	input wire [AXI_USER_W - 1:0] error_user_i;
	input wire [AXI_ID_IN - 1:0] error_id_i;
	input wire sample_ardata_info_i;
	localparam AUX_WIDTH = (AXI_DATA_W + 3) + AXI_USER_W;
	wire [(N_INIT_PORT * AUX_WIDTH) - 1:0] AUX_VECTOR_IN;
	wire [AUX_WIDTH - 1:0] AUX_VECTOR_OUT;
	wire [(N_INIT_PORT * AXI_ID_IN) - 1:0] rid_int;
	genvar _gv_i_18;
	reg [9:0] outstanding_counter;
	wire decr_req;
	reg [1:0] CS;
	reg [1:0] NS;
	reg [7:0] CounterBurstCS;
	reg [7:0] CounterBurstNS;
	reg [7:0] error_len_S;
	reg [AXI_USER_W - 1:0] error_user_S;
	reg [AXI_ID_IN - 1:0] error_id_S;
	wire [AXI_ID_IN - 1:0] rid_ARB_TREE;
	wire [AXI_DATA_W - 1:0] rdata_ARB_TREE;
	wire [1:0] rresp_ARB_TREE;
	wire rlast_ARB_TREE;
	wire [AXI_USER_W - 1:0] ruser_ARB_TREE;
	wire rvalid_ARB_TREE;
	reg rready_ARB_TREE;
	assign outstanding_trans_o = (outstanding_counter == {10 {1'sb0}} ? 1'b0 : 1'b1);
	assign decr_req = (rvalid_ARB_TREE & rready_ARB_TREE) & rlast_ARB_TREE;
	assign full_counter_o = (outstanding_counter == {10 {1'sb1}} ? 1'b1 : 1'b0);
	always @(posedge clk or negedge rst_n)
		if (rst_n == 1'b0)
			outstanding_counter <= 1'sb0;
		else
			case ({incr_req_i, decr_req})
				2'b00: outstanding_counter <= outstanding_counter;
				2'b01:
					if (outstanding_counter != {10 {1'sb0}})
						outstanding_counter <= outstanding_counter - 1'b1;
					else
						outstanding_counter <= 1'sb0;
				2'b10:
					if (outstanding_counter != {10 {1'sb1}})
						outstanding_counter <= outstanding_counter + 1'b1;
					else
						outstanding_counter <= 1'sb1;
				2'b11: outstanding_counter <= outstanding_counter;
			endcase
	always @(posedge clk or negedge rst_n)
		if (rst_n == 1'b0) begin
			CS <= 2'd0;
			CounterBurstCS <= 1'sb0;
			error_user_S <= 1'sb0;
			error_id_S <= 1'sb0;
			error_len_S <= 1'sb0;
		end
		else begin
			CS <= NS;
			CounterBurstCS <= CounterBurstNS;
			if (sample_ardata_info_i) begin
				error_user_S <= error_user_i;
				error_id_S <= error_id_i;
				error_len_S <= error_len_i;
			end
		end
	localparam axi_pkg_RESP_DECERR = 2'b11;
	always @(*) begin
		if (_sv2v_0)
			;
		rid_o = rid_ARB_TREE;
		rdata_o = rdata_ARB_TREE;
		rresp_o = rresp_ARB_TREE;
		rlast_o = rlast_ARB_TREE;
		ruser_o = ruser_ARB_TREE;
		rvalid_o = rvalid_ARB_TREE;
		rready_ARB_TREE = rready_i;
		CounterBurstNS = CounterBurstCS;
		error_gnt_o = 1'b0;
		case (CS)
			2'd0: begin
				CounterBurstNS = 1'sb0;
				rready_ARB_TREE = rready_i;
				error_gnt_o = 1'b0;
				if (error_req_i == 1'b1) begin
					if (outstanding_trans_o == 1'b0) begin
						if (error_len_i == {8 {1'sb0}})
							NS = 2'd1;
						else
							NS = 2'd2;
					end
					else
						NS = 2'd3;
				end
				else
					NS = 2'd0;
			end
			2'd3: begin
				CounterBurstNS = 1'sb0;
				rready_ARB_TREE = rready_i;
				error_gnt_o = 1'b0;
				if (outstanding_trans_o == 1'b0) begin
					if (error_len_S == {8 {1'sb0}})
						NS = 2'd1;
					else
						NS = 2'd2;
				end
				else
					NS = 2'd3;
			end
			2'd1: begin
				rready_ARB_TREE = 1'b0;
				CounterBurstNS = 1'sb0;
				error_gnt_o = 1'b1;
				rresp_o = axi_pkg_RESP_DECERR;
				rdata_o = {AXI_DATA_W / 32 {32'hdeadbeef}};
				rvalid_o = 1'b1;
				ruser_o = error_user_S;
				rlast_o = 1'b1;
				rid_o = error_id_S;
				if (rready_i)
					NS = 2'd0;
				else
					NS = 2'd1;
			end
			2'd2: begin
				rready_ARB_TREE = 1'b0;
				rresp_o = axi_pkg_RESP_DECERR;
				rdata_o = {AXI_DATA_W / 32 {32'hdeadbeef}};
				rvalid_o = 1'b1;
				ruser_o = error_user_S;
				rid_o = error_id_S;
				if (rready_i) begin
					if (CounterBurstCS < error_len_i) begin
						CounterBurstNS = CounterBurstCS + 1'b1;
						error_gnt_o = 1'b0;
						rlast_o = 1'b0;
						NS = 2'd2;
					end
					else begin
						error_gnt_o = 1'b1;
						CounterBurstNS = 1'sb0;
						NS = 2'd0;
						rlast_o = 1'b1;
					end
				end
				else begin
					NS = 2'd2;
					error_gnt_o = 1'b0;
				end
			end
			default: begin
				CounterBurstNS = 1'sb0;
				NS = 2'd0;
				error_gnt_o = 1'b0;
			end
		endcase
	end
	assign {ruser_ARB_TREE, rlast_ARB_TREE, rresp_ARB_TREE, rdata_ARB_TREE} = AUX_VECTOR_OUT;
	generate
		for (_gv_i_18 = 0; _gv_i_18 < N_INIT_PORT; _gv_i_18 = _gv_i_18 + 1) begin : AUX_VECTOR_BINDING
			localparam i = _gv_i_18;
			assign AUX_VECTOR_IN[i * AUX_WIDTH+:AUX_WIDTH] = {ruser_i[i * AXI_USER_W+:AXI_USER_W], rlast_i[i], rresp_i[i * 2+:2], rdata_i[i * AXI_DATA_W+:AXI_DATA_W]};
		end
		for (_gv_i_18 = 0; _gv_i_18 < N_INIT_PORT; _gv_i_18 = _gv_i_18 + 1) begin : RID_VECTOR_BINDING
			localparam i = _gv_i_18;
			assign rid_int[i * AXI_ID_IN+:AXI_ID_IN] = rid_i[(i * AXI_ID_OUT) + (AXI_ID_IN - 1)-:AXI_ID_IN];
		end
		if (N_INIT_PORT == 1) begin : DIRECT_BINDING
			assign rvalid_ARB_TREE = rvalid_i;
			assign AUX_VECTOR_OUT = AUX_VECTOR_IN;
			assign rid_ARB_TREE = rid_int;
			assign rready_o = rready_i;
		end
		else begin : ARB_TREE
			axi_ArbitrationTree #(
				.AUX_WIDTH(AUX_WIDTH),
				.ID_WIDTH(AXI_ID_IN),
				.N_MASTER(N_INIT_PORT)
			) BR_ARB_TREE(
				.clk(clk),
				.rst_n(rst_n),
				.data_req_i(rvalid_i),
				.data_AUX_i(AUX_VECTOR_IN),
				.data_ID_i(rid_int),
				.data_gnt_o(rready_o),
				.data_req_o(rvalid_ARB_TREE),
				.data_AUX_o(AUX_VECTOR_OUT),
				.data_ID_o(rid_ARB_TREE),
				.data_gnt_i(rready_ARB_TREE),
				.lock(1'b0),
				.SEL_EXCLUSIVE({$clog2(N_INIT_PORT) {1'b0}})
			);
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
module axi_address_decoder_AR (
	clk,
	rst_n,
	arvalid_i,
	araddr_i,
	arready_o,
	arvalid_o,
	arready_i,
	START_ADDR_i,
	END_ADDR_i,
	enable_region_i,
	connectivity_map_i,
	incr_req_o,
	full_counter_i,
	outstanding_trans_i,
	error_req_o,
	error_gnt_i,
	sample_ardata_info_o
);
	reg _sv2v_0;
	parameter ADDR_WIDTH = 32;
	parameter N_INIT_PORT = 8;
	parameter N_REGION = 4;
	input wire clk;
	input wire rst_n;
	input wire arvalid_i;
	input wire [ADDR_WIDTH - 1:0] araddr_i;
	output reg arready_o;
	output reg [N_INIT_PORT - 1:0] arvalid_o;
	input wire [N_INIT_PORT - 1:0] arready_i;
	input wire [((N_REGION * N_INIT_PORT) * ADDR_WIDTH) - 1:0] START_ADDR_i;
	input wire [((N_REGION * N_INIT_PORT) * ADDR_WIDTH) - 1:0] END_ADDR_i;
	input wire [(N_REGION * N_INIT_PORT) - 1:0] enable_region_i;
	input wire [N_INIT_PORT - 1:0] connectivity_map_i;
	output reg incr_req_o;
	input wire full_counter_i;
	input wire outstanding_trans_i;
	output reg error_req_o;
	input wire error_gnt_i;
	output reg sample_ardata_info_o;
	wire [N_INIT_PORT - 1:0] match_region;
	wire [N_INIT_PORT:0] match_region_masked;
	wire [(N_REGION * N_INIT_PORT) - 1:0] match_region_int;
	wire [(N_INIT_PORT * N_REGION) - 1:0] match_region_rev;
	reg arready_int;
	reg [N_INIT_PORT - 1:0] arvalid_int;
	genvar _gv_i_19;
	genvar _gv_j_9;
	reg CS;
	reg NS;
	generate
		for (_gv_j_9 = 0; _gv_j_9 < N_REGION; _gv_j_9 = _gv_j_9 + 1) begin : genblk1
			localparam j = _gv_j_9;
			for (_gv_i_19 = 0; _gv_i_19 < N_INIT_PORT; _gv_i_19 = _gv_i_19 + 1) begin : genblk1
				localparam i = _gv_i_19;
				assign match_region_int[(j * N_INIT_PORT) + i] = (enable_region_i[(j * N_INIT_PORT) + i] == 1'b1 ? (araddr_i >= START_ADDR_i[((j * N_INIT_PORT) + i) * ADDR_WIDTH+:ADDR_WIDTH]) && (araddr_i <= END_ADDR_i[((j * N_INIT_PORT) + i) * ADDR_WIDTH+:ADDR_WIDTH]) : 1'b0);
			end
		end
		for (_gv_j_9 = 0; _gv_j_9 < N_INIT_PORT; _gv_j_9 = _gv_j_9 + 1) begin : genblk2
			localparam j = _gv_j_9;
			for (_gv_i_19 = 0; _gv_i_19 < N_REGION; _gv_i_19 = _gv_i_19 + 1) begin : genblk1
				localparam i = _gv_i_19;
				assign match_region_rev[(j * N_REGION) + i] = match_region_int[(i * N_INIT_PORT) + j];
			end
		end
		for (_gv_i_19 = 0; _gv_i_19 < N_INIT_PORT; _gv_i_19 = _gv_i_19 + 1) begin : genblk3
			localparam i = _gv_i_19;
			assign match_region[i] = |match_region_rev[i * N_REGION+:N_REGION];
		end
	endgenerate
	assign match_region_masked[N_INIT_PORT - 1:0] = match_region & connectivity_map_i;
	assign match_region_masked[N_INIT_PORT] = ~(|match_region_masked[N_INIT_PORT - 1:0]);
	always @(*) begin
		if (_sv2v_0)
			;
		if (arvalid_i)
			{error_req_o, arvalid_int} = {N_INIT_PORT + 1 {arvalid_i}} & match_region_masked;
		else begin
			arvalid_int = 1'sb0;
			error_req_o = 1'b0;
		end
		arready_int = |({error_gnt_i, arready_i} & match_region_masked);
	end
	always @(posedge clk or negedge rst_n)
		if (rst_n == 1'b0)
			CS <= 1'd0;
		else
			CS <= NS;
	always @(*) begin
		if (_sv2v_0)
			;
		arready_o = 1'b0;
		arvalid_o = arvalid_int;
		sample_ardata_info_o = 1'b0;
		incr_req_o = 1'b0;
		case (CS)
			1'd0:
				if (error_req_o) begin
					NS = 1'd1;
					arready_o = 1'b1;
					sample_ardata_info_o = 1'b1;
					arvalid_o = 1'sb0;
				end
				else begin
					NS = 1'd0;
					arready_o = arready_int;
					sample_ardata_info_o = 1'b0;
					incr_req_o = |(arvalid_o & arready_i);
					arvalid_o = arvalid_int;
				end
			1'd1: begin
				arready_o = 1'b0;
				arvalid_o = 1'sb0;
				if (outstanding_trans_i)
					NS = 1'd1;
				else if (error_gnt_i)
					NS = 1'd0;
				else
					NS = 1'd1;
			end
			default: begin
				NS = 1'd0;
				arready_o = arready_int;
			end
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module axi_address_decoder_AW (
	clk,
	rst_n,
	awvalid_i,
	awaddr_i,
	awready_o,
	awvalid_o,
	awready_i,
	grant_FIFO_DEST_i,
	DEST_o,
	push_DEST_o,
	START_ADDR_i,
	END_ADDR_i,
	enable_region_i,
	connectivity_map_i,
	incr_req_o,
	full_counter_i,
	outstanding_trans_i,
	error_req_o,
	error_gnt_i,
	handle_error_o,
	wdata_error_completed_i,
	sample_awdata_info_o
);
	reg _sv2v_0;
	parameter ADDR_WIDTH = 32;
	parameter N_INIT_PORT = 8;
	parameter N_REGION = 2;
	input wire clk;
	input wire rst_n;
	input wire awvalid_i;
	input wire [ADDR_WIDTH - 1:0] awaddr_i;
	output reg awready_o;
	output reg [N_INIT_PORT - 1:0] awvalid_o;
	input wire [N_INIT_PORT - 1:0] awready_i;
	input wire grant_FIFO_DEST_i;
	output wire [N_INIT_PORT - 1:0] DEST_o;
	output wire push_DEST_o;
	input wire [((N_REGION * N_INIT_PORT) * ADDR_WIDTH) - 1:0] START_ADDR_i;
	input wire [((N_REGION * N_INIT_PORT) * ADDR_WIDTH) - 1:0] END_ADDR_i;
	input wire [(N_REGION * N_INIT_PORT) - 1:0] enable_region_i;
	input wire [N_INIT_PORT - 1:0] connectivity_map_i;
	output reg incr_req_o;
	input wire full_counter_i;
	input wire outstanding_trans_i;
	output reg error_req_o;
	input wire error_gnt_i;
	output reg handle_error_o;
	input wire wdata_error_completed_i;
	output reg sample_awdata_info_o;
	wire [N_INIT_PORT - 1:0] match_region;
	wire [N_INIT_PORT:0] match_region_masked;
	wire [(N_REGION * N_INIT_PORT) - 1:0] match_region_int;
	wire [(N_INIT_PORT * N_REGION) - 1:0] match_region_rev;
	reg awready_int;
	reg [N_INIT_PORT - 1:0] awvalid_int;
	reg error_detected;
	wire local_increm;
	genvar _gv_i_20;
	genvar _gv_j_10;
	assign DEST_o = match_region[N_INIT_PORT - 1:0];
	assign push_DEST_o = |(awvalid_i & awready_o) & ~error_detected;
	reg [1:0] CS;
	reg [1:0] NS;
	generate
		for (_gv_j_10 = 0; _gv_j_10 < N_REGION; _gv_j_10 = _gv_j_10 + 1) begin : genblk1
			localparam j = _gv_j_10;
			for (_gv_i_20 = 0; _gv_i_20 < N_INIT_PORT; _gv_i_20 = _gv_i_20 + 1) begin : genblk1
				localparam i = _gv_i_20;
				assign match_region_int[(j * N_INIT_PORT) + i] = (enable_region_i[(j * N_INIT_PORT) + i] == 1'b1 ? (awaddr_i >= START_ADDR_i[((j * N_INIT_PORT) + i) * ADDR_WIDTH+:ADDR_WIDTH]) && (awaddr_i <= END_ADDR_i[((j * N_INIT_PORT) + i) * ADDR_WIDTH+:ADDR_WIDTH]) : 1'b0);
			end
		end
		for (_gv_j_10 = 0; _gv_j_10 < N_INIT_PORT; _gv_j_10 = _gv_j_10 + 1) begin : genblk2
			localparam j = _gv_j_10;
			for (_gv_i_20 = 0; _gv_i_20 < N_REGION; _gv_i_20 = _gv_i_20 + 1) begin : genblk1
				localparam i = _gv_i_20;
				assign match_region_rev[(j * N_REGION) + i] = match_region_int[(i * N_INIT_PORT) + j];
			end
		end
		for (_gv_i_20 = 0; _gv_i_20 < N_INIT_PORT; _gv_i_20 = _gv_i_20 + 1) begin : genblk3
			localparam i = _gv_i_20;
			assign match_region[i] = |match_region_rev[i * N_REGION+:N_REGION];
		end
	endgenerate
	assign match_region_masked[N_INIT_PORT - 1:0] = match_region & connectivity_map_i;
	assign match_region_masked[N_INIT_PORT] = ~(|match_region_masked[N_INIT_PORT - 1:0]);
	always @(*) begin
		if (_sv2v_0)
			;
		if (grant_FIFO_DEST_i == 1'b1) begin
			if (awvalid_i)
				{error_detected, awvalid_int} = {N_INIT_PORT + 1 {awvalid_i}} & match_region_masked;
			else begin
				awvalid_int = 1'sb0;
				error_detected = 1'b0;
			end
			awready_int = |({error_gnt_i, awready_i} & match_region_masked);
		end
		else begin
			awvalid_int = 1'sb0;
			awready_int = 1'b0;
			error_detected = 1'b0;
		end
	end
	always @(posedge clk or negedge rst_n)
		if (rst_n == 1'b0)
			CS <= 2'd0;
		else
			CS <= NS;
	assign local_increm = |(awvalid_o & awready_i);
	always @(*) begin
		if (_sv2v_0)
			;
		awready_o = 1'b0;
		handle_error_o = 1'b0;
		sample_awdata_info_o = 1'b0;
		error_req_o = 1'b0;
		incr_req_o = 1'b0;
		awvalid_o = 1'sb0;
		case (CS)
			2'd0: begin
				handle_error_o = 1'b0;
				incr_req_o = local_increm;
				if (error_detected) begin
					NS = 2'd1;
					awready_o = 1'b1;
					sample_awdata_info_o = 1'b1;
					awvalid_o = 1'sb0;
				end
				else begin
					NS = 2'd0;
					awready_o = awready_int;
					awvalid_o = awvalid_int;
				end
			end
			2'd1: begin
				awready_o = 1'b0;
				handle_error_o = 1'b0;
				if (outstanding_trans_i) begin
					NS = 2'd1;
					awready_o = 1'b0;
				end
				else begin
					awready_o = 1'b0;
					NS = 2'd2;
				end
			end
			2'd2: begin
				awready_o = 1'b0;
				handle_error_o = 1'b1;
				if (wdata_error_completed_i)
					NS = 2'd3;
				else
					NS = 2'd2;
			end
			2'd3: begin
				handle_error_o = 1'b0;
				error_req_o = 1'b1;
				if (error_gnt_i)
					NS = 2'd0;
				else
					NS = 2'd3;
			end
			default: begin
				NS = 2'd0;
				awready_o = awready_int;
				handle_error_o = 1'b0;
			end
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module axi_address_decoder_DW (
	clk,
	rst_n,
	test_en_i,
	wvalid_i,
	wlast_i,
	wready_o,
	wvalid_o,
	wready_i,
	grant_FIFO_DEST_o,
	DEST_i,
	push_DEST_i,
	handle_error_i,
	wdata_error_completed_o
);
	reg _sv2v_0;
	parameter N_INIT_PORT = 4;
	parameter FIFO_DEPTH = 8;
	input wire clk;
	input wire rst_n;
	input wire test_en_i;
	input wire wvalid_i;
	input wire wlast_i;
	output reg wready_o;
	output reg [N_INIT_PORT - 1:0] wvalid_o;
	input wire [N_INIT_PORT - 1:0] wready_i;
	output wire grant_FIFO_DEST_o;
	input wire [N_INIT_PORT - 1:0] DEST_i;
	input wire push_DEST_i;
	input wire handle_error_i;
	output reg wdata_error_completed_o;
	wire valid_DEST;
	wire pop_from_DEST_FIFO;
	wire [N_INIT_PORT - 1:0] DEST_int;
	wire empty;
	wire full;
	fifo_v2 #(
		.FALL_THROUGH(1'b0),
		.DATA_WIDTH(N_INIT_PORT),
		.DEPTH(FIFO_DEPTH)
	) MASTER_ID_FIFO(
		.clk_i(clk),
		.rst_ni(rst_n),
		.testmode_i(test_en_i),
		.flush_i(1'b0),
		.alm_empty_o(),
		.alm_full_o(),
		.data_i(DEST_i),
		.push_i(push_DEST_i),
		.full_o(full),
		.data_o(DEST_int),
		.empty_o(empty),
		.pop_i(pop_from_DEST_FIFO)
	);
	assign grant_FIFO_DEST_o = ~full;
	assign valid_DEST = ~empty;
	assign pop_from_DEST_FIFO = ((wlast_i & wvalid_i) & wready_o) & valid_DEST;
	always @(*) begin
		if (_sv2v_0)
			;
		if (handle_error_i) begin
			wready_o = 1'b1;
			wvalid_o = 1'sb0;
			wdata_error_completed_o = wlast_i & wvalid_i;
		end
		else begin
			wready_o = |(wready_i & DEST_int);
			wdata_error_completed_o = 1'b0;
			if (wvalid_i & valid_DEST)
				wvalid_o = {N_INIT_PORT {wvalid_i}} & DEST_int;
			else
				wvalid_o = 1'sb0;
		end
	end
	initial _sv2v_0 = 0;
endmodule
module axi_FanInPrimitive_Req (
	RR_FLAG,
	data_AUX0_i,
	data_AUX1_i,
	data_req0_i,
	data_req1_i,
	data_ID0_i,
	data_ID1_i,
	data_gnt0_o,
	data_gnt1_o,
	data_AUX_o,
	data_req_o,
	data_ID_o,
	data_gnt_i,
	lock_EXCLUSIVE,
	SEL_EXCLUSIVE
);
	reg _sv2v_0;
	parameter AUX_WIDTH = 32;
	parameter ID_WIDTH = 16;
	input wire RR_FLAG;
	input wire [AUX_WIDTH - 1:0] data_AUX0_i;
	input wire [AUX_WIDTH - 1:0] data_AUX1_i;
	input wire data_req0_i;
	input wire data_req1_i;
	input wire [ID_WIDTH - 1:0] data_ID0_i;
	input wire [ID_WIDTH - 1:0] data_ID1_i;
	output reg data_gnt0_o;
	output reg data_gnt1_o;
	output reg [AUX_WIDTH - 1:0] data_AUX_o;
	output reg data_req_o;
	output reg [ID_WIDTH - 1:0] data_ID_o;
	input wire data_gnt_i;
	input wire lock_EXCLUSIVE;
	input wire SEL_EXCLUSIVE;
	reg SEL;
	always @(*) begin
		if (_sv2v_0)
			;
		if (lock_EXCLUSIVE) begin
			data_req_o = (SEL_EXCLUSIVE ? data_req1_i : data_req0_i);
			data_gnt0_o = (SEL_EXCLUSIVE ? 1'b0 : data_gnt_i);
			data_gnt1_o = (SEL_EXCLUSIVE ? data_gnt_i : 1'b0);
			SEL = SEL_EXCLUSIVE;
		end
		else begin
			data_req_o = data_req0_i | data_req1_i;
			data_gnt0_o = ((data_req0_i & ~data_req1_i) | (data_req0_i & ~RR_FLAG)) & data_gnt_i;
			data_gnt1_o = ((~data_req0_i & data_req1_i) | (data_req1_i & RR_FLAG)) & data_gnt_i;
			SEL = ~data_req0_i | (RR_FLAG & data_req1_i);
		end
	end
	always @(*) begin : FanIn_MUX2
		if (_sv2v_0)
			;
		case (SEL)
			1'b0: begin
				data_AUX_o = data_AUX0_i;
				data_ID_o = data_ID0_i;
			end
			1'b1: begin
				data_AUX_o = data_AUX1_i;
				data_ID_o = data_ID1_i;
			end
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module formal_top;
	wire clk_i;
	wire rst_ni;
	wire [63:0] boot_addr_i;
	wire [63:0] hart_id_i;
	wire [1:0] irq_i;
	wire ipi_i;
	wire time_irq_i;
	wire debug_req_i;
	wire [1:0] priv_lvl_o;
	wire umode_i;
	wire testmode_i;
	wire [31:0] jtag_key;
	wire dmi_rst_no;
	wire [40:0] dmi_req_o;
	wire dmi_req_valid_o;
	wire dmi_req_ready_i;
	wire [33:0] dmi_resp_i;
	wire dmi_resp_ready_o;
	wire dmi_resp_valid_i;
	wire tck_i;
	wire tms_i;
	wire trst_ni;
	wire td_i;
	wire td_o;
	wire tdo_oe_o;
	wire umode_o;
	wire test_en_i;
	wire [7:0] priv_lvl_i;
	wire [511:0] access_ctrl_i;
	wire [255:0] start_addr_i;
	wire [255:0] end_addr_i;
	wire [127:0] l15_req_o;
	wire [127:0] l15_rtrn_i;
	localparam _param_FDDF6_AXI_ADDR_WIDTH = 32;
	localparam _param_FDDF6_AXI_DATA_WIDTH = 32;
	localparam _param_FDDF6_AXI_ID_WIDTH = 10;
	localparam _param_FDDF6_AXI_USER_WIDTH = 0;
	genvar _arr_FDDF6;
	generate
		for (_arr_FDDF6 = 7; _arr_FDDF6 >= 0; _arr_FDDF6 = _arr_FDDF6 - 1) begin : subordinate
			localparam AXI_ADDR_WIDTH = _param_FDDF6_AXI_ADDR_WIDTH;
			localparam AXI_DATA_WIDTH = _param_FDDF6_AXI_DATA_WIDTH;
			localparam AXI_ID_WIDTH = _param_FDDF6_AXI_ID_WIDTH;
			localparam AXI_USER_WIDTH = _param_FDDF6_AXI_USER_WIDTH;
			localparam AXI_STRB_WIDTH = 4;
			wire [9:0] aw_id;
			wire [31:0] aw_addr;
			wire [7:0] aw_len;
			wire [2:0] aw_size;
			wire [1:0] aw_burst;
			wire aw_lock;
			wire [3:0] aw_cache;
			wire [2:0] aw_prot;
			wire [3:0] aw_qos;
			wire [3:0] aw_region;
			wire [_param_FDDF6_AXI_USER_WIDTH - 1:0] aw_user;
			wire aw_valid;
			wire aw_ready;
			wire [31:0] w_data;
			wire [3:0] w_strb;
			wire w_last;
			wire [_param_FDDF6_AXI_USER_WIDTH - 1:0] w_user;
			wire w_valid;
			wire w_ready;
			wire [9:0] b_id;
			wire [1:0] b_resp;
			wire [_param_FDDF6_AXI_USER_WIDTH - 1:0] b_user;
			wire b_valid;
			wire b_ready;
			wire [9:0] ar_id;
			wire [31:0] ar_addr;
			wire [7:0] ar_len;
			wire [2:0] ar_size;
			wire [1:0] ar_burst;
			wire ar_lock;
			wire [3:0] ar_cache;
			wire [2:0] ar_prot;
			wire [3:0] ar_qos;
			wire [3:0] ar_region;
			wire [_param_FDDF6_AXI_USER_WIDTH - 1:0] ar_user;
			wire ar_valid;
			wire ar_ready;
			wire [9:0] r_id;
			wire [31:0] r_data;
			wire [1:0] r_resp;
			wire r_last;
			wire [_param_FDDF6_AXI_USER_WIDTH - 1:0] r_user;
			wire r_valid;
			wire r_ready;
		end
	endgenerate
	localparam _param_0084D_AXI_ADDR_WIDTH = 32;
	localparam _param_0084D_AXI_DATA_WIDTH = 32;
	localparam _param_0084D_AXI_ID_WIDTH = 10;
	localparam _param_0084D_AXI_USER_WIDTH = 0;
	genvar _arr_0084D;
	generate
		for (_arr_0084D = 7; _arr_0084D >= 0; _arr_0084D = _arr_0084D - 1) begin : primary
			localparam AXI_ADDR_WIDTH = _param_0084D_AXI_ADDR_WIDTH;
			localparam AXI_DATA_WIDTH = _param_0084D_AXI_DATA_WIDTH;
			localparam AXI_ID_WIDTH = _param_0084D_AXI_ID_WIDTH;
			localparam AXI_USER_WIDTH = _param_0084D_AXI_USER_WIDTH;
			localparam AXI_STRB_WIDTH = 4;
			wire [9:0] aw_id;
			wire [31:0] aw_addr;
			wire [7:0] aw_len;
			wire [2:0] aw_size;
			wire [1:0] aw_burst;
			wire aw_lock;
			wire [3:0] aw_cache;
			wire [2:0] aw_prot;
			wire [3:0] aw_qos;
			wire [3:0] aw_region;
			wire [_param_0084D_AXI_USER_WIDTH - 1:0] aw_user;
			wire aw_valid;
			wire aw_ready;
			wire [31:0] w_data;
			wire [3:0] w_strb;
			wire w_last;
			wire [_param_0084D_AXI_USER_WIDTH - 1:0] w_user;
			wire w_valid;
			wire w_ready;
			wire [9:0] b_id;
			wire [1:0] b_resp;
			wire [_param_0084D_AXI_USER_WIDTH - 1:0] b_user;
			wire b_valid;
			wire b_ready;
			wire [9:0] ar_id;
			wire [31:0] ar_addr;
			wire [7:0] ar_len;
			wire [2:0] ar_size;
			wire [1:0] ar_burst;
			wire ar_lock;
			wire [3:0] ar_cache;
			wire [2:0] ar_prot;
			wire [3:0] ar_qos;
			wire [3:0] ar_region;
			wire [_param_0084D_AXI_USER_WIDTH - 1:0] ar_user;
			wire ar_valid;
			wire ar_ready;
			wire [9:0] r_id;
			wire [31:0] r_data;
			wire [1:0] r_resp;
			wire r_last;
			wire [_param_0084D_AXI_USER_WIDTH - 1:0] r_user;
			wire r_valid;
			wire r_ready;
		end
	endgenerate
	localparam _bbase_25D66_subordinate = 0;
	localparam _bbase_25D66_primary = 0;
	generate
		if (1) begin : dut
			localparam NB_MANAGER = 8;
			localparam NB_SUBORDINATE = 8;
			localparam NB_PRIV_LVL = 8;
			localparam PRIV_LVL_WIDTH = 8;
			localparam AXI_ADDR_WIDTH = 32;
			localparam AXI_DATA_WIDTH = 32;
			localparam AXI_ID_WIDTH = 10;
			localparam AXI_USER_WIDTH = 0;
			localparam [63:0] CachedAddrBeg = 64'h0000000080000000;
			wire clk_i;
			wire rst_ni;
			wire [63:0] boot_addr_i;
			wire [63:0] hart_id_i;
			wire [1:0] irq_i;
			wire ipi_i;
			wire time_irq_i;
			wire debug_req_i;
			wire [1:0] priv_lvl_o;
			wire umode_i;
			wire testmode_i;
			wire [31:0] jtag_key;
			wire dmi_rst_no;
			wire [40:0] dmi_req_o;
			wire dmi_req_valid_o;
			wire dmi_req_ready_i;
			wire [33:0] dmi_resp_i;
			wire dmi_resp_ready_o;
			wire dmi_resp_valid_i;
			wire tck_i;
			wire tms_i;
			wire trst_ni;
			wire td_i;
			wire td_o;
			wire tdo_oe_o;
			wire umode_o;
			wire test_en_i;
			localparam _mbase_subordinate = 0;
			localparam _mbase_primary = 0;
			wire [7:0] priv_lvl_i;
			wire [511:0] access_ctrl_i;
			wire [255:0] start_addr_i;
			wire [255:0] end_addr_i;
			localparam serpent_cache_pkg_L15_TID_WIDTH = 2;
			localparam serpent_cache_pkg_L15_TLB_CSM_WIDTH = 33;
			localparam [31:0] ariane_pkg_DCACHE_SET_ASSOC = 8;
			localparam serpent_cache_pkg_L15_SET_ASSOC = ariane_pkg_DCACHE_SET_ASSOC;
			localparam serpent_cache_pkg_L15_WAY_WIDTH = 3;
			wire [224:0] l15_req_o;
			wire [295:0] l15_rtrn_i;
			wire axi_req_o;
			wire axi_resp_i;
			ariane #(.CachedAddrBeg(CachedAddrBeg)) ariane_i(
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
				.axi_req_o(axi_req_o),
				.axi_resp_i(axi_resp_i)
			);
			dmi_jtag dmi_jtag_i(
				.clk_i(clk_i),
				.rst_ni(rst_ni),
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
				.umode_o(umode_o)
			);
			localparam _bbase_AF8BE_slave = 0;
			localparam _bbase_AF8BE_master = 0;
			localparam _param_AF8BE_NB_MANAGER = 8;
			localparam _param_AF8BE_NB_SUBORDINATE = 8;
			localparam _param_AF8BE_NB_PRIV_LVL = 8;
			localparam _param_AF8BE_PRIV_LVL_WIDTH = 8;
			localparam _param_AF8BE_AXI_ADDR_WIDTH = 32;
			localparam _param_AF8BE_AXI_DATA_WIDTH = 32;
			localparam _param_AF8BE_AXI_ID_WIDTH = 10;
			localparam _param_AF8BE_AXI_USER_WIDTH = 0;
			if (1) begin : axi_node_intf_wrap_i
				localparam NB_MANAGER = _param_AF8BE_NB_MANAGER;
				localparam NB_SUBORDINATE = _param_AF8BE_NB_SUBORDINATE;
				localparam NB_PRIV_LVL = _param_AF8BE_NB_PRIV_LVL;
				localparam PRIV_LVL_WIDTH = _param_AF8BE_PRIV_LVL_WIDTH;
				localparam AXI_ADDR_WIDTH = _param_AF8BE_AXI_ADDR_WIDTH;
				localparam AXI_DATA_WIDTH = _param_AF8BE_AXI_DATA_WIDTH;
				localparam AXI_ID_WIDTH = _param_AF8BE_AXI_ID_WIDTH;
				localparam AXI_USER_WIDTH = _param_AF8BE_AXI_USER_WIDTH;
				wire clk;
				wire rst_n;
				wire test_en_i;
				localparam _mbase_slave = 0;
				localparam _mbase_master = 0;
				wire [7:0] priv_lvl_i;
				wire [511:0] access_ctrl_i;
				wire [255:0] start_addr_i;
				wire [255:0] end_addr_i;
				localparam AXI_STRB_WIDTH = 4;
				localparam NB_REGION = 1;
				localparam AXI_ID_WIDTH_TARG = AXI_ID_WIDTH;
				localparam AXI_ID_WIDTH_INIT = 13;
				wire [103:0] s_master_aw_id;
				wire [255:0] s_master_aw_addr;
				wire [63:0] s_master_aw_len;
				wire [23:0] s_master_aw_size;
				wire [15:0] s_master_aw_burst;
				wire [7:0] s_master_aw_lock;
				wire [31:0] s_master_aw_cache;
				wire [23:0] s_master_aw_prot;
				wire [31:0] s_master_aw_region;
				wire [-1:0] s_master_aw_user;
				wire [31:0] s_master_aw_qos;
				wire [7:0] s_master_aw_valid;
				wire [7:0] s_master_aw_ready;
				wire [103:0] s_master_ar_id;
				wire [255:0] s_master_ar_addr;
				wire [63:0] s_master_ar_len;
				wire [23:0] s_master_ar_size;
				wire [15:0] s_master_ar_burst;
				wire [7:0] s_master_ar_lock;
				wire [31:0] s_master_ar_cache;
				wire [23:0] s_master_ar_prot;
				wire [31:0] s_master_ar_region;
				wire [-1:0] s_master_ar_user;
				wire [31:0] s_master_ar_qos;
				wire [7:0] s_master_ar_valid;
				wire [7:0] s_master_ar_ready;
				wire [255:0] s_master_w_data;
				wire [31:0] s_master_w_strb;
				wire [7:0] s_master_w_last;
				wire [-1:0] s_master_w_user;
				wire [7:0] s_master_w_valid;
				wire [7:0] s_master_w_ready;
				wire [103:0] s_master_b_id;
				wire [15:0] s_master_b_resp;
				wire [7:0] s_master_b_valid;
				wire [-1:0] s_master_b_user;
				wire [7:0] s_master_b_ready;
				wire [103:0] s_master_r_id;
				wire [255:0] s_master_r_data;
				wire [15:0] s_master_r_resp;
				wire [7:0] s_master_r_last;
				wire [-1:0] s_master_r_user;
				wire [7:0] s_master_r_valid;
				wire [7:0] s_master_r_ready;
				wire [79:0] s_slave_aw_id;
				wire [255:0] s_slave_aw_addr;
				wire [63:0] s_slave_aw_len;
				wire [23:0] s_slave_aw_size;
				wire [15:0] s_slave_aw_burst;
				wire [7:0] s_slave_aw_lock;
				wire [31:0] s_slave_aw_cache;
				wire [23:0] s_slave_aw_prot;
				wire [31:0] s_slave_aw_region;
				wire [-1:0] s_slave_aw_user;
				wire [31:0] s_slave_aw_qos;
				wire [7:0] s_slave_aw_valid;
				wire [7:0] s_slave_aw_ready;
				wire [79:0] s_slave_ar_id;
				wire [255:0] s_slave_ar_addr;
				wire [63:0] s_slave_ar_len;
				wire [23:0] s_slave_ar_size;
				wire [15:0] s_slave_ar_burst;
				wire [7:0] s_slave_ar_lock;
				wire [31:0] s_slave_ar_cache;
				wire [23:0] s_slave_ar_prot;
				wire [31:0] s_slave_ar_region;
				wire [-1:0] s_slave_ar_user;
				wire [31:0] s_slave_ar_qos;
				wire [7:0] s_slave_ar_valid;
				wire [7:0] s_slave_ar_ready;
				wire [255:0] s_slave_w_data;
				wire [31:0] s_slave_w_strb;
				wire [7:0] s_slave_w_last;
				wire [-1:0] s_slave_w_user;
				wire [7:0] s_slave_w_valid;
				wire [7:0] s_slave_w_ready;
				wire [79:0] s_slave_b_id;
				wire [15:0] s_slave_b_resp;
				wire [7:0] s_slave_b_valid;
				wire [-1:0] s_slave_b_user;
				wire [7:0] s_slave_b_ready;
				wire [79:0] s_slave_r_id;
				wire [255:0] s_slave_r_data;
				wire [15:0] s_slave_r_resp;
				wire [7:0] s_slave_r_last;
				wire [-1:0] s_slave_r_user;
				wire [7:0] s_slave_r_valid;
				wire [7:0] s_slave_r_ready;
				wire [255:0] s_start_addr;
				wire [255:0] s_end_addr;
				wire [7:0] s_valid_rule;
				wire [63:0] s_connectivity_map;
				genvar _gv_i_10;
				for (_gv_i_10 = 0; _gv_i_10 < NB_MANAGER; _gv_i_10 = _gv_i_10 + 1) begin : genblk1
					localparam i = _gv_i_10;
					assign formal_top.primary[i + _mbase_master].aw_id[12:0] = s_master_aw_id[i * 13+:13];
					assign formal_top.primary[i + _mbase_master].aw_addr = s_master_aw_addr[i * 32+:32];
					assign formal_top.primary[i + _mbase_master].aw_len = s_master_aw_len[i * 8+:8];
					assign formal_top.primary[i + _mbase_master].aw_size = s_master_aw_size[i * 3+:3];
					assign formal_top.primary[i + _mbase_master].aw_burst = s_master_aw_burst[i * 2+:2];
					assign formal_top.primary[i + _mbase_master].aw_lock = s_master_aw_lock[i];
					assign formal_top.primary[i + _mbase_master].aw_cache = s_master_aw_cache[i * 4+:4];
					assign formal_top.primary[i + _mbase_master].aw_prot = s_master_aw_prot[i * 3+:3];
					assign formal_top.primary[i + _mbase_master].aw_region = s_master_aw_region[i * 4+:4];
					assign formal_top.primary[i + _mbase_master].aw_user = s_master_aw_user[0+:AXI_USER_WIDTH];
					assign formal_top.primary[i + _mbase_master].aw_qos = s_master_aw_qos[i * 4+:4];
					assign formal_top.primary[i + _mbase_master].aw_valid = s_master_aw_valid[i];
					assign s_master_aw_ready[i] = formal_top.primary[i + _mbase_master].aw_ready;
					assign formal_top.primary[i + _mbase_master].ar_id[12:0] = s_master_ar_id[i * 13+:13];
					assign formal_top.primary[i + _mbase_master].ar_addr = s_master_ar_addr[i * 32+:32];
					assign formal_top.primary[i + _mbase_master].ar_len = s_master_ar_len[i * 8+:8];
					assign formal_top.primary[i + _mbase_master].ar_size = s_master_ar_size[i * 3+:3];
					assign formal_top.primary[i + _mbase_master].ar_burst = s_master_ar_burst[i * 2+:2];
					assign formal_top.primary[i + _mbase_master].ar_lock = s_master_ar_lock[i];
					assign formal_top.primary[i + _mbase_master].ar_cache = s_master_ar_cache[i * 4+:4];
					assign formal_top.primary[i + _mbase_master].ar_prot = s_master_ar_prot[i * 3+:3];
					assign formal_top.primary[i + _mbase_master].ar_region = s_master_ar_region[i * 4+:4];
					assign formal_top.primary[i + _mbase_master].ar_user = s_master_ar_user[0+:AXI_USER_WIDTH];
					assign formal_top.primary[i + _mbase_master].ar_qos = s_master_ar_qos[i * 4+:4];
					assign formal_top.primary[i + _mbase_master].ar_valid = s_master_ar_valid[i];
					assign s_master_ar_ready[i] = formal_top.primary[i + _mbase_master].ar_ready;
					assign formal_top.primary[i + _mbase_master].w_data = s_master_w_data[i * 32+:32];
					assign formal_top.primary[i + _mbase_master].w_strb = s_master_w_strb[i * 4+:4];
					assign formal_top.primary[i + _mbase_master].w_last = s_master_w_last[i];
					assign formal_top.primary[i + _mbase_master].w_user = s_master_w_user[0+:AXI_USER_WIDTH];
					assign formal_top.primary[i + _mbase_master].w_valid = s_master_w_valid[i];
					assign s_master_w_ready[i] = formal_top.primary[i + _mbase_master].w_ready;
					assign s_master_b_id[i * 13+:13] = formal_top.primary[i + _mbase_master].b_id[12:0];
					assign s_master_b_resp[i * 2+:2] = formal_top.primary[i + _mbase_master].b_resp;
					assign s_master_b_valid[i] = formal_top.primary[i + _mbase_master].b_valid;
					assign s_master_b_user[0+:AXI_USER_WIDTH] = formal_top.primary[i + _mbase_master].b_user;
					assign formal_top.primary[i + _mbase_master].b_ready = s_master_b_ready[i];
					assign s_master_r_id[i * 13+:13] = formal_top.primary[i + _mbase_master].r_id[12:0];
					assign s_master_r_data[i * 32+:32] = formal_top.primary[i + _mbase_master].r_data;
					assign s_master_r_resp[i * 2+:2] = formal_top.primary[i + _mbase_master].r_resp;
					assign s_master_r_last[i] = formal_top.primary[i + _mbase_master].r_last;
					assign s_master_r_user[0+:AXI_USER_WIDTH] = formal_top.primary[i + _mbase_master].r_user;
					assign s_master_r_valid[i] = formal_top.primary[i + _mbase_master].r_valid;
					assign formal_top.primary[i + _mbase_master].r_ready = s_master_r_ready[i];
					assign s_start_addr[(0 + i) * 32+:32] = start_addr_i[i * 32+:32];
					assign s_end_addr[(0 + i) * 32+:32] = end_addr_i[i * 32+:32];
				end
				genvar _gv_j_4;
				for (_gv_j_4 = 0; _gv_j_4 < NB_SUBORDINATE; _gv_j_4 = _gv_j_4 + 1) begin : genblk2
					localparam j = _gv_j_4;
					assign s_slave_aw_id[j * 10+:10] = formal_top.subordinate[j + _mbase_slave].aw_id[9:0];
					assign s_slave_aw_addr[j * 32+:32] = formal_top.subordinate[j + _mbase_slave].aw_addr;
					assign s_slave_aw_len[j * 8+:8] = formal_top.subordinate[j + _mbase_slave].aw_len;
					assign s_slave_aw_size[j * 3+:3] = formal_top.subordinate[j + _mbase_slave].aw_size;
					assign s_slave_aw_burst[j * 2+:2] = formal_top.subordinate[j + _mbase_slave].aw_burst;
					assign s_slave_aw_lock[j] = formal_top.subordinate[j + _mbase_slave].aw_lock;
					assign s_slave_aw_cache[j * 4+:4] = formal_top.subordinate[j + _mbase_slave].aw_cache;
					assign s_slave_aw_prot[j * 3+:3] = formal_top.subordinate[j + _mbase_slave].aw_prot;
					assign s_slave_aw_region[j * 4+:4] = formal_top.subordinate[j + _mbase_slave].aw_region;
					assign s_slave_aw_user[0+:AXI_USER_WIDTH] = formal_top.subordinate[j + _mbase_slave].aw_user;
					assign s_slave_aw_qos[j * 4+:4] = formal_top.subordinate[j + _mbase_slave].aw_qos;
					assign s_slave_aw_valid[j] = formal_top.subordinate[j + _mbase_slave].aw_valid;
					assign formal_top.subordinate[j + _mbase_slave].aw_ready = s_slave_aw_ready[j];
					assign s_slave_ar_id[j * 10+:10] = formal_top.subordinate[j + _mbase_slave].ar_id[9:0];
					assign s_slave_ar_addr[j * 32+:32] = formal_top.subordinate[j + _mbase_slave].ar_addr;
					assign s_slave_ar_len[j * 8+:8] = formal_top.subordinate[j + _mbase_slave].ar_len;
					assign s_slave_ar_size[j * 3+:3] = formal_top.subordinate[j + _mbase_slave].ar_size;
					assign s_slave_ar_burst[j * 2+:2] = formal_top.subordinate[j + _mbase_slave].ar_burst;
					assign s_slave_ar_lock[j] = formal_top.subordinate[j + _mbase_slave].ar_lock;
					assign s_slave_ar_cache[j * 4+:4] = formal_top.subordinate[j + _mbase_slave].ar_cache;
					assign s_slave_ar_prot[j * 3+:3] = formal_top.subordinate[j + _mbase_slave].ar_prot;
					assign s_slave_ar_region[j * 4+:4] = formal_top.subordinate[j + _mbase_slave].ar_region;
					assign s_slave_ar_user[0+:AXI_USER_WIDTH] = formal_top.subordinate[j + _mbase_slave].ar_user;
					assign s_slave_ar_qos[j * 4+:4] = formal_top.subordinate[j + _mbase_slave].ar_qos;
					assign s_slave_ar_valid[j] = formal_top.subordinate[j + _mbase_slave].ar_valid;
					assign formal_top.subordinate[j + _mbase_slave].ar_ready = s_slave_ar_ready[j];
					assign s_slave_w_data[j * 32+:32] = formal_top.subordinate[j + _mbase_slave].w_data;
					assign s_slave_w_strb[j * 4+:4] = formal_top.subordinate[j + _mbase_slave].w_strb;
					assign s_slave_w_last[j] = formal_top.subordinate[j + _mbase_slave].w_last;
					assign s_slave_w_user[0+:AXI_USER_WIDTH] = formal_top.subordinate[j + _mbase_slave].w_user;
					assign s_slave_w_valid[j] = formal_top.subordinate[j + _mbase_slave].w_valid;
					assign formal_top.subordinate[j + _mbase_slave].w_ready = s_slave_w_ready[j];
					assign formal_top.subordinate[j + _mbase_slave].b_id[9:0] = s_slave_b_id[j * 10+:10];
					assign formal_top.subordinate[j + _mbase_slave].b_resp = s_slave_b_resp[j * 2+:2];
					assign formal_top.subordinate[j + _mbase_slave].b_valid = s_slave_b_valid[j];
					assign formal_top.subordinate[j + _mbase_slave].b_user = s_slave_b_user[0+:AXI_USER_WIDTH];
					assign s_slave_b_ready[j] = formal_top.subordinate[j + _mbase_slave].b_ready;
					assign formal_top.subordinate[j + _mbase_slave].r_id[9:0] = s_slave_r_id[j * 10+:10];
					assign formal_top.subordinate[j + _mbase_slave].r_data = s_slave_r_data[j * 32+:32];
					assign formal_top.subordinate[j + _mbase_slave].r_resp = s_slave_r_resp[j * 2+:2];
					assign formal_top.subordinate[j + _mbase_slave].r_last = s_slave_r_last[j];
					assign formal_top.subordinate[j + _mbase_slave].r_user = s_slave_r_user[0+:AXI_USER_WIDTH];
					assign formal_top.subordinate[j + _mbase_slave].r_valid = s_slave_r_valid[j];
					assign s_slave_r_ready[j] = formal_top.subordinate[j + _mbase_slave].r_ready;
				end
				axi_node #(
					.AXI_ADDRESS_W(AXI_ADDR_WIDTH),
					.AXI_DATA_W(AXI_DATA_WIDTH),
					.N_MASTER_PORT(NB_MANAGER),
					.N_SLAVE_PORT(NB_SUBORDINATE),
					.AXI_ID_IN(AXI_ID_WIDTH_TARG),
					.AXI_USER_W(AXI_USER_WIDTH),
					.N_REGION(NB_REGION)
				) axi_node_i(
					.clk(clk),
					.rst_n(rst_n),
					.test_en_i(test_en_i),
					.slave_awid_i(s_slave_aw_id),
					.slave_awaddr_i(s_slave_aw_addr),
					.slave_awlen_i(s_slave_aw_len),
					.slave_awsize_i(s_slave_aw_size),
					.slave_awburst_i(s_slave_aw_burst),
					.slave_awlock_i(s_slave_aw_lock),
					.slave_awcache_i(s_slave_aw_cache),
					.slave_awprot_i(s_slave_aw_prot),
					.slave_awregion_i(s_slave_aw_region),
					.slave_awqos_i(s_slave_aw_qos),
					.slave_awuser_i(s_slave_aw_user),
					.slave_awvalid_i(s_slave_aw_valid),
					.slave_awready_o(s_slave_aw_ready),
					.slave_wdata_i(s_slave_w_data),
					.slave_wstrb_i(s_slave_w_strb),
					.slave_wlast_i(s_slave_w_last),
					.slave_wuser_i(s_slave_w_user),
					.slave_wvalid_i(s_slave_w_valid),
					.slave_wready_o(s_slave_w_ready),
					.slave_bid_o(s_slave_b_id),
					.slave_bresp_o(s_slave_b_resp),
					.slave_buser_o(s_slave_b_user),
					.slave_bvalid_o(s_slave_b_valid),
					.slave_bready_i(s_slave_b_ready),
					.slave_arid_i(s_slave_ar_id),
					.slave_araddr_i(s_slave_ar_addr),
					.slave_arlen_i(s_slave_ar_len),
					.slave_arsize_i(s_slave_ar_size),
					.slave_arburst_i(s_slave_ar_burst),
					.slave_arlock_i(s_slave_ar_lock),
					.slave_arcache_i(s_slave_ar_cache),
					.slave_arprot_i(s_slave_ar_prot),
					.slave_arregion_i(s_slave_ar_region),
					.slave_aruser_i(s_slave_ar_user),
					.slave_arqos_i(s_slave_ar_qos),
					.slave_arvalid_i(s_slave_ar_valid),
					.slave_arready_o(s_slave_ar_ready),
					.slave_rid_o(s_slave_r_id),
					.slave_rdata_o(s_slave_r_data),
					.slave_rresp_o(s_slave_r_resp),
					.slave_rlast_o(s_slave_r_last),
					.slave_ruser_o(s_slave_r_user),
					.slave_rvalid_o(s_slave_r_valid),
					.slave_rready_i(s_slave_r_ready),
					.master_awid_o(s_master_aw_id),
					.master_awaddr_o(s_master_aw_addr),
					.master_awlen_o(s_master_aw_len),
					.master_awsize_o(s_master_aw_size),
					.master_awburst_o(s_master_aw_burst),
					.master_awlock_o(s_master_aw_lock),
					.master_awcache_o(s_master_aw_cache),
					.master_awprot_o(s_master_aw_prot),
					.master_awregion_o(s_master_aw_region),
					.master_awqos_o(s_master_aw_qos),
					.master_awuser_o(s_master_aw_user),
					.master_awvalid_o(s_master_aw_valid),
					.master_awready_i(s_master_aw_ready),
					.master_wdata_o(s_master_w_data),
					.master_wstrb_o(s_master_w_strb),
					.master_wlast_o(s_master_w_last),
					.master_wuser_o(s_master_w_user),
					.master_wvalid_o(s_master_w_valid),
					.master_wready_i(s_master_w_ready),
					.master_bid_i(s_master_b_id),
					.master_bresp_i(s_master_b_resp),
					.master_buser_i(s_master_b_user),
					.master_bvalid_i(s_master_b_valid),
					.master_bready_o(s_master_b_ready),
					.master_arid_o(s_master_ar_id),
					.master_araddr_o(s_master_ar_addr),
					.master_arlen_o(s_master_ar_len),
					.master_arsize_o(s_master_ar_size),
					.master_arburst_o(s_master_ar_burst),
					.master_arlock_o(s_master_ar_lock),
					.master_arcache_o(s_master_ar_cache),
					.master_arprot_o(s_master_ar_prot),
					.master_arregion_o(s_master_ar_region),
					.master_aruser_o(s_master_ar_user),
					.master_arqos_o(s_master_ar_qos),
					.master_arvalid_o(s_master_ar_valid),
					.master_arready_i(s_master_ar_ready),
					.master_rid_i(s_master_r_id),
					.master_rdata_i(s_master_r_data),
					.master_rresp_i(s_master_r_resp),
					.master_rlast_i(s_master_r_last),
					.master_ruser_i(s_master_r_user),
					.master_rvalid_i(s_master_r_valid),
					.master_rready_o(s_master_r_ready),
					.cfg_START_ADDR_i(s_start_addr),
					.cfg_END_ADDR_i(s_end_addr),
					.cfg_valid_rule_i(s_valid_rule),
					.cfg_connectivity_map_i(s_connectivity_map)
				);
				assign s_valid_rule = 1'sb1;
				connectivity_mapping #(
					.NB_SUBORDINATE(NB_SUBORDINATE),
					.NB_MANAGER(NB_MANAGER),
					.NB_PRIV_LVL(NB_PRIV_LVL),
					.PRIV_LVL_WIDTH(PRIV_LVL_WIDTH)
				) i_connectivity_map(
					.priv_lvl_i(priv_lvl_i),
					.access_ctrl_i(access_ctrl_i),
					.connectivity_map_o(s_connectivity_map)
				);
			end
			assign axi_node_intf_wrap_i.clk = clk_i;
			assign axi_node_intf_wrap_i.rst_n = rst_ni;
			assign axi_node_intf_wrap_i.test_en_i = test_en_i;
			assign axi_node_intf_wrap_i.priv_lvl_i = priv_lvl_i;
			assign axi_node_intf_wrap_i.access_ctrl_i = access_ctrl_i;
			assign axi_node_intf_wrap_i.start_addr_i = start_addr_i;
			assign axi_node_intf_wrap_i.end_addr_i = end_addr_i;
		end
	endgenerate
	assign dut.clk_i = clk_i;
	assign dut.rst_ni = rst_ni;
	assign dut.boot_addr_i = boot_addr_i;
	assign dut.hart_id_i = hart_id_i;
	assign dut.irq_i = irq_i;
	assign dut.ipi_i = ipi_i;
	assign dut.time_irq_i = time_irq_i;
	assign dut.debug_req_i = debug_req_i;
	assign priv_lvl_o = dut.priv_lvl_o;
	assign dut.umode_i = umode_i;
	assign dut.testmode_i = testmode_i;
	assign dut.jtag_key = jtag_key;
	assign dmi_rst_no = dut.dmi_rst_no;
	assign dmi_req_o = dut.dmi_req_o;
	assign dmi_req_valid_o = dut.dmi_req_valid_o;
	assign dut.dmi_req_ready_i = dmi_req_ready_i;
	assign dut.dmi_resp_i = dmi_resp_i;
	assign dmi_resp_ready_o = dut.dmi_resp_ready_o;
	assign dut.dmi_resp_valid_i = dmi_resp_valid_i;
	assign dut.tck_i = tck_i;
	assign dut.tms_i = tms_i;
	assign dut.trst_ni = trst_ni;
	assign dut.td_i = td_i;
	assign td_o = dut.td_o;
	assign tdo_oe_o = dut.tdo_oe_o;
	assign umode_o = dut.umode_o;
	assign dut.test_en_i = test_en_i;
	assign dut.priv_lvl_i = priv_lvl_i;
	assign dut.access_ctrl_i = access_ctrl_i;
	assign dut.start_addr_i = start_addr_i;
	assign dut.end_addr_i = end_addr_i;
	assign l15_req_o = dut.l15_req_o;
	assign dut.l15_rtrn_i = l15_rtrn_i;
endmodule