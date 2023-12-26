`timescale 1 ns / 1 ps
`default_nettype none

module tm_choice (
		  input wire [7:0]   data_in,
		  output logic [8:0] qm_out
		  );



   //your code here, friend

   logic [3:0] 			     count_ones;
   logic 			     mode_choice;
   always_comb begin
      count_ones = data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7];
      mode_choice = ~ ((count_ones > 4) || (count_ones == 4 && !data_in[0]));
      qm_out[8] = mode_choice;
      
      qm_out[0] = data_in[0];
      for(integer i=1; i<8; i+=1) begin
	 qm_out[i] = (mode_choice) ?
                    qm_out[i-1] ^ data_in[i] :
                    ~( qm_out[i-1] ^ data_in[i] );
      end
   end

endmodule //end tm_choice

`default_nettype wire
