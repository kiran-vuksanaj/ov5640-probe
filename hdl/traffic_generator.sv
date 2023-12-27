`timescale 1ns / 1ps
`default_nettype none

module traffic_generator
  (
   input wire 		clk_in, // should be ui clk of DDR3!
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
   output logic 	app_sr_req, // ??
   output logic 	app_ref_req,// ??
   output logic 	app_zq_req, // ??
   input wire 		app_sr_active,
   input wire 		app_ref_ack,
   input wire 		app_zq_ack,
   input wire 		init_calib_complete,
   // Write AXIS FIFO input
   input wire [127:0] 	write_axis_data,
   input wire 		write_axis_valid,
   input wire 		write_axis_smallpile,
   output logic 	write_axis_ready,
   // Read AXIS FIFO output
   output logic [127:0] read_axis_data,
   output logic 	read_axis_valid,
   input wire 		read_axis_af,
   input wire 		read_axis_ready,
   // state indicators
   input wire 		trigger_btn_sync,
   output logic [2:0] 	state_out
   );

   localparam CMD_WRITE = 3'b000;
   localparam CMD_READ = 3'b001;

   // unused signals
   assign app_sr_req = 0;
   assign app_ref_req = 0;
   assign app_zq_req = 0;
   assign app_wdf_mask = 16'b0;

   typedef enum {RST,
		 WAIT_TRIG,
		 WAIT_NF_CAM,
		 WAIT_WR,
		 WR_BTB,
		 READ_CMD,
		 READ_WAIT,
		 FIFO_SEND,
		 CMD_WAIT
		 } tc_state;
   tc_state state;

   assign state_out = state[2:0];
   
   logic [26:0] wr_addr;
   logic 	rollover_wr_addr;
   
   addr_increment #(.ROLLOVER(1280*720 >> 3)) aiwa
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .incr_in( write_ready ),
      .addr_out( wr_addr ),
      .rollover_out(rollover_wr_addr));

   logic 	write_ready;
   logic 	wdf_ready;
   assign wdf_ready = app_rdy && app_wdf_rdy;
   assign write_ready = wdf_ready && state == WR_BTB;
   assign write_axis_ready = write_ready;
   
   // Flip-Flop state behavior (see also combinational)

   always_ff @(posedge clk_in) begin
      if(rst_in) begin
	state <= RST;
      end else begin
	 case(state)
	   RST: begin
	      state <= WAIT_TRIG;
	   end
	   WAIT_TRIG: begin
	      state <= (trigger_btn_sync) ? WAIT_WR : WAIT_TRIG;
	   end
	   // WAIT_NF_CAM: begin
	   //    state <= (nf_cam_sync) ? WAIT_WR : WAIT_NF_CAM;
	   // end
	   WAIT_WR: begin
	      state <= wdf_ready ? WR_BTB : WAIT_WR;
	   end
	   WR_BTB: begin
	      // i think maybe write_axis being valid continues to imply our ready signal?
	      // frankly this is overly hopeful tho
	      state <= rollover_wr_addr ? READ_CMD :
		       (write_axis_valid ? WR_BTB : WAIT_WR);
	   end
	   READ_CMD: begin
	   end
	   READ_WAIT: begin
	   end
	   FIFO_SEND: begin
	   end
	   CMD_WAIT: begin
	   end
	 endcase // case (state)
      end
   end


   // Combinational state behavior (see also flip-flop)
   always_comb begin
      case(state)
	RST, WAIT_TRIG, WAIT_NF_CAM, WAIT_WR: begin
	   app_addr = 0;
	   app_cmd = 0;
	   app_en = 0;
	   app_wdf_data = 0;
	   app_wdf_end = 0;
	   app_wdf_wren = 0;
	end
	WR_BTB: begin
	   // app signals
	   app_addr = wr_addr;
	   app_cmd = CMD_WRITE;
	   app_en = 1'b1;
	   app_wdf_wren = 1'b1;
	   app_wdf_data = write_axis_data;
	   app_wdf_end = 1'b1;
	end
	READ_CMD: begin
	end
	READ_WAIT: begin
	end
	FIFO_SEND: begin
	end
	CMD_WAIT: begin
	end
      endcase // case (state)
   end

endmodule

`default_nettype wire

