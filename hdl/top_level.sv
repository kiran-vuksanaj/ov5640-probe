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
   assign rgb0 = 0;
   assign rgb1 = 0;
   
   logic 	       sys_rst_camera;
   logic 	       sys_rst_ui;
   logic 	       sys_rst_pixel;

   logic 	       trigger_btn_camera;
   logic 	       trigger_btn_ui;
   logic 	       trigger_btn_pixel;

   logic 	       clk_camera;
   logic 	       clk_pixel;
   logic 	       clk_5x;
   logic 	       ui_clk;
   
   
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

   debouncer dbr
     (.clk_in(clk_camera),
      .rst_in(btn[2]),
      .dirty_in(btn[0]),
      .clean_out(sys_rst_camera));

   slow_clock_sync #(.WIDEN_CYCLES(4)) scs_ru
     (.clk_fast(clk_camera),
      .rst_fast(btn[2]),
      .signal_fast(sys_rst_camera),
      .clk_slow(ui_clk),
      .signal_slow(sys_rst_ui));
   slow_clock_sync #(.WIDEN_CYCLES(4)) scs_rp
     (.clk_fast(clk_camera),
      .rst_fast(btn[2]),
      .signal_fast(sys_rst_camera),
      .clk_slow(clk_pixel),
      .signal_slow(sys_rst_pixel));

   debouncer dbt
     (.clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .dirty_in(btn[1]),
      .clean_out(trigger_btn_camera));

   slow_clock_sync #(.WIDEN_CYCLES(4)) scs_tu
     (.clk_fast(clk_camera),
      .rst_fast(sys_rst_camera),
      .signal_fast(trigger_btn_camera),
      .clk_slow(ui_clk),
      .signal_slow(trigger_btn_ui));
   slow_clock_sync #(.WIDEN_CYCLES(4)) scs_tp
     (.clk_fast(clk_camera),
      .rst_fast(sys_rst_camera),
      .signal_fast(trigger_btn_camera),
      .clk_slow(clk_pixel),
      .signal_slow(trigger_btn_pixel));
   
   
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
   // logic 	       ui_clk; // defined higher up now
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
      .rst_in(sys_rst_camera),
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
      .rst_in(sys_rst_camera),
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

   // logic [2:0] 	 offset;

   logic [15:0]  pixel_cc_filter;

   /* temporary code to test out hcount/vcount in a different way */
   logic 	 ready_builder;
   
   logic [20:0]  addr_simulator;
   addr_increment #(.ROLLOVER(1280*720)) aias
     (.clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .incr_in( valid_cc && ready_builder ),
      .addr_out( addr_simulator )
      );
   logic [12:0]	 hcount_fake;
   logic [12:0]  vcount_fake;
   assign hcount_fake = addr_simulator % 1280;
   assign vcount_fake = addr_simulator / 1280;

   logic [15:0]  hcount_stripes;
   assign hcount_stripes = {hcount_fake[5:1],hcount_fake[5:1],1'b0,hcount_fake[5:1]};

   logic [15:0]  vcount_stripes;
   assign vcount_stripes = {vcount_fake[7:3],vcount_fake[7:3],1'b0,vcount_fake[7:3]};
   
   // assign pixel_cc_filter = (hcount_cc < 200 || hcount_cc > 300) ? pixel_cc : 0'hF81F;
   // assign pixel_cc_filter = 16'hFFFF;
   // assign pixel_cc_filter = {hcount_cc[4:0],vcount_cc[5:0],5'b10101};
   assign pixel_cc_filter = sw[2] ? vcount_stripes : hcount_stripes;
   /* end temp code */
   
   build_wr_data
     (.clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .valid_in(valid_cc),
      .ready_in(ready_builder), // discard
      // .data_in(pixel_cc_filter),// temporary test value
      .data_in(pixel_cc),
      .valid_out(phrase_axis_valid),
      .ready_out(phrase_axis_ready),
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
      .rst_in(sys_rst_camera),
      .one_hz_out(one_hz)
      );

   display_hcount_vcount dm00
     (.clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .hcount_in(hcount_cc),
      .vcount_in(vcount_cc),
      .hsync_in(hsync_cc),
      .vsync_in(vsync_cc),
      .display_out(display_hcvc)
      );

   display_cycle_count dm01
     (.clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .one_hz_in(one_hz),
      .valid_byte_in(valid_byte),
      .display_out(display_cycle_count)
      );

   display_frame_length dm02
     (.clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .vsync_in(vsync),
      .valid_byte_in(valid_byte),
      .display_out(display_frame_length)
      );

   display_rowlen_fps dm03
     (.clk_in(clk_camera),
      .rst_in(sys_rst_camera),
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
      if (sys_rst_camera) begin
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
      .rst_in(sys_rst_camera),
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
     (.s_axis_aresetn(~sys_rst_camera), // active low
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

   // assign led[0] = 1'b1;
   assign led[2] = init_calib_complete; // og led[1]
   // assign led[3] = cycle_counter[28]; // og led[2]

   logic [127:0] read_axis_data;
   logic 	 read_axis_valid;
   logic 	 read_axis_af;
   logic 	 read_axis_ready;

   logic [2:0] 	 state;
   
   traffic_generator tg
     (.clk_in(ui_clk),
      .rst_in(sys_rst_ui),
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
      .read_axis_data(read_axis_data),
      .read_axis_valid(read_axis_valid),
      .read_axis_af(read_axis_af),
      .read_axis_ready(read_axis_ready),
      .state_out(state),
      .trigger_btn_sync(trigger_btn_ui)
      );


   logic 	 hdmi_axis_valid;
   logic 	 hdmi_axis_ready;
   logic [127:0] hdmi_axis_data;
   
   ddr_fifo hdmi_read
     (.s_axis_aresetn(~sys_rst_ui), // active low
      .s_axis_aclk(ui_clk),
      .s_axis_tvalid(read_axis_valid),
      .s_axis_tready(read_axis_ready),
      .s_axis_tdata(read_axis_data),
      .prog_full(read_axis_af),
      .m_axis_aclk(clk_pixel),
      .m_axis_tvalid(hdmi_axis_valid),
      .m_axis_tready(hdmi_axis_ready), // ready will spit you data! use in proper state
      .m_axis_tdata(hdmi_axis_data));

   logic [15:0]  hdmi_pixel;
   logic 	 hdmi_pixel_ready;
   logic 	 hdmi_pixel_valid;

   digest_phrase
     (.clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .valid_phrase(hdmi_axis_valid),
      .ready_phrase(hdmi_axis_ready),
      .phrase_data(hdmi_axis_data),
      .valid_word(hdmi_pixel_valid),
      .ready_word(hdmi_pixel_ready),
      .word(hdmi_pixel));
   
   // assign led[5:4] = hdmi_pixel[8:7];
   // assign led[7] = hdmi_axis_ready;
   // assign led[8] = hdmi_axis_valid;
   // assign led[9] = read_axis_ready;
   // assign led[14] = read_axis_valid;
   // assign led[15] = hdmi_pixel_valid;
   // assign led[6] = hdmi_pixel_ready;

   assign led[15:3] = {state, // 15:13
		       write_axis_ready, write_axis_valid, // 12:11
		       write_axis_phrase == 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, small_pile, // 10:9
		       phrase_axis_ready, phrase_axis_valid, phrase_axis_data == 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, //8:6
		       valid_cc, pixel_cc_filter == 16'hFFFF, 1'b0//5:3
		       };
    
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
      .sys_rst(!sys_rst_camera) // active low
      );


   // =============== CHAPTER: HDMI OUTPUT =========================
   
   logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
   logic       tmds_signal [2:0]; //output of each TMDS serializer!
   
   
   // // for now:
   // assign red = 8'hFF;
   // assign green = 8'h77;
   // assign blue = 8'hAA;
   assign hdmi_pixel_ready = active_draw_hdmi;
   // logic [15:0] hdmi_pixel_hold;
   // always_ff @(posedge clk_pixel) begin
   //    if (sys_rst_pixel) begin
   // 	 hdmi_pixel_hold <= 24'h000000;
   //    end else begin
   // 	 hdmi_pixel_hold <= (hdmi_pixel_ready && hdmi_pixel_valid) ? hdmi_pixel : hdmi_pixel_hold;
   //    end
   // end
   assign red = (vcount_hdmi == 222) ? 8'h00 : (hdmi_pixel_valid ? {hdmi_pixel[15:11],3'b0} : 8'hFF);
   assign green = (vcount_hdmi == 222) ? 8'hFF : (hdmi_pixel_valid ? {hdmi_pixel[10:5],2'b0} : 8'h77);
   assign blue = (vcount_hdmi == 222) ? 8'h00 : (hdmi_pixel_valid ? {hdmi_pixel[4:0],3'b0} : 8'hAA);
   // assign red = hdmi_pixel_valid ? 8'hFF : 16'h88;
   // assign green = hdmi_pixel_valid ? 8'h77 : 8'h88;
   // assign blue = hdmi_pixel_valid ? 8'hAA : 8'h88;
   // assign red = {hdmi_pixel_hold[15:11],3'b0};
   // assign green = {hdmi_pixel_hold[10:5],2'b0};
   // assign blue = {hdmi_pixel_hold[4:0],3'b0};
   
   // video signal generator
   video_sig_gen vsg
     (
      .clk_pixel_in(clk_pixel),
      .rst_in(sys_rst_pixel),
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
			 .rst_in(sys_rst_pixel),
			 .data_in(red),
			 .control_in(2'b0),
			 .ve_in(active_draw_hdmi),
			 .tmds_out(tmds_10b[2]));

   tmds_encoder tmds_green(
			   .clk_in(clk_pixel),
			   .rst_in(sys_rst_pixel),
			   .data_in(green),
			   .control_in(2'b0),
			   .ve_in(active_draw_hdmi),
			   .tmds_out(tmds_10b[1]));

   tmds_encoder tmds_blue(
			  .clk_in(clk_pixel),
			  .rst_in(sys_rst_pixel),
			  .data_in(blue),
			  .control_in({vsync_hdmi,hsync_hdmi}),
			  .ve_in(active_draw_hdmi),
			  .tmds_out(tmds_10b[0]));
   
   
   //three tmds_serializers (blue, green, red):
   //MISSING: two more serializers for the green and blue tmds signals.
   tmds_serializer red_ser(
			   .clk_pixel_in(clk_pixel),
			   .clk_5x_in(clk_5x),
			   .rst_in(sys_rst_pixel),
			   .tmds_in(tmds_10b[2]),
			   .tmds_out(tmds_signal[2]));
   tmds_serializer green_ser(
			   .clk_pixel_in(clk_pixel),
			   .clk_5x_in(clk_5x),
			   .rst_in(sys_rst_pixel),
			   .tmds_in(tmds_10b[1]),
			   .tmds_out(tmds_signal[1]));
   tmds_serializer blue_ser(
			   .clk_pixel_in(clk_pixel),
			   .clk_5x_in(clk_5x),
			   .rst_in(sys_rst_pixel),
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
     (.clk(ui_clk),
      .rx(uart_rxd),
      .tx(uart_txd),
      .tg_state(state), 
      .app_rdy(app_rdy), 
      .app_en(app_en),
      .app_cmd(app_cmd),
      .app_addr(app_addr[20:0]),
      .app_wdf_rdy(app_wdf_rdy), 
      .app_wdf_wren(app_wdf_wren), 
      .app_wdf_data_slice(app_wdf_data[95:80]), 
      .app_rd_data_valid(app_rd_data_valid), 
      .app_rd_data_slice(app_rd_data[95:80]),
      .app_rd_data_end(app_rd_data_end),
      .write_axis_smallpile(small_pile), 
      .read_axis_af(read_axis_af), 
      .trigger_btn(trigger_btn_ui)
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
  parameter CLK_PERIOD_NS = 5,
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
