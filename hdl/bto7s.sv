module bto7s(
	     input wire [3:0] 	x_in,
	     output logic [6:0] s_out
	     );

   logic [15:0] 		num;

   assign num[0] = ~x_in[3] && ~x_in[2] && ~x_in[1] && ~x_in[0];

   assign num[1] = ~x_in[3] && ~x_in[2] && ~x_in[1] && x_in[0];

   assign num[2] = x_in == 4'd2;

   assign num[3] = x_in == 4'd3;

   assign num[4] = x_in == 4'd4;

   assign num[5] = x_in == 4'd5;

   assign num[6] = x_in == 4'd6;

   assign num[7] = x_in == 4'd7;

   assign num[8] = x_in == 4'd8;

   assign num[9] = x_in == 4'd9;

   assign num[10] = x_in == 4'ha;

   assign num[11] = x_in == 4'hb;

   assign num[12] = x_in == 4'hc;

   assign num[13] = x_in == 4'hd;

   assign num[14] = x_in == 4'he;

   assign num[15] = x_in == 4'd15;


   assign s_out[0] = ~( num[1] || num[4] || num[11] || num[13] );
   // sa
   assign s_out[1] = ~( num[5] || num[6] || num[11] || num[12] || num[14] || num[15] );
   // sb
   assign s_out[2] = ~( num[2] || num[12] || num[14] || num[15] );
   // sc
   assign s_out[3] = ~( num[1] || num[4] || num[7] || num[10] || num[15] );
   // sd
   assign s_out[4] = ~( num[1] || num[3] || num[4] || num[5] || num[7] || num[9]);
   // se
   assign s_out[5] = ~( num[1] || num[2] || num[3] || num[7] || num[13]);
   // sf
   assign s_out[6] = ~( num[0] || num[1] || num[7] || num[12]);
   // sg

   // your code here!

endmodule // bto7s
