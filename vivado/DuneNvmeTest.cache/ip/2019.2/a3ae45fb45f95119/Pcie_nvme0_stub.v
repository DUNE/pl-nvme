// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (lin64) Build 2708876 Wed Nov  6 21:39:14 MST 2019
// Date        : Fri Aug 14 15:58:09 2020
// Host        : excession.phy.bris.ac.uk running 64-bit Scientific Linux release 7.8 (Nitrogen)
// Command     : write_verilog -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ Pcie_nvme0_stub.v
// Design      : Pcie_nvme0
// Purpose     : Stub declaration of top-level module interface
// Device      : xcku115-flva1517-2-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "Pcie_nvme0_pcie3_uscale_core_top,Vivado 2019.2" *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix(pci_exp_txn, pci_exp_txp, pci_exp_rxn, 
  pci_exp_rxp, user_clk, user_reset, user_lnk_up, s_axis_rq_tdata, s_axis_rq_tkeep, 
  s_axis_rq_tlast, s_axis_rq_tready, s_axis_rq_tuser, s_axis_rq_tvalid, m_axis_rc_tdata, 
  m_axis_rc_tkeep, m_axis_rc_tlast, m_axis_rc_tready, m_axis_rc_tuser, m_axis_rc_tvalid, 
  m_axis_cq_tdata, m_axis_cq_tkeep, m_axis_cq_tlast, m_axis_cq_tready, m_axis_cq_tuser, 
  m_axis_cq_tvalid, s_axis_cc_tdata, s_axis_cc_tkeep, s_axis_cc_tlast, s_axis_cc_tready, 
  s_axis_cc_tuser, s_axis_cc_tvalid, cfg_interrupt_int, cfg_interrupt_pending, 
  cfg_interrupt_sent, sys_clk, sys_clk_gt, sys_reset, int_qpll1lock_out, 
  int_qpll1outrefclk_out, int_qpll1outclk_out, phy_rdy_out)
/* synthesis syn_black_box black_box_pad_pin="pci_exp_txn[3:0],pci_exp_txp[3:0],pci_exp_rxn[3:0],pci_exp_rxp[3:0],user_clk,user_reset,user_lnk_up,s_axis_rq_tdata[127:0],s_axis_rq_tkeep[3:0],s_axis_rq_tlast,s_axis_rq_tready[3:0],s_axis_rq_tuser[59:0],s_axis_rq_tvalid,m_axis_rc_tdata[127:0],m_axis_rc_tkeep[3:0],m_axis_rc_tlast,m_axis_rc_tready,m_axis_rc_tuser[74:0],m_axis_rc_tvalid,m_axis_cq_tdata[127:0],m_axis_cq_tkeep[3:0],m_axis_cq_tlast,m_axis_cq_tready,m_axis_cq_tuser[84:0],m_axis_cq_tvalid,s_axis_cc_tdata[127:0],s_axis_cc_tkeep[3:0],s_axis_cc_tlast,s_axis_cc_tready[3:0],s_axis_cc_tuser[32:0],s_axis_cc_tvalid,cfg_interrupt_int[3:0],cfg_interrupt_pending[3:0],cfg_interrupt_sent,sys_clk,sys_clk_gt,sys_reset,int_qpll1lock_out[0:0],int_qpll1outrefclk_out[0:0],int_qpll1outclk_out[0:0],phy_rdy_out" */;
  output [3:0]pci_exp_txn;
  output [3:0]pci_exp_txp;
  input [3:0]pci_exp_rxn;
  input [3:0]pci_exp_rxp;
  output user_clk;
  output user_reset;
  output user_lnk_up;
  input [127:0]s_axis_rq_tdata;
  input [3:0]s_axis_rq_tkeep;
  input s_axis_rq_tlast;
  output [3:0]s_axis_rq_tready;
  input [59:0]s_axis_rq_tuser;
  input s_axis_rq_tvalid;
  output [127:0]m_axis_rc_tdata;
  output [3:0]m_axis_rc_tkeep;
  output m_axis_rc_tlast;
  input m_axis_rc_tready;
  output [74:0]m_axis_rc_tuser;
  output m_axis_rc_tvalid;
  output [127:0]m_axis_cq_tdata;
  output [3:0]m_axis_cq_tkeep;
  output m_axis_cq_tlast;
  input m_axis_cq_tready;
  output [84:0]m_axis_cq_tuser;
  output m_axis_cq_tvalid;
  input [127:0]s_axis_cc_tdata;
  input [3:0]s_axis_cc_tkeep;
  input s_axis_cc_tlast;
  output [3:0]s_axis_cc_tready;
  input [32:0]s_axis_cc_tuser;
  input s_axis_cc_tvalid;
  input [3:0]cfg_interrupt_int;
  input [3:0]cfg_interrupt_pending;
  output cfg_interrupt_sent;
  input sys_clk;
  input sys_clk_gt;
  input sys_reset;
  output [0:0]int_qpll1lock_out;
  output [0:0]int_qpll1outrefclk_out;
  output [0:0]int_qpll1outclk_out;
  output phy_rdy_out;
endmodule
