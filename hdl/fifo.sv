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
    input wire 		 newframe_in,
    // output axis: 128 bit mig-phrases
    output logic 	 valid_out,
    input wire 		 ready_out,
    output logic [127:0] data_out,
    output logic 	 tuser_out
    );

   logic [15:0] 	 words [7:0]; // unpacked version of data_out
   logic 		 accept_in;
   logic [2:0] 		 offset;
   logic 		 offset_rollover;
   logic 		 phrase_taken;
   logic 		 tuser_hold;
      
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
      .calib_in(newframe_in && accept_in),
      .incr_in(accept_in),
      .addr_out(offset),
      .rollover_out(offset_rollover));

   assign ready_in = phrase_taken;
   assign accept_in = ready_in && valid_in;
   assign valid_out = (offset_rollover) || ~phrase_taken || (accept_in && newframe_in);
   assign tuser_out = (accept_in && newframe_in) || tuser_hold;
   
   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 phrase_taken <= 1'b1;
	 tuser_hold <= 1'b0;
      end else begin
	 if (accept_in) begin
	    // write data to proper section of phrasedata
	    words[offset] <= data_in;
	    tuser_hold <= newframe_in;
	    // tuser_out <= (offset == 0) ? newframe_in : (newframe_in || tuser_out);
	 end
	 if (offset == 7 || ~phrase_taken || newframe_in) begin
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
   input wire 	       phrase_tuser,
   // output axis: 16 bit words
   output logic        valid_word,
   input wire 	       ready_word,
   output logic [15:0] word,
   output logic        newframe_out
   );

   // IMPORTANT NOTE
   // newframe_out can be checked whenever valid_word is asserted, /regardless/ of if ready_word is high.
   // user can check whether the /next/ data will be the newframe data, without consuming it!

   logic [2:0] 	       offset;
   addr_increment #(.ROLLOVER(8)) aio
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .calib_in(1'b0),
      .incr_in( ready_word && valid_word ),
      .addr_out(offset));

   logic [127:0]       phrase;
   logic 	       tuser;
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
   assign newframe_out = valid_word && (offset == 0) && tuser;
   
   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 phrase <= 128'b0;
	 needphrase <= 1'b1;
      end else begin
	 if (ready_phrase) begin
	    if (valid_phrase) begin
	       needphrase <= 1'b0;
	       phrase <= phrase_data;
	       tuser <= phrase_tuser;
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
    input wire 				clk_in,
    input wire 				rst_in,
    input wire 				calib_in,
    input wire 				incr_in,
    output logic [$clog2(ROLLOVER)-1:0] addr_out,
    output logic 			rollover_out
    );

   // for each cycle that incr_in is high, increment address register--never reach rollover, turn it back to 0.
   // ON THE CYCLE THAT calib_in is cycled,
   // (so it probably needs to be a little combinational)
   
   logic [$clog2(ROLLOVER):0] 		next_addr; // deliberately include extra bit!

   assign addr_out = calib_in ? RST_ADDR : next_addr;

   always @(posedge clk_in) begin
      if (rst_in) begin
	 next_addr <= RST_ADDR;
	 rollover_out <= 0;
      end else if (calib_in) begin
	 next_addr <= RST_ADDR + INCR_AMT;
	 rollover_out <= 0;
      end else if (incr_in) begin
	 next_addr <= (next_addr+INCR_AMT >= ROLLOVER) ? 0 : next_addr+INCR_AMT;
	 rollover_out <= next_addr+INCR_AMT >= ROLLOVER || next_addr+INCR_AMT==0;
      end else begin
	 rollover_out <= 0;
      end
   end
endmodule // addr_increment

`default_nettype wire
