`timescale 1ns / 1ps
`default_nettype none

module camera_bare
  (
   input wire 	       clk_pixel_in,
   input wire 	       pclk_cam_in,
   input wire 	       hs_cam_in,
   input wire 	       vs_cam_in,
   input wire 	       rst_in,
   input wire [7:0]    data_cam_in,
   output logic        hs_cam_out,
   output logic        vs_cam_out,
   output logic [15:0] data_out,
   output logic        valid_out,
   output logic        valid_byte
   );
   logic 	       pclk_prev;
   logic 	       vsync_prev;
   logic 	       clk_rise;
   logic 	       real_pixel;
   logic 	       real_pixel_prev;
   
   logic 	       hi_byte;
   logic 	       new_row;
      
   assign clk_rise = pclk_cam_in && !pclk_prev;
   assign real_pixel = hs_cam_in && vs_cam_in;
   
   always_ff @(posedge clk_pixel_in) begin
      if(rst_in) begin
	 hi_byte <= 1;
	 real_pixel_prev <= 1'b0;
	 new_row <= 0;
	 vsync_prev <= 0;
	 valid_byte <= 1'b0;
      end else begin
	 if (clk_rise) begin
	    hs_cam_out <= hs_cam_in;
	    vs_cam_out <= vs_cam_in;
	    if (hi_byte) begin
	       data_out[15:8] <= data_cam_in;
	       valid_out <= 1'b0;
	    end else begin
	       data_out[7:0] <= data_cam_in;
	       // valid_out <= new_row ? 1'b0 : 1'b1; // if its a new row, wait a cycle!
	       valid_out <= 1'b1; // i am, sus of this change to say the least...
	    end
	    hi_byte <= (~real_pixel_prev && real_pixel) ? 1'b0 : ~hi_byte; // spot check change
	    // sync data: when new row starts (first real pixel data), that's a first-half byte
	    new_row <= (~real_pixel_prev && real_pixel);
	    vsync_prev <= vs_cam_in;
	    real_pixel_prev <= real_pixel;
	 end else begin // if (clk_rise)
	    valid_out <= 1'b0;
	 end // else: !if(clk_rise)
	 valid_byte <= clk_rise;
      end // else: !if(rst_in)
      pclk_prev <= pclk_cam_in;
   end
   
endmodule // camera_bare


`default_nettype wire
