`timescale 1ns / 1ps
`default_nettype none

module build_wr_data
   (
    input wire 		 clk_in,
    input wire 		 rst_in,
    // input axis: 16 bit pixels
    input wire 		 valid_in,
    output logic 	 ready_in,
    input wire [15:0] 	 data_in,
    // output axis: 128 bit mig-phrases
    output logic 	 valid_out,
    input wire 		 ready_out,
    output logic [127:0] data_out,
    logic [2:0] 	 offset
    );

   logic [15:0] 	 words [7:0]; // unpacked version of data_out
   logic 		 accept_in;
   // logic [2:0] 	 offset;
   
   assign data_out = {words[0],
		      words[1],
		      words[2],
		      words[3],
		      words[4],
		      words[5],
		      words[6],
		      words[7]};

   addr_increment #(.ROLLOVER(8)) aio
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .incr_in(accept_in),
      .addr_out(offset));

   assign ready_in = ready_out;
   assign accept_in = ready_in && valid_in;

   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 valid_out <= 1'b0;
      end else begin
	 if (accept_in) begin
	    // write data to proper section of phrasedata
	    words[offset] <= data_in;
	    valid_out <= (offset==7);
	 end else begin
	    valid_out <= 1'b0;
	 end
      end
   end
   
endmodule // build_wr_data



module addr_increment
  #(parameter ROLLOVER = 128,
    parameter RST_ADDR = 0,
    parameter INCR_AMT = 1
    )
   (
    input wire clk_in,
    input wire rst_in,
    input wire incr_in,
    output logic [$clog2(ROLLOVER)-1:0] addr_out,
    output logic rollover_out
    );

   // for each cycle that incr_in is high, increment address register--never reach rollover, turn it back to 0.
   
   logic [$clog2(ROLLOVER):0] 		next_addr; // deliberately include extra bit!
   assign next_addr = addr_out + INCR_AMT;

   always @(posedge clk_in) begin
      if (rst_in) begin
	 addr_out <= RST_ADDR;
	 rollover_out <= 0;
      end else begin
	 if (incr_in) begin
	    addr_out <= (next_addr >= ROLLOVER) ? 0 : next_addr;
	    rollover_out <= next_addr >= ROLLOVER || next_addr==0;
	 end else begin
	    rollover_out <= 0;
	 end
      end
   end
endmodule // addr_increment

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
