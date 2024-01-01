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
    output logic [127:0] data_out
    );

   logic [15:0] 	 words [7:0]; // unpacked version of data_out
   logic 		 accept_in;
   logic [2:0] 		 offset;
   logic 		 offset_rollover;
   logic 		 phrase_taken;
   
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
      .addr_out(offset),
      .rollover_out(offset_rollover));

   assign ready_in = phrase_taken;
   assign accept_in = ready_in && valid_in;
   assign valid_out = (offset_rollover) || ~phrase_taken;

   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 phrase_taken <= 1'b1;
      end else begin
	 if (accept_in) begin
	    // write data to proper section of phrasedata
	    words[offset] <= data_in;
	 end
	 if (offset == 7 || ~phrase_taken) begin
	    phrase_taken <= ready_out;
	 end
      end
   end
   
endmodule // build_wr_data

module digest_phrase
  (
   input wire 	       clk_in,
   input wire 	       rst_in,
   // input axis: 128 bit phrases
   input wire 	       valid_phrase,
   output logic        ready_phrase,
   input wire [127:0]  phrase_data,
   // output axis: 16 bit words
   output logic        valid_word,
   input wire 	       ready_word,
   output logic [15:0] word
   );


   logic [2:0] 	       offset;
   addr_increment #(.ROLLOVER(8)) aio
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .incr_in( ready_word && valid_word ),
      .addr_out(offset));

   logic [127:0]       phrase;
   logic [15:0]        words[7:0]; // unpacked phrase
   assign words[7] = phrase[15:0];
   assign words[6] = phrase[31:16];
   assign words[5] = phrase[47:32];
   assign words[4] = phrase[63:48];
   assign words[3] = phrase[79:64];
   assign words[2] = phrase[95:80];
   assign words[1] = phrase[111:96];
   assign words[0] = phrase[127:112];

   logic 	       needphrase;
   
   assign valid_word = ~needphrase; // lock output + keep offset=0 while
   
   assign ready_phrase = ((offset == 7) && ready_word) ||
			 ((offset == 0) && needphrase);
   
   assign word = words[offset];
   
   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 phrase <= 128'b0;
	 needphrase <= 1'b1;
      end else begin
	 if (ready_phrase) begin
	    if (valid_phrase) begin
	       needphrase <= 1'b0;
	       phrase <= phrase_data;
	    end else begin
	       needphrase <= 1'b1;
	    end
	 end
      end
   end
   
endmodule   

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
