`timescale 1ns / 1ps
`default_nettype none

module trail_iir
  #(
    // parameter THRESHOLD = 216, // currently not in use, moved threshold to be controlled by switches
    parameter DECAY = 24'b111110101110000101000111 // 0.98 to binary fraction
)
   (
    input wire 		clk_in,
    input wire 		rst_in,
    input wire 		mask_in,
    input wire [7:0] 	threshold_in,
    input wire 		valid_in,
    input wire [23:0] 	history_in,
    input wire [23:0] 	camera_in,
    output logic [23:0] update_out,
    output logic 	valid_out
    );
   

   logic [7:0] 		history_y;
   logic [7:0] 		camera_y;
   rgb_to_y history_rgby
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .red_in(history_in[23:16]),
      .green_in(history_in[15:8]),
      .blue_in(history_in[7:0]),
      .y_out(history_y)
      );

   rgb_to_y camera_rgby
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .red_in(camera_in[23:16]),
      .green_in(camera_in[15:8]),
      .blue_in(camera_in[7:0]),
      .y_out(camera_y)
      );

   // delay 1 cycle to match luminance
   logic [23:0] 	history_buf;
   logic [23:0] 	camera_buf;
   logic 		valid_buf;
   
   always_ff @(posedge clk_in) begin
      history_buf <= history_in;
      camera_buf <= camera_in;
      valid_buf <= valid_in;
   end

   // calculate decay on buffered history
   logic [31:0] decay_r_full;
   logic [31:0] decay_g_full;
   logic [31:0] decay_b_full;
   
   logic [7:0] decay_r;
   logic [7:0] decay_g;
   logic [7:0] decay_b;
   
   assign decay_r_full = (history_buf[23:16])*DECAY;
   assign decay_g_full = (history_buf[15:8])*DECAY;
   assign decay_b_full = (history_buf[7:0])*DECAY;

   assign decay_r = decay_r_full >> 24;
   assign decay_g = decay_g_full >> 24;
   assign decay_b = decay_b_full >> 24;
   
   logic [23:0] hisbuf_decay;
   assign hisbuf_decay = {decay_r,decay_g,decay_b};
   
   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 valid_out <= 1'b0;
	 update_out <= 0;
	 
      end else if (valid_buf) begin
	 valid_out <= 1'b1;
	 if (mask_in) begin // extra stuff, just to see the threshold
	    update_out <= (camera_y > threshold_in) ? camera_buf : 24'b0;
	 end else begin
	    update_out <= (history_y > camera_y && history_y > threshold_in) ? hisbuf_decay : camera_buf;
	 end
	 
      end else begin
	 valid_out <= 1'b0;
      end
   end
      

endmodule // trail_iir

`default_nettype wire
