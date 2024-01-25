`timescale 1ns / 1ps

module registers_tb;

   logic clk;
   logic rst;

   logic init_valid;
   logic init_ready;

   wire scl_pin;
   pullup(scl_pin);
   
   wire sda_pin;
   pullup(sda_pin);

   logic [23:0] bram_dout;
   logic [7:0] 	bram_addr;
   
  xilinx_single_port_ram_read_first
    #(
      .RAM_WIDTH(24),                       // Specify RAM data width
      .RAM_DEPTH(256),                     // Specify RAM depth (number of entries)
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
      .INIT_FILE("/home/kiranv/Documents/fpga/cam/ov5640-probe/rom.mem")          // Specify name/location of RAM initialization file if using one (leave blank if not)
      ) registers
      (
       .addra(bram_addr),     // Address bus, width determined from RAM_DEPTH
       .dina(24'b0),       // RAM input data, width determined from RAM_WIDTH
       .clka(clk),       // Clock
       .wea(1'b0),         // Write enable
       .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
       .rsta(rst),       // Output reset (does not affect memory contents)
       .regcea(1'b1),   // Output register enable
       .douta(bram_dout)      // RAM output data, width determined from RAM_WIDTH
       );

   logic 	con_scl_i,con_scl_o,con_scl_t;
   logic 	con_sda_i,con_sda_o,con_sda_t;
   
   camera_registers tcr
     (.clk_in(clk),
      .rst_in(rst),
      .init_valid(init_valid),
      .init_ready(init_ready),
      .scl_i(con_scl_i),
      .scl_o(con_scl_o),
      .scl_t(con_scl_t),
      .sda_i(con_sda_i),
      .sda_o(con_sda_o),
      .sda_t(con_sda_t),
      .bram_dout(bram_dout),
      .bram_addr(bram_addr));

   logic [7:0] 	rcv_data;
   logic 	rcv_valid;
   logic 	rcv_ready;
   logic 	rcv_last;

   logic 	cam_scl_i, cam_scl_o, cam_scl_t;
   logic 	cam_sda_i, cam_sda_o, cam_sda_t;

   assign cam_scl_i = cam_scl_o & con_scl_o;
   assign con_scl_i = cam_scl_o & con_scl_o;
   // assign scl_pin = (cam_scl_o & con_scl_o) ? 1'bz : 1'b0; // pullup

   assign cam_sda_i = cam_sda_o & con_sda_o;
   assign con_sda_i = cam_sda_o & con_sda_o;
   // assign sda_pin = (cam_sda_o & con_sda_o) ? 1'bz : 1'b0; // pullup (sim)
   
   i2c_slave simcam
     (.clk(clk),
      .rst(rst),
      .s_axis_data_tdata(8'b0),
      .s_axis_data_tvalid(1'b0),
      .s_axis_data_tready(),
      .s_axis_data_tlast(1'b0),
      .m_axis_data_tdata(rcv_data),
      .m_axis_data_tvalid(rcv_valid),
      .m_axis_data_tready(rcv_ready),
      .m_axis_data_tlast(rcv_last),
      .scl_i(cam_scl_i),
      .scl_o(cam_scl_o),
      .scl_t(cam_scl_t),
      .sda_i(cam_sda_i),
      .sda_o(cam_sda_o),
      .sda_t(cam_sda_t),
      .busy(),
      .bus_address(),
      .bus_addressed(),
      .bus_active(),
      .enable(1'b1),
      .device_address(7'h3C),
      .device_address_mask(7'h7F));

   always begin
      #5;
      clk = ~clk;
   end
   initial begin
      clk = 0;
   end

   initial begin
      $dumpfile("simcam.vcd");
      $dumpvars(0,registers_tb);

      $display("starting sim");
      rst = 0;
      init_valid = 0;
      #6;
      rst = 1;
      #10;
      rst = 0;
      #50;
      init_valid = 1;
      #10;
      init_valid = 0;
      #4_000_000;

      $display("finishing sim");
      $finish;
   end // initial begin

   always_ff @(posedge clk) begin
      if(rcv_valid) begin
	 $monitor("At time %t, rcv_valid. rcv_data = %h, rcv_last = %h",$time,rcv_data,rcv_last);
      end
   end

endmodule // registers_tb

