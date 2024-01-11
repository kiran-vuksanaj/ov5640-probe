// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.1 (lin64) Build 3865809 Sun May  7 15:04:56 MDT 2023
// Date        : Tue Jan  9 13:51:08 2024
// Host        : beatrice running 64-bit Ubuntu 22.04.3 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/kiranv/Documents/fpga/ov5640-probe/ip/ddr3_mig/ip/ddr3_mig/ddr3_mig_stub.v
// Design      : ddr3_mig
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7s50csga324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module ddr3_mig(ddr3_dq, ddr3_dqs_n, ddr3_dqs_p, ddr3_addr, 
  ddr3_ba, ddr3_ras_n, ddr3_cas_n, ddr3_we_n, ddr3_reset_n, ddr3_ck_p, ddr3_ck_n, ddr3_cke, 
  ddr3_dm, ddr3_odt, sys_clk_i, app_addr, app_cmd, app_en, app_wdf_data, app_wdf_end, app_wdf_mask, 
  app_wdf_wren, app_rd_data, app_rd_data_end, app_rd_data_valid, app_rdy, app_wdf_rdy, 
  app_sr_req, app_ref_req, app_zq_req, app_sr_active, app_ref_ack, app_zq_ack, ui_clk, 
  ui_clk_sync_rst, init_calib_complete, device_temp, sys_rst)
/* synthesis syn_black_box black_box_pad_pin="ddr3_dq[15:0],ddr3_dqs_n[1:0],ddr3_dqs_p[1:0],ddr3_addr[12:0],ddr3_ba[2:0],ddr3_ras_n,ddr3_cas_n,ddr3_we_n,ddr3_reset_n,ddr3_ck_p[0:0],ddr3_ck_n[0:0],ddr3_cke[0:0],ddr3_dm[1:0],ddr3_odt[0:0],app_addr[26:0],app_cmd[2:0],app_en,app_wdf_data[127:0],app_wdf_end,app_wdf_mask[15:0],app_wdf_wren,app_rd_data[127:0],app_rd_data_end,app_rd_data_valid,app_rdy,app_wdf_rdy,app_sr_req,app_ref_req,app_zq_req,app_sr_active,app_ref_ack,app_zq_ack,ui_clk_sync_rst,init_calib_complete,device_temp[11:0],sys_rst" */
/* synthesis syn_force_seq_prim="sys_clk_i" */
/* synthesis syn_force_seq_prim="ui_clk" */;
  inout [15:0]ddr3_dq;
  inout [1:0]ddr3_dqs_n;
  inout [1:0]ddr3_dqs_p;
  output [12:0]ddr3_addr;
  output [2:0]ddr3_ba;
  output ddr3_ras_n;
  output ddr3_cas_n;
  output ddr3_we_n;
  output ddr3_reset_n;
  output [0:0]ddr3_ck_p;
  output [0:0]ddr3_ck_n;
  output [0:0]ddr3_cke;
  output [1:0]ddr3_dm;
  output [0:0]ddr3_odt;
  input sys_clk_i /* synthesis syn_isclock = 1 */;
  input [26:0]app_addr;
  input [2:0]app_cmd;
  input app_en;
  input [127:0]app_wdf_data;
  input app_wdf_end;
  input [15:0]app_wdf_mask;
  input app_wdf_wren;
  output [127:0]app_rd_data;
  output app_rd_data_end;
  output app_rd_data_valid;
  output app_rdy;
  output app_wdf_rdy;
  input app_sr_req;
  input app_ref_req;
  input app_zq_req;
  output app_sr_active;
  output app_ref_ack;
  output app_zq_ack;
  output ui_clk /* synthesis syn_isclock = 1 */;
  output ui_clk_sync_rst;
  output init_calib_complete;
  output [11:0]device_temp;
  input sys_rst;
endmodule
