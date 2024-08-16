`timescale 1ns / 1ps
`default_nettype none

/* module cursor
 *  little baby module to manage all state for a signal meant to increment
 *  through values
 * 
 *  - cursor_out increases each cycle incr_in is high
 *  - if setval_in is asserted, cursor_out matches manual_in
 *  - if cursor_out reaches ROLLOVER, it returns to RESET_VAL and
 *    rollover_out issues a single_cycle_high
 */
module cursor #
  (parameter WIDTH = 27,
   parameter RESET_VAL = 0,
   parameter ROLLOVER = 0,
   parameter INCR_AMT = 1)
   (
    input wire 		     clk_in,
    input wire 		     rst_in,
    input wire 		     incr_in,
    input wire 		     setval_in,
    input wire [WIDTH-1:0]   manual_in,
    output logic [WIDTH-1:0] cursor_out,
    output logic 	     rollover_out);

   logic [WIDTH-1:0] 	     next_cursor;
   always_comb begin
      if (rst_in) next_cursor = RESET_VAL;
      else if (setval_in) next_cursor = manual_in;
      else if (incr_in) begin
	 if (cursor_out + INCR_AMT == ROLLOVER) next_cursor = RESET_VAL;
	 else next_cursor = cursor_out + INCR_AMT;
      end else next_cursor = cursor_out;
   end

   logic next_rollover;
   assign next_rollover = ~rst_in && incr_in && next_cursor == RESET_VAL;
   
   always_ff @(posedge clk_in) begin
      cursor_out <= next_cursor;
      rollover_out <= next_rollover;
   end
   
endmodule
   
`default_nettype wire
