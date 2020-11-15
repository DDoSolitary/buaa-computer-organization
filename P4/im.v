`include "constants.v"

module im #(parameter ADDR_WIDTH = 12, ADDR_OFFSET = 'h3000) (
	input clk,
	input reset,
	input cmp_result,
	input [1:0] jump_mode,
	input [31:0] jump_addr,
	output [31:0] pc4,
	output [31:0] instr
);
	localparam MEM_LOW = ADDR_OFFSET >> 2;
	localparam MEM_HIGH = MEM_LOW + (1 << (ADDR_WIDTH - 2));
	reg [31:0] pc;
	reg [31:0] mem [MEM_HIGH - 1:MEM_LOW];
	assign pc4 = pc + 4;
	assign instr = mem[pc[ADDR_WIDTH - 1:2] | MEM_LOW];

	always @(posedge clk)
		if (reset) begin
			pc <= ADDR_OFFSET;
			$readmemh("code.txt", mem);
		end else
			case (jump_mode)
				`JUMP_MODE_OFFSET:
					if (cmp_result) pc <= $signed(pc4) + $signed({instr[15:0], 2'b0});
					else pc <= pc4;
				`JUMP_MODE_ABS: pc <= pc4[31:28] | {instr[25:0], 2'b0};
				`JUMP_MODE_INPUT: pc <= jump_addr;
				default: pc <= pc4;
			endcase
endmodule
