`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
   input wire 	       clk_100mhz,
   output logic [15:0] led,
   input wire [7:0]    pmoda,
   input wire [2:0]    pmodb,
   input wire [15:0]   sw,
   output logic        pmodb_xc,
   input wire [3:0]    btn,
   output logic [2:0]  rgb0,
   output logic [2:0]  rgb1,
   output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
   output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
   output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
   output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits
   input wire 	       uart_rxd,
   output logic        uart_txd
   );
   logic 	       sys_rst;
   assign sys_rst = btn;
   assign rgb0 = 0;
   assign rgb1 = 0;

   logic 	       clk_camera;

   // xc_pc_clk_wiz wizard
   //   (.clk_in1(clk_100mhz),
   //    .clk_xc(pmodb_xc),
   //    .clk_rd(clk_camera),
   //    .reset(0)
   //    );
   very_fast_clk_wiz wizard
     (.clk_in1(clk_100mhz),
      .clk_out1(clk_camera),
      .reset(0)
      );
   
   
   // manta BRAM
   logic 	       fb_we;
   logic [15:0]        fb_dout;
   logic [15:0]        fb_din;
   logic [$clog2(15360)-1:0] fb_addr;
   

   logic [7:0]        count_frames;
   logic [31:0]        ssc_display;
   
   logic 	       hsync_raw;
   logic 	       hsync;
   logic 	       vsync_raw;
   logic 	       vsync;
   
   logic [15:0]        data;
   logic 	       valid_pixel;
   logic 	       valid_byte;
      

   logic 	       pclk_prev;

   logic [2:0] 	       pmodb_buf0;
   logic [7:0] 	       pmoda_buf0;
   
   logic [2:0] 	       pmodb_buf; // buffer, to make sure values only update on our clock domain!p
   logic [7:0] 	       pmoda_buf;
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


   // manta connection
   manta manta_inst
     (.clk(clk_camera),
      .rx(uart_rxd),
      .tx(uart_txd),
      .data_valid_cb(valid_pixel),
      .data_valid_cc(valid_cc),
      .cam_data_in(pmoda_buf),
      .cam_data_cb(data),
      // .cam_data_cc(pixel_cc),
      .hsync(hsync),
      .vsync(vsync),
      .pclk_cam_in(pmodb_buf[0])
      // fb BRAM
      // .frame_buffer_clk(clk_camera),
      // .frame_buffer_addr(fb_addr),
      // .frame_buffer_din(fb_din),
      // .frame_buffer_dout(fb_dout),
      // .frame_buffer_we(fb_we)
      );
   
endmodule // top_level


`default_nettype wire
