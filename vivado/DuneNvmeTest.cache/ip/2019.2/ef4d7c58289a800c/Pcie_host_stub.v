// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (lin64) Build 2708876 Wed Nov  6 21:39:14 MST 2019
// Date        : Fri Aug 14 16:03:49 2020
// Host        : excession.phy.bris.ac.uk running 64-bit Scientific Linux release 7.8 (Nitrogen)
// Command     : write_verilog -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ Pcie_host_stub.v
// Design      : Pcie_host
// Purpose     : Stub declaration of top-level module interface
// Device      : xcku115-flva1517-2-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "Pcie_host_core_top,Vivado 2019.2" *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix(sys_clk, sys_clk_gt, sys_rst_n, user_lnk_up, 
  pci_exp_txp, pci_exp_txn, pci_exp_rxp, pci_exp_rxn, axi_aclk, axi_aresetn, usr_irq_req, 
  usr_irq_ack, msi_enable, msi_vector_width, m_axil_awaddr, m_axil_awprot, m_axil_awvalid, 
  m_axil_awready, m_axil_wdata, m_axil_wstrb, m_axil_wvalid, m_axil_wready, m_axil_bvalid, 
  m_axil_bresp, m_axil_bready, m_axil_araddr, m_axil_arprot, m_axil_arvalid, m_axil_arready, 
  m_axil_rdata, m_axil_rresp, m_axil_rvalid, m_axil_rready, cfg_mgmt_addr, cfg_mgmt_write, 
  cfg_mgmt_write_data, cfg_mgmt_byte_enable, cfg_mgmt_read, cfg_mgmt_read_data, 
  cfg_mgmt_read_write_done, cfg_mgmt_type1_cfg_reg_access, s_axis_c2h_tdata_0, 
  s_axis_c2h_tlast_0, s_axis_c2h_tvalid_0, s_axis_c2h_tready_0, s_axis_c2h_tkeep_0, 
  m_axis_h2c_tdata_0, m_axis_h2c_tlast_0, m_axis_h2c_tvalid_0, m_axis_h2c_tready_0, 
  m_axis_h2c_tkeep_0, int_qpll1lock_out, int_qpll1outrefclk_out, int_qpll1outclk_out)
/* synthesis syn_black_box black_box_pad_pin="sys_clk,sys_clk_gt,sys_rst_n,user_lnk_up,pci_exp_txp[3:0],pci_exp_txn[3:0],pci_exp_rxp[3:0],pci_exp_rxn[3:0],axi_aclk,axi_aresetn,usr_irq_req[0:0],usr_irq_ack[0:0],msi_enable,msi_vector_width[2:0],m_axil_awaddr[31:0],m_axil_awprot[2:0],m_axil_awvalid,m_axil_awready,m_axil_wdata[31:0],m_axil_wstrb[3:0],m_axil_wvalid,m_axil_wready,m_axil_bvalid,m_axil_bresp[1:0],m_axil_bready,m_axil_araddr[31:0],m_axil_arprot[2:0],m_axil_arvalid,m_axil_arready,m_axil_rdata[31:0],m_axil_rresp[1:0],m_axil_rvalid,m_axil_rready,cfg_mgmt_addr[18:0],cfg_mgmt_write,cfg_mgmt_write_data[31:0],cfg_mgmt_byte_enable[3:0],cfg_mgmt_read,cfg_mgmt_read_data[31:0],cfg_mgmt_read_write_done,cfg_mgmt_type1_cfg_reg_access,s_axis_c2h_tdata_0[127:0],s_axis_c2h_tlast_0,s_axis_c2h_tvalid_0,s_axis_c2h_tready_0,s_axis_c2h_tkeep_0[15:0],m_axis_h2c_tdata_0[127:0],m_axis_h2c_tlast_0,m_axis_h2c_tvalid_0,m_axis_h2c_tready_0,m_axis_h2c_tkeep_0[15:0],int_qpll1lock_out[0:0],int_qpll1outrefclk_out[0:0],int_qpll1outclk_out[0:0]" */;
  input sys_clk;
  input sys_clk_gt;
  input sys_rst_n;
  output user_lnk_up;
  output [3:0]pci_exp_txp;
  output [3:0]pci_exp_txn;
  input [3:0]pci_exp_rxp;
  input [3:0]pci_exp_rxn;
  output axi_aclk;
  output axi_aresetn;
  input [0:0]usr_irq_req;
  output [0:0]usr_irq_ack;
  output msi_enable;
  output [2:0]msi_vector_width;
  output [31:0]m_axil_awaddr;
  output [2:0]m_axil_awprot;
  output m_axil_awvalid;
  input m_axil_awready;
  output [31:0]m_axil_wdata;
  output [3:0]m_axil_wstrb;
  output m_axil_wvalid;
  input m_axil_wready;
  input m_axil_bvalid;
  input [1:0]m_axil_bresp;
  output m_axil_bready;
  output [31:0]m_axil_araddr;
  output [2:0]m_axil_arprot;
  output m_axil_arvalid;
  input m_axil_arready;
  input [31:0]m_axil_rdata;
  input [1:0]m_axil_rresp;
  input m_axil_rvalid;
  output m_axil_rready;
  input [18:0]cfg_mgmt_addr;
  input cfg_mgmt_write;
  input [31:0]cfg_mgmt_write_data;
  input [3:0]cfg_mgmt_byte_enable;
  input cfg_mgmt_read;
  output [31:0]cfg_mgmt_read_data;
  output cfg_mgmt_read_write_done;
  input cfg_mgmt_type1_cfg_reg_access;
  input [127:0]s_axis_c2h_tdata_0;
  input s_axis_c2h_tlast_0;
  input s_axis_c2h_tvalid_0;
  output s_axis_c2h_tready_0;
  input [15:0]s_axis_c2h_tkeep_0;
  output [127:0]m_axis_h2c_tdata_0;
  output m_axis_h2c_tlast_0;
  output m_axis_h2c_tvalid_0;
  input m_axis_h2c_tready_0;
  output [15:0]m_axis_h2c_tkeep_0;
  output [0:0]int_qpll1lock_out;
  output [0:0]int_qpll1outrefclk_out;
  output [0:0]int_qpll1outclk_out;
endmodule
