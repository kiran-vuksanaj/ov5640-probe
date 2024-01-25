`timescale 1ns / 1ps

module i2c_tb;

   logic clk_in;
   logic rst_in;

   logic init_valid;
   logic init_ready;

   wire  scl_pin;
   wire  sda_pin;

   logic [23:0] bram_dout;
   logic [8:0] 	bram_addr;


   camera_registers tcr
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .init_valid(init_valid),
      .init_ready(init_ready),
      .scl_pin(scl_pin),
      .sda_pin(sda_pin),
      .bram_dout(bram_dout),
      .bram_addr(bram_addr));

   always begin
      #5;
      clk_in = ~clk_in;
   end
   initial begin
      clk_in = 0;
   end

   initial begin
      $dumpfile("i2c.vcd");
      $dumpvars(0, i2c_tb);

      $display("starting sim");
      rst_in = 0;
      init_valid = 0;
      
      #6;
      rst_in = 1;
      #10;
      rst_in = 0;
      #50;
      init_valid = 1;
      bram_dout = 24'hAABBCC;
      #10;
      init_valid = 0;
      #2_000_000;
      bram_dout = 24'h000000;
      #1_000_000;
      $display("sim complete");
      $finish;
   end // initial begin
   
endmodule // i2c_tb
