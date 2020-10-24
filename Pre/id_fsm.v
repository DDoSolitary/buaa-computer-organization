module id_fsm(
	input [7:0] char,
	input clk,
	output out
);
	reg [1:0] state = 0;
	assign out = state == 2;

	always @(posedge clk) begin
		if (char >= "A" && char <= "Z" || char >= "a" && char <= "z") begin
			state <= 1;
		end else if (char >= "0" && char <= "9") begin
			if (state == 1) state <= 2;
		end else begin
			state <= 0;
		end
	end
endmodule

module id_fsm_test;
	reg [7:0] char = 0;
	reg clk = 1;
	wire out;

	id_fsm uut(char, clk, out);

	always #5 clk = ~clk;

	initial begin
`ifdef DUMPFILE
		$dumpfile(`DUMPFILE);
		$dumpvars(0, id_fsm_test);
`endif
		#10;
		char = "a";
		#10;
		char = "b";
		#10;
		char = "c";
		#10;
		char = "0";
		#10;
		char = "1";
		#10;
		char = "2";
		#10;
		char = "*";
		#10;
		char = "a";
		#10;
		char = "0";
		#10;
		char = "b";
		#10;
		char = "1";
		#20;
		$finish();
	end
endmodule
