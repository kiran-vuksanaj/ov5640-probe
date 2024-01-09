`timescale 1ns / 1ps
`default_nettype none

//written in lab!
//debounce_2.sv is a different attempt at this done after class with a few students
module  debouncer #(
  parameter CLK_PERIOD_NS = 5,
  parameter DEBOUNCE_TIME_MS = 5
) (
  input wire clk_in,
  input wire rst_in,
  input wire dirty_in,
  output logic clean_out
);
  
  parameter COUNTER_MAX = int($ceil(DEBOUNCE_TIME_MS*1_000_000/CLK_PERIOD_NS));
  parameter COUNTER_SIZE = $clog2(COUNTER_MAX);
  logic [COUNTER_SIZE-1:0] counter;
  logic current; //register holds current output
  logic old_dirty_in;
  assign clean_out = current;

  always_ff @(posedge clk_in) begin
    if (rst_in)begin
      counter <= 0;
      current <= dirty_in;
      old_dirty_in <= dirty_in;
    end else begin
      if (counter == COUNTER_MAX-1)begin
        current <= old_dirty_in;
        counter <= 0;
      end else if (dirty_in == old_dirty_in) begin
        counter <= counter +1;
      end else begin
        counter <= 0;
      end
    end
    old_dirty_in <= dirty_in;
  end
endmodule

module slow_clock_sync #(parameter WIDEN_CYCLES=3)
   (input wire clk_fast,
    input wire rst_fast,
    input wire 	 signal_fast,
    input wire 	 clk_slow,
    output logic signal_slow);

   logic [WIDEN_CYCLES-1:0] signal_fast_history;
   
   logic 		    signal_wide;
   assign signal_wide = signal_fast_history > 0;
   
   always_ff @(posedge clk_fast) begin
      if (rst_fast) begin
	 signal_fast_history <= 0;
      end else begin
	 signal_fast_history <= {signal_fast_history[WIDEN_CYCLES-2:0],signal_fast};
      end
   end

   logic signal_slow_tmp;
   always_ff @(posedge clk_slow) begin
      signal_slow_tmp <= signal_wide;
      signal_slow <= signal_slow_tmp;
   end
endmodule // slow_clock_sync

`default_nettype wire
