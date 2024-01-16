`timescale 1ns / 1ps
`default_nettype none

module rgb_to_y
  (
   input wire clk_in,
   input wire rst_in,
   input wire [7:0] red_in,
   input wire [7:0] green_in,
   input wire [7:0] blue_in,
   output logic [7:0] y_out
   );

   parameter R_MULT = 24'b010011001000101101000011; // 0.299 to binary fraction
   parameter G_MULT = 24'b100101100100010110100001; // 0.587 to binary fraction
   parameter B_MULT = 24'b000111010010111100011010; // 0.115 to binary fraction

   logic [31:0] 	      red_prod;
   logic [31:0] 	      green_prod;
   logic [31:0] 	      blue_prod;

   assign red_prod = (red_in * R_MULT);
   assign green_prod = (green_in * G_MULT);
   assign blue_prod = (blue_in * B_MULT);

   logic [7:0] 		      red_small;
   logic [7:0] 		      green_small;
   logic [7:0] 		      blue_small;
   assign red_small = red_prod >> 24;
   assign green_small = green_prod >> 24;
   assign blue_small = blue_prod >> 24;
   
   
   logic [31:0] 	      sum;
   assign sum = red_prod + green_prod + blue_prod;
   
   
   always_ff @(posedge clk_in) begin
      if  (rst_in) begin
	 y_out <= 0;
      end else begin
	 y_out <= sum >> 24;
      end
   end
   
endmodule // rgb_to_y


`default_nettype wire
