`timescale 1ns / 1ps
`default_nettype none 
module video_sig_gen
  #(
    parameter ACTIVE_H_PIXELS = 1280,
    parameter H_FRONT_PORCH = 110,
    parameter H_SYNC_WIDTH = 40,
    parameter H_BACK_PORCH = 220,
    parameter ACTIVE_LINES = 720,
    parameter V_FRONT_PORCH = 5,
    parameter V_SYNC_WIDTH = 5,
    parameter V_BACK_PORCH = 20)
   (
    input wire 				    clk_pixel_in,
    input wire 				    rst_in,
    output logic [$clog2(TOTAL_PIXELS)-1:0] hcount_out,
    output logic [$clog2(TOTAL_LINES)-1:0]  vcount_out,
    output logic 			    vs_out,
    output logic 			    hs_out,
    output logic 			    ad_out,
    output logic 			    nf_out,
    output logic [5:0] 			    fc_out);

   localparam TOTAL_PIXELS = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH; //figure this out
   localparam TOTAL_LINES = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH; //figure this out

   
   //your code here
   logic 				    rst_prev;
   logic [$clog2(TOTAL_PIXELS)-1:0] 	    next_h;
   logic [$clog2(TOTAL_LINES)-1:0] 	    next_v;
   
   assign next_h = (hcount_out+1 == TOTAL_PIXELS) ? 0 : hcount_out+1;
   assign next_v = (next_h == 0) ?
		   ( (vcount_out+1 == TOTAL_LINES) ? 0 : vcount_out+1 ) :
		   vcount_out;
   
   
   
   always_ff @(posedge clk_pixel_in) begin
      if (rst_in) begin
	 // nothing should be outputting!
	 hcount_out <= 0;
	 vcount_out <= 0;
	 vs_out <= 0;
	 hs_out <= 0;
	 ad_out <= 0;
	 nf_out <= 0;
	 fc_out <= 0;
      end else if (rst_prev && !rst_in) begin
	 // deassertion: proceed to starting pixel 0,0
	 hcount_out <= 0;
	 vcount_out <= 0;
	 ad_out <= 1;
      end else begin

	 vs_out <= (next_v >= ACTIVE_LINES+V_FRONT_PORCH && next_v < ACTIVE_LINES+V_FRONT_PORCH+V_SYNC_WIDTH);
	 hs_out <= (next_h >= ACTIVE_H_PIXELS+H_FRONT_PORCH && next_h < ACTIVE_H_PIXELS+H_FRONT_PORCH+H_SYNC_WIDTH);
	 ad_out <= (next_v < ACTIVE_LINES && next_h < ACTIVE_H_PIXELS);
	 nf_out <= (next_v == ACTIVE_LINES && next_h == ACTIVE_H_PIXELS);
	 if (next_v == ACTIVE_LINES && next_h == ACTIVE_H_PIXELS) begin
	    fc_out <= (fc_out+1 == 60) ? 0 : fc_out+1;
	 end
	 
	 hcount_out <= next_h;
	 vcount_out <= next_v;
	 
      end

      rst_prev <= rst_in;
   end
   

endmodule

`default_nettype wire
