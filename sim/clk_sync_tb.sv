`timescale 1ns / 1ps
	 
module clk_sync_tb;

   logic clk_slow;
   logic clk_fast;
   logic rst_fast;

   logic signal_fast;
   logic signal_slow;
   
   slow_clock_sync scstm
     (.clk_fast(clk_fast),
      .rst_fast(rst_fast),
      .signal_fast(signal_fast),
      .clk_slow(clk_slow),
      .signal_slow(signal_slow));

   always begin
      #5;
      clk_fast = ~clk_fast;
   end
   always begin
      #14;
      clk_slow = ~clk_slow;
   end
   initial begin
      clk_fast = 0;
      clk_slow = 0;
   end

   initial begin
      $dumpfile("clock.vcd");
      $dumpvars(0, clk_sync_tb);


      $display("Starting sim");
      rst_fast = 0;
      #16;
      rst_fast = 1;
      #10;
      rst_fast = 0;
      signal_fast = 0;
      #30;
      signal_fast = 1;
      #10;
      signal_fast = 0;
      #40;
      signal_fast = 1;
      #10;
      signal_fast = 0;
      #100;
      
      $display("sim done");
      $finish;
      
   end

   

endmodule // fifo_tb
