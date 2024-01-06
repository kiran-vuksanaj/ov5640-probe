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
   input wire 		write_axis_tuser,
   input wire 		write_axis_valid,
   input wire 		write_axis_smallpile,
   output logic 	write_axis_ready,
   // Read AXIS FIFO output
   output logic [127:0] read_axis_data,
   output logic 	read_axis_tuser,
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

   typedef enum {RST,           // X000 / 0,8
		 WAIT_INIT,     // X001 / 1,9
		 RD_HDMI,   // X010 / 2,A
		 WR_CAM       // X011 / 3,B
		 } tg_state;
   tg_state state;

   assign state_out = {state[2:0]};
   
   logic [26:0] wr_addr_incr;
   logic [26:0] wr_addr;
   logic 	rollover_wr_addr;
   
   addr_increment #(.ROLLOVER(1280*720 >> 3)) aiwa
     (.clk_in(clk_in),
      .rst_in(rst_in || (write_axis_valid && write_axis_tuser)),
      .incr_in( write_ready && app_en ),
      .addr_out( wr_addr_incr ),
      .rollover_out(rollover_wr_addr));

   // get instant combinational logic for when a new frame is indicated
   // (this feels jank)
   assign wr_addr = (write_axis_valid && write_axis_tuser) ? 0 : wr_addr_incr + 1;
   
   logic 	write_ready;
   logic 	wdf_ready;
   assign wdf_ready = app_rdy && app_wdf_rdy;
   assign write_ready = wdf_ready && (state == WR_CAM);
   assign write_axis_ready = write_ready;

   localparam MAX_CMD_QUEUE = 8;
   
   logic [26:0] rd_addr;
   logic 	rollover_rd_addr;

   logic [26:0] rdout_addr;
   logic 	rollover_rdout_addr;

   logic [26:0] addr_diff;
   assign addr_diff = rd_addr - rdout_addr;
   
   logic 	issue_rd_cmd;
   assign issue_rd_cmd = (addr_diff < MAX_CMD_QUEUE) && ~read_axis_af && state == RD_HDMI;
   
   addr_increment #(.ROLLOVER(1280*720 >> 3)) aira
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .incr_in( issue_rd_cmd && app_rdy ),
      .addr_out(rd_addr),
      .rollover_out(rollover_rd_addr));

   addr_increment #(.ROLLOVER(1280*720 >> 3)) airoa
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .incr_in( app_rd_data_valid ),
      .addr_out( rdout_addr ),
      .rollover_out( rollover_rdout_addr ));
         

   // NOTE: this does no maintenance of data if read_axis is not ready!!
   // its a built in assumption that we never reach that point
   // issue_rd_cmd logic should prevent any requests going in that would exceed capacity.
   assign read_axis_valid = app_rd_data_valid;
   assign read_axis_data = app_rd_data;
   assign read_axis_tuser = (rdout_addr == 0);


   // switch between read/write logic:
   // most simple version, if command can't complete, switch modes.
   // both states work towards these conditions.
   // at pretty different rates though, which could cause problems maybe
   logic 	go_to_wr, go_to_rd;
   assign go_to_wr = (addr_diff >= MAX_CMD_QUEUE) || read_axis_af;
   assign go_to_rd = ~write_axis_valid;
         
   always_ff @(posedge clk_in) begin
      if(rst_in) begin
	state <= RST;
      end else begin
	 case(state)
	   RST: begin
	      state <= WAIT_INIT;
	   end
	   WAIT_INIT: begin
	      state <= init_calib_complete ? RD_HDMI : WAIT_INIT;
	   end
	   RD_HDMI: begin
	      state <= go_to_wr ? WR_CAM : RD_HDMI;
	   end
	   WR_CAM: begin
	      state <= go_to_rd ? RD_HDMI : WR_CAM; 
	   end
	 endcase // case (state)
      end
   end

   /* temporary stuff to test out write excluding fifo+phrase builder */
   /* should generate vertical gradient stripes, b/w */
   /* still relies on write_axis valid? in case that somehow causes a problem ? */
   // logic [15:0] pixel;
   // logic [15:0] pixel_alt;
   // logic [12:0] hcount;
   // assign hcount = wr_addr % (1280 >> 3); // 8 sequential pixels, within 1 phrase, will all be ident
   // i think this should make 5 gradient repeats. and i THINk it shouldn't have offset errors...
   // since its based directly on the wr_addr?
   // assign pixel = 0'hFFFF;
   // assign pixel_alt = 0'h00FF;
   // logic [127:0] write_data_tmp;
   // assign pixel = {hcount[4:0],hcount[4:0],1'b0,hcount[4:0]};
   // assign write_data_tmp = {pixel,pixel,pixel,pixel,pixel,pixel,pixel,pixel};
   // assign write_data_tmp = 128'h0000_1082_2104_3186_4208_528A_630C_738E; // should be a gradient on EACH 8 PIXELS (very tight vertical gradient stripes)
   // assign write_data_tmp = (wr_addr == 300) ? {pixel,pixel,pixel,pixel,pixel,pixel_alt,pixel,pixel} : {pixel,pixel,pixel,pixel,pixel,pixel,pixel,pixel};
   // assign write_data_tmp = {20'h0000_0, wr_addr, 80'h0000_0000_0000_0000_0000};
   // assign write_data_tmp = (wr_addr%2 == 0) ? 128'h0000_0000_0000_0000_0000_0000_0000_0000 : 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
   
   /* end temporary stuff */

   // Combinational state behavior, for ui app signals
   // Flip-Flop state behavior (see also combinational)
   // typedef enum {RST,           // X000 / 0,8
   // 		 WAIT_INIT,     // X001 / 1,9
   // 		 RD_HDMI,   // X010 / 2,A
   // 		 WR_CAM       // X011 / 3,B
   // 		 } tg_state;
   // tg_state state;

   always_comb begin
      case(state)
	RST, WAIT_INIT: begin
	   app_addr = 0;
	   app_cmd = 0;
	   app_en = 0;
	   app_wdf_data = 0;
	   app_wdf_end = 0;
	   app_wdf_wren = 0;
	end
	WR_CAM: begin
	   // app signals
	   app_addr = wr_addr << 7;
	   app_cmd = CMD_WRITE;
	   // app_en = 1'b1;
	   app_en = write_axis_valid && wdf_ready;
	   // app_wdf_wren = 1'b1;
	   app_wdf_wren = write_axis_valid && wdf_ready;
	   app_wdf_data = write_axis_data;
	   // app_wdf_data = write_data_tmp;
	   // app_wdf_end = 1'b1;
	   app_wdf_end = write_axis_valid && wdf_ready;
	end
	RD_HDMI: begin
	   app_addr = rd_addr << 7;
	   app_cmd = CMD_READ;
	   // app_en = 1'b1;
	   app_en = issue_rd_cmd;
	   app_wdf_wren = 1'b0;
	   app_wdf_data = 0;
	   app_wdf_end = 1'b0;
	end
      endcase // case (state)
   end // always_comb

endmodule

`default_nettype wire

