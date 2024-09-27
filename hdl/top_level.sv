`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
   input wire 				 clk_100mhz,
   output logic [15:0] led,
	 // camera bus
   input wire [7:0] 	 camera_d, // 8 parallel data wires
   output logic 			 cam_xclk, // XC driving camera
   input wire 				 cam_hsync, // camera hsync wire
   input wire 				 cam_vsync, // camera vsync wire
   input wire 				 cam_pclk, // camera pixel clock
   inout wire 				 i2c_scl, // i2c inout clock
   inout wire 				 i2c_sda, // i2c inout data
   input wire [15:0] 	 sw,
   input wire [3:0] 	 btn,
   output logic [2:0]  rgb0,
   output logic [2:0]  rgb1,
   // seven segment
   output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
   output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
   output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
   output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits
   // uart for manta
   input wire 				 uart_rxd,
   output logic 			 uart_txd,
   // hdmi port
   output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
   output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
   output logic 			 hdmi_clk_p, hdmi_clk_n //differential hdmi clock
   );
   assign rgb0 = 0;
   assign rgb1 = 0;
   
   logic 	       sys_rst_camera;
   logic 	       sys_rst_pixel;

   logic 	       clk_camera;
   logic 	       clk_pixel;
   logic 	       clk_5x;
   logic 	       clk_xc;

   // logic 	       ui_clk;
   // logic 	       ui_clk_sync_rst;
   
   logic 	       clk_100_passthrough;
   
   cw_hdmi_clk_wiz wizard_hdmi
     (.sysclk(clk_100_passthrough),
      .clk_pixel(clk_pixel),
      .clk_tmds(clk_5x),
      .reset(0));

   cw_fast_clk_wiz wizard_migcam
     (.clk_in1(clk_100mhz),
      .clk_camera(clk_camera),
      .clk_xc(clk_xc),
      .clk_100(clk_100_passthrough),
      .reset(0));

	 // assign camera's xclk to pmod port
   assign cam_xclk = clk_xc;

	 assign sys_rst_camera = btn[0];
	 assign sys_rst_pixel = btn[0];

	 logic 				 trigger_btn_camera;
	 
	 debouncer camera_config_deb
		 (.clk_in(clk_camera),
			.rst_in(sys_rst_camera),
			.dirty_in(btn[1]),
			.clean_out(trigger_btn_camera));
	 
	 
	 
   // ================== CHAPTER: REGISTER DECLARATIONS ================
   
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
   logic [7:0] 	 camera_d_buf [1:0];
   logic 	       cam_hsync_buf [1:0];
   logic 	       cam_vsync_buf [1:0];
   logic 	       cam_pclk_buf [1:0];
   
   // HDMI output wires

   // video signal generator
   logic 	       hsync_hdmi;
   logic 	       vsync_hdmi;
   logic [10:0]  hcount_hdmi;
   logic [9:0] 	 vcount_hdmi;
   logic 	       active_draw_hdmi;
   logic 	       new_frame_hdmi;
   logic [5:0] 	 frame_count_hdmi;

   // rgb output values
   logic [7:0] 	       red,green,blue;


   // ==================== CHAPTER: CAMERA CAPTURE =======================

	 // synchronizers anti-metastability
   always_ff @(posedge clk_camera) begin
      camera_d_buf <= {camera_d, camera_d_buf[0]};
      cam_pclk_buf <= {cam_pclk, cam_pclk_buf[0]};
      cam_hsync_buf <= {cam_hsync, cam_hsync_buf[0]};
      cam_vsync_buf <= {cam_vsync, cam_vsync_buf[0]};
   end

	 // camera bare: reconstructs 8-bit adjacent pieces into 16-bit pixels (RGB565)
	 // in accordance with when vs/hs are held high
	 // 1 clock cycle delay
   camera_bare cbm
     (.clk_pixel_in(clk_camera),
      .pclk_cam_in(cam_pclk_buf[1]),
      .hs_cam_in(cam_hsync_buf[1]),
      .vs_cam_in(cam_vsync_buf[1]),
      .rst_in(sys_rst_camera),
      .data_cam_in(camera_d_buf[1]),
      .hs_cam_out(hsync_raw),
      .vs_cam_out(vsync_raw),
      .data_out(data),
      .valid_out(valid_pixel),
      .valid_byte(valid_byte)
      );
   assign hsync = hsync_raw;
   assign vsync = vsync_raw;

   logic valid_cc;
   logic [15:0] pixel_cc;
   logic [12:0] hcount_cc;
   logic [11:0] vcount_cc;

	 // camera coord: determines hcount and vcount of incoming camera data
	 // 1 clock cycle delay
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


   // ======================= CHAPTER : SEVEN SEGMENT PROBE ======================
   
   // for the sake of syncing all potentially-used signals:
   logic 	hsync_cc;
   logic 	vsync_cc;
   always_ff @(posedge clk_camera) begin
      hsync_cc <= hsync;
      vsync_cc <= vsync;
   end
   
   logic 	one_hz;
   logic [31:0] display_hcvc;
   logic [31:0] display_cycle_count;
   logic [31:0] display_frame_length;
   logic [31:0] display_rowlen_fps;
   
   one_hertz #(.REF_CLK(200_000_000)) ohm 
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


   // =============== CHAPTER: HDMI OUTPUT =========================
   
   logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
   logic       tmds_signal [2:0]; //output of each TMDS serializer!
   
   // for now:
	 assign red = 8'h94;
	 assign green = 8'h13;
	 assign blue = 8'h34;
	 
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
   

   // ====================== CHAPTER: REGISTER WRITES ===================

   logic 	 busy, bus_active;
   logic       cr_init_valid, cr_init_ready;
	 assign cr_init_valid = trigger_btn_camera;

   logic [23:0] bram_dout;
   logic [7:0] 	bram_addr;
   
   
   xilinx_single_port_ram_read_first
     #(
       .RAM_WIDTH(24),                       // Specify RAM data width
       .RAM_DEPTH(256),                     // Specify RAM depth (number of entries)
       .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
       .INIT_FILE("rom.mem")          // Specify name/location of RAM initialization file if using one (leave blank if not)
       ) registers
       (
				.addra(bram_addr),     // Address bus, width determined from RAM_DEPTH
				.dina(24'b0),       // RAM input data, width determined from RAM_WIDTH
				.clka(clk_camera),       // Clock
				.wea(1'b0),         // Write enable
				.ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
				.rsta(sys_rst_camera),       // Output reset (does not affect memory contents)
				.regcea(1'b1),   // Output register enable
				.douta(bram_dout)      // RAM output data, width determined from RAM_WIDTH
				);

   logic [23:0] registers_dout;
   logic [7:0] 	registers_addr;
	 assign registers_dout = bram_dout;
   assign bram_addr = registers_addr;
   
   logic       con_scl_i, con_scl_o, con_scl_t;
   logic       con_sda_i, con_sda_o, con_sda_t;

   // NOTE these also have pullup specified in the xdc file!
   IOBUF IOBUF_scl (.I(con_scl_o), .IO(i2c_scl), .O(con_scl_i), .T(con_scl_t) );
   IOBUF IOBUF_sda (.I(con_sda_o), .IO(i2c_sda), .O(con_sda_i), .T(con_sda_t) );
   
   camera_registers crw
     (.clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .init_valid(cr_init_valid),
      .init_ready(cr_init_ready),
      .scl_i(con_scl_i),
      .scl_o(con_scl_o),
      .scl_t(con_scl_t),
      .sda_i(con_sda_i),
      .sda_o(con_sda_o),
      .sda_t(con_sda_t),
      .bram_dout(registers_dout),
      .bram_addr(registers_addr),
      .busy(busy),
      .bus_active(bus_active));

	 assign led[5] = busy;
	 assign led[6] = bus_active;
	 assign led[7] = cr_init_valid;
	 assign led[8] = cr_init_ready;
	 
endmodule // top_level


`default_nettype wire
