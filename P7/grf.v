`include "def.v"

module grf #(parameter GRF_SIZE = 32) (
	input wire clk,
	input wire reset,
	input wire [31:0] pc,
	input wire [4:0] read_addr0,
	input wire [4:0] read_addr1,
	input wire [4:0] write_addr,
	input wire [31:0] write_data,
	output wire [31:0] read_data0,
	output wire [31:0] read_data1
);
	reg [31:0] regs [GRF_SIZE - 1:0];
	assign read_data0 = read_addr0 == write_addr ? write_data : regs[read_addr0];
	assign read_data1 = read_addr1 == write_addr ? write_data : regs[read_addr1];

	integer i;
	always @(posedge clk)
		if (reset)
			for (i = 0; i < GRF_SIZE; i = i + 1) regs[i] <= 0;
		else if (write_addr != 0) begin
			$display("%d@%h: $%d <= %h", $time, pc, write_addr, write_data);
			regs[write_addr] <= write_data;
		end
endmodule
