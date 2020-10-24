module ext(
	input [15:0] imm,
	input [1:0] EOp,
	output reg [31:0] ext
);
	always @(imm, EOp) begin
		case (EOp)
			2'b00: ext <= $signed({imm, 16'b0}) >>> 16;
			2'b01: ext <= {16'b0, imm};
			2'b10: ext <= {imm, 16'b0};
			2'b11: ext <= $signed({imm, 16'b0}) >>> 14;
		endcase
	end
endmodule

module ext_test();
	reg [15:0] in;
	reg [1:0] op;
	wire [31:0] out;

	ext uut(in, op, out);

	initial begin
`ifdef DUMPFILE
		$dumpfile(`DUMPFILE);
		$dumpvars(0, ext_test);
`endif
		in = 16'b1000_1001_0000_0000;
		op = 2'b00;
		#10;
		$display("%b", out);
		op = 2'b01;
		#10;
		$display("%b", out);
		op = 2'b10;
		#10;
		$display("%b", out);
		op = 2'b11;
		#10;
		$display("%b", out);
	end
endmodule
