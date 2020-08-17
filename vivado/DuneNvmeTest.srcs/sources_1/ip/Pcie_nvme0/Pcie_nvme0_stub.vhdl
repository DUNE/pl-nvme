-- Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2019.2 (lin64) Build 2708876 Wed Nov  6 21:39:14 MST 2019
-- Date        : Fri Aug 14 15:58:13 2020
-- Host        : excession.phy.bris.ac.uk running 64-bit Scientific Linux release 7.8 (Nitrogen)
-- Command     : write_vhdl -force -mode synth_stub
--               /usersc/ag17009/NVMe/BlockFormatting/Test/pl-nvme/vivado/DuneNvmeTest.srcs/sources_1/ip/Pcie_nvme0/Pcie_nvme0_stub.vhdl
-- Design      : Pcie_nvme0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xcku115-flva1517-2-e
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Pcie_nvme0 is
  Port ( 
    pci_exp_txn : out STD_LOGIC_VECTOR ( 3 downto 0 );
    pci_exp_txp : out STD_LOGIC_VECTOR ( 3 downto 0 );
    pci_exp_rxn : in STD_LOGIC_VECTOR ( 3 downto 0 );
    pci_exp_rxp : in STD_LOGIC_VECTOR ( 3 downto 0 );
    user_clk : out STD_LOGIC;
    user_reset : out STD_LOGIC;
    user_lnk_up : out STD_LOGIC;
    s_axis_rq_tdata : in STD_LOGIC_VECTOR ( 127 downto 0 );
    s_axis_rq_tkeep : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axis_rq_tlast : in STD_LOGIC;
    s_axis_rq_tready : out STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axis_rq_tuser : in STD_LOGIC_VECTOR ( 59 downto 0 );
    s_axis_rq_tvalid : in STD_LOGIC;
    m_axis_rc_tdata : out STD_LOGIC_VECTOR ( 127 downto 0 );
    m_axis_rc_tkeep : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axis_rc_tlast : out STD_LOGIC;
    m_axis_rc_tready : in STD_LOGIC;
    m_axis_rc_tuser : out STD_LOGIC_VECTOR ( 74 downto 0 );
    m_axis_rc_tvalid : out STD_LOGIC;
    m_axis_cq_tdata : out STD_LOGIC_VECTOR ( 127 downto 0 );
    m_axis_cq_tkeep : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axis_cq_tlast : out STD_LOGIC;
    m_axis_cq_tready : in STD_LOGIC;
    m_axis_cq_tuser : out STD_LOGIC_VECTOR ( 84 downto 0 );
    m_axis_cq_tvalid : out STD_LOGIC;
    s_axis_cc_tdata : in STD_LOGIC_VECTOR ( 127 downto 0 );
    s_axis_cc_tkeep : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axis_cc_tlast : in STD_LOGIC;
    s_axis_cc_tready : out STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axis_cc_tuser : in STD_LOGIC_VECTOR ( 32 downto 0 );
    s_axis_cc_tvalid : in STD_LOGIC;
    cfg_interrupt_int : in STD_LOGIC_VECTOR ( 3 downto 0 );
    cfg_interrupt_pending : in STD_LOGIC_VECTOR ( 3 downto 0 );
    cfg_interrupt_sent : out STD_LOGIC;
    sys_clk : in STD_LOGIC;
    sys_clk_gt : in STD_LOGIC;
    sys_reset : in STD_LOGIC;
    int_qpll1lock_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    int_qpll1outrefclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    int_qpll1outclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    phy_rdy_out : out STD_LOGIC
  );

end Pcie_nvme0;

architecture stub of Pcie_nvme0 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "pci_exp_txn[3:0],pci_exp_txp[3:0],pci_exp_rxn[3:0],pci_exp_rxp[3:0],user_clk,user_reset,user_lnk_up,s_axis_rq_tdata[127:0],s_axis_rq_tkeep[3:0],s_axis_rq_tlast,s_axis_rq_tready[3:0],s_axis_rq_tuser[59:0],s_axis_rq_tvalid,m_axis_rc_tdata[127:0],m_axis_rc_tkeep[3:0],m_axis_rc_tlast,m_axis_rc_tready,m_axis_rc_tuser[74:0],m_axis_rc_tvalid,m_axis_cq_tdata[127:0],m_axis_cq_tkeep[3:0],m_axis_cq_tlast,m_axis_cq_tready,m_axis_cq_tuser[84:0],m_axis_cq_tvalid,s_axis_cc_tdata[127:0],s_axis_cc_tkeep[3:0],s_axis_cc_tlast,s_axis_cc_tready[3:0],s_axis_cc_tuser[32:0],s_axis_cc_tvalid,cfg_interrupt_int[3:0],cfg_interrupt_pending[3:0],cfg_interrupt_sent,sys_clk,sys_clk_gt,sys_reset,int_qpll1lock_out[0:0],int_qpll1outrefclk_out[0:0],int_qpll1outclk_out[0:0],phy_rdy_out";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "Pcie_nvme0_pcie3_uscale_core_top,Vivado 2019.2";
begin
end;
