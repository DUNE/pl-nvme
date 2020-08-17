// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (lin64) Build 2708876 Wed Nov  6 21:39:14 MST 2019
// Date        : Fri Aug 14 15:57:28 2020
// Host        : excession.phy.bris.ac.uk running 64-bit Scientific Linux release 7.8 (Nitrogen)
// Command     : write_verilog -force -mode synth_stub
//               /usersc/ag17009/NVMe/BlockFormatting/Test/pl-nvme/vivado/DuneNvmeTest.srcs/sources_1/ip/Clk_core/Clk_core_stub.v
// Design      : Clk_core
// Purpose     : Stub declaration of top-level module interface
// Device      : xcku115-flva1517-2-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module Clk_core(clk_out1, locked, clk_in1_p, clk_in1_n)
/* synthesis syn_black_box black_box_pad_pin="clk_out1,locked,clk_in1_p,clk_in1_n" */;
  output clk_out1;
  output locked;
  input clk_in1_p;
  input clk_in1_n;
endmodule
