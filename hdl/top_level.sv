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
   // clk_wiz_0_clk_wiz wizard
   //   (.clk_in1(clk_100mhz),
   //    .clk_out2(clk_camera),
   //    .reset(0)
   //    );
   xc_pc_clk_wiz wizard
     (.clk_in1(clk_100mhz),
      .clk_xc(pmodb_xc),
      .clk_rd(clk_camera),
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
   

   logic 	       pclk_prev;

   logic [2:0] 	       pmodb_buf; // buffer, to make sure values only update on our clock domain!p
   logic [7:0] 	       pmoda_buf;
   always_ff @(posedge clk_camera) begin
      pmoda_buf <= pmoda;
      pmodb_buf <= pmodb;
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
      .valid_out(valid_pixel)
      );
   assign hsync = sw[0] ^ hsync_raw; // if sw[0], invert hsync
   assign vsync = sw[1] ^ vsync_raw; // if sw[1], invert vsync

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

   assign fb_addr = vcount_cc*120 + hcount_cc;
   assign fb_we = valid_cc && vcount_cc < 128 && hcount_cc < 100;
   assign fb_din = pixel_cc;
   
   // assign led[1] = hcount_cc > 120;
   
   logic [31:0] vs_lo_count;
   logic 	vs_lo_long;
   assign vs_lo_long = vs_lo_count > 10;
   // assign led[0] = vs_lo_long;
   logic [31:0] frame_cycle_length;
   logic [31:0] row_count;
   logic 	hsync_prev;
   logic 	vsync_prev;

   always_ff @(posedge clk_camera) begin
      if (sys_rst) begin
	 ssc_display <= 0;
	 vs_lo_count <= 0;
	 frame_cycle_length <= 0;
	 row_count <= 0;
	 hsync_prev <= 0;
      end else begin
	 hsync_prev <= hsync;
	 vsync_prev <= vsync;
	 vs_lo_count <= (vsync ? 0 : vs_lo_count+1);

	 if ((vsync_prev && ~vsync) || btn[2]) begin
	    ssc_display[31:16] <= vcount_cc;
	 end
	 if (hsync_prev && ~hsync && (vcount_cc % 34 == 14)) begin
	    ssc_display[15:0] <= hcount_cc;
	 end
	 
	 
	 if (vs_lo_long && row_count != 0) begin
	    // ssc_display[31:16] <= row_count[15:0];
	    row_count <= 0;
	 end
	 
	 // frame_cycle_length <= (vs_lo_long) ? 0 : frame_cycle_length + valid_pixel;
	 // ssc_display <= (vs_lo_long && frame_cycle_length > 0) ? frame_cycle_length : ssc_display;
	 
	 // ssc_display <= (ssc_display > clock_count) ? ssc_display : clock_count;
	 if (~hsync && hsync_prev) begin
	    frame_cycle_length <= 0;
	    row_count <= row_count + 1;
	    if (row_count == 14) begin
	       // ssc_display[15:0] <= frame_cycle_length[15:0];
	    end
	 end else begin
	    frame_cycle_length <= frame_cycle_length + (hsync && valid_pixel);
	 end
      end
   end

   // logic [15:0] count_frames;
   // logic [$clog2(192000000):0] count_cycles;
   // logic [15:0] 	       frame_total;
   
   // always_ff @(posedge clk_camera) begin
   //    if (sys_rst) begin
   // 	 count_cycles <= 0;
   // 	 count_frames <= 0;
   // 	 frame_total <= 0;
   //    end else begin
   // 	 if (count_cycles == 192000000) begin
   // 	    count_cycles <= 0;
   // 	    frame_total <= count_frames;
   // 	    count_frames <= 0;
   // 	 end else begin
   // 	    count_cycles <= count_cycles + 1;
   // 	    count_frames <= count_frames + (newframe ? 1 : 0);
   // 	 end
   //    end // else: !if(sys_rst)
   // end // always_ff @ (posedge clk_camera)
   // assign led = frame_total;

   logic valid_cc_pipe [5:0];
   always_ff @(posedge clk_camera) begin
      if (sys_rst) begin
	 led[0] <= 0;
	 led[1] <= 0;
	 for(int i=1; i<=5; i+=1) begin
	    valid_cc_pipe[i] <= 0;
	 end
      end else begin

	 if( valid_cc_pipe[0] && valid_cc_pipe[1] ) begin
	    led[0] <= 1;
	 end

	 if( valid_cc_pipe[0] + valid_cc_pipe[1] + valid_cc_pipe[2] + valid_cc_pipe[3] + valid_cc_pipe[4] + valid_cc_pipe[5] > 3 ) begin
	    led[1] <= 1;
	 end
	 
	 
	 valid_cc_pipe[0] <= valid_cc;
	 for(int i=1; i<=5; i+=1) begin
	    valid_cc_pipe[i] <= valid_cc_pipe[i-1];
	 end
      end
   end
   
	 
   // logic [7:0] pmodb_buf;
   // logic [7:0] 	       pmoda_buf;
   
   
   // always_ff @(posedge clk_camera) begin
   //    if (sys_rst) begin
   // 	 clock_count <= 0;
   // 	 ssc_display <= 0;
   // 	 count_frames <= 0;
   //    end else if (pmodb[2]) begin
   // 	 clock_count <= 0;
   // 	 if (clock_count > 1) begin
   // 	    count_frames <= count_frames + 1;
   // 	    if (count_frames == 0) begin
   // 	       ssc_display <= clock_count;
   // 	    end
   // 	 end
   //    end else if (pmodb[0]) begin
   // 	 pmoda_buf <= pmoda;
   // 	 pmodb_buf <= pmodb;
   // 	 clock_count <= clock_count + 1;
   //    end
   // end
   
   // assign led[6:0] = count_frames;

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

   manta manta_inst
     (.clk(clk_camera),
      .rx(uart_rxd),
      .tx(uart_txd),
      .data_valid_cb(valid_pixel),
      .data_valid_cc(valid_cc),
      .cam_data_in(pmoda_buf),
      .cam_data_cb(data),
      // .cam_data_cc(pixel_cc),
      .vs_lo_long(vs_lo_long),
      .hsync(hsync),
      .pclk_cam_in(pmodb_buf[0])
      // fb BRAM
      // .frame_buffer_clk(clk_camera),
      // .frame_buffer_addr(fb_addr),
      // .frame_buffer_din(fb_din),
      // .frame_buffer_dout(fb_dout),
      // .frame_buffer_we(fb_we)
      );
   
   
   // logic [7:0]      count_pclk;
   // logic [7:0] 	    data_led;
   
   // camera_bare cbm
   //   (
   //    .clk_pixel_in(clk_100mhz),
   //    .pclk_cam_in(pmodb[0]),
   //    .hs_cam_in(pmodb[2]),
   //    .vs_cam_in(pmodb[1]),
   //    .rst_in(sys_rst),
   //    .data_cam_in(pmoda),
   //    .count_pclk_out(count_pclk),
   //    .data_out(data_led)
   //    );
   // assign led[7:0] = count_pclk;
   // assign led[15:8] = data_led;
   
   
		    
   
   // logic 	     pclk_in;
   // assign pclk_in = pmodb[0];
   
   // logic [15:0]      count_pclk;
   // logic [15:0]      count_cycle;
   
   // always_ff @(posedge clk_100mhz) begin
   //    if (sys_rst || !pmodb[1]) begin
   // 	 count_pclk <= 0;
   // 	 count_cycle <= 0;
   //    end else begin
   // 	 if (pclk_in) begin
   // 	    count_pclk <= count_pclk+1;
   // 	 end
   // 	 count_cycle <= count_cycle+1;
	 
   //    end
   // end
     
   // assign led = count_pclk;
   
   
endmodule // top_level


`default_nettype wire
