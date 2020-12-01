`include "def.v"

module stage_fetch #(parameter ADDR_WIDTH = 12, ADDR_OFFSET = 'h3000) (
	input wire clk,
	input wire reset,
	input wire [31:0] next_pc,
	output reg [31:0] pc,
	output wire [31:0] instr
);
	localparam MEM_LOW = ADDR_OFFSET >> 2;
	localparam MEM_HIGH = MEM_LOW + (1 << (ADDR_WIDTH - 2));
	reg [31:0] mem [MEM_HIGH - 1:MEM_LOW];

	assign instr = mem[pc[ADDR_WIDTH - 1:2] | MEM_LOW];

	always @(posedge clk) begin
		if (reset) begin
			pc <= ADDR_OFFSET;
			$readmemh("code.txt", mem);
		end else pc <= next_pc;
	end
endmodule
