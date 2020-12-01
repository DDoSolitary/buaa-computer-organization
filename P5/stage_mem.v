`include "def.v"

module stage_mem #(parameter ADDR_WIDTH = 12) (
	input wire clk,
	input wire reset,
	input wire write_enable,
	input wire [31:0] addr,
	input wire [31:0] write_data,
	output wire [31:0] read_data
);
	localparam MEM_SIZE = 1 << (ADDR_WIDTH - 2);
	reg [31:0] mem [MEM_SIZE - 1:0];
	assign read_data = mem[addr[ADDR_WIDTH - 1:2]];

	integer i;
	always @(posedge clk)
		if (reset)
			for (i = 0; i < MEM_SIZE; i = i + 1) mem[i] = 0;
		else if (write_enable)
			mem[addr[ADDR_WIDTH - 1:2]] = write_data;
endmodule
