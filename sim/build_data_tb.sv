`timescale 1ns / 1ps

module build_data_tb;

   logic clk;
   logic rst;

   logic valid_in;
   logic ready_in;
   logic [15:0] data_in;
   logic 	newframe_in;

   logic 	valid_out;
   logic 	ready_out;
   logic [127:0] data_out;
   logic 	 tuser_out;

   build_wr_data bwdtm
     (.clk_in(clk),
      .rst_in(rst),
      .valid_in(valid_in),
      .ready_in(ready_in),
      .data_in(data_in),
      .newframe_in(newframe_in),
      .valid_out(valid_out),
      .ready_out(ready_out),
      .data_out(data_out),
      .tuser_out(tuser_out));
   
   
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
      newframe_in = 0;
      #10;

      valid_in = 1;
      data_in = 16'hABCD;
      newframe_in = 0;
      #10;
      valid_in = 0;
      newframe_in = 0;
      #20;

      valid_in = 1;
      data_in = 16'hDCBA;
      #10;
      valid_in = 0;
      #20;


      valid_in = 1;
      data_in = 16'h1234;
      #10;
      valid_in = 0;
      #20;


      valid_in = 1;
      data_in = 16'h5678;
      #10;
      valid_in = 0;
      #20;


      valid_in = 1;
      data_in = 16'h7654;
      #10;
      valid_in = 0;
      #20;


      valid_in = 1;
      data_in = 16'h3210;
      #10;
      valid_in = 0;
      #20;


      valid_in = 1;
      data_in = 16'hDEAD;
      #10;
      valid_in = 0;
      #20;


      valid_in = 1;
      ready_out = 0;
      data_in = 16'hBEEF;
      #10;
      valid_in = 0;
      #20;


      valid_in = 1;
      data_in = 16'hFFFF;
      #10;
      valid_in = 0;
      #20;


      ready_out = 1;
      valid_in = 1;
      data_in = 16'hEEEE;
      #10;
      valid_in = 0;
      #20;


      valid_in = 0;
      data_in = 16'hABBA;
      #10;
      valid_in = 0;
      #20;


      valid_in = 1;
      data_in = 16'h4444;
      #100;
      newframe_in = 1;
      data_in = 16'h5555;
      #10;
      newframe_in = 0;
      #200;

      $display("sim complete");
      $finish;
   end
endmodule // build_data_tb
