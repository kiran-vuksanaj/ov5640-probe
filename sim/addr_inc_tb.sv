`timescale 1ns / 1ps
	 
module addr_inc_tb;

   logic clk;
   logic rst;
   
   logic incr_in1;
   logic [5:0] addr_out1;
   logic       calib_in1;
   
   addr_increment 
     #(.ROLLOVER(64),
       .RST_ADDR(24),
       .INCR_AMT(4)) aitm1
       (.clk_in(clk),
	.rst_in(rst),
	.calib_in(calib_in1),
	.incr_in(incr_in1),
	.addr_out(addr_out1)
	);

   logic       incr_in2;
   logic [3:0] addr_out2;
   logic       calib_in2;
   
   addr_increment
     #(.ROLLOVER(11),
       .RST_ADDR(0)) aitm2
       (.clk_in(clk),
	.rst_in(rst),
	.calib_in(calib_in2),
	.incr_in(incr_in2),
	.addr_out(addr_out2)
	);
   
      

   always begin
      #5;
      clk = ~clk;
   end
   initial begin
      clk = 0;
   end

   initial begin
      $dumpfile("fifo.vcd");
      $dumpvars(0, addr_inc_tb);


      $display("Starting sim");
      rst = 0;
      incr_in1 = 0;
      incr_in2 = 0;
      calib_in1 = 0;
      calib_in2 = 0;
      
      #16;

      rst = 1;
      #10;

      rst = 0;
      incr_in1 = 0;
      incr_in2 = 1;
      #10;

      incr_in1 = 1;
      incr_in2 = 1;
      #10;

      rst = 1;
      incr_in1 = 1;
      incr_in2 = 1;
      #10;

      rst = 0;
      incr_in1 = 1;
      incr_in2 = 1;
      #10;

      incr_in1 = 1;
      incr_in2 = 1;
      #10;

      incr_in1 = 0;
      incr_in2 = 0;
      #10;

      incr_in1 = 0;
      incr_in2 = 0;
      #10;

      incr_in1 = 0;
      incr_in2 = 0;
      #10;

      incr_in1 = 1;
      incr_in2 = 1;
      #10;

      incr_in1 = 1;
      incr_in2 = 1;
      #10;

      incr_in1 = 1;
      incr_in2 = 1;
      #10;

      incr_in1 = 1;
      incr_in2 = 1;
      #10;

      incr_in1 = 1;
      incr_in2 = 1;
      #10;
      
      incr_in1 = 1;
      incr_in2 = 1;
      #10;
      
      incr_in1 = 1;
      incr_in2 = 1;
      #10;
      
      incr_in1 = 1;
      incr_in2 = 1;
      #10;
      
      incr_in1 = 1;
      incr_in2 = 1;
      calib_in1 = 1;
      calib_in2 = 1;
      #10;
      
      incr_in1 = 1;
      incr_in2 = 1;
      calib_in1 = 0;
      calib_in2 = 0;
      #10;
      
      incr_in1 = 1;
      incr_in2 = 1;
      #10;
      
      incr_in1 = 0;
      incr_in2 = 0;
      #10;
      
      incr_in1 = 1;
      incr_in2 = 1;
      #10;
      
      $finish;
      
   end

   

endmodule // fifo_tb
