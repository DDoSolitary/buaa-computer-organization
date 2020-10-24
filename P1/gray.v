module gray(
	input Clk,
	input Reset,
	input En,
	output reg [2:0] Output = 0,
	output reg Overflow = 0
);
	always @(posedge Clk) begin
		if (Reset) begin
			Output <= 0;
			Overflow <= 0;
		end else if (En) begin
			case (Output)
				3'b000: Output <= 3'b001;
				3'b001: Output <= 3'b011;
				3'b011: Output <= 3'b010;
				3'b010: Output <= 3'b110;
				3'b110: Output <= 3'b111;
				3'b111: Output <= 3'b101;
				3'b101: Output <= 3'b100;
				3'b100: begin
					Output <= 3'b000;
					Overflow <= 1;
				end
			endcase
		end
	end
endmodule

module gray_test();
	reg Clk = 0, Reset = 0, En = 0;
	wire [2:0] Output;
	wire Overflow;

	gray uut(Clk, Reset, En, Output, Overflow);

	always #5 Clk = ~Clk;

	initial begin
`ifdef DUMPFILE
		$dumpfile(`DUMPFILE);
		$dumpvars(0, gray_test);
`endif
		#50;
		En = 1;
		#100;
		Reset = 1;
		#50;
		Reset = 0;
		#100;

		$finish();
	end
endmodule
