`include "def.v"

module stage_execute(
	input wire clk,
	input wire reset,
	input wire [31:0] grf_in0,
	input wire [31:0] grf_in1,
	input wire alu_src0,
	input wire alu_src1,
	input wire [`ALU_OP_LEN - 1:0] alu_op,
	input wire [4:0] sa,
	input wire [31:0] ext_imm,
	input wire check_overflow,
	input wire int_req,
	output wire [31:0] alu_result,
	output wire alu_busy,
	output wire [`EXC_CODE_LEN - 1:0] exc
);
	reg [31:0] lo, hi;
	reg [3:0] busy_count;

	assign alu_busy = busy_count > 0 || (alu_op >= `ALU_OP_BUSY_MIN && alu_op <= `ALU_OP_BUSY_MAX);

	wire [31:0] in0 = alu_src0 == `ALU_SRC0_RS ? grf_in0 : sa;
	wire [31:0] in1 = alu_src1 == `ALU_SRC1_RT ? grf_in1 : ext_imm;

	wire [32:0] ext_in0 = {in0[31], in0};
	wire [32:0] ext_in1 = {in1[31], in1};

	wire [32:0] add_result = ext_in0 + ext_in1;
	wire [32:0] sub_result = ext_in0 - ext_in1;
	wire [31:0] sra_result = $signed(in1) >>> in0[4:0];
	wire [31:0] slt_result = $signed(in0) < $signed(in1);

	wire overflowed =
		alu_op == `ALU_OP_ADD && add_result[32] != add_result[31] ||
		alu_op == `ALU_OP_SUB && sub_result[32] != sub_result[31];
	assign exc = check_overflow && overflowed ? `EXC_CODE_OV : 0;

	assign alu_result =
		alu_op == `ALU_OP_ADD ? add_result[31:0] :
		alu_op == `ALU_OP_SUB ? sub_result[31:0] :
		alu_op == `ALU_OP_AND ? in0 & in1 :
		alu_op == `ALU_OP_OR ? in0 | in1 :
		alu_op == `ALU_OP_XOR ? in0 ^ in1 :
		alu_op == `ALU_OP_NOR ? ~(in0 | in1) :
		alu_op == `ALU_OP_SLL ? in1 << in0[4:0] :
		alu_op == `ALU_OP_SRL ? in1 >> in0[4:0] :
		alu_op == `ALU_OP_SRA ? sra_result :
		alu_op == `ALU_OP_SLT ? slt_result :
		alu_op == `ALU_OP_SLTU ? in0 < in1 :
		alu_op == `ALU_OP_MFLO ? lo :
		alu_op == `ALU_OP_MFHI ? hi : 0;

	always @(posedge clk)
		if (reset) begin
			lo <= 0;
			hi <= 0;
			busy_count <= 0;
		end else if (busy_count == 0) begin
			if (!int_req) begin
				if (alu_op == `ALU_OP_MULT) begin
					{hi, lo} <= {{32{in0[31]}}, in0} * {{32{in1[31]}}, in1};
					busy_count <= 5;
				end else if (alu_op == `ALU_OP_MULTU) begin
					{hi, lo} <= {32'b0, in0} * {32'b0, in1};
					busy_count <= 5;
				end else if (alu_op == `ALU_OP_DIV) begin
					if (in1 != 0) begin
						lo <= $signed(in0) / $signed(in1);
						hi <= $signed(in0) % $signed(in1);
					end else begin
						lo <= 0;
						hi <= 0;
					end
					busy_count <= 10;
				end else if (alu_op == `ALU_OP_DIVU) begin
					if (in1 != 0) begin
						lo <= in0 / in1;
						hi <= in0 % in1;
					end else begin
						lo <= 0;
						hi <= 0;
					end
					busy_count <= 10;
				end else if (alu_op == `ALU_OP_MTLO)
					lo <= in0;
				else if (alu_op == `ALU_OP_MTHI)
					hi <= in0;
			end
		end else
			busy_count <= busy_count - 1;
endmodule
