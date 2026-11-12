//=====================================================================================
//			FIFO Module
//
//			Parameters:
//				DATA_WIDTH - input and output data width
//				ADDR_WIDTH - FIFO address width
//				ALMOST_FULL_VAL - value for almost full flag
//				ALMOST_EMPTY_VAL - value for almost empty flag
//				MEM_STYLE - FIFO memory type (D-flip-flop, BRAM)
//
//			Control Signals:
//				clk - clock signal
//				rst_n – reset (Active-Low)
//				wr_en - write enable signal
//				rd_en - read enable signal
//
//			Data:
//				data_in - input data
//				data_out - output data
//				full - FIFO full flag
//				empty - FIFO empty flag
//				almost_full - FIFO almost full flag
//				almost_empty - FIFO almost empty flag
//=====================================================================================

module FIFO
#(
	parameter DATA_WIDTH = 8,
	parameter ADDR_WIDTH = 4,
	parameter ALMOST_FULL_VAL = 2 ** ADDR_WIDTH - 2,
	parameter ALMOST_EMPTY_VAL = 2,
	parameter MEM_STYLE = "M9K" // "logic" for D-flip-flops, "M9K" for BRAM MAX10
)
(
	input clk, // Clock
	input rst_n, // Reset
	input wr_en, // Write enable
	input [DATA_WIDTH - 1:0] data_in, // Input data
	input rd_en, // Read enable
	output [DATA_WIDTH - 1:0] data_out, // Output data
	output reg full, // Full flag
	output reg empty, // Empty flag
	output reg almost_full, // Almost full
	output reg almost_empty // Almost empty
);

localparam FIFO_DEPTH = 2 ** ADDR_WIDTH; // FIFO depth

(* ramstyle = MEM_STYLE *) reg [DATA_WIDTH - 1:0] fifo_mem [0:FIFO_DEPTH - 1]; // Buffer
reg [ADDR_WIDTH:0] wr_ptr, rd_ptr; // Write and Read pointers
wire [ADDR_WIDTH:0] wr_ptr_next, rd_ptr_next; // Write and Read pointers (next value)
wire wr_valid, rd_valid; // Write and Read valid
wire [ADDR_WIDTH:0] num_elements; // Number of elements for almost flags

//=====================================================================================
// FIFO Write and Pointers Registers
//=====================================================================================
always @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		wr_ptr <= {(ADDR_WIDTH + 1){1'b0}};
		rd_ptr <= {(ADDR_WIDTH + 1){1'b0}};
	end
	else begin
		if (wr_valid) begin
			fifo_mem[wr_ptr[ADDR_WIDTH - 1:0]] <= data_in;
			wr_ptr <= wr_ptr_next;
		end
		if (rd_valid) begin
			rd_ptr <= rd_ptr_next;
		end
	end
end

//=====================================================================================
// Flags
//=====================================================================================
always @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		full <= 1'b0;
		empty <= 1'b1;
		almost_full <= 1'b0;
		almost_empty <= 1'b1;
	end
	else begin
		case ({wr_valid, rd_valid})
			2'b10 : begin
				empty <= 1'b0;
				full <= (wr_ptr_next[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && (wr_ptr_next[ADDR_WIDTH - 1:0] == rd_ptr[ADDR_WIDTH - 1:0]);
			end
			2'b01 : begin
				empty <= (rd_ptr_next == wr_ptr);
				full <= 1'b0;
			end
			default : begin
				empty <= empty;
				full <= full;
			end
		endcase
		almost_full <= (num_elements >= ALMOST_FULL_VAL);
		almost_empty <= (num_elements <= ALMOST_EMPTY_VAL);
	end
end

//=====================================================================================
// Write and Read Enable Signals Generation
//=====================================================================================
assign wr_valid = wr_en && !full;
assign rd_valid = rd_en && !empty;

//=====================================================================================
// Pointers next value
//=====================================================================================
assign wr_ptr_next = wr_ptr + 1'b1;
assign rd_ptr_next = rd_ptr + 1'b1;

//=====================================================================================
// Number of elements in FIFO
//=====================================================================================
assign num_elements = wr_ptr - rd_ptr;

//=====================================================================================
// Output Data
//=====================================================================================
assign data_out = fifo_mem[rd_ptr[ADDR_WIDTH - 1:0]];

endmodule