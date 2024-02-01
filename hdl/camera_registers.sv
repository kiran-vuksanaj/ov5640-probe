`timescale 1ns / 1ps
`default_nettype none

module camera_registers
  #(
    parameter RAM_DEPTH = 256,
    parameter PRESCALE = 500)
  (
   input wire 				clk_in,
   input wire 				rst_in,

   input wire 				init_valid,
   output logic 			init_ready,

   input wire 				scl_i,
   output logic 			scl_o,
   output logic 			scl_t,
   input wire 				sda_i,
   output logic 			sda_o,
   output logic 			sda_t,

   input wire [23:0] 			bram_dout,
   output logic [$clog2(RAM_DEPTH)-1:0] bram_addr,

   output logic 			busy,
   output logic 			bus_active,
   output logic [3:0] 			state_out
   );

   // goal: write sequence of registers as specified in a BRAM
   // it shall contain... a manta... perhaps...??

   // I2C ports
   // logic 	scl_i, scl_o, scl_t;
   // logic 	sda_i, sda_o, sda_t;

   // interface with tristate pins
   // assign scl_i = scl_pin;
   // assign scl_pin = scl_t ? 1'bz : scl_o;

   // assign sda_i  = sda_pin;
   // assign sda_pin = sda_t ? 1'bz : sda_o;


   localparam ADDR = 7'h3C;
   logic [6:0] 	cmd_address;
   assign cmd_address = ADDR;
   
   logic 	cmd_start, cmd_read, cmd_write, cmd_write_multiple, cmd_stop;
   logic 	cmd_valid, cmd_ready;

   logic [7:0] 	write_tdata;
   logic 	write_tvalid, write_tready, write_tlast;

   // logic 	busy,bus_control,bus_active,missed_ack;
   logic 	bus_control, missed_ack;
   

   // progress through states:
   // send command with address: write multiple?
   // send data via write axis: 3 bytes, with tlast on the last one
   // ALWAYS 3 BYTES!
   
   // states in between to pull from BRAM
   // repeat!

   typedef enum {RST,
		 WAIT_INIT,
		 GET_REGPAIR,
		 WAIT_REGPAIR,
		 WRITE_REGPAIR,
		 ISSUE_CMD,
		 WRITE_REGADDR_HI,
		 WRITE_REGADDR_LO,
		 WRITE_REGDATA,
		 DONE} istate;
   istate state;
   assign state_out = state;

   logic [$clog2(RAM_DEPTH)-1:0] next_regpair_addr;
   addr_increment #(.ROLLOVER(RAM_DEPTH)) aia
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .calib_in( state == WAIT_INIT ),
      .incr_in( state == GET_REGPAIR ),
      .addr_out( next_regpair_addr ));
		    
   logic [23:0] 		 regpair;

   logic 			 wait_bram;
   
   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 state <= RST;
      end else begin
	 case(state)
	   RST: begin
	      state <= WAIT_INIT;
	   end
	   WAIT_INIT: begin
	      regpair <= 0;
	      wait_bram <= 0;
	      state <= (init_valid) ? GET_REGPAIR : WAIT_INIT;
	   end
	   GET_REGPAIR: begin
	      state <= WAIT_REGPAIR;
	      wait_bram <= 1'b1;
	      bram_addr <= next_regpair_addr;
	      // addr_increment pushes regpair
	   end
	   WAIT_REGPAIR: begin
	      // stay here for 2 cycles
	      wait_bram <= ~wait_bram;
	      state <= wait_bram ? WAIT_REGPAIR : WRITE_REGPAIR;
	   end
	   WRITE_REGPAIR: begin
	      // if the bram is blank, stop trying to write and return to idle state
	      regpair <= bram_dout;
	      state <= (bram_dout == 24'b0) ? WAIT_INIT : ISSUE_CMD;
	      // state <= (next_regpair_addr > 228) ? DONE : ISSUE_CMD;
	   end
	   ISSUE_CMD: begin
	      state <= (cmd_valid && cmd_ready) ? WRITE_REGADDR_HI : ISSUE_CMD;
	   end
	   WRITE_REGADDR_HI: begin
	      state <= (write_tvalid && write_tready) ? WRITE_REGADDR_LO : WRITE_REGADDR_HI;
	   end
	   WRITE_REGADDR_LO: begin
	      state <= (write_tvalid && write_tready) ? WRITE_REGDATA : WRITE_REGADDR_LO;
	   end
	   WRITE_REGDATA: begin
	      state <= (write_tvalid && write_tready) ? GET_REGPAIR : WRITE_REGDATA;
	   end
	   DONE: begin
	      state <= DONE;
	   end
	 endcase // case (state)
      end
   end // always_ff @ (posedge clk_in)

   assign init_ready = (state == WAIT_INIT);

   assign cmd_read = 1'b0;
   assign cmd_write = 1'b0; // only using write_multiple
   
   always_comb begin
      case(state)
	RST, WAIT_INIT, GET_REGPAIR, WAIT_REGPAIR, DONE: begin
	   cmd_start = 1'b0;
	   cmd_write_multiple = 1'b0;
	   cmd_stop = 1'b0;
	   cmd_valid = 1'b0;
	   
	   write_tdata = 8'b0;
	   write_tvalid = 1'b0;
	   write_tlast = 1'b0;
	end
	ISSUE_CMD: begin
	   cmd_start = 1'b1;
	   cmd_write_multiple = 1'b1;
	   cmd_stop = 1'b1;
	   cmd_valid = 1'b1;
	   
	   write_tdata = 8'b0;
	   write_tvalid = 1'b0;
	   write_tlast = 1'b0;
	end
	WRITE_REGADDR_HI: begin
	   cmd_start = 1'b0;
	   cmd_write_multiple = 1'b0;
	   cmd_stop = 1'b0;
	   cmd_valid = 1'b0;
	   
	   write_tdata = regpair[23:16];
	   write_tvalid = 1'b1;
	   write_tlast = 1'b0;
	end
	WRITE_REGADDR_LO: begin
	   cmd_start = 1'b0;
	   cmd_write_multiple = 1'b0;
	   cmd_stop = 1'b0;
	   cmd_valid = 1'b0;
	   
	   write_tdata = regpair[15:8];
	   write_tvalid = 1'b1;
	   write_tlast = 1'b0;
	end
	WRITE_REGDATA: begin
	   cmd_start = 1'b0;
	   cmd_write_multiple = 1'b0;
	   cmd_stop = 1'b0;
	   cmd_valid = 1'b0;
	   
	   write_tdata = regpair[7:0];
	   write_tvalid = 1'b1;
	   write_tlast = 1'b1;
	end
      endcase // case (state)
   end
   
   // for now, not hooking up the read data bc i dont intend to read anything lmao

   // could be a fifo? but for now im not bothering with that, especially since its much slower to serialize
   
   i2c_master sccb_c
     (.clk(clk_in),
      .rst(rst_in),
      
      .s_axis_cmd_address(cmd_address),
      .s_axis_cmd_start(cmd_start),
      .s_axis_cmd_read(cmd_read),
      .s_axis_cmd_write(cmd_write),
      .s_axis_cmd_write_multiple(cmd_write_multiple),
      .s_axis_cmd_stop(cmd_stop),
      .s_axis_cmd_valid(cmd_valid),
      .s_axis_cmd_ready(cmd_ready),

      .s_axis_data_tdata(write_tdata),
      .s_axis_data_tvalid(write_tvalid),
      .s_axis_data_tready(write_tready),
      .s_axis_data_tlast(write_tlast),

      .m_axis_data_tready(1'b0),

      .busy(busy),
      .bus_control(bus_control),
      .bus_active(bus_active),
      .missed_ack(missed_ack),

      .prescale(PRESCALE),

      .scl_i(scl_i),
      .scl_o(scl_o),
      .scl_t(scl_t),
      .sda_i(sda_i),
      .sda_o(sda_o),
      .sda_t(sda_t));

endmodule // camera_registers

`default_nettype wire
