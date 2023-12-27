`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
   input wire 	       clk_100mhz,
   output logic [15:0] led,
   input wire [7:0]    pmoda,
   input wire [2:0]    pmodb,
   input wire [15:0]   sw,
   input wire [3:0]    btn,
   output logic [2:0]  rgb0,
   output logic [2:0]  rgb1,
   // seven segment
   output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
   output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
   output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
   output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits
   // uart for manta
   input wire 	       uart_rxd,
   output logic        uart_txd,
   // hdmi port
   output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
   output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
   output logic        hdmi_clk_p, hdmi_clk_n, //differential hdmi clock
   // DDR3 ports
   inout wire [15:0]   ddr3_dq,
   inout wire [1:0]    ddr3_dqs_n,
   inout wire [1:0]    ddr3_dqs_p,
   output wire [12:0]  ddr3_addr,
   output wire [2:0]   ddr3_ba,
   output wire 	       ddr3_ras_n,
   output wire 	       ddr3_cas_n,
   output wire 	       ddr3_we_n,
   output wire 	       ddr3_reset_n,
   output wire 	       ddr3_ck_p,
   output wire 	       ddr3_ck_n,
   output wire 	       ddr3_cke,
   output wire [1:0]   ddr3_dm,
   output wire 	       ddr3_odt
   );
   
   logic 	       sys_rst;
   assign sys_rst = btn;
   assign rgb0 = 0;
   assign rgb1 = 0;

   logic 	       clk_camera;
   logic 	       clk_pixel;
   logic 	       clk_5x;
   
   // very_fast_clk_wiz wizard
   //   (.clk_in1(clk_100mhz),
   //    .clk_out1(clk_camera),
   //    .reset(0)
   //    );
   hdmi_mig_clk_wiz wizard
     (.clk_in1(clk_100mhz),
      .clk_sysref(clk_camera),
      .clk_pixel(clk_pixel),
      .clk_tmds(clk_5x),
      .reset(0)
      );
   
   // ================== CHAPTER: REGISTER DECLARATIONS ================
   
   // manta BRAM
   logic 	       fb_we;
   logic [15:0]        fb_dout;
   logic [15:0]        fb_din;
   logic [$clog2(15360)-1:0] fb_addr;

   // seven segment
   logic [31:0]        ssc_display;


   // camera_bare
   logic 	       hsync_raw;
   logic 	       hsync;
   logic 	       vsync_raw;
   logic 	       vsync;
   
   logic [15:0]        data;
   logic 	       valid_pixel;
   logic 	       valid_byte;
      
   // buffering
   logic [2:0] 	       pmodb_buf0;
   logic [7:0] 	       pmoda_buf0;
   
   logic [2:0] 	       pmodb_buf; // buffer, to make sure values only update on our clock domain!p
   logic [7:0] 	       pmoda_buf;

   // HDMI output wires

   // video signal generator
   logic 	       hsync_hdmi;
   logic 	       vsync_hdmi;
   logic [10:0]        hcount_hdmi;
   logic [9:0] 	       vcount_hdmi;
   logic 	       active_draw_hdmi;
   logic 	       new_frame_hdmi;
   logic [5:0] 	       frame_count_hdmi;

   // rgb output values
   logic [7:0] 	       red,green,blue;

   // mig module
   // user interface signals
   logic [26:0]        app_addr;
   logic [2:0] 	       app_cmd;
   logic 	       app_en;
   logic [127:0]       app_wdf_data;
   logic 	       app_wdf_end;
   logic 	       app_wdf_wren;
   logic [127:0]       app_rd_data;
   logic 	       app_rd_data_end;
   logic 	       app_rd_data_valid;
   logic 	       app_rdy;
   logic 	       app_wdf_rdy;
   logic 	       app_sr_req;
   logic 	       app_ref_req;
   logic 	       app_zq_req;
   logic 	       app_sr_active;
   logic 	       app_ref_ack;
   logic 	       app_zq_ack;
   logic 	       ui_clk;
   logic 	       ui_clk_sync_rst;
   logic [15:0]        app_wdf_mask;
   logic 	       init_calib_complete;
   logic [11:0]        device_temp;


   // ==================== CHAPTER: CAMERA CAPTURE =======================
   always_ff @(posedge clk_camera) begin
      pmoda_buf0 <= pmoda;
      pmodb_buf0 <= pmodb;
      
      pmoda_buf <= pmoda_buf0;
      pmodb_buf <= pmodb_buf0;
   end

   camera_bare cbm
     (.clk_pixel_in(clk_camera),
      .pclk_cam_in(pmodb_buf[0] ),
      .hs_cam_in(pmodb_buf[2]),
      .vs_cam_in(pmodb_buf[1]),
      .rst_in(sys_rst),
      .data_cam_in(pmoda_buf),
      .hs_cam_out(hsync_raw),
      .vs_cam_out(vsync_raw),
      .data_out(data),
      .valid_out(valid_pixel),
      .valid_byte(valid_byte)
      );
   // assign hsync = sw[0] ^ hsync_raw; // if sw[0], invert hsync
   // assign vsync = sw[1] ^ vsync_raw; // if sw[1], invert vsync
   assign hsync = hsync_raw;
   assign vsync = vsync_raw;

   logic valid_cc;
   logic [15:0] pixel_cc;
   logic [12:0] hcount_cc;
   logic [11:0] vcount_cc;

   camera_coord ccm
     (.clk_in(clk_camera),
      .rst_in(sys_rst),
      .valid_in(valid_pixel),
      .data_in(data),
      .hsync_in(hsync),
      .vsync_in(vsync),
      .valid_out(valid_cc),
      .data_out(pixel_cc),
      .hcount_out(hcount_cc),
      .vcount_out(vcount_cc)
      );

   // pass pixels into the phrase builder
   // ignore the ready signal! if its not ready, data will just be missed.
   // nothing else can be done since this is just coming at the rate of the camera
   logic 	phrase_axis_valid;
   logic 	phrase_axis_ready;
   logic [127:0] phrase_axis_data;

   logic [2:0] 	 offset;
   
   build_wr_data
     (.clk_in(clk_camera),
      .rst_in(sys_rst),
      .valid_in(valid_cc),
      .ready_in(), // discard
      .data_in(pixel_cc),
      .valid_out(phrase_axis_valid),
      .ready_out(phrase_axis_ready),
      .offset(offset),
      .data_out(phrase_axis_data)
      );


   // ======================= CHAPTER : SEVEN SEGMENT PROBE ======================
   
   // for the sake of syncing all potentially-used signals:
   logic 	hsync_cc;
   logic 	vsync_cc;
   always_ff @(posedge clk_camera) begin
      hsync_cc <= hsync;
      vsync_cc <= vsync;
   end
   
   assign fb_addr = vcount_cc*120 + hcount_cc;
   assign fb_we = valid_cc && vcount_cc < 128 && hcount_cc < 100;
   assign fb_din = pixel_cc;
   
   // assign led[1] = hcount_cc > 120;

   logic 	one_hz;
   logic [31:0] display_hcvc;
   logic [31:0] display_cycle_count;
   logic [31:0] display_frame_length;
   logic [31:0] display_rowlen_fps;
   
   one_hertz ohm
     (.clk_in(clk_camera),
      .rst_in(sys_rst),
      .one_hz_out(one_hz)
      );

   display_hcount_vcount dm00
     (.clk_in(clk_camera),
      .rst_in(sys_rst),
      .hcount_in(hcount_cc),
      .vcount_in(vcount_cc),
      .hsync_in(hsync_cc),
      .vsync_in(vsync_cc),
      .display_out(display_hcvc)
      );

   display_cycle_count dm01
     (.clk_in(clk_camera),
      .rst_in(sys_rst),
      .one_hz_in(one_hz),
      .valid_byte_in(valid_byte),
      .display_out(display_cycle_count)
      );

   display_frame_length dm02
     (.clk_in(clk_camera),
      .rst_in(sys_rst),
      .vsync_in(vsync),
      .valid_byte_in(valid_byte),
      .display_out(display_frame_length)
      );

   display_rowlen_fps dm03
     (.clk_in(clk_camera),
      .rst_in(sys_rst),
      .hsync_in(hsync),
      .vsync_in(vsync),
      .valid_byte_in(valid_byte),
      .one_hz_in(one_hz),
      .display_out(display_rowlen_fps)
      );

   logic [31:0] ssc_sw;
   
   always_comb begin
      case (sw[1:0])
	2'b00: ssc_sw = display_hcvc;
	2'b01: ssc_sw = display_cycle_count;
	2'b10: ssc_sw = display_frame_length;
	2'b11: ssc_sw = display_rowlen_fps;
      endcase // case (sw[0])
   end
   
   
   always_ff @(posedge clk_camera) begin
      if (sys_rst) begin
	 ssc_display <= 0;
	 led[0] <= 0;
	 led[1] <= 0;
      end else begin
	 if (one_hz || btn[1]) begin
	    ssc_display <= ssc_sw;
	    led[0] <= !led[0];
	    led[1] <= 0;
	 end else if (btn[2]) begin
	    ssc_display <= 32'hDEADBEEF;
	 end else if (ssc_display != ssc_sw) begin
	    led[1] <= 1'b1;
	 end
      end
   end // always_ff @ (posedge clk_camera)


   logic [6:0] ss_c;
   logic       ssc_en;
   assign ssc_en = 1'b1;
   
   seven_segment_controller mssc
     (.clk_in(clk_camera),
      .rst_in(sys_rst),
      .val_in(ssc_display),
      .en_in(ssc_en),
      .cat_out(ss_c),
      .an_out({ss0_an,ss1_an}));
   assign ss0_c = ss_c;
   assign ss1_c = ss_c;

   // =============== CHAPTER: MEMORY MIG STUFF ====================

   logic       write_axis_valid;
   logic       write_axis_ready;
   logic [127:0] write_axis_phrase;

   logic 	 small_pile;

   ddr_fifo camera_write
     (.s_axis_aresetn(~sys_rst), // active low
      .s_axis_aclk(clk_camera),
      .s_axis_tvalid(phrase_axis_valid),
      .s_axis_tready(phrase_axis_ready),
      .s_axis_tdata(phrase_axis_data),
      .m_axis_aclk(ui_clk),
      .m_axis_tvalid(write_axis_valid),
      .m_axis_tready(write_axis_ready), // ready will spit you data! use in proper state
      .m_axis_tdata(write_axis_phrase),
      .prog_empty(small_pile));

   // assign write_axis_ready = 1;
   // always_ff @(posedge ui_clk) begin
   //    if (sys_rst) begin
   // 	 led[15:12] <= 0;
   //    end
   //    led[15] <= led[15] || write_axis_valid;
   //    led[14] <= led[14] || phrase_axis_valid;
   //    led[13] <= led[13] || phrase_axis_ready;
   //    led[12] <= led[12] || valid_cc;
   //    led[11:4] <= phrase_axis_data[39:32];
   // end
   

   // MIG state machine for prime numbers. just to make sure DDR3 is alive
  // logic [31:0] state;
  // logic [31:0] cycle_counter;
  // logic [31:0] num_to_write;
  // logic [31:0] num_to_read;
  // logic [31:0] latency_counter;
  // logic [31:0] val_to_display;
  
  // logic [15:0] sw_intermediate;
  // logic [15:0] sw_sync;
  //  logic       clk_200;
  //  assign clk_200 = clk_camera;
  //  localparam NUM_MAX = 10000;
   
   
   // always_ff @(posedge ui_clk) begin // handle asynchronous switch toggles
   //    sw_intermediate <= sw;
   //    sw_sync <= sw_intermediate;
   // end
   
   // assign led[0] = 1'b1;
   assign led[2] = init_calib_complete; // og led[1]
   // assign led[3] = cycle_counter[28]; // og led[2]

   traffic_generator tg
     (.clk_in(ui_clk),
      .rst_in(sys_rst),
      .app_addr(app_addr),
      .app_cmd(app_cmd),
      .app_en(app_en),
      .app_wdf_data(app_wdf_data),
      .app_wdf_end(app_wdf_end),
      .app_wdf_wren(app_wdf_wren),
      .app_wdf_mask(app_wdf_mask),
      .app_rd_data(app_rd_data),
      .app_rd_data_valid(app_rd_data_valid),
      .app_rdy(app_rdy),
      .app_wdf_rdy(app_wdf_rdy),
      .app_sr_req(app_sr_req),
      .app_ref_req(app_ref_req),
      .app_zq_req(app_zq_req),
      .app_sr_active(app_sr_active),
      .app_ref_ack(app_ref_ack),
      .app_zq_ack(app_zq_ack),
      .init_calib_complete(init_calib_complete),
      .write_axis_data(write_axis_phrase),
      .write_axis_valid(write_axis_valid),
      .write_axis_ready(write_axis_ready),
      .write_axis_smallpile(small_pile),
      .state_out(led[13:11]),
      .trigger_btn_sync(btn[1])
      );
   assign led[5:4] = app_addr[1:0];
   assign led[7] = app_rdy;
   assign led[8] = app_en;
   assign led[9] = app_wdf_rdy;
   assign led[10] = app_wdf_wren;
   assign led[14] = small_pile;
   assign led[15] = write_axis_ready;
   assign led[6] = phrase_axis_ready;
   
   
   
   
  // assign led[3] = app_rdy;
  // assign led[15:4] = device_temp;

  // logic btn0_deb;
  // debouncer btn0_db (
  //   .clk_in(clk_200),
  //   .rst_in(btn[1]), // button 0 resets the system, button 1 resets the debouncer.
  //   .dirty_in(btn[0]),
  //   .clean_out(btn0_deb)
  // );
  // logic sys_rst_200, sys_rst_200_0, sys_rst_200_1;
  // always_ff @(posedge clk_200) begin
  //   sys_rst_200_0 <= btn0_deb;
  //   sys_rst_200_1 <= sys_rst_200_0;
  //   sys_rst_200 <= sys_rst_200_1;
  // end

  // always_ff @(posedge ui_clk) begin
  //   if (ui_clk_sync_rst) begin
  //     cycle_counter <= 0;
  //   end else begin
  //     cycle_counter <= cycle_counter + 1;
  //   end
  // end
  
  // // Made by Andrew Weinfeld, andrewj31415@gmail.com
  // always_ff @(posedge ui_clk) begin
  //   if (ui_clk_sync_rst) begin
  //     state <= 0;
  //   end else begin
  //     if (state == 0) begin
  //       state <= 1;
  //     end else if (state == 1) begin
  //       state <= 2;
  //       num_to_write <= 2;
  //     end else if (state == 2) begin
  //       if (app_wdf_rdy) begin
  //         state <= 3;
  //       end
  //     end else if (state == 3) begin
  //       if (app_rdy) begin
  //         if (num_to_write < NUM_MAX) begin
  //           state <= 2;
  //           num_to_write <= num_to_write + 1;
  //         end else begin
  //           state <= 4;
  //           num_to_read <= 2;
  //         end
  //       end
  //     end else if (state == 4) begin
  //       if (app_rdy) begin
  //         state <= 5;
  //       end
  //     end else if (state == 5) begin
  //       if (app_rd_data_valid) begin
  //         if (app_rd_data == 0) begin // not prime
  //           state <= 4;
  //           num_to_read <= num_to_read + 1;
  //         end else begin // prime!
  //           state <= 6;
  //           num_to_write <= num_to_read * 2;
  //         end
  //       end
  //     end else if (state == 6) begin
  //       if (app_wdf_rdy) begin
  //         state <= 7;
  //       end
  //     end else if (state == 7) begin
  //       if (app_rdy) begin
  //         if (num_to_write < NUM_MAX) begin
  //           num_to_write <= num_to_write + num_to_read;
  //           state <= 6;
  //         end else if (num_to_read < NUM_MAX) begin
  //           state <= 4;
  //           num_to_read <= num_to_read + 1;
  //         end else begin
  //           state <= 8;
  //           num_to_read <= 1;
  //         end
  //       end
  //     end else if (state == 8) begin
  //       if ((cycle_counter[23:0] == 0) && !sw_sync[0]) begin
  //         state <= 9;
  //         latency_counter <= 0;
  //         if (num_to_read >= NUM_MAX) begin
  //           num_to_read <= 2;
  //         end else begin
  //           num_to_read <= num_to_read + 1;
  //         end
  //       end else if (sw_sync[1]) begin
  //         num_to_read <= 2;
  //       end
  //     end else if (state == 9) begin
  //       latency_counter <= latency_counter + 1;
  //       if (app_rdy) begin
  //         state <= 10;
  //       end
  //     end else if (state == 10) begin
  //       latency_counter <= latency_counter + 1;
  //       if (app_rd_data_valid) begin
  //         if (app_rd_data == 0) begin
  //           state <= 9;
  //           if (num_to_read >= NUM_MAX) begin
  //             num_to_read <= 2;
  //           end else begin
  //             num_to_read <= num_to_read + 1;
  //           end
  //         end else begin
  //           state <= 8;
  //         end
  //       end
  //     end
  //   end
  // end

  // assign app_sr_req = 0;    // We aren't using these signals.
  // assign app_ref_req = 0;
  // assign app_zq_req = 0;
  // always_comb begin   // Made by Andrew Weinfeld, andrewj31415@gmail.com
  //   if (state == 0) begin
  //     app_addr = 0;
  //     app_cmd = 0;
  //     app_en = 0;
  //     app_wdf_data = 0;
  //     app_wdf_end = 0;
  //     app_wdf_wren = 0;
  //     app_wdf_mask = 0;
  //   end else if (state == 1) begin
  //     app_addr = 0;
  //     app_cmd = 0;
  //     app_en = 0;
  //     app_wdf_data = 0;
  //     app_wdf_end = 0;
  //     app_wdf_wren = 0;
  //     app_wdf_mask = 0;
  //   end else if (state == 2) begin
  //     app_addr = 0;
  //     app_cmd = 0;
  //     app_en = 0;
  //     app_wdf_data = num_to_write;
  //     app_wdf_end = 1;
  //     app_wdf_wren = 1;
  //     app_wdf_mask = 0;
  //   end else if (state == 3) begin
  //     app_addr = num_to_write << 8;
  //     app_cmd = 0;
  //     app_en = 1;
  //     app_wdf_data = 0;
  //     app_wdf_end = 0;
  //     app_wdf_wren = 0;
  //     app_wdf_mask = 0;
  //   end else if (state == 4) begin
  //     app_addr = num_to_read << 8;
  //     app_cmd = 1;
  //     app_en = 1;
  //     app_wdf_data = 0;
  //     app_wdf_end = 0;
  //     app_wdf_wren = 0;
  //     app_wdf_mask = 0;
  //   end else if (state == 5) begin
  //     app_addr = 0;
  //     app_cmd = 0;
  //     app_en = 0;
  //     app_wdf_data = 0;
  //     app_wdf_end = 0;
  //     app_wdf_wren = 0;
  //     app_wdf_mask = 0;
  //   end else if (state == 6) begin
  //     app_addr = 0;
  //     app_cmd = 0;
  //     app_en = 0;
  //     app_wdf_data = 0;
  //     app_wdf_end = 1;
  //     app_wdf_wren = 1;
  //     app_wdf_mask = 0;
  //   end else if (state == 7) begin
  //     app_addr = num_to_write << 8;
  //     app_cmd = 0;
  //     app_en = 1;
  //     app_wdf_data = 0;
  //     app_wdf_end = 0;
  //     app_wdf_wren = 0;
  //     app_wdf_mask = 0;
  //   end else if (state == 8) begin
  //     app_addr = 0;
  //     app_cmd = 0;
  //     app_en = 0;
  //     app_wdf_data = 0;
  //     app_wdf_end = 0;
  //     app_wdf_wren = 0;
  //     app_wdf_mask = 0;
  //   end else if (state == 9) begin
  //     app_addr = num_to_read << 8;
  //     app_cmd = 1;
  //     app_en = 1;
  //     app_wdf_data = 0;
  //     app_wdf_end = 0;
  //     app_wdf_wren = 0;
  //     app_wdf_mask = 0;
  //   end else if (state == 10) begin
  //     app_addr = 0;
  //     app_cmd = 0;
  //     app_en = 0;
  //     app_wdf_data = 0;
  //     app_wdf_end = 0;
  //     app_wdf_wren = 0;
  //     app_wdf_mask = 0;
  //   end else begin
  //     app_addr = 0;
  //     app_cmd = 0;
  //     app_en = 0;
  //     app_wdf_data = 0;
  //     app_wdf_end = 0;
  //     app_wdf_wren = 0;
  //     app_wdf_mask = 0;
  //   end
  // end

  // logic [16+(16-4)/3:0] bcd;
  // logic [16+(16-4)/3:0] bcd2;
  // bin2bcd#(.W(16)) bin2bcd_inst (
  //   .bin(num_to_read),
  //   .bcd(bcd)
  // );
  // bin2bcd#(.W(16)) bin2bcd_inst2 (
  //   .bin(latency_counter),
  //   .bcd(bcd2)
  // );
  // assign val_to_display = {bcd2[15:0], bcd[15:0]};

  // logic [6:0] ss_c;
  // seven_segment_controller mssc (
  //   .clk_in(ui_clk),
  //   .rst_in(ui_clk_sync_rst),
  //   .val_in(val_to_display),
  //   .cat_out(ss_c),
  //   .an_out({ss0_an, ss1_an})
  // );
  // assign ss0_c = ss_c; //control upper four digit's cathodes!
  // assign ss1_c = ss_c; //same as above but for lower four digits!
    
   ddr3_mig ddr3_mig_inst 
     (
      .ddr3_dq(ddr3_dq),
      .ddr3_dqs_n(ddr3_dqs_n),
      .ddr3_dqs_p(ddr3_dqs_p),
      .ddr3_addr(ddr3_addr),
      .ddr3_ba(ddr3_ba),
      .ddr3_ras_n(ddr3_ras_n),
      .ddr3_cas_n(ddr3_cas_n),
      .ddr3_we_n(ddr3_we_n),
      .ddr3_reset_n(ddr3_reset_n),
      .ddr3_ck_p(ddr3_ck_p),
      .ddr3_ck_n(ddr3_ck_n),
      .ddr3_cke(ddr3_cke),
      .ddr3_dm(ddr3_dm),
      .ddr3_odt(ddr3_odt),
      .sys_clk_i(clk_camera),
      .app_addr(app_addr),
      .app_cmd(app_cmd),
      .app_en(app_en),
      .app_wdf_data(app_wdf_data),
      .app_wdf_end(app_wdf_end),
      .app_wdf_wren(app_wdf_wren),
      .app_rd_data(app_rd_data),
      .app_rd_data_end(app_rd_data_end),
      .app_rd_data_valid(app_rd_data_valid),
      .app_rdy(app_rdy),
      .app_wdf_rdy(app_wdf_rdy), 
      .app_sr_req(app_sr_req),
      .app_ref_req(app_ref_req),
      .app_zq_req(app_zq_req),
      .app_sr_active(app_sr_active),
      .app_ref_ack(app_ref_ack),
      .app_zq_ack(app_zq_ack),
      .ui_clk(ui_clk), 
      .ui_clk_sync_rst(ui_clk_sync_rst),
      .app_wdf_mask(app_wdf_mask),
      .init_calib_complete(init_calib_complete),
      .device_temp(device_temp),
      .sys_rst(!sys_rst) // active low
      );


   // =============== CHAPTER: HDMI OUTPUT =========================
   
   logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
   logic       tmds_signal [2:0]; //output of each TMDS serializer!
   
   
   // for now:
   assign red = 8'hFF;
   assign green = 8'h77;
   assign blue = 8'hAA;

   // video signal generator
   video_sig_gen vsg
     (
      .clk_pixel_in(clk_pixel),
      .rst_in(sys_rst),
      .hcount_out(hcount_hdmi),
      .vcount_out(vcount_hdmi),
      .vs_out(vsync_hdmi),
      .hs_out(hsync_hdmi),
      .ad_out(active_draw_hdmi),
      .fc_out(frame_count_hdmi)
      );
   
   
      
   //three tmds_encoders (blue, green, red)
   //note green should have no control signal like red
   //the blue channel DOES carry the two sync signals:
   //  * control_in[0] = horizontal sync signal
   //  * control_in[1] = vertical sync signal

   tmds_encoder tmds_red(
			 .clk_in(clk_pixel),
			 .rst_in(sys_rst),
			 .data_in(red),
			 .control_in(2'b0),
			 .ve_in(active_draw_hdmi),
			 .tmds_out(tmds_10b[2]));

   tmds_encoder tmds_green(
			   .clk_in(clk_pixel),
			   .rst_in(sys_rst),
			   .data_in(green),
			   .control_in(2'b0),
			   .ve_in(active_draw_hdmi),
			   .tmds_out(tmds_10b[1]));

   tmds_encoder tmds_blue(
			  .clk_in(clk_pixel),
			  .rst_in(sys_rst),
			  .data_in(blue),
			  .control_in({vsync_hdmi,hsync_hdmi}),
			  .ve_in(active_draw_hdmi),
			  .tmds_out(tmds_10b[0]));
   
   
   //three tmds_serializers (blue, green, red):
   //MISSING: two more serializers for the green and blue tmds signals.
   tmds_serializer red_ser(
			   .clk_pixel_in(clk_pixel),
			   .clk_5x_in(clk_5x),
			   .rst_in(sys_rst),
			   .tmds_in(tmds_10b[2]),
			   .tmds_out(tmds_signal[2]));
   tmds_serializer green_ser(
			   .clk_pixel_in(clk_pixel),
			   .clk_5x_in(clk_5x),
			   .rst_in(sys_rst),
			   .tmds_in(tmds_10b[1]),
			   .tmds_out(tmds_signal[1]));
   tmds_serializer blue_ser(
			   .clk_pixel_in(clk_pixel),
			   .clk_5x_in(clk_5x),
			   .rst_in(sys_rst),
			   .tmds_in(tmds_10b[0]),
			   .tmds_out(tmds_signal[0]));
   
   //output buffers generating differential signals:
   //three for the r,g,b signals and one that is at the pixel clock rate
   //the HDMI receivers use recover logic coupled with the control signals asserted
   //during blanking and sync periods to synchronize their faster bit clocks off
   //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
   //the slower 74.25 MHz clock)
   OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
   OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
   OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
   OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));
   

   // ====================== CHAPTER: MANTA PROBE ===================

   // manta connection
   manta manta_inst
     (.clk(clk_camera),
      .rx(uart_rxd),
      .tx(uart_txd),
      .data_valid_cb(valid_pixel),
      .data_valid_cc(valid_cc),
      .cam_data_in(pmoda_buf),
      // .cam_data_cb(data),
      .cam_data_cc(pixel_cc),
      // .hsync(hsync),
      // .vsync(vsync),
      .pclk_cam_in(pmodb_buf[0]),
      .offset(offset),
      .phrase_axis_ready(phrase_axis_ready),
      .phrase_axis_valid(phrase_axis_valid)
      // fb BRAM
      // .frame_buffer_clk(clk_camera),
      // .frame_buffer_addr(fb_addr),
      // .frame_buffer_din(fb_din),
      // .frame_buffer_dout(fb_dout),
      // .frame_buffer_we(fb_we)
      );
   
endmodule // top_level


//written in lab!
//debounce_2.sv is a different attempt at this done after class with a few students
module  debouncer #(
  parameter CLK_PERIOD_NS = 10,
  parameter DEBOUNCE_TIME_MS = 5
) (
  input wire clk_in,
  input wire rst_in,
  input wire dirty_in,
  output logic clean_out
);
  
  parameter COUNTER_MAX = int($ceil(DEBOUNCE_TIME_MS*1_000_000/CLK_PERIOD_NS));
  parameter COUNTER_SIZE = $clog2(COUNTER_MAX);
  logic [COUNTER_SIZE-1:0] counter;
  logic current; //register holds current output
  logic old_dirty_in;
  assign clean_out = current;

  always_ff @(posedge clk_in) begin
    if (rst_in)begin
      counter <= 0;
      current <= dirty_in;
      old_dirty_in <= dirty_in;
    end else begin
      if (counter == COUNTER_MAX-1)begin
        current <= old_dirty_in;
        counter <= 0;
      end else if (dirty_in == old_dirty_in) begin
        counter <= counter +1;
      end else begin
        counter <= 0;
      end
    end
    old_dirty_in <= dirty_in;
  end
endmodule

`default_nettype wire
