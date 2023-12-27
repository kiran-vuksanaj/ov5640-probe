// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.1 (lin64) Build 3865809 Sun May  7 15:04:56 MDT 2023
// Date        : Tue Dec 26 21:22:27 2023
// Host        : beatrice running 64-bit Ubuntu 22.04.3 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/kiranv/Documents/fpga/ov5640_probe/ip/ddr_fifo/ip/ddr_fifo/ddr_fifo_stub.v
// Design      : ddr_fifo
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7s50csga324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "axis_data_fifo_v2_0_10_top,Vivado 2023.1" *)
module ddr_fifo(s_axis_aresetn, s_axis_aclk, s_axis_tvalid, 
  s_axis_tready, s_axis_tdata, m_axis_aclk, m_axis_tvalid, m_axis_tready, m_axis_tdata, 
  prog_empty, prog_full)
/* synthesis syn_black_box black_box_pad_pin="s_axis_aresetn,s_axis_tvalid,s_axis_tready,s_axis_tdata[127:0],m_axis_tvalid,m_axis_tready,m_axis_tdata[127:0],prog_empty,prog_full" */
/* synthesis syn_force_seq_prim="s_axis_aclk" */
/* synthesis syn_force_seq_prim="m_axis_aclk" */;
  input s_axis_aresetn;
  input s_axis_aclk /* synthesis syn_isclock = 1 */;
  input s_axis_tvalid;
  output s_axis_tready;
  input [127:0]s_axis_tdata;
  input m_axis_aclk /* synthesis syn_isclock = 1 */;
  output m_axis_tvalid;
  input m_axis_tready;
  output [127:0]m_axis_tdata;
  output prog_empty;
  output prog_full;
endmodule
