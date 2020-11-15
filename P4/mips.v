`include "constants.v"

module mips(
	input clk,
	input reset
);
	// instr related things
	wire [31:0] instr;
	wire [5:0] op = instr[31:26], func = instr[5:0];
	wire [4:0] rs = instr[25:21], rt = instr[20:16], rd = instr[15:11];
	wire [15:0] imm = instr[15:0];

	// ctrl output
	wire reg_write;
	wire [1:0] reg_dst, reg_data;
	wire alu_src;
	wire [2:0] alu_op;
	wire mem_write;
	wire [1:0] jump_mode;
	wire ext_op;

	// other output
	wire [31:0] alu_out, ext_out, grf_read_data0, grf_read_data1, dm_read_data, pc4;

	ctrl ctrl(
		.op(op), .func(func),
		.reg_write(reg_write), .reg_dst(reg_dst), .reg_data(reg_data),
		.alu_src(alu_src), .alu_op(alu_op),
		.mem_write(mem_write),
		.jump_mode(jump_mode),
		.ext_op(ext_op)
	);

	reg [4:0] grf_write_addr;
	always @*
		case (reg_dst)
			`REG_DST_RD: grf_write_addr = rd;
			`REG_DST_RT: grf_write_addr = rt;
			`REG_DST_RA: grf_write_addr = 31;
			default: grf_write_addr = 0;
		endcase
	reg [31:0] grf_write_data;
	always @*
		case (reg_data)
			`REG_DATA_ALU: grf_write_data = alu_out;
			`REG_DATA_MEM: grf_write_data = dm_read_data;
			`REG_DATA_PC4: grf_write_data = pc4;
			default: grf_write_data = 0;
		endcase
	grf grf(
		.clk(clk), .reset(reset), .write_enable(reg_write),
		.read_addr0(rs), .read_addr1(rt),
		.write_addr(grf_write_addr), .write_data(grf_write_data),
		.read_data0(grf_read_data0), .read_data1(grf_read_data1)
	);

	reg [31:0] alu_in1;
	always @*
		case (alu_src)
			`ALU_SRC_RT: alu_in1 = grf_read_data1;
			`ALU_SRC_EXT: alu_in1 = ext_out;
			default: alu_in1 = 0;
		endcase
	alu alu(.in0(grf_read_data0), .in1(alu_in1), .op(alu_op), .out(alu_out));

	ext ext(.in(imm), .op(ext_op), .out(ext_out));

	wire cmp_result = alu_out[0];
	im im(
		.clk(clk), .reset(reset),
		.cmp_result(cmp_result),
		.jump_mode(jump_mode), .jump_addr(grf_read_data0),
		.pc4(pc4), .instr(instr)
	);

	dm dm(
		.clk(clk), .reset(reset), .write_enable(mem_write),
		.addr(alu_out), .write_data(grf_read_data1),
		.read_data(dm_read_data)
	);

	always @(posedge clk)
		if (!reset) begin
			if (grf.write_enable) $display("@%h: $%d <= %h", im.pc, grf.write_addr, grf.write_data);
			if (dm.write_enable) $display("@%h: *%h <= %h", im.pc, dm.addr, dm.write_data);
		end
endmodule
