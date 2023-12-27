`timescale 1ns / 1ps

module build_data_tb;

   logic clk;
   logic rst;

   logic valid_in;
   logic ready_in;
   logic [15:0] data_in;

   logic 	valid_out;
   logic 	ready_out;
   logic [127:0] data_out;

   build_wr_data bwdtm
     (.clk_in(clk),
      .rst_in(rst),
      .valid_in(valid_in),
      .ready_in(ready_in),
      .data_in(data_in),
      .valid_out(valid_out),
      .ready_out(ready_out),
      .data_out(data_out));
   
   
   always begin
      #5;
      clk = ~clk;
   end

   initial begin
      clk = 0;
   end

   initial begin
      $dumpfile("sim/builder.vcd");
      $dumpvars(0, build_data_tb);

      $display("starting sim");
      rst = 0;
      #16;
      rst = 1;
      #10;
      rst = 0;
      valid_in = 0;
      ready_out = 1;
      data_in = 0;
      #10;

      valid_in = 1;
      data_in = 16'hABCD;
      #10;

      data_in = 16'hDCBA;
      #10;

      data_in = 16'h1234;
      #10;

      data_in = 16'h5678;
      #10;

      data_in = 16'h7654;
      #10;

      data_in = 16'h3210;
      #10;

      data_in = 16'hDEAD;
      #10;

      data_in = 16'hBEEF;
      #10;

      data_in = 16'h7777;
      #10;

      ready_out = 0;
      data_in = 16'h6666;
      #10;

      ready_out = 1;
      valid_in = 0;
      data_in = 16'h5555;
      #10;

      valid_in = 1;
      data_in = 16'h4444;
      #10;
      #200;

      $display("sim complete");
      $finish;
   end
endmodule // build_data_tb
