// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (lin64) Build 2708876 Wed Nov  6 21:39:14 MST 2019
// Date        : Fri Aug 14 15:57:32 2020
// Host        : excession.phy.bris.ac.uk running 64-bit Scientific Linux release 7.8 (Nitrogen)
// Command     : write_verilog -force -mode synth_stub
//               /usersc/ag17009/NVMe/BlockFormatting/Test/pl-nvme/vivado/DuneNvmeTest.srcs/sources_1/ip/Axis_clock_converter/Axis_clock_converter_stub.v
// Design      : Axis_clock_converter
// Purpose     : Stub declaration of top-level module interface
// Device      : xcku115-flva1517-2-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "axis_clock_converter_v1_1_21_axis_clock_converter,Vivado 2019.2" *)
module Axis_clock_converter(s_axis_aresetn, m_axis_aresetn, s_axis_aclk, 
  s_axis_tvalid, s_axis_tready, s_axis_tdata, s_axis_tkeep, s_axis_tlast, m_axis_aclk, 
  m_axis_tvalid, m_axis_tready, m_axis_tdata, m_axis_tkeep, m_axis_tlast)
/* synthesis syn_black_box black_box_pad_pin="s_axis_aresetn,m_axis_aresetn,s_axis_aclk,s_axis_tvalid,s_axis_tready,s_axis_tdata[127:0],s_axis_tkeep[15:0],s_axis_tlast,m_axis_aclk,m_axis_tvalid,m_axis_tready,m_axis_tdata[127:0],m_axis_tkeep[15:0],m_axis_tlast" */;
  input s_axis_aresetn;
  input m_axis_aresetn;
  input s_axis_aclk;
  input s_axis_tvalid;
  output s_axis_tready;
  input [127:0]s_axis_tdata;
  input [15:0]s_axis_tkeep;
  input s_axis_tlast;
  input m_axis_aclk;
  output m_axis_tvalid;
  input m_axis_tready;
  output [127:0]m_axis_tdata;
  output [15:0]m_axis_tkeep;
  output m_axis_tlast;
endmodule
