`timescale 1ns / 1ps
`default_nettype none

module one_hertz #
  (
   parameter REF_CLK = 200_000_000
  ) 
   (
    input wire clk_in,
    input wire rst_in,
    output logic one_hz_out
    );

   logic [$clog2(REF_CLK):0] count_cycles;

   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 one_hz_out <= 1'b0;
	 count_cycles <= 1'b0;
      end else begin
	 if (count_cycles == REF_CLK) begin
	    count_cycles <= 1;
	    one_hz_out <= 1'b1;
	 end else begin
	    count_cycles <= count_cycles + 1;
	    one_hz_out <= 1'b0;
	 end
      end
   end

endmodule // one_hertz


module display_hcount_vcount
  (
   input wire 	       clk_in,
   input wire 	       rst_in,
   input wire [12:0]   hcount_in,
   input wire [11:0]   vcount_in,
   input wire 	       hsync_in,
   input wire 	       vsync_in,
   output logic [31:0] display_out
   );

   logic 	hsync_prev;
   logic 	vsync_prev;

   logic [15:0] display_vcount;
   logic [15:0] display_hcount;
   assign display_out = {display_vcount,display_hcount};
   
   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 display_hcount <= 16'b0;
	 display_vcount <= 16'b0;
      end else begin
	 if (vsync_prev && ~vsync_in) begin
	    display_vcount <= vcount_in;
	 end
	 if (hsync_prev && ~hsync_in) begin
	    display_hcount <= hcount_in;
	 end
	 hsync_prev <= hsync_in;
	 vsync_prev <= vsync_in;
      end
   end

endmodule // display_hcount_vcount

module display_cycle_count
  (
   input wire clk_in,
   input wire rst_in,
   input wire one_hz_in,
   input wire valid_byte_in,
   output logic [31:0] display_out
   );

   logic [31:0] display_bin;
   logic [41:0] bcd_full;
   
   bin2bcd #(.W(32)) decm
     (.bin(display_bin),
      .bcd(bcd_full));
   assign display_out = {2'b0,bcd_full[41:12]}; // decimal, in thousands
   // assign display_out = display_bin;
   
   logic [31:0]        count_cycles;

   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 display_bin <= 32'b0;
	 count_cycles <= 0;
      end else begin
	 if (one_hz_in) begin
	    count_cycles <= 0;
	    display_bin <= count_cycles;
	 end else if (valid_byte_in) begin
	    count_cycles <= count_cycles + 1;
	 end
      end
   end
   
endmodule // display_cycle_count

module display_frame_length
  (
   input wire 	       clk_in,
   input wire 	       rst_in,
   input wire 	       vsync_in,
   input wire 	       valid_byte_in,
   output logic [31:0] display_out
   );

   logic 	       vsync_prev;
   logic [31:0]        count_cycles;

   logic [31:0]	       display_bin;
   logic [41:0]        bcd_full;
   bin2bcd #(.W(32)) decm
     (.bin(display_bin),
      .bcd(bcd_full));
   assign display_out = bcd_full[31:0]; // decimal, in thousands

   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 display_bin <= 0;
	 count_cycles <= 0;
	 vsync_prev <= 0;
      end else begin
	 if (valid_byte_in) begin
	    vsync_prev <= vsync_in;

	    if (vsync_prev && ~vsync_in) begin
	       count_cycles <= 0;
	       display_bin <= count_cycles;
	    end else begin
	       count_cycles <= count_cycles + 1;
	    end
	    
	 end
      end // else: !if(rst_in)
   end // always_ff @ (posedge clk_in)
endmodule // display_frame_length


// module for row length + fps
module display_rowlen_fps
  (
   input wire 	       clk_in,
   input wire 	       rst_in,
   input wire 	       hsync_in,
   input wire 	       vsync_in,
   input wire 	       valid_byte_in,
   input wire 	       one_hz_in,
   output logic [31:0] display_out
   );

   logic 	       hsync_prev;
   logic 	       vsync_prev;
   
   logic [15:0]        count_cycles;
   logic [15:0]        count_frames;

   logic [15:0]        display_rowlen;
   logic [15:0]        display_fps;

   logic [20:0]        bcd_cycles;
   logic [20:0]        bcd_frames;
   
   bin2bcd #(.W(16)) decc
     (.bin(display_rowlen),
      .bcd(bcd_cycles));
   bin2bcd #(.W(16)) decf
     (.bin(display_fps),
      .bcd(bcd_frames));
   
   assign display_out = {bcd_frames[15:0],bcd_cycles[15:0]};

   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 hsync_prev <= 0;
	 vsync_prev <= 0;
	 count_cycles <= 0;
	 count_frames <= 0;
	 display_rowlen <= 0;
	 display_fps <= 0;
      end else begin
	 // FPS stuff
	 if (one_hz_in) begin
	    display_fps <= count_frames;
	    count_frames <= 0;
	 end else if (valid_byte_in && vsync_prev && ~vsync_in) begin
	    count_frames <= count_frames + 1;
	 end
	    
	 // rowlen stuff
	 if (valid_byte_in) begin
	    // update previous vals, used for both operations
	    hsync_prev <= hsync_in;
	    vsync_prev <= vsync_in;
	    
	    if (hsync_prev && ~hsync_in) begin
	       display_rowlen <= count_cycles;
	       count_cycles <= 0;
	    end else begin
	       count_cycles <= count_cycles + 1;
	    end
	 end
      end
   end

endmodule // display_rowlen_fps



`default_nettype wire
