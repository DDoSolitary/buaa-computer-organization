`include "def.v"

module mips(
	input wire clk,
	input wire reset
);
	wire [31:0] f_pc, f_instr, f_next_pc;

	wire [4:0] d_read_addr0, d_read_addr1, d_write_addr;
	wire [31:0] grf_read_data0, grf_read_data1, d_read_data0, d_read_data1, d_ext_imm, d_next_pc;
	wire [1:0] d_read_stage0, d_read_stage1, d_write_stage, d_alu_op;
	wire d_alu_src1, d_mem_write;

	wire [31:0] e_read_data0, e_read_data1, e_alu_result, e_write_data;

	wire [31:0] m_read_data, m_mem_read_data, m_write_data;

	reg [31:0] fd_pc, fd_instr;

	reg [31:0] de_pc;
	reg [4:0] de_read_addr0, de_read_addr1, de_write_addr;
	reg [31:0] de_read_data0, de_read_data1, de_write_data, de_ext_imm;
	reg [1:0] de_write_stage, de_alu_op;
	reg de_alu_src1, de_mem_write;

	reg [31:0] em_pc;
	reg [4:0] em_read_addr, em_write_addr;
	reg [31:0] em_read_data, em_write_data, em_alu_result;
	reg [1:0] em_write_stage;
	reg em_mem_write;

	reg [31:0] mw_pc;
	reg [4:0] mw_write_addr;
	reg [31:0] mw_write_data;

	assign e_write_data = de_write_stage == `STAGE_EXECUTE ? e_alu_result : de_write_data;
	assign m_write_data = em_write_stage == `STAGE_MEM ? m_mem_read_data : em_write_data;

	assign d_read_data0 =
		d_read_addr0 == 0 ? 0 :
		d_read_addr0 == de_write_addr ? de_write_data :
		d_read_addr0 == em_write_addr ? em_write_data : grf_read_data0;
	assign d_read_data1 =
		d_read_addr1 == 0 ? 0 :
		d_read_addr1 == de_write_addr ? de_write_data :
		d_read_addr1 == em_write_addr ? em_write_data : grf_read_data1;
	assign e_read_data0 =
		de_read_addr0 == 0 ? 0 :
		de_read_addr0 == em_write_addr ? em_write_data :
		de_read_addr0 == mw_write_addr ? mw_write_data : de_read_data0;
	assign e_read_data1 =
		de_read_addr1 == 0 ? 0 :
		de_read_addr1 == em_write_addr ? em_write_data :
		de_read_addr1 == mw_write_addr ? mw_write_data : de_read_data1;
	assign m_read_data =
		em_read_addr == 0 ? 0 :
		em_read_addr == mw_write_addr ? mw_write_data : em_read_data;

	wire stall = de_write_addr != 0 &&
		((d_read_addr0 == de_write_addr && de_write_stage > d_read_stage0) ||
		(d_read_addr0 == em_write_addr && em_write_stage - 1 > d_read_stage0) ||
		(d_read_addr1 == de_write_addr && de_write_stage > d_read_stage1) ||
		(d_read_addr1 == em_write_addr && em_write_stage - 1 > d_read_stage1));

	assign f_next_pc = stall ? f_pc : d_next_pc;

	stage_fetch stage_fetch(
		.clk(clk), .reset(reset),
		.next_pc(f_next_pc),
		.pc(f_pc), .instr(f_instr)
	);

	grf grf(
		.clk(clk), .reset(reset),
		.read_addr0(d_read_addr0), .read_addr1(d_read_addr1),
		.write_addr(mw_write_addr), .write_data(mw_write_data),
		.read_data0(grf_read_data0), .read_data1(grf_read_data1)
	);

	stage_decode stage_decode(
		.pc(f_pc), .instr(fd_instr),
		.grf_read_data0(d_read_data0), .grf_read_data1(d_read_data1),
		.grf_read_addr0(d_read_addr0), .grf_read_addr1(d_read_addr1),
		.grf_read_stage0(d_read_stage0), .grf_read_stage1(d_read_stage1),
		.grf_write_addr(d_write_addr), .grf_write_stage(d_write_stage),
		.alu_src1(d_alu_src1), .alu_op(d_alu_op), .ext_imm(d_ext_imm),
		.mem_write(d_mem_write),
		.next_pc(d_next_pc)
	);

	stage_execute stage_execute(
		.grf_in0(e_read_data0), .grf_in1(e_read_data1),
		.alu_src1(de_alu_src1), .alu_op(de_alu_op),
		.ext_imm(de_ext_imm),
		.alu_result(e_alu_result)
	);

	stage_mem stage_mem(
		.clk(clk), .reset(reset),
		.write_enable(em_mem_write),
		.addr(em_alu_result),
		.write_data(m_read_data),
		.read_data(m_mem_read_data)
	);

	always @(posedge clk)
		if (reset) begin
			fd_pc <= 0;
			fd_instr <= 0;
			de_pc <= 0;
			de_read_addr0 <= 0;
			de_read_addr1 <= 0;
			de_read_data0 <= 0;
			de_read_data1 <= 0;
			de_write_addr <= 0;
			de_write_data <= 0;
			de_write_stage <= 0;
			de_alu_src1 <= 0;
			de_alu_op <= 0;
			de_ext_imm <= 0;
			de_mem_write <= 0;
			em_pc <= 0;
			em_read_addr <= 0;
			em_read_data <= 0;
			em_write_addr <= 0;
			em_write_data <= 0;
			em_write_stage <= 0;
			em_mem_write <= 0;
			em_alu_result <= 0;
			mw_pc <= 0;
			mw_write_addr <= 0;
			mw_write_data <= 0;
		end else begin
			if (mw_write_addr != 0) $display("%d@%h: $%d <= %h", $time, mw_pc, mw_write_addr, mw_write_data);
			if (em_mem_write) $display("%d@%h: *%h <= %h", $time, em_pc, em_alu_result, m_read_data);
			fd_pc <= stall ? fd_pc : f_pc;
			fd_instr <= stall ? fd_instr : f_instr;
			de_pc <= fd_pc;
			de_read_addr0 <= d_read_addr0;
			de_read_addr1 <= d_read_addr1;
			de_read_data0 <= d_read_data0;
			de_read_data1 <= d_read_data1;
			de_write_addr <= stall ? 0 : d_write_addr;
			de_write_data <= f_pc + 4;
			de_write_stage <= d_write_stage;
			de_alu_src1 <= d_alu_src1;
			de_alu_op <= d_alu_op;
			de_ext_imm <= d_ext_imm;
			de_mem_write <= !stall && d_mem_write;
			em_pc <= de_pc;
			em_read_addr <= de_read_addr1;
			em_read_data <= e_read_data1;
			em_write_addr <= de_write_addr;
			em_write_data <= e_write_data;
			em_write_stage <= de_write_stage;
			em_mem_write <= de_mem_write;
			em_alu_result <= e_alu_result;
			mw_pc <= em_pc;
			mw_write_addr <= em_write_addr;
			mw_write_data <= m_write_data;
		end
endmodule

module mips_test();
	reg clk = 0, reset;
	always #5 clk = ~clk;
	mips uut(clk, reset);

	initial begin
		$dumpfile("P5.vcd");
		$dumpvars(0, uut);
		reset = 1;
		#10;
		reset = 0;
		#10240;
		$finish();
	end
endmodule
