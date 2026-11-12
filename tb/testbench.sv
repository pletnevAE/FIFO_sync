//=====================================================================================
//		FIFO Testbench Module
//
//		The module is used to test the FIFO.
//		The test was conducted in ModelSim 10.6d.
//		To verify the correct operation of the FIFO module, it's necessary to display signal waveforms.
//		The console displays messages about the start of test and errors;
//		Finally, a success/failure message is displayed, along with the number of errors, if any.
//
//=====================================================================================

`timescale 1 ns/1 ps

module testbench;

//=====================================================================================
// Testbench parameters
//=====================================================================================
parameter CLK_PERIOD = 20; // Clock period
parameter RESET_CYCLES = 10; // Reset cycles
parameter RAND_CYCLES = 1000; // Number of random tests
parameter DATA_WIDTH = 8; // Input and output data width
parameter ADDR_WIDTH = 4; // FIFO address width
parameter ALMOST_FULL_VAL = 2 ** ADDR_WIDTH - 2; // Value for almost full flag
parameter ALMOST_EMPTY_VAL = 2; // Value for almost empty flag
parameter MEM_STYLE = "M9K"; // FIFO memory type (D-flip-flop, BRAM)

localparam FIFO_DEPTH = 2 ** ADDR_WIDTH; // FIFO depth

//=====================================================================================
// Testbench signals
//=====================================================================================	
logic clk; // Clock
logic rst_n; // Reset
logic wr_en; // Write enable
logic [DATA_WIDTH - 1:0] data_in; // Input data
logic rd_en; // Read enable
logic [DATA_WIDTH - 1:0] data_out; // Output data
logic full; // Full flag
logic empty; // Empty flag
logic almost_full; // Almost full
logic almost_empty; // Almost empty

//=====================================================================================
// FIFO Instantiation
//=====================================================================================
FIFO #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .ALMOST_FULL_VAL(ALMOST_FULL_VAL), .ALMOST_EMPTY_VAL(ALMOST_EMPTY_VAL), .MEM_STYLE(MEM_STYLE)) dut
(
	.clk(clk),
	.rst_n(rst_n),
	.wr_en(wr_en),
	.data_in(data_in),
	.rd_en(rd_en),
	.data_out(data_out),
	.full(full),
	.empty(empty),
	.almost_full(almost_full),
	.almost_empty(almost_empty)
);

//=====================================================================================
// Clock signal generation
//=====================================================================================
initial begin
	clk = 0;
	forever clk = #(CLK_PERIOD/2) ~clk;
end

//=====================================================================================
// Scoreboard Class
//=====================================================================================
class Scoreboard;
	logic [DATA_WIDTH - 1:0] ref_queue[$];
	int prev_size = 0;
	int current_size = 0;
	int error_count = 0;
	int wr_accepted = 0;
	int rd_accepted = 0;
	int wr_rejected = 0;
	int rd_rejected = 0;
	int wr_rd_both = 0;

//=====================================================================================
// Reference FIFO Update Function
//=====================================================================================	
	function void update (logic wr, logic rd, logic [DATA_WIDTH - 1:0] din);
		prev_size = ref_queue.size();
		if (wr && prev_size < FIFO_DEPTH) begin
			ref_queue.push_back(din);
			wr_accepted++;
		end
		else if (wr) begin
			wr_rejected++;
		end
		if (rd && prev_size != 0) begin
			ref_queue.pop_front();
			rd_accepted++;
		end
		else if (rd) begin
			rd_rejected++;
		end
		if (wr && rd) begin
			wr_rd_both++;
		end
		current_size = ref_queue.size();
	endfunction

//=====================================================================================
// FIFO Check Function
//=====================================================================================	
	function void check (logic f, logic e, logic af, logic ae, logic [DATA_WIDTH - 1:0] dout);
		logic expected_full = (current_size == FIFO_DEPTH);
		logic expected_empty = (current_size == 0);
		logic expected_almost_full = (prev_size >= ALMOST_FULL_VAL);
		logic expected_almost_empty = (prev_size <= ALMOST_EMPTY_VAL);
		
		if (f != expected_full) begin
			$error("[ERROR] Full mismatch! Current size: %0d. Expected Full: %0b | Got Full: %0b", current_size, expected_full, f);
			error_count++;
		end
		if (e != expected_empty) begin
			$error("[ERROR] Empty mismatch! Current size: %0d. Expected Empty: %0b | Got Empty: %0b", current_size, expected_empty, e);
			error_count++;
		end
		if (af != expected_almost_full) begin
			$error("[ERROR] Almost Full mismatch! Current size: %0d. Expected Almost Full: %0b | Got Almost Full: %0b", current_size, expected_almost_full, af);
			error_count++;
		end
		if (ae != expected_almost_empty) begin
			$error("[ERROR] Almost Empty mismatch! Current size: %0d. Expected Almost Empty: %0b | Got Almost Empty: %0b", current_size, expected_almost_empty, ae);
			error_count++;
		end
		if (!expected_empty) begin
			if (dout != ref_queue[0]) begin
				$error("[ERROR] Data out mismatch! Current size: %0d. Expected Data: %0b | Got Data: %0b", current_size, ref_queue[0], dout);
				error_count++;
			end
		end
	endfunction
endclass

Scoreboard sb = new();

//=====================================================================================
// Scoreboard Updata and Check in Every Clock Cycle
//=====================================================================================
always @ (posedge clk) begin
	if (rst_n) begin
		sb.update(wr_en, rd_en, data_in);
		#1; // Outputs are checked 1 ns after the edge
		sb.check(full, empty, almost_full, almost_empty, data_out);
	end
end

//=====================================================================================
// Stimulus task - one clock cycle
//=====================================================================================
task automatic drive (input logic wr, input logic rd);
	wr_en = wr;
	rd_en = rd;
	data_in = $urandom();
	@(negedge clk);
endtask

//=====================================================================================
// FIFO Data Write Task
//=====================================================================================
task automatic data_write ();
	drive(1'b1, 1'b0);
endtask

//=====================================================================================
// FIFO Data Read Task
//=====================================================================================
task automatic data_read ();
	drive(1'b0, 1'b1);
endtask

//=====================================================================================
// FIFO Idle Task
//=====================================================================================
task automatic data_idle ();
	drive(1'b0, 1'b0);
endtask

//=====================================================================================
// Random Read and Write Task
//=====================================================================================
task automatic random_stimulus ();
	drive($urandom_range(0, 1), $urandom_range(0, 1));
endtask

//=====================================================================================
// Main initial block
//=====================================================================================
initial begin
	$display("\n\nSTARTING TESTBENCH FOR FIFO (DATA_WIDTH = %0d, ADDR_WIDTH = %0d, ALMOST_FULL_VAL = %0d, ALMOST_EMPTY_VAL = %0d)", DATA_WIDTH, ADDR_WIDTH, ALMOST_FULL_VAL, ALMOST_EMPTY_VAL);
	rst_n = 0;
	wr_en = 0;
	rd_en = 0;
	data_in = 0;
	
	repeat (RESET_CYCLES) begin
		@(posedge clk);
	end
	#1;
	rst_n = 1'b1;

// Test 1: Writing to the FIFO before setting almost full
	$display("[%0t] TEST 1: Writing to the FIFO before setting almost full", $time);
	while (sb.current_size != ALMOST_FULL_VAL) begin
		data_write();
	end
	data_idle();

// Test 2: Writing to the FIFO before setting full
	$display("[%0t] TEST 2: Writing to the FIFO before setting full", $time);
	while (sb.current_size != FIFO_DEPTH) begin
		data_write();
	end
	data_idle();

// Test 3: Reading from the FIFO before setting almost empty
	$display("[%0t] TEST 3: Reading from the FIFO before setting almost empty", $time);
	while (sb.current_size != ALMOST_EMPTY_VAL) begin
		data_read();
	end
	data_idle();

// Test 4: Reading from the FIFO before setting empty
	$display("[%0t] TEST 4: Reading from the FIFO before setting empty", $time);
	while (sb.current_size != 0) begin
		data_read();
	end
	data_idle();
	
// Test 5: Random reading and writing
	$display("[%0t] TEST 5: Random reading and writing", $time);
	repeat (RAND_CYCLES) begin
		random_stimulus();
	end
	data_idle();
	
	$display("[%0t] Statistics: writes accepted/rejected(full) = %0d/%0d, reads accepted/rejected(empty) = %0d/%0d, simultaneous read and write = %0d", $time, sb.wr_accepted, sb.wr_rejected, sb.rd_accepted, sb.rd_rejected, sb.wr_rd_both);
	if (sb.error_count == 0) begin
		$display("[PASS] FIFO MODULE TESTS PASSED!");
	end
	else begin
		$display("[FAIL] TESTS FAILED! %0d errors detected!", sb.error_count);
	end
	$stop;
end

endmodule