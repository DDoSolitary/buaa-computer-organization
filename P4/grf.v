module grf #(parameter GRF_SIZE = 32) (
	input clk,
	input reset,
	input write_enable,
	input [4:0] read_addr0,
	input [4:0] read_addr1,
	input [4:0] write_addr,
	input [31:0] write_data,
	output [31:0] read_data0,
	output [31:0] read_data1
);
	reg [31:0] regs [GRF_SIZE - 1:0];
	assign read_data0 = read_addr0 == 0 ? 0 : regs[read_addr0];
	assign read_data1 = read_addr1 == 0 ? 0 : regs[read_addr1];

	integer i;
	always @(posedge clk)
		if (reset)
			for (i = 0; i < GRF_SIZE; i = i + 1) regs[i] <= 0;
		else if (write_enable)
			regs[write_addr] <= write_data;
endmodule

module grf_test(input start, output reg stop = 0);
	reg clk = 0, reset = 0, write_enable = 0;
	reg [4:0] read_addr0 = 0, read_addr1 = 0, write_addr;
	reg [31:0] write_data;
	wire [31:0] read_data0, read_data1;

	grf uut(
		clk, reset, write_enable,
		read_addr0, read_addr1,
		write_addr, write_data,
		read_data0, read_data1
	);

	always #5 clk = ~clk;

	integer i;
	always @(posedge start) begin
		$display("--- grf_test start ---");
		reset = 1;
		#10;
		reset = 0;
		write_enable = 1;
		for (i = 0; i < uut.GRF_SIZE; i = i + 1) begin
			if (i == uut.GRF_SIZE / 2) write_enable = 0;
			write_addr = i;
			write_data = -i - 1;
			read_addr0 = i > 0 ? i - 1 : 0;
			read_addr1 = i;
			#10;
			$display("%h %h", read_data0, read_data1);
		end
		$display("--- grf_test stop ---\n");
		stop = 1;
	end
endmodule
