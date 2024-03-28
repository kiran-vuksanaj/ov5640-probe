`timescale 1ns / 1 ps

module dvp_receiver_tb;

   // toy situation test cases
   logic clk;
   logic rst;

   logic        valid_in;
   logic [15:0] pixel_in;
   logic 	hsync_in;
   logic 	vsync_in;
   
   logic 	valid_out;
   logic [15:0] pixel_out;
   logic [12:0] hcount_out;
   logic [11:0] vcount_out;

   // hsync length == 1, > 1
   // vsync length == 1, > 1
   // rst happens at initial, from steady state
   // data changes each cycle, still matches proper output
   // valid signal during (hsync==vsync==1), (hsync==vsync==0), (hsync==1, vsync==0), (hsync==0, vsync==1)

   logic [19:0] mem_out;
   logic 	memread_done;
   
   sim_sample_read
     #(.FILENAME("sim/test.hex"),
      .HEX_WIDTH(20),
      .HEX_DEPTH(17)) reader 
       (
	.clk_in(clk),
	.rst_in(rst),
	.data_out(mem_out),
	.done_out(memread_done)
	);

   assign pixel_in = mem_out[19:4];
   assign vsync_in = mem_out[2];
   assign hsync_in = mem_out[1];
   assign valid_in = mem_out[0];
		
   // only check outputs when valid goes high! don't care what extranneous values come otherwise
   // but DO check whether valid is going high at the right times

   dvp_receiver dut
     (.clk_in(clk),
      .rst_in(rst),
      .valid_in(valid_in),
      .pixel_in(pixel_in),
      .hsync_in(hsync_in),
      .vsync_in(vsync_in),
      .valid_out(valid_out),
      .pixel_out(pixel_out),
      .hcount_out(hcount_out),
      .vcount_out(vcount_out)
      );

   // initialize clock
   always begin
      #5;
      clk = ~clk;
   end
   initial begin
      clk = 0;
   end

   // vars for testing one-cycle-after
   logic [15:0] pixel_del;
   logic 	hsync_del;
   logic 	vsync_del;
   logic 	valid_del;

   always_ff @(posedge clk) begin
      pixel_del <= pixel_in;
      hsync_del <= hsync_in;
      vsync_del <= vsync_in;
      valid_del <= valid_in;
   end

   // test case reaction: only care what happens on signal 1 cycle after a valid_in
   // so check then and print out data!
   always @(posedge clk) begin // should this be an _ff?
      $display("%x",mem_out);
      if (valid_del) begin
	 if ( hsync_del && vsync_del ) begin
	    $display("%t [TEST_PASSTHROUGH] %b",$time,valid_out);
	    $display("%t [TEST_HCOUNT] %d",$time,hcount_out);
	    $display("%t [TEST_VCOUNT] %d",$time,vcount_out);
	    $display("%t [TEST_PIXEL] %x",$time,pixel_out);
	 end else begin
	    // should have made this valid data become invalid, no valid out signal
	    $display("%t [TEST_INVALIDATE] %b",$time, valid_out);
	 end
      end
   end

   always @(posedge clk) begin
      if (memread_done) begin
	 $display("sim complete");
	 $finish;
      end
   end
   
   // actual test cases
   initial begin
      $display("Starting sim");
      $dumpfile("dvp_rcv.vcd");
      $dumpvars(0, dvp_receiver_tb);
      
      // reset signal
      rst = 0;
      #6;
      rst = 1;
      #10;
      rst = 0;


      #20_000;
      $display("timeout");
      $finish;
   end

endmodule

