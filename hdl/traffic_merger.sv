`timescale 1ns / 1ps
`default_nettype none

/* channel_update struct
 * 
 * When TUSER sideband bit to a write AXI-Stream is high,
 * TDATA gets interpreted as a command.
 * `wen`: Write Enable
 * `addr`: starting address of read/write command
 * `stream_length`: How many 128-bit chunks should be returned (ignored for write commands)
 */

`ifndef CHANNEL_UPDATE
 `define CHANNEL_UPDATE

typedef struct packed {
   logic [26:0] addr;
   logic [26:0] stream_length;
   logic 	wen;
} channel_update;
`endif


/*
 * traffic_merger module: Manages N sources of MIG commands
 *  - Takes commands indicating read/write mode for each "channel",
 *    expecting sequential reads/writes for each channel.
 * 
 *  - Receives write data in 128-bit chunks on incoming AXI-Stream
 *     ( when TUSER 1-bit side-channel data is high, incoming AXI-Stream
 *       is interpreted as a command, otherwise it's interpreted as 
 *       write data )
 * 
 *  - Responds on read (but not write) commands with data on an outgoing AXI-Stream for each channel
 *     ( asserts TUSER for the first chunk of data from a given read command )
 * 
 *  - Cycles through commands requested by each channel round-robin style
 *     
 *  - When many sequential addresses are requested (either to read or write),
 *    sends them as a burst of multiple 128-bit chunks
 *     (i think that MIG works more efficiently with bursts of adjacent addresses?)
 *     -max size of burst defined by MAX_CMD_QUEUE
 * 
 */
module traffic_merger #
  (parameter CHANNEL_COUNT = 3,
   parameter MAX_CMD_QUEUE = 8)
  (
   output logic [31:0] 	debug_lane, // debug signal for 7-segment display
   input wire 		clk_in,
   input wire 		rst_in,

   // MIG UI --> generic outputs
   output logic [26:0] 	app_addr,
   output logic [2:0] 	app_cmd,
   output logic 	app_en,
   // MIG UI --> write outputs
   output logic [127:0] app_wdf_data,
   output logic 	app_wdf_end,
   output logic 	app_wdf_wren,
   output logic [15:0] 	app_wdf_mask,
   // MIG UI --> read inputs
   input wire [127:0] 	app_rd_data,
   input wire 		app_rd_data_end,
   input wire 		app_rd_data_valid,
   // MIG UI --> generic inputs
   input wire 		app_rdy,
   input wire 		app_wdf_rdy,
   // MIG UI --> misc
   output logic 	app_sr_req, 
   output logic 	app_ref_req,
   output logic 	app_zq_req, 
   input wire 		app_sr_active,
   input wire 		app_ref_ack,
   input wire 		app_zq_ack,
   input wire 		init_calib_complete,

   // Array of AXI-Stream write data/command inputs, an index for each channel
   input wire [127:0] 	write_axis_data [CHANNEL_COUNT-1:0],
   input wire 		write_axis_tuser [CHANNEL_COUNT-1:0],
   input wire 		write_axis_valid [CHANNEL_COUNT-1:0],
   input wire 		write_axis_smallpile [CHANNEL_COUNT-1:0],
   output logic 	write_axis_ready [CHANNEL_COUNT-1:0],

   // Array of AXI-Stream read data/command inputs, an index for each channel
   output logic [127:0] read_axis_data [CHANNEL_COUNT-1:0],
   output logic 	read_axis_tuser [CHANNEL_COUNT-1:0],
   output logic 	read_axis_valid [CHANNEL_COUNT-1:0],
   input wire 		read_axis_af [CHANNEL_COUNT-1:0], // FIFO almost-full
   input wire 		read_axis_ready [CHANNEL_COUNT-1:0]
   );

   localparam CHANNEL_INDEX = $clog2(CHANNEL_COUNT);

   /* specified by MIG datasheet */
   localparam CMD_WRITE = 3'b000;
   localparam CMD_READ = 3'b001;
   
   logic [CHANNEL_INDEX-1:0] current_channel;
   logic [CHANNEL_INDEX-1:0] next_response_channel;

   /* Nothing should be done until MIG asserts `initial_calib_complete` */
   logic 		     hold_for_calib;

   // Arrays of state values for each channel
   logic 		     wen[CHANNEL_COUNT-1:0];           // current read/write state: write enable
   logic [26:0] 	     cmd_addr[CHANNEL_COUNT-1:0];      // next (128-bit) address to request from MIG
   logic [26:0] 	     resp_addr[CHANNEL_COUNT-1:0];     // next (128-bit) read-address response from MIG
   logic [26:0] 	     command_addr[CHANNEL_COUNT-1:0];  // address specified when last command was issued
   logic [26:0] 	     target_addr[CHANNEL_COUNT-1:0];   // command_addr + stream_length, final read address
   // Arrays of combinational logic values for each channel
   logic 		     channel_ready[CHANNEL_COUNT-1:0]; // channel can receive data from write input AXI-Stream
   logic 		     read_cmd_done[CHANNEL_COUNT-1:0]; // channel has sent all read-requests to target_addr, doesn't need to send more
   logic 		     read_resp_done[CHANNEL_COUNT-1:0];// channel has received all read-responses to target_addr
   
   logic [26:0]		     addr_diff[CHANNEL_COUNT-1:0];            // resp_addr - cmd_addr, should not exceed MAX_CMD_QUEUE
   logic 		     yield[CHANNEL_COUNT-1:0];                // channel yields control of MIG -- nothing to currently send
   logic 		     new_command_received[CHANNEL_COUNT-1:0]; // channel's input AXI-S is receiving a new command

   always_comb begin
      for (int i = 0; i < CHANNEL_COUNT; i++) begin
	 /* define combinational logic for each channel */
	 
	 read_cmd_done[i] = (cmd_addr[i] == target_addr[i]);
	 read_resp_done[i] = (resp_addr[i] == target_addr[i]);
	 addr_diff[i] = cmd_addr[i] - resp_addr[i];
	 
	 if (wen[i] == 1'b0) begin
	    /* READ mode specifications of when a request is ready, when to yield */
	    
	    channel_ready[i] = read_cmd_done[i] && read_resp_done[i] && app_rdy;
	    yield[i] = addr_diff[i] >= MAX_CMD_QUEUE || read_axis_af[i] || cmd_addr[i] == target_addr[i];
	    
	 end else begin
	    /* WRITE mode specifications of when a request is ready, when to yield */
	    channel_ready[i] = app_rdy && app_wdf_rdy;
	    yield[i] = ~write_axis_valid[i];
	 end

	 write_axis_ready[i] = (channel_ready[i] && current_channel == i && ~hold_for_calib);
	 new_command_received[i] = write_axis_ready[i] && write_axis_valid[i] && write_axis_tuser[i];

	 // Read response output AXI-Stream: only enabled when next_response_channel matches
	 if (next_response_channel == i) begin
	    read_axis_data[i] = app_rd_data;
	    read_axis_tuser[i] = resp_addr[i] == command_addr[i]; // first response has associated TUSER high
	    read_axis_valid[i] = app_rd_data_valid;
	 end else begin
	    read_axis_data[i] = 0;
	    read_axis_tuser[i] = 1'b0;
	    read_axis_valid[i] = 1'b0;
	 end
      end // for (int i = 0; i < CHANNEL_COUNT; i++)
   end // always_comb

   channel_update command;
   assign command = write_axis_data[current_channel];

   logic write_command_success;
   logic read_command_success;
   logic command_success;

   assign write_command_success = wen[current_channel] &&
				  write_axis_ready[current_channel] &&
				  write_axis_valid[current_channel] &&
				  ~write_axis_tuser[current_channel];
   assign read_command_success = ~wen[current_channel] &&
				 ~yield[current_channel] &&
				 app_rdy;
   assign command_success = write_command_success || read_command_success;
   logic [CHANNEL_COUNT-1:0] yields = {yield[0], yield[1], yield[2]};
   
   generate
      /* State variables for each channel: generate block to instantiate all separately */
      genvar i;
      for(i = 0; i < CHANNEL_COUNT; i++) begin: cursors

	 /* cmd_addr is set when new_command_received, increments when a command succeeds on its channel */
	 cursor #(.WIDTH(27)) cmd_addr_cursor
	      (.clk_in(clk_in),
	       .rst_in(rst_in),
	       .incr_in( command_success && current_channel == i ),
	       .setval_in(new_command_received[i]),
	       .manual_in(command.addr),
	       .cursor_out(cmd_addr[i]));

	 /* resp_addr is set when new_command_received, increments when a response is received on its channel */
	 cursor #(.WIDTH(27)) resp_addr_cursor
	   (.clk_in(clk_in),
	    .rst_in(rst_in),
	    .incr_in( app_rd_data_valid && next_response_channel == i ),
	    .setval_in(new_command_received[i]),
	    .manual_in(command.addr),
	    .cursor_out(resp_addr[i]));

	 /* set new values for command state when new_command_received */
	 always_ff @(posedge clk_in) begin
	    if (rst_in) begin
	       target_addr[i] <= 0;
	       command_addr[i] <= 0;
	       wen[i] <= 0;
	    end else if (new_command_received[i]) begin 
	       target_addr[i] <= command.addr + command.stream_length;
	       command_addr[i] <= command.addr;
	       wen[i] <= command.wen;
	    end
	 end
	    
	 
      end
   endgenerate

   /* manager of current_channel; round-robin select a new channel when the current channel yields. */
   cursor #
     (.WIDTH(CHANNEL_INDEX), .ROLLOVER(CHANNEL_COUNT))
   current_channel_cursor
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .incr_in( yield[current_channel] && ~hold_for_calib),
      .cursor_out( current_channel ));

   /* tiny FIFO for managing proper destination of read responses 
         (defined below)
    */
   
   response_destination_fifo #(.INDEX_WIDTH(CHANNEL_INDEX), .QUEUE_LENGTH(CHANNEL_COUNT*MAX_CMD_QUEUE+1)) rqm
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .current_channel(current_channel),
      .read_cmd_success( read_command_success ),
      .next_channel(next_response_channel),
      .read_data_ready(app_rd_data_valid));


   /* Manage MIG Signals to match the proper current state (READ command, WRITE command, or no command) */
   
   always_comb begin
      
      if (wen[current_channel] &&
	  write_axis_ready[current_channel] &&
	  write_axis_valid[current_channel] &&
	  ~write_axis_tuser[current_channel]) begin
	 // WRITE command for MIG from current_channel

	 // address offset by 7: 128-bit address becomes 1-bit address (what the MIG wants)
	 app_addr = cmd_addr[current_channel] << 3;
	 app_cmd = CMD_WRITE;
	 app_en = 1'b1;
	 app_wdf_wren = 1'b1;
	 app_wdf_data = write_axis_data[current_channel];
	 app_wdf_end = 1'b1;
      end 
      else if (~wen[current_channel] &&
	       ~yield[current_channel] &&
	       app_rdy) begin
	 // READ command for MIG from current_channel

	 // address offset by 7: 128-bit address becomes 1-bit address (what the MIG wants)
	 app_addr = cmd_addr[current_channel] << 3;
	 app_cmd = CMD_READ;
	 app_en = 1'b1;
	 app_wdf_wren = 1'b0;
	 app_wdf_data = 0;
	 app_wdf_end = 1'b0;
      end else begin 
	 
	 app_addr = 0;
	 app_cmd = 0;
	 app_en = 1'b0;
	 app_wdf_wren = 1'b0;
	 app_wdf_data = 0;
	 app_wdf_end = 1'b0;
      end
   end // always_comb

   
   /* Unused MIG Signals */
   assign app_sr_req = 0;
   assign app_ref_req = 0;
   assign app_zq_req = 0;
   assign app_wdf_mask = 16'b0;


   /* Enable module after init_calib_complete goes high. Nothing should happen while `hold_for_calib` is low */
   
   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 hold_for_calib <= 1'b1;
      end else if (hold_for_calib) begin
	 hold_for_calib <= ~init_calib_complete;
      end else begin
	 hold_for_calib <= hold_for_calib;
      end
   end

   assign debug_lane = cmd_addr[0];

   /* Massive block of logics generated so that they can be viewed in GTKWave.
      These signals, with _vcd suffix, are never used, only viewed
    */
   generate
      genvar 		     idx;
      for (idx = 0; idx < CHANNEL_COUNT; idx++) begin: vcd_access
	 logic [127:0] 	write_axis_data_vcd;
	 assign write_axis_data_vcd = write_axis_data[idx];
	 logic 		write_axis_tuser_vcd;
	 assign write_axis_tuser_vcd = write_axis_tuser[idx];
	 logic 		write_axis_valid_vcd;
	 assign write_axis_valid_vcd = write_axis_valid[idx];
	 logic 		write_axis_smallpile_vcd;
	 assign write_axis_smallpile_vcd = write_axis_smallpile[idx];
	 logic 		write_axis_ready_vcd;
	 assign write_axis_ready_vcd = write_axis_ready[idx];
	 logic [127:0] 	read_axis_data_vcd;
	 assign read_axis_data_vcd = read_axis_data[idx];
	 logic 		read_axis_tuser_vcd;
	 assign read_axis_tuser_vcd = read_axis_tuser[idx];
	 logic 		read_axis_valid_vcd;
	 assign read_axis_valid_vcd = read_axis_valid[idx];
	 logic 		read_axis_af_vcd;
	 assign read_axis_af_vcd = read_axis_af[idx];
	 logic 		read_axis_ready_vcd;
	 assign read_axis_ready_vcd = read_axis_ready[idx];
	 logic 		wen_vcd;
	 assign wen_vcd = wen[idx];
	 logic [26:0] 	cmd_addr_vcd;
	 assign cmd_addr_vcd = cmd_addr[idx];
	 logic [26:0] 	resp_addr_vcd;
	 assign resp_addr_vcd = resp_addr[idx];
	 logic [26:0] 	target_addr_vcd;
	 assign target_addr_vcd = target_addr[idx];
	 logic [26:0] 	command_addr_vcd;
	 assign command_addr_vcd = command_addr[idx];
	 logic 		channel_ready_vcd;
	 assign channel_ready_vcd = channel_ready[idx];
	 logic 		read_cmd_done_vcd;
	 assign read_cmd_done_vcd = read_cmd_done[idx];
	 logic 		read_resp_done_vcd;
	 assign read_resp_done_vcd = read_resp_done[idx];
	 logic [26:0] 	addr_diff_vcd;
	 assign addr_diff_vcd = addr_diff[idx]; // should never be higher than MAX_CMD_QUEUE
	 logic 		yield_vcd;
	 assign yield_vcd = yield[idx];
	 logic 		new_command_received_vcd;
	 assign new_command_received_vcd = new_command_received[idx];
      end
   endgenerate

endmodule


/* 
 * Module response_destination_fifo
 * 
 * a little FIFO for managing proper destinations of addresses.
 * Assert `read_cmd_success` when MIG accepts a read command--
 * the current channel will be stored to the FIFO.
 * When `read_data_ready` is asserted, a channel id is consumed
 * from the FIFO, and `next_channel` indicates where the current
 * data from MIG should be directed
 */
module response_destination_fifo #
  (parameter INDEX_WIDTH = 1,
   parameter QUEUE_LENGTH = 1)
   (
    input wire 			   clk_in,
    input wire 			   rst_in,
    input wire [INDEX_WIDTH-1:0]   current_channel,
    input wire 			   read_cmd_success,
    output logic [INDEX_WIDTH-1:0] next_channel,
    input wire 			   read_data_ready);

   localparam QUEUE_INDEX = $clog2(QUEUE_LENGTH);
   
   logic [INDEX_WIDTH-1:0] 	   queue [QUEUE_LENGTH-1:0];
   logic [QUEUE_INDEX-1:0] 	   new_cmd_index;
   logic [QUEUE_INDEX-1:0] 	   next_rsp_index;

   cursor #(.WIDTH(QUEUE_INDEX),.ROLLOVER(QUEUE_LENGTH)) nci_cur
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .incr_in(read_cmd_success),
      .setval_in(0),
      .manual_in(),
      .cursor_out(new_cmd_index));

   cursor #(.WIDTH(QUEUE_INDEX),.ROLLOVER(QUEUE_LENGTH)) nri_cur
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .incr_in(read_data_ready),
      .setval_in(0),
      .manual_in(),
      .cursor_out(next_rsp_index));

   assign next_channel = queue[next_rsp_index];
   
   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 for(int i = 0; i < QUEUE_LENGTH; i++) begin
	    queue[i] <= 0;
	 end
      end else begin
	 if( read_cmd_success ) queue[new_cmd_index] <= current_channel;
      end
   end

endmodule

`default_nettype wire
