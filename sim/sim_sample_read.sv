`timescale 1ns / 1ps

module sim_sample_read
  #(parameter FILENAME = "set_filename.hex",
    parameter HEX_WIDTH = 24,
    parameter HEX_DEPTH = 64)
   (input wire clk_in,
    input wire rst_in,
    output logic [HEX_WIDTH-1:0] data_out,
    output logic done_out
    );

   // for simulation: the bits of the output data cycle through the hex file
   // updating on each rising clock edge

   logic [HEX_WIDTH-1:0] 	 mem_block [HEX_DEPTH-1:0];
   initial begin
      $readmemh(FILENAME,mem_block);
      cursor = 0;
   end
   
   logic [$clog2(HEX_DEPTH)-1:0] cursor;

   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 cursor <= 0;
	 data_out <= 0;
	 done_out <= 0;
      end else begin
	 data_out <= mem_block[cursor];
	 cursor <= (cursor + 1 == HEX_DEPTH) ? 0 : cursor + 1;
	 done_out <= (cursor + 1 == HEX_DEPTH || cursor + 1 == 0);
      end
   end
   
endmodule // sim_sample_read

    
    
