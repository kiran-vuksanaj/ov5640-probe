`timescale 1ns / 1ps

module digest_tb;

   logic clk;
   logic rst;

   logic valid_phrase;
   logic ready_phrase;
   logic [127:0] phrase_data;
   logic 	 phrase_tuser;

   logic 	 valid_word;
   logic 	 ready_word;
   logic [15:0]  word;
   logic 	 newframe_out;

   digest_phrase dpt
     (.clk_in(clk),
      .rst_in(rst),
      .valid_phrase(valid_phrase),
      .ready_phrase(ready_phrase),
      .phrase_data(phrase_data),
      .phrase_tuser(phrase_tuser),
      .valid_word(valid_word),
      .ready_word(ready_word),
      .word(word),
      .newframe_out(newframe_out));

   always begin
      #5;
      clk = ~clk;
   end
   
   initial begin
      clk = 0;
   end

   initial begin
      $dumpfile("sim/digest.vcd");
      $dumpvars(0,digest_tb);

      $display("starting sim");

      rst = 0;
      #6;
      rst = 1;
      #10;
      rst = 0;
      #10;

      // TEST CASES:-phrase valid at last draw, phrase valid 1 later, phrase valid 3 later
      //            -word ready before phrase, same time as phrase draw, 1 later
      valid_phrase = 1;
      phrase_data = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
      phrase_tuser = 0;
      ready_word = 1;
      #10; // no successful read here
      phrase_data = 128'hDEAD_DEAD_DEAD_DEAD_DEAD_DEAD_DEAD_DEAD;
      #70; // 7 successful reads
      phrase_tuser = 1;
      phrase_data = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
      #10; // 8th successful read, should be able to immediately read out from new phrase next
      #40; // 4 more succesful reads, wait before 55
      ready_word = 0;
      #20;
      ready_word = 1;
      valid_phrase = 0; // irrelevant, but make sure it doesnt fuck w things
      phrase_tuser = 0;
      phrase_data = 128'hABBA_ACDC_BEEF_FEED_DEEF_FEEB_CDCA_ABBA;
      #40; // 4 more successful reads, but new data not ready yet
      valid_phrase = 1; // 1 cycle later, valid phrase
      #70; // 7 successful reads
      valid_phrase = 0;
      phrase_data = 128'h3141_5926_5358_2823_1234_5678_9abc_def0; // i prbly dont actually remember pi
      #10; // 1 more successful read
      ready_word = 0;
      #20;
      valid_phrase = 1;
      #10;
      ready_word = 1;
      #100;

      $display("ending sim");
      $finish;
      
   end
   

endmodule // digest_tb


   
