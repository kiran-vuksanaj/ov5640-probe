`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module tmds_encoder(
		    input wire 	       clk_in,
		    input wire 	       rst_in,
		    input wire [7:0]   data_in, // video data (red, green or blue)
		    input wire [1:0]   control_in, //for blue set to {vs,hs}, else will be 0
		    input wire 	       ve_in, // video data enable, to choose between control or video signal
		    output logic [9:0] tmds_out
		    );
   
   logic [8:0] 			       q_m;
   logic [4:0] 			       tally;  /* 5-bit signed, from -10 to +10*/
   logic [3:0] 			       count_ones; // N_1{q_m[0:7]}
   logic [3:0] 			       count_zeros; // N_0{q_m[0:7]}
   int 				       i; // for loops
   
   tm_choice mtm(
		 .data_in(data_in),
		 .qm_out(q_m));

   assign count_ones = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7];
   assign count_zeros = 8 - count_ones;
   
   //your code here.
   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 // reset tally
	 tally <= 0;
	 tmds_out <= 0;
	 
      end else if (ve_in) begin
	 // standard video behavior
	 // TMDS part 2 flowchart!
	 if (tally==0 || count_ones == count_zeros) begin
	    // TRUE path
	    // $write(".");
	    tmds_out[9] <= ~q_m[8];
	    // $write(".");
	    tmds_out[8] <= q_m[8];
	    for (i = 0; i < 8; i+=1) begin
	       // $write(".");
	       tmds_out[i] <= (q_m[8]) ? q_m[i] : ~q_m[i];
	    end
	    if (q_m[8]) begin
	       // FALSE path
	       tally <= tally + count_ones - count_zeros;
	    end else begin
	       // TRUE path
	       tally <= tally + count_zeros - count_ones;
	    end
	    // $display("tally=%0d diff=%0d %0t",$signed(tally),$signed(count_ones-count_zeros),$time);
	 end else begin
	    // FALSE PATH
	    if ((~tally[4] && count_ones>count_zeros) || (tally[4] && count_zeros>count_ones)) begin
	       // TRUE PATH; invert bits for balance
	       // $write("%0t inverting tally=%0d q_m=%0b ones=%d zeros=%d ",$time,$signed(tally),q_m,count_ones,count_zeros);
	       // $write("TRUE %b || %b",(~tally[4] && count_ones>count_zeros), (tally[4] && count_zeros>count_ones));
	       
	       // $write(".");
	       tmds_out[9] <= 1;
	       // $write(".");
	       tmds_out[8] <= q_m[8];
	       for (i = 0; i < 8; i += 1) begin
		  // $write(".");
		  tmds_out[i] <= ~q_m[i];
	       end
	       // $display("");
	       tally <= tally + 1 +(q_m[8]?1:-1) + count_zeros - count_ones;
	    end else begin
	       // FALSE PATH; don't invert bits
	       // $write("%0t NOT inverting tally=%0d q_m=%0b ones=%d zeros=%d ",$time,$signed(tally),q_m,count_ones,count_zeros);
	       // $write("FALSE %b || %b",(~tally[4] && count_ones>count_zeros), (tally[4] && count_zeros>count_ones));
	       // $write(".");
	       tmds_out[9] <= 0;
	       // $write(".");
	       tmds_out[8] <= q_m[8];
	       for (i = 0; i < 8; i += 1) begin
		  // $write(".");
		  tmds_out[i] <= q_m[i];
	       end
	       // $write(" %0d %0b %0h %0h %0d",tally,~q_m[8],(~q_m[8])+(~q_m[8]),2*(~q_m[8]),count_ones-count_zeros);
	       // $display("");
	       tally <= tally - 1 +(q_m[8]?1:-1) + count_ones - count_zeros;
	    end // else: !if( (tally>0 && count_ones > count_zeros) ||...
	    
	 end
      end else begin
	 // control behavior
	 tally <= 0; // I SPILLED THE BLOOD OF TEN THOUSAND ENEMIES FOR THIS LINE OF CODE
	 
	 case(control_in)
	   2'b00: tmds_out <= 10'b1101010100;
	   2'b01: tmds_out <= 10'b0010101011;
	   2'b10: tmds_out <= 10'b0101010100;
	   2'b11: tmds_out <= 10'b1010101011;
	 endcase // case (control_in)
	 
      end
      
   end
   
endmodule

`default_nettype wire
