module test_coordinator();
/*
	reg alu_test_start = 0;
	wire alu_test_stop;
	reg ext_test_start = 0;
	wire ext_test_stop;
	reg grf_test_start = 0;
	wire grf_test_stop;

	alu_test alu_tester(alu_test_start, alu_test_stop);
	ext_test ext_tester(ext_test_start, ext_test_stop);
	grf_test grf_tester(grf_test_start, grf_test_stop);

	initial begin
		$dumpfile("P4.vcd");
		$dumpvars(0, test_coordinator);
		alu_test_start = 1;
	end
	always @(posedge alu_test_stop) ext_test_start = 1;
	always @(posedge ext_test_stop) grf_test_start = 1;
	always @(posedge grf_test_stop) $finish();
*/
	reg clk = 0, reset;
	always #5 clk = ~clk;
	mips uut(clk, reset);

	initial begin
		$dumpfile("P4.vcd");
		$dumpvars(0, test_coordinator);
		reset = 1;
		#10;
		reset = 0;
		#10240;
		$finish();
	end
endmodule
