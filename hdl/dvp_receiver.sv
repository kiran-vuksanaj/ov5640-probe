`timescale 1ns / 1ps
`default_nettype none

module dvp_receiver
  (
   input wire 	       clk_in,
   input wire 	       rst_in,
   input wire 	       valid_in,
   input wire [15:0]   pixel_in,
   input wire 	       hsync_in,
   input wire 	       vsync_in,
   output logic        valid_out,
   output logic [15:0] pixel_out,
   output logic [12:0] hcount_out,
   output logic [11:0] vcount_out
   );
   logic 	       hsync_prev;
   logic 	       vsync_prev;

   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 hcount_out <= 0;
	 vcount_out <= 0;
	 pixel_out <= 0;
	 valid_out <= 0;
      end else if (valid_in) begin
	 if (!vsync_in && vsync_prev) begin
	    hcount_out <= 0;
	    vcount_out <= 0;
	    pixel_out <= 0;
	    valid_out <= 0;
	 end else if (!hsync_in && hsync_prev) begin
	    hcount_out <= 0;
	    vcount_out <= vcount_out + 1;
	    pixel_out <= 0;
	    valid_out <= 0;
	 end else if (hsync_in && vsync_in) begin
	    valid_out <= 1;
	    hcount_out <= hcount_out + 1;
	    pixel_out <= pixel_in;
	 end
	 hsync_prev <= hsync_in;
	 vsync_prev <= vsync_in;
      end else begin // if (pixel_valid_in)
	 valid_out <= 0;
      end // else: !if(pixel_valid_in)
   end

endmodule // camera_store

`default_nettype wire

   
