-- (c) Copyright 1995-2020 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.

-- IP VLNV: xilinx.com:ip:pcie3_ultrascale:4.4
-- IP Revision: 6

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY Pcie_nvme0 IS
  PORT (
    pci_exp_txn : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    pci_exp_txp : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    pci_exp_rxn : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    pci_exp_rxp : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    user_clk : OUT STD_LOGIC;
    user_reset : OUT STD_LOGIC;
    user_lnk_up : OUT STD_LOGIC;
    s_axis_rq_tdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    s_axis_rq_tkeep : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axis_rq_tlast : IN STD_LOGIC;
    s_axis_rq_tready : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axis_rq_tuser : IN STD_LOGIC_VECTOR(59 DOWNTO 0);
    s_axis_rq_tvalid : IN STD_LOGIC;
    m_axis_rc_tdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    m_axis_rc_tkeep : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axis_rc_tlast : OUT STD_LOGIC;
    m_axis_rc_tready : IN STD_LOGIC;
    m_axis_rc_tuser : OUT STD_LOGIC_VECTOR(74 DOWNTO 0);
    m_axis_rc_tvalid : OUT STD_LOGIC;
    m_axis_cq_tdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    m_axis_cq_tkeep : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axis_cq_tlast : OUT STD_LOGIC;
    m_axis_cq_tready : IN STD_LOGIC;
    m_axis_cq_tuser : OUT STD_LOGIC_VECTOR(84 DOWNTO 0);
    m_axis_cq_tvalid : OUT STD_LOGIC;
    s_axis_cc_tdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    s_axis_cc_tkeep : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axis_cc_tlast : IN STD_LOGIC;
    s_axis_cc_tready : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axis_cc_tuser : IN STD_LOGIC_VECTOR(32 DOWNTO 0);
    s_axis_cc_tvalid : IN STD_LOGIC;
    cfg_interrupt_int : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    cfg_interrupt_pending : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    cfg_interrupt_sent : OUT STD_LOGIC;
    sys_clk : IN STD_LOGIC;
    sys_clk_gt : IN STD_LOGIC;
    sys_reset : IN STD_LOGIC;
    int_qpll1lock_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    int_qpll1outrefclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    int_qpll1outclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    phy_rdy_out : OUT STD_LOGIC
  );
END Pcie_nvme0;

ARCHITECTURE Pcie_nvme0_arch OF Pcie_nvme0 IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF Pcie_nvme0_arch: ARCHITECTURE IS "yes";
  COMPONENT Pcie_nvme0_pcie3_uscale_core_top IS
    GENERIC (
      PL_LINK_CAP_MAX_LINK_SPEED : INTEGER;
      PL_LINK_CAP_MAX_LINK_WIDTH : INTEGER;
      USER_CLK_FREQ : INTEGER;
      CORE_CLK_FREQ : INTEGER;
      PLL_TYPE : INTEGER;
      PF0_LINK_CAP_ASPM_SUPPORT : INTEGER;
      C_DATA_WIDTH : INTEGER;
      REF_CLK_FREQ : INTEGER;
      PCIE_LINK_SPEED : INTEGER;
      KEEP_WIDTH : INTEGER;
      ARI_CAP_ENABLE : STRING;
      PF0_ARI_CAP_NEXT_FUNC : STD_LOGIC_VECTOR;
      AXISTEN_IF_CC_ALIGNMENT_MODE : STRING;
      AXISTEN_IF_CQ_ALIGNMENT_MODE : STRING;
      AXISTEN_IF_RC_ALIGNMENT_MODE : STRING;
      AXISTEN_IF_RC_STRADDLE : STRING;
      AXISTEN_IF_RQ_ALIGNMENT_MODE : STRING;
      AXISTEN_IF_ENABLE_MSG_ROUTE : STD_LOGIC_VECTOR;
      AXISTEN_IF_ENABLE_RX_MSG_INTFC : STRING;
      PF0_AER_CAP_ECRC_CHECK_CAPABLE : STRING;
      PF0_AER_CAP_ECRC_GEN_CAPABLE : STRING;
      PF0_AER_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_ARI_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF0_ARI_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF1_ARI_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF2_ARI_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF3_ARI_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF4_ARI_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF5_ARI_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_BAR0_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_BAR0_CONTROL : STD_LOGIC_VECTOR;
      PF0_BAR1_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_BAR1_CONTROL : STD_LOGIC_VECTOR;
      PF0_BAR2_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_BAR2_CONTROL : STD_LOGIC_VECTOR;
      PF0_BAR3_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_BAR3_CONTROL : STD_LOGIC_VECTOR;
      PF0_BAR4_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_BAR4_CONTROL : STD_LOGIC_VECTOR;
      PF0_BAR5_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_BAR5_CONTROL : STD_LOGIC_VECTOR;
      PF0_CAPABILITY_POINTER : STD_LOGIC_VECTOR;
      PF0_CLASS_CODE : STD_LOGIC_VECTOR;
      PF0_VENDOR_ID : STD_LOGIC_VECTOR;
      PF0_DEVICE_ID : STD_LOGIC_VECTOR;
      PF0_DEV_CAP2_128B_CAS_ATOMIC_COMPLETER_SUPPORT : STRING;
      PF0_DEV_CAP2_32B_ATOMIC_COMPLETER_SUPPORT : STRING;
      PF0_DEV_CAP2_64B_ATOMIC_COMPLETER_SUPPORT : STRING;
      PF0_DEV_CAP2_LTR_SUPPORT : STRING;
      PF0_DEV_CAP2_OBFF_SUPPORT : STD_LOGIC_VECTOR;
      PF0_DEV_CAP2_TPH_COMPLETER_SUPPORT : STRING;
      PF0_DEV_CAP_EXT_TAG_SUPPORTED : STRING;
      PF0_DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE : STRING;
      PF0_DEV_CAP_MAX_PAYLOAD_SIZE : STD_LOGIC_VECTOR;
      PF0_DPA_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION0 : STD_LOGIC_VECTOR;
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION1 : STD_LOGIC_VECTOR;
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION2 : STD_LOGIC_VECTOR;
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION3 : STD_LOGIC_VECTOR;
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION4 : STD_LOGIC_VECTOR;
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION5 : STD_LOGIC_VECTOR;
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION6 : STD_LOGIC_VECTOR;
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION7 : STD_LOGIC_VECTOR;
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION0 : STD_LOGIC_VECTOR;
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION1 : STD_LOGIC_VECTOR;
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION2 : STD_LOGIC_VECTOR;
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION3 : STD_LOGIC_VECTOR;
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION4 : STD_LOGIC_VECTOR;
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION5 : STD_LOGIC_VECTOR;
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION6 : STD_LOGIC_VECTOR;
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION7 : STD_LOGIC_VECTOR;
      PF0_DSN_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_EXPANSION_ROM_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_EXPANSION_ROM_ENABLE : STRING;
      PF0_INTERRUPT_PIN : STD_LOGIC_VECTOR;
      PF0_LINK_STATUS_SLOT_CLOCK_CONFIG : STRING;
      PF0_LTR_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_MSIX_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_MSIX_CAP_PBA_BIR : INTEGER;
      PF0_MSIX_CAP_PBA_OFFSET : STD_LOGIC_VECTOR;
      PF0_MSIX_CAP_TABLE_BIR : INTEGER;
      PF0_MSIX_CAP_TABLE_OFFSET : STD_LOGIC_VECTOR;
      PF0_MSIX_CAP_TABLE_SIZE : STD_LOGIC_VECTOR;
      PF0_MSI_CAP_MULTIMSGCAP : INTEGER;
      PF0_MSI_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_PB_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_PM_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_PM_CAP_PMESUPPORT_D0 : STRING;
      PF0_PM_CAP_PMESUPPORT_D1 : STRING;
      PF0_PM_CAP_PMESUPPORT_D3HOT : STRING;
      PF0_PM_CAP_SUPP_D1_STATE : STRING;
      PF0_RBAR_CAP_ENABLE : STRING;
      PF0_RBAR_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_RBAR_CAP_SIZE0 : STD_LOGIC_VECTOR;
      PF0_RBAR_CAP_SIZE1 : STD_LOGIC_VECTOR;
      PF0_RBAR_CAP_SIZE2 : STD_LOGIC_VECTOR;
      PF1_RBAR_CAP_SIZE0 : STD_LOGIC_VECTOR;
      PF1_RBAR_CAP_SIZE1 : STD_LOGIC_VECTOR;
      PF1_RBAR_CAP_SIZE2 : STD_LOGIC_VECTOR;
      PF0_REVISION_ID : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR0_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR0_CONTROL : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR1_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR1_CONTROL : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR2_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR2_CONTROL : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR3_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR3_CONTROL : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR4_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR4_CONTROL : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR5_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF0_SRIOV_BAR5_CONTROL : STD_LOGIC_VECTOR;
      PF0_SRIOV_CAP_INITIAL_VF : STD_LOGIC_VECTOR;
      PF0_SRIOV_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_SRIOV_CAP_TOTAL_VF : STD_LOGIC_VECTOR;
      PF0_SRIOV_CAP_VER : STD_LOGIC_VECTOR;
      PF0_SRIOV_FIRST_VF_OFFSET : STD_LOGIC_VECTOR;
      PF0_SRIOV_FUNC_DEP_LINK : STD_LOGIC_VECTOR;
      PF0_SRIOV_SUPPORTED_PAGE_SIZE : STD_LOGIC_VECTOR;
      PF0_SRIOV_VF_DEVICE_ID : STD_LOGIC_VECTOR;
      PF0_SUBSYSTEM_VENDOR_ID : STD_LOGIC_VECTOR;
      PF0_SUBSYSTEM_ID : STD_LOGIC_VECTOR;
      PF0_TPHR_CAP_ENABLE : STRING;
      PF0_TPHR_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF0_TPHR_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF1_TPHR_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF2_TPHR_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF3_TPHR_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF4_TPHR_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF5_TPHR_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_TPHR_CAP_ST_MODE_SEL : STD_LOGIC_VECTOR;
      PF0_TPHR_CAP_ST_TABLE_LOC : STD_LOGIC_VECTOR;
      PF0_TPHR_CAP_ST_TABLE_SIZE : STD_LOGIC_VECTOR;
      PF0_TPHR_CAP_VER : STD_LOGIC_VECTOR;
      PF1_TPHR_CAP_ST_MODE_SEL : STD_LOGIC_VECTOR;
      PF1_TPHR_CAP_ST_TABLE_LOC : STD_LOGIC_VECTOR;
      PF1_TPHR_CAP_ST_TABLE_SIZE : STD_LOGIC_VECTOR;
      PF1_TPHR_CAP_VER : STD_LOGIC_VECTOR;
      VF0_TPHR_CAP_ST_MODE_SEL : STD_LOGIC_VECTOR;
      VF0_TPHR_CAP_ST_TABLE_LOC : STD_LOGIC_VECTOR;
      VF0_TPHR_CAP_ST_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF0_TPHR_CAP_VER : STD_LOGIC_VECTOR;
      VF1_TPHR_CAP_ST_MODE_SEL : STD_LOGIC_VECTOR;
      VF1_TPHR_CAP_ST_TABLE_LOC : STD_LOGIC_VECTOR;
      VF1_TPHR_CAP_ST_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF1_TPHR_CAP_VER : STD_LOGIC_VECTOR;
      VF2_TPHR_CAP_ST_MODE_SEL : STD_LOGIC_VECTOR;
      VF2_TPHR_CAP_ST_TABLE_LOC : STD_LOGIC_VECTOR;
      VF2_TPHR_CAP_ST_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF2_TPHR_CAP_VER : STD_LOGIC_VECTOR;
      VF3_TPHR_CAP_ST_MODE_SEL : STD_LOGIC_VECTOR;
      VF3_TPHR_CAP_ST_TABLE_LOC : STD_LOGIC_VECTOR;
      VF3_TPHR_CAP_ST_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF3_TPHR_CAP_VER : STD_LOGIC_VECTOR;
      VF4_TPHR_CAP_ST_MODE_SEL : STD_LOGIC_VECTOR;
      VF4_TPHR_CAP_ST_TABLE_LOC : STD_LOGIC_VECTOR;
      VF4_TPHR_CAP_ST_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF4_TPHR_CAP_VER : STD_LOGIC_VECTOR;
      VF5_TPHR_CAP_ST_MODE_SEL : STD_LOGIC_VECTOR;
      VF5_TPHR_CAP_ST_TABLE_LOC : STD_LOGIC_VECTOR;
      VF5_TPHR_CAP_ST_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF5_TPHR_CAP_VER : STD_LOGIC_VECTOR;
      PF0_TPHR_CAP_DEV_SPECIFIC_MODE : STRING;
      PF0_TPHR_CAP_INT_VEC_MODE : STRING;
      PF1_TPHR_CAP_DEV_SPECIFIC_MODE : STRING;
      PF1_TPHR_CAP_INT_VEC_MODE : STRING;
      VF0_TPHR_CAP_DEV_SPECIFIC_MODE : STRING;
      VF0_TPHR_CAP_INT_VEC_MODE : STRING;
      VF1_TPHR_CAP_DEV_SPECIFIC_MODE : STRING;
      VF1_TPHR_CAP_INT_VEC_MODE : STRING;
      VF2_TPHR_CAP_DEV_SPECIFIC_MODE : STRING;
      VF2_TPHR_CAP_INT_VEC_MODE : STRING;
      VF3_TPHR_CAP_DEV_SPECIFIC_MODE : STRING;
      VF3_TPHR_CAP_INT_VEC_MODE : STRING;
      VF4_TPHR_CAP_DEV_SPECIFIC_MODE : STRING;
      VF4_TPHR_CAP_INT_VEC_MODE : STRING;
      VF5_TPHR_CAP_DEV_SPECIFIC_MODE : STRING;
      VF5_TPHR_CAP_INT_VEC_MODE : STRING;
      PF0_SECONDARY_PCIE_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      MCAP_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF0_VC_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      SPARE_WORD1 : STD_LOGIC_VECTOR;
      PF1_AER_CAP_ECRC_CHECK_CAPABLE : STRING;
      PF1_AER_CAP_ECRC_GEN_CAPABLE : STRING;
      PF1_AER_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF1_ARI_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF1_BAR0_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_BAR0_CONTROL : STD_LOGIC_VECTOR;
      PF1_BAR1_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_BAR1_CONTROL : STD_LOGIC_VECTOR;
      PF1_BAR2_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_BAR2_CONTROL : STD_LOGIC_VECTOR;
      PF1_BAR3_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_BAR3_CONTROL : STD_LOGIC_VECTOR;
      PF1_BAR4_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_BAR4_CONTROL : STD_LOGIC_VECTOR;
      PF1_BAR5_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_BAR5_CONTROL : STD_LOGIC_VECTOR;
      PF1_CAPABILITY_POINTER : STD_LOGIC_VECTOR;
      PF1_CLASS_CODE : STD_LOGIC_VECTOR;
      PF1_DEVICE_ID : STD_LOGIC_VECTOR;
      PF1_DEV_CAP_MAX_PAYLOAD_SIZE : STD_LOGIC_VECTOR;
      PF1_DPA_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF1_DSN_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF1_EXPANSION_ROM_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_EXPANSION_ROM_ENABLE : STRING;
      PF1_INTERRUPT_PIN : STD_LOGIC_VECTOR;
      PF1_MSIX_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF1_MSIX_CAP_PBA_BIR : INTEGER;
      PF1_MSIX_CAP_PBA_OFFSET : STD_LOGIC_VECTOR;
      PF1_MSIX_CAP_TABLE_BIR : INTEGER;
      PF1_MSIX_CAP_TABLE_OFFSET : STD_LOGIC_VECTOR;
      PF1_MSIX_CAP_TABLE_SIZE : STD_LOGIC_VECTOR;
      PF1_MSI_CAP_MULTIMSGCAP : INTEGER;
      PF1_MSI_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF1_PB_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF1_PM_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF1_RBAR_CAP_ENABLE : STRING;
      PF1_RBAR_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF1_REVISION_ID : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR0_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR0_CONTROL : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR1_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR1_CONTROL : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR2_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR2_CONTROL : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR3_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR3_CONTROL : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR4_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR4_CONTROL : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR5_APERTURE_SIZE : STD_LOGIC_VECTOR;
      PF1_SRIOV_BAR5_CONTROL : STD_LOGIC_VECTOR;
      PF1_SRIOV_CAP_INITIAL_VF : STD_LOGIC_VECTOR;
      PF1_SRIOV_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PF1_SRIOV_CAP_TOTAL_VF : STD_LOGIC_VECTOR;
      PF1_SRIOV_CAP_VER : STD_LOGIC_VECTOR;
      PF1_SRIOV_FIRST_VF_OFFSET : STD_LOGIC_VECTOR;
      PF1_SRIOV_FUNC_DEP_LINK : STD_LOGIC_VECTOR;
      PF1_SRIOV_SUPPORTED_PAGE_SIZE : STD_LOGIC_VECTOR;
      PF1_SRIOV_VF_DEVICE_ID : STD_LOGIC_VECTOR;
      PF1_SUBSYSTEM_ID : STD_LOGIC_VECTOR;
      PF1_TPHR_CAP_ENABLE : STRING;
      PF1_TPHR_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      PL_UPSTREAM_FACING : STRING;
      en_msi_per_vec_masking : STRING;
      SRIOV_CAP_ENABLE : STRING;
      TL_CREDITS_CD : STD_LOGIC_VECTOR;
      TL_CREDITS_CH : STD_LOGIC_VECTOR;
      TL_CREDITS_NPD : STD_LOGIC_VECTOR;
      TL_CREDITS_NPH : STD_LOGIC_VECTOR;
      TL_CREDITS_PD : STD_LOGIC_VECTOR;
      TL_CREDITS_PH : STD_LOGIC_VECTOR;
      TL_EXTENDED_CFG_EXTEND_INTERFACE_ENABLE : STRING;
      ACS_EXT_CAP_ENABLE : STRING;
      ACS_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      TL_LEGACY_MODE_ENABLE : STRING;
      TL_PF_ENABLE_REG : STD_LOGIC_VECTOR;
      VF0_CAPABILITY_POINTER : STD_LOGIC_VECTOR;
      VF0_MSIX_CAP_PBA_BIR : INTEGER;
      VF0_MSIX_CAP_PBA_OFFSET : STD_LOGIC_VECTOR;
      VF0_MSIX_CAP_TABLE_BIR : INTEGER;
      VF0_MSIX_CAP_TABLE_OFFSET : STD_LOGIC_VECTOR;
      VF0_MSIX_CAP_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF0_MSI_CAP_MULTIMSGCAP : INTEGER;
      VF0_PM_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF1_MSIX_CAP_PBA_BIR : INTEGER;
      VF1_MSIX_CAP_PBA_OFFSET : STD_LOGIC_VECTOR;
      VF1_MSIX_CAP_TABLE_BIR : INTEGER;
      VF1_MSIX_CAP_TABLE_OFFSET : STD_LOGIC_VECTOR;
      VF1_MSIX_CAP_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF1_MSI_CAP_MULTIMSGCAP : INTEGER;
      VF1_PM_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF2_MSIX_CAP_PBA_BIR : INTEGER;
      VF2_MSIX_CAP_PBA_OFFSET : STD_LOGIC_VECTOR;
      VF2_MSIX_CAP_TABLE_BIR : INTEGER;
      VF2_MSIX_CAP_TABLE_OFFSET : STD_LOGIC_VECTOR;
      VF2_MSIX_CAP_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF2_MSI_CAP_MULTIMSGCAP : INTEGER;
      VF2_PM_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF3_MSIX_CAP_PBA_BIR : INTEGER;
      VF3_MSIX_CAP_PBA_OFFSET : STD_LOGIC_VECTOR;
      VF3_MSIX_CAP_TABLE_BIR : INTEGER;
      VF3_MSIX_CAP_TABLE_OFFSET : STD_LOGIC_VECTOR;
      VF3_MSIX_CAP_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF3_MSI_CAP_MULTIMSGCAP : INTEGER;
      VF3_PM_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF4_MSIX_CAP_PBA_BIR : INTEGER;
      VF4_MSIX_CAP_PBA_OFFSET : STD_LOGIC_VECTOR;
      VF4_MSIX_CAP_TABLE_BIR : INTEGER;
      VF4_MSIX_CAP_TABLE_OFFSET : STD_LOGIC_VECTOR;
      VF4_MSIX_CAP_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF4_MSI_CAP_MULTIMSGCAP : INTEGER;
      VF4_PM_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      VF5_MSIX_CAP_PBA_BIR : INTEGER;
      VF5_MSIX_CAP_PBA_OFFSET : STD_LOGIC_VECTOR;
      VF5_MSIX_CAP_TABLE_BIR : INTEGER;
      VF5_MSIX_CAP_TABLE_OFFSET : STD_LOGIC_VECTOR;
      VF5_MSIX_CAP_TABLE_SIZE : STD_LOGIC_VECTOR;
      VF5_MSI_CAP_MULTIMSGCAP : INTEGER;
      VF5_PM_CAP_NEXTPTR : STD_LOGIC_VECTOR;
      COMPLETION_SPACE : STRING;
      gen_x0y0_xdc : INTEGER;
      gen_x0y1_xdc : INTEGER;
      gen_x0y2_xdc : INTEGER;
      gen_x0y3_xdc : INTEGER;
      gen_x0y4_xdc : INTEGER;
      gen_x0y5_xdc : INTEGER;
      xlnx_ref_board : INTEGER;
      pcie_blk_locn : INTEGER;
      PIPE_SIM : STRING;
      AXISTEN_IF_ENABLE_CLIENT_TAG : STRING;
      PCIE_USE_MODE : STRING;
      PCIE_FAST_CONFIG : STRING;
      EXT_STARTUP_PRIMITIVE : STRING;
      PL_INTERFACE : STRING;
      PCIE_CONFIGURATION : STRING;
      CFG_STATUS_IF : STRING;
      GT_TX_PD : STRING;
      TX_FC_IF : STRING;
      CFG_EXT_IF : STRING;
      CFG_FC_IF : STRING;
      PER_FUNC_STATUS_IF : STRING;
      CFG_MGMT_IF : STRING;
      RCV_MSG_IF : STRING;
      CFG_TX_MSG_IF : STRING;
      CFG_CTL_IF : STRING;
      MSI_EN : STRING;
      MSIX_EN : STRING;
      PCIE3_DRP : STRING;
      DIS_GT_WIZARD : STRING;
      TRANSCEIVER_CTRL_STATUS_PORTS : STRING;
      SHARED_LOGIC : INTEGER;
      DEDICATE_PERST : STRING;
      SYS_RESET_POLARITY : INTEGER;
      MCAP_ENABLEMENT : STRING;
      MCAP_FPGA_BITSTREAM_VERSION : STD_LOGIC_VECTOR;
      PHY_LP_TXPRESET : INTEGER;
      EXT_CH_GT_DRP : STRING;
      EN_GT_SELECTION : STRING;
      SELECT_QUAD : STRING;
      silicon_revision : STRING;
      DEV_PORT_TYPE : INTEGER;
      RX_DETECT : INTEGER;
      ENABLE_IBERT : STRING;
      DBG_DESCRAMBLE_EN : STRING;
      ENABLE_JTAG_DBG : STRING;
      AXISTEN_IF_CC_PARITY_CHK : STRING;
      AXISTEN_IF_RQ_PARITY_CHK : STRING;
      ENABLE_AUTO_RXEQ : STRING;
      GTWIZ_IN_CORE : INTEGER;
      INS_LOSS_PROFILE : STRING;
      PM_ENABLE_L23_ENTRY : STRING;
      BMD_PIO_MODE : STRING;
      MULT_PF_DES : STRING;
      ENABLE_GT_V1_5 : STRING;
      EXT_XVC_VSEC_ENABLE : STRING;
      GT_DRP_CLK_SRC : INTEGER;
      FREE_RUN_FREQ : INTEGER
    );
    PORT (
      pci_exp_txn : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pci_exp_txp : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pci_exp_rxn : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      pci_exp_rxp : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      user_clk : OUT STD_LOGIC;
      user_reset : OUT STD_LOGIC;
      user_lnk_up : OUT STD_LOGIC;
      gt_tx_powerdown : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      s_axis_rq_tdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      s_axis_rq_tkeep : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axis_rq_tlast : IN STD_LOGIC;
      s_axis_rq_tready : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axis_rq_tuser : IN STD_LOGIC_VECTOR(59 DOWNTO 0);
      s_axis_rq_tvalid : IN STD_LOGIC;
      m_axis_rc_tdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      m_axis_rc_tkeep : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axis_rc_tlast : OUT STD_LOGIC;
      m_axis_rc_tready : IN STD_LOGIC;
      m_axis_rc_tuser : OUT STD_LOGIC_VECTOR(74 DOWNTO 0);
      m_axis_rc_tvalid : OUT STD_LOGIC;
      m_axis_cq_tdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      m_axis_cq_tkeep : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axis_cq_tlast : OUT STD_LOGIC;
      m_axis_cq_tready : IN STD_LOGIC;
      m_axis_cq_tuser : OUT STD_LOGIC_VECTOR(84 DOWNTO 0);
      m_axis_cq_tvalid : OUT STD_LOGIC;
      s_axis_cc_tdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      s_axis_cc_tkeep : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axis_cc_tlast : IN STD_LOGIC;
      s_axis_cc_tready : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axis_cc_tuser : IN STD_LOGIC_VECTOR(32 DOWNTO 0);
      s_axis_cc_tvalid : IN STD_LOGIC;
      pcie_rq_seq_num : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pcie_rq_seq_num_vld : OUT STD_LOGIC;
      pcie_rq_tag : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
      pcie_rq_tag_av : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      pcie_rq_tag_vld : OUT STD_LOGIC;
      pcie_tfc_nph_av : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      pcie_tfc_npd_av : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      pcie_cq_np_req : IN STD_LOGIC;
      pcie_cq_np_req_count : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
      cfg_phy_link_down : OUT STD_LOGIC;
      cfg_phy_link_status : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      cfg_negotiated_width : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_current_speed : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      cfg_max_payload : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      cfg_max_read_req : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      cfg_function_status : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      cfg_function_power_state : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      cfg_vf_status : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      cfg_vf_power_state : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
      cfg_link_power_state : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      cfg_mgmt_addr : IN STD_LOGIC_VECTOR(18 DOWNTO 0);
      cfg_mgmt_write : IN STD_LOGIC;
      cfg_mgmt_write_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      cfg_mgmt_byte_enable : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_mgmt_read : IN STD_LOGIC;
      cfg_mgmt_read_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      cfg_mgmt_read_write_done : OUT STD_LOGIC;
      cfg_mgmt_type1_cfg_reg_access : IN STD_LOGIC;
      cfg_err_cor_out : OUT STD_LOGIC;
      cfg_err_nonfatal_out : OUT STD_LOGIC;
      cfg_err_fatal_out : OUT STD_LOGIC;
      cfg_local_error : OUT STD_LOGIC;
      cfg_ltr_enable : OUT STD_LOGIC;
      cfg_ltssm_state : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
      cfg_rcb_status : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_dpa_substate_change : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_obff_enable : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      cfg_pl_status_change : OUT STD_LOGIC;
      cfg_tph_requester_enable : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_tph_st_mode : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      cfg_vf_tph_requester_enable : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_vf_tph_st_mode : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
      cfg_msg_received : OUT STD_LOGIC;
      cfg_msg_received_data : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_msg_received_type : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
      cfg_msg_transmit : IN STD_LOGIC;
      cfg_msg_transmit_type : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      cfg_msg_transmit_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      cfg_msg_transmit_done : OUT STD_LOGIC;
      cfg_fc_ph : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_fc_pd : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      cfg_fc_nph : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_fc_npd : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      cfg_fc_cplh : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_fc_cpld : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      cfg_fc_sel : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      cfg_per_func_status_control : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      cfg_per_func_status_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      cfg_per_function_number : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_per_function_output_request : IN STD_LOGIC;
      cfg_per_function_update_done : OUT STD_LOGIC;
      cfg_dsn : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      cfg_power_state_change_ack : IN STD_LOGIC;
      cfg_power_state_change_interrupt : OUT STD_LOGIC;
      cfg_err_cor_in : IN STD_LOGIC;
      cfg_err_uncor_in : IN STD_LOGIC;
      cfg_flr_in_process : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_flr_done : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_vf_flr_in_process : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_vf_flr_done : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_link_training_enable : IN STD_LOGIC;
      cfg_ext_read_received : OUT STD_LOGIC;
      cfg_ext_write_received : OUT STD_LOGIC;
      cfg_ext_register_number : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
      cfg_ext_function_number : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_ext_write_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      cfg_ext_write_byte_enable : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_ext_read_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      cfg_ext_read_data_valid : IN STD_LOGIC;
      cfg_interrupt_int : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_interrupt_pending : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_interrupt_sent : OUT STD_LOGIC;
      cfg_interrupt_msi_enable : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_interrupt_msi_vf_enable : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_interrupt_msi_mmenable : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      cfg_interrupt_msi_mask_update : OUT STD_LOGIC;
      cfg_interrupt_msi_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      cfg_interrupt_msi_select : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_interrupt_msi_int : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      cfg_interrupt_msi_pending_status : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      cfg_interrupt_msi_pending_status_data_enable : IN STD_LOGIC;
      cfg_interrupt_msi_pending_status_function_num : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_interrupt_msi_sent : OUT STD_LOGIC;
      cfg_interrupt_msi_fail : OUT STD_LOGIC;
      cfg_interrupt_msi_attr : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      cfg_interrupt_msi_tph_present : IN STD_LOGIC;
      cfg_interrupt_msi_tph_type : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      cfg_interrupt_msi_tph_st_tag : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
      cfg_interrupt_msi_function_number : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_interrupt_msix_enable : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_interrupt_msix_mask : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_interrupt_msix_vf_enable : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_interrupt_msix_vf_mask : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_interrupt_msix_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      cfg_interrupt_msix_address : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      cfg_interrupt_msix_int : IN STD_LOGIC;
      cfg_interrupt_msix_sent : OUT STD_LOGIC;
      cfg_interrupt_msix_fail : OUT STD_LOGIC;
      cfg_hot_reset_out : OUT STD_LOGIC;
      cfg_config_space_enable : IN STD_LOGIC;
      cfg_req_pm_transition_l23_ready : IN STD_LOGIC;
      cfg_hot_reset_in : IN STD_LOGIC;
      cfg_ds_port_number : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_ds_bus_number : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      cfg_ds_device_number : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
      cfg_ds_function_number : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      cfg_subsys_vend_id : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      drp_rdy : OUT STD_LOGIC;
      drp_do : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      drp_clk : IN STD_LOGIC;
      drp_en : IN STD_LOGIC;
      drp_we : IN STD_LOGIC;
      drp_addr : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
      drp_di : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      user_tph_stt_address : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
      user_tph_function_num : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      user_tph_stt_read_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      user_tph_stt_read_data_valid : OUT STD_LOGIC;
      user_tph_stt_read_enable : IN STD_LOGIC;
      sys_clk : IN STD_LOGIC;
      sys_clk_gt : IN STD_LOGIC;
      sys_reset : IN STD_LOGIC;
      conf_req_type : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      conf_req_reg_num : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      conf_req_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      conf_req_valid : IN STD_LOGIC;
      conf_req_ready : OUT STD_LOGIC;
      conf_resp_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      conf_resp_valid : OUT STD_LOGIC;
      mcap_design_switch : OUT STD_LOGIC;
      mcap_eos_in : IN STD_LOGIC;
      startup_cfgclk : OUT STD_LOGIC;
      startup_cfgmclk : OUT STD_LOGIC;
      startup_di : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      startup_eos : OUT STD_LOGIC;
      startup_preq : OUT STD_LOGIC;
      startup_do : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      startup_dts : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      startup_fcsbo : IN STD_LOGIC;
      startup_fcsbts : IN STD_LOGIC;
      startup_gsr : IN STD_LOGIC;
      startup_gts : IN STD_LOGIC;
      startup_keyclearb : IN STD_LOGIC;
      startup_pack : IN STD_LOGIC;
      startup_usrcclko : IN STD_LOGIC;
      startup_usrcclkts : IN STD_LOGIC;
      startup_usrdoneo : IN STD_LOGIC;
      startup_usrdonets : IN STD_LOGIC;
      cap_req : OUT STD_LOGIC;
      cap_gnt : IN STD_LOGIC;
      cap_rel : IN STD_LOGIC;
      pl_eq_reset_eieos_count : IN STD_LOGIC;
      pl_gen2_upstream_prefer_deemph : IN STD_LOGIC;
      pl_eq_in_progress : OUT STD_LOGIC;
      pl_eq_phase : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      pcie_perstn1_in : IN STD_LOGIC;
      pcie_perstn0_out : OUT STD_LOGIC;
      pcie_perstn1_out : OUT STD_LOGIC;
      ext_qpll1refclk : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      ext_qpll1rate : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      ext_qpll1pd : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      ext_qpll1reset : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      ext_qpll1lock_out : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      ext_qpll1outclk_out : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      ext_qpll1outrefclk_out : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      int_qpll1lock_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      int_qpll1outrefclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      int_qpll1outclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      common_commands_in : IN STD_LOGIC_VECTOR(25 DOWNTO 0);
      pipe_rx_0_sigs : IN STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_rx_1_sigs : IN STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_rx_2_sigs : IN STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_rx_3_sigs : IN STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_rx_4_sigs : IN STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_rx_5_sigs : IN STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_rx_6_sigs : IN STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_rx_7_sigs : IN STD_LOGIC_VECTOR(83 DOWNTO 0);
      common_commands_out : OUT STD_LOGIC_VECTOR(25 DOWNTO 0);
      pipe_tx_0_sigs : OUT STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_tx_1_sigs : OUT STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_tx_2_sigs : OUT STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_tx_3_sigs : OUT STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_tx_4_sigs : OUT STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_tx_5_sigs : OUT STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_tx_6_sigs : OUT STD_LOGIC_VECTOR(83 DOWNTO 0);
      pipe_tx_7_sigs : OUT STD_LOGIC_VECTOR(83 DOWNTO 0);
      gt_pcieuserratedone : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_loopback : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      gt_txprbsforceerr : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_txinhibit : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_txprbssel : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      gt_rxprbssel : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      gt_rxprbscntreset : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_txelecidle : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_txresetdone : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_rxresetdone : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_rxpmaresetdone : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_txphaligndone : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_txphinitdone : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_txdlysresetdone : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_rxphaligndone : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_rxdlysresetdone : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_rxsyncdone : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_eyescandataerror : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_rxprbserr : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_dmonfiforeset : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_dmonitorclk : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_dmonitorout : OUT STD_LOGIC_VECTOR(67 DOWNTO 0);
      gt_rxcommadet : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_phystatus : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_rxvalid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_rxcdrlock : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_pcierateidle : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_pcieuserratestart : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_gtpowergood : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_cplllock : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_rxoutclk : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_rxrecclkout : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gt_qpll1lock : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      gt_rxstatus : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      gt_rxbufstatus : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      gt_bufgtdiv : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
      phy_txeq_ctrl : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      phy_txeq_preset : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      phy_rst_fsm : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      phy_txeq_fsm : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      phy_rxeq_fsm : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      phy_rst_idle : OUT STD_LOGIC;
      phy_rrst_n : OUT STD_LOGIC;
      phy_prst_n : OUT STD_LOGIC;
      ext_ch_gt_drpclk : OUT STD_LOGIC;
      ext_ch_gt_drpaddr : IN STD_LOGIC_VECTOR(35 DOWNTO 0);
      ext_ch_gt_drpen : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      ext_ch_gt_drpdi : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      ext_ch_gt_drpwe : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      ext_ch_gt_drpdo : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      ext_ch_gt_drprdy : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdlysresetdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxelecidle_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxoutclk_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxphaligndone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxpmaresetdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxprbserr_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxprbslocked_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxprgdivresetdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxratedone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxresetdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxsyncdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxvalid_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      txdlysresetdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      txoutclk_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      txphaligndone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      txphinitdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      txpmaresetdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      txprgdivresetdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      txresetdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      txsyncout_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      txsyncdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      cplllock_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      eyescandataerror_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      gtpowergood_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      pcierategen3_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      pcierateidle_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      pciesynctxsyncdone_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      pcieusergen3rdy_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      pcieuserphystatusrst_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      pcieuserratestart_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      phystatus_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxbyteisaligned_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxbyterealign_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxcdrlock_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxcommadet_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      gthtxn_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      gthtxp_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      drprdy_out : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      pcierateqpllpd_out : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      pcierateqpllreset_out : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      rxclkcorcnt_out : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      bufgtce_out : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      bufgtcemask_out : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      bufgtreset_out : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      bufgtrstmask_out : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      rxbufstatus_out : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      rxstatus_out : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      rxctrl2_out : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      rxctrl3_out : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      bufgtdiv_out : IN STD_LOGIC_VECTOR(35 DOWNTO 0);
      pcsrsvdout_out : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
      drpdo_out : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      rxctrl0_out : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      rxctrl1_out : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      dmonitorout_out : IN STD_LOGIC_VECTOR(67 DOWNTO 0);
      rxdata_out : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
      gtwiz_reset_rx_done_in : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      gtwiz_reset_tx_done_in : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      gtwiz_userclk_rx_active_in : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      gtwiz_userclk_tx_active_in : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      gtwiz_userclk_tx_reset_in : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      cpllpd_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfeagchold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfecfokhold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfelfhold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfekhhold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap2hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap3hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap4hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap5hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap6hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap7hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap8hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap9hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap10hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap11hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap12hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap13hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap14hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfetap15hold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfeuthold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxdfevphold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxoshold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxlpmgchold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxlpmhfhold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxlpmlfhold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxlpmoshold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      cpllreset_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      dmonfiforeset_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      dmonitorclk_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      drpclk_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      drpen_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      drpwe_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      eyescanreset_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gthrxn_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gthrxp_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gtrefclk0_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gtrxreset_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gttxreset_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pcieeqrxeqadaptdone_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pcierstidle_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pciersttxsyncstart_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pcieuserratedone_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rx8b10ben_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxbufreset_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxcdrhold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxcommadeten_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxlpmen_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxmcommaalignen_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxpcommaalignen_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxpolarity_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxprbscntreset_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxprogdivreset_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxratemode_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxslide_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxuserrdy_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxusrclk2_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxusrclk_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      tx8b10ben_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txdeemph_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txdetectrx_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txdlybypass_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txdlyen_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txdlyhold_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txdlyovrden_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txdlysreset_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txdlyupdown_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txelecidle_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txinhibit_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txphalign_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txphalignen_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txphdlypd_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txphdlyreset_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txphdlytstclk_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txphinit_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txphovrden_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txprbsforceerr_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txprogdivreset_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txswing_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txsyncallin_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txsyncin_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txsyncmode_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txuserrdy_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txusrclk2_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      txusrclk_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      rxpd_in : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      txpd_in : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      loopback_in : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      rxrate_in : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      txrate_in : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      txmargin_in : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      txoutclksel_in : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      rxprbssel_in : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      txdiffctrl_in : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      txprbssel_in : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      txprecursor_in : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      txpostcursor_in : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      txmaincursor_in : OUT STD_LOGIC_VECTOR(27 DOWNTO 0);
      txctrl2_in : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      drpaddr_in : OUT STD_LOGIC_VECTOR(35 DOWNTO 0);
      drpdi_in : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      pcsrsvdin_in : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      txctrl0_in : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      txctrl1_in : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      txdata_in : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
      qpll0clk_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      qpll0refclk_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      qpll1clk_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      qpll1refclk_in : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      gtrefclk01_in : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      qpll1pd_in : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      qpll1reset_in : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      qpll1lock_out : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      qpll1outclk_out : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      qpll1outrefclk_out : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      qpllrsvd2_in : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
      qpllrsvd3_in : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
      free_run_clock : IN STD_LOGIC;
      phy_rdy_out : OUT STD_LOGIC
    );
  END COMPONENT Pcie_nvme0_pcie3_uscale_core_top;
  ATTRIBUTE X_CORE_INFO : STRING;
  ATTRIBUTE X_CORE_INFO OF Pcie_nvme0_arch: ARCHITECTURE IS "Pcie_nvme0_pcie3_uscale_core_top,Vivado 2019.2";
  ATTRIBUTE CHECK_LICENSE_TYPE : STRING;
  ATTRIBUTE CHECK_LICENSE_TYPE OF Pcie_nvme0_arch : ARCHITECTURE IS "Pcie_nvme0,Pcie_nvme0_pcie3_uscale_core_top,{}";
  ATTRIBUTE CORE_GENERATION_INFO : STRING;
  ATTRIBUTE CORE_GENERATION_INFO OF Pcie_nvme0_arch: ARCHITECTURE IS "Pcie_nvme0,Pcie_nvme0_pcie3_uscale_core_top,{x_ipProduct=Vivado 2019.2,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=pcie3_ultrascale,x_ipVersion=4.4,x_ipCoreRevision=6,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,PL_LINK_CAP_MAX_LINK_SPEED=4,PL_LINK_CAP_MAX_LINK_WIDTH=4,USER_CLK_FREQ=3,CORE_CLK_FREQ=1,PLL_TYPE=2,PF0_LINK_CAP_ASPM_SUPPORT=0,C_DATA_WIDTH=128,REF_CLK_FREQ=0,PCIE_LINK_SPEED=3,KEEP_WIDTH=4,ARI_CAP_ENABLE=FALSE,PF0_ARI_CAP_NEXT_FUNC=0x00,AXISTEN_IF_CC_ALIGNMENT_MODE=FALSE,AXISTEN_IF_CQ_AL" & 
"IGNMENT_MODE=FALSE,AXISTEN_IF_RC_ALIGNMENT_MODE=FALSE,AXISTEN_IF_RC_STRADDLE=FALSE,AXISTEN_IF_RQ_ALIGNMENT_MODE=FALSE,AXISTEN_IF_ENABLE_MSG_ROUTE=0x2FFFF,AXISTEN_IF_ENABLE_RX_MSG_INTFC=FALSE,PF0_AER_CAP_ECRC_CHECK_CAPABLE=FALSE,PF0_AER_CAP_ECRC_GEN_CAPABLE=FALSE,PF0_AER_CAP_NEXTPTR=0x300,PF0_ARI_CAP_NEXTPTR=0x000,VF0_ARI_CAP_NEXTPTR=0x000,VF1_ARI_CAP_NEXTPTR=0x000,VF2_ARI_CAP_NEXTPTR=0x000,VF3_ARI_CAP_NEXTPTR=0x000,VF4_ARI_CAP_NEXTPTR=0x000,VF5_ARI_CAP_NEXTPTR=0x000,PF0_BAR0_APERTURE_SIZE=0x09,P" & 
"F0_BAR0_CONTROL=0x4,PF0_BAR1_APERTURE_SIZE=0x00,PF0_BAR1_CONTROL=0x0,PF0_BAR2_APERTURE_SIZE=0x00,PF0_BAR2_CONTROL=0x0,PF0_BAR3_APERTURE_SIZE=0x00,PF0_BAR3_CONTROL=0x0,PF0_BAR4_APERTURE_SIZE=0x00,PF0_BAR4_CONTROL=0x0,PF0_BAR5_APERTURE_SIZE=0x00,PF0_BAR5_CONTROL=0x0,PF0_CAPABILITY_POINTER=0xC0,PF0_CLASS_CODE=0x060A00,PF0_VENDOR_ID=0x10EE,PF0_DEVICE_ID=0x8124,PF0_DEV_CAP2_128B_CAS_ATOMIC_COMPLETER_SUPPORT=FALSE,PF0_DEV_CAP2_32B_ATOMIC_COMPLETER_SUPPORT=FALSE,PF0_DEV_CAP2_64B_ATOMIC_COMPLETER_SUPPOR" & 
"T=FALSE,PF0_DEV_CAP2_LTR_SUPPORT=FALSE,PF0_DEV_CAP2_OBFF_SUPPORT=0x0,PF0_DEV_CAP2_TPH_COMPLETER_SUPPORT=FALSE,PF0_DEV_CAP_EXT_TAG_SUPPORTED=FALSE,PF0_DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE=FALSE,PF0_DEV_CAP_MAX_PAYLOAD_SIZE=0x3,PF0_DPA_CAP_NEXTPTR=0x000,PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION0=0x00,PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION1=0x00,PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION2=0x00,PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION3=0x00,PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION4=0x00,PF0_DPA_CAP_SUB_STATE_P" & 
"OWER_ALLOCATION5=0x00,PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION6=0x00,PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION7=0x00,PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION0=0x00,PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION1=0x00,PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION2=0x00,PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION3=0x00,PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION4=0x00,PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION5=0x00,PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION6=0x00,PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION7=0x00,PF0_DSN_CAP_NEXTPTR=0x300,PF" & 
"0_EXPANSION_ROM_APERTURE_SIZE=0x00,PF0_EXPANSION_ROM_ENABLE=FALSE,PF0_INTERRUPT_PIN=0x0,PF0_LINK_STATUS_SLOT_CLOCK_CONFIG=TRUE,PF0_LTR_CAP_NEXTPTR=0x000,PF0_MSIX_CAP_NEXTPTR=0x00,PF0_MSIX_CAP_PBA_BIR=0,PF0_MSIX_CAP_PBA_OFFSET=0x00000000,PF0_MSIX_CAP_TABLE_BIR=0,PF0_MSIX_CAP_TABLE_OFFSET=0x00000000,PF0_MSIX_CAP_TABLE_SIZE=0x000,PF0_MSI_CAP_MULTIMSGCAP=0,PF0_MSI_CAP_NEXTPTR=0x00,PF0_PB_CAP_NEXTPTR=0x000,PF0_PM_CAP_NEXTPTR=0x00,PF0_PM_CAP_PMESUPPORT_D0=FALSE,PF0_PM_CAP_PMESUPPORT_D1=FALSE,PF0_PM_CA" & 
"P_PMESUPPORT_D3HOT=FALSE,PF0_PM_CAP_SUPP_D1_STATE=FALSE,PF0_RBAR_CAP_ENABLE=FALSE,PF0_RBAR_CAP_NEXTPTR=0x000,PF0_RBAR_CAP_SIZE0=0x00000,PF0_RBAR_CAP_SIZE1=0x00000,PF0_RBAR_CAP_SIZE2=0x00000,PF1_RBAR_CAP_SIZE0=0x00000,PF1_RBAR_CAP_SIZE1=0x00000,PF1_RBAR_CAP_SIZE2=0x00000,PF0_REVISION_ID=0x00,PF0_SRIOV_BAR0_APERTURE_SIZE=0x00,PF0_SRIOV_BAR0_CONTROL=0x0,PF0_SRIOV_BAR1_APERTURE_SIZE=0x00,PF0_SRIOV_BAR1_CONTROL=0x0,PF0_SRIOV_BAR2_APERTURE_SIZE=0x00,PF0_SRIOV_BAR2_CONTROL=0x0,PF0_SRIOV_BAR3_APERTURE_S" & 
"IZE=0x00,PF0_SRIOV_BAR3_CONTROL=0x0,PF0_SRIOV_BAR4_APERTURE_SIZE=0x00,PF0_SRIOV_BAR4_CONTROL=0x0,PF0_SRIOV_BAR5_APERTURE_SIZE=0x00,PF0_SRIOV_BAR5_CONTROL=0x0,PF0_SRIOV_CAP_INITIAL_VF=0x0000,PF0_SRIOV_CAP_NEXTPTR=0x000,PF0_SRIOV_CAP_TOTAL_VF=0x0000,PF0_SRIOV_CAP_VER=0x0,PF0_SRIOV_FIRST_VF_OFFSET=0x0000,PF0_SRIOV_FUNC_DEP_LINK=0x0000,PF0_SRIOV_SUPPORTED_PAGE_SIZE=0x00000553,PF0_SRIOV_VF_DEVICE_ID=0x0000,PF0_SUBSYSTEM_VENDOR_ID=0x10EE,PF0_SUBSYSTEM_ID=0x0007,PF0_TPHR_CAP_ENABLE=FALSE,PF0_TPHR_CAP_N" & 
"EXTPTR=0x300,VF0_TPHR_CAP_NEXTPTR=0x000,VF1_TPHR_CAP_NEXTPTR=0x000,VF2_TPHR_CAP_NEXTPTR=0x000,VF3_TPHR_CAP_NEXTPTR=0x000,VF4_TPHR_CAP_NEXTPTR=0x000,VF5_TPHR_CAP_NEXTPTR=0x000,PF0_TPHR_CAP_ST_MODE_SEL=0x0,PF0_TPHR_CAP_ST_TABLE_LOC=0x0,PF0_TPHR_CAP_ST_TABLE_SIZE=0x000,PF0_TPHR_CAP_VER=0x1,PF1_TPHR_CAP_ST_MODE_SEL=0x0,PF1_TPHR_CAP_ST_TABLE_LOC=0x0,PF1_TPHR_CAP_ST_TABLE_SIZE=0x000,PF1_TPHR_CAP_VER=0x1,VF0_TPHR_CAP_ST_MODE_SEL=0x0,VF0_TPHR_CAP_ST_TABLE_LOC=0x0,VF0_TPHR_CAP_ST_TABLE_SIZE=0x000,VF0_TPH" & 
"R_CAP_VER=0x1,VF1_TPHR_CAP_ST_MODE_SEL=0x0,VF1_TPHR_CAP_ST_TABLE_LOC=0x0,VF1_TPHR_CAP_ST_TABLE_SIZE=0x000,VF1_TPHR_CAP_VER=0x1,VF2_TPHR_CAP_ST_MODE_SEL=0x0,VF2_TPHR_CAP_ST_TABLE_LOC=0x0,VF2_TPHR_CAP_ST_TABLE_SIZE=0x000,VF2_TPHR_CAP_VER=0x1,VF3_TPHR_CAP_ST_MODE_SEL=0x0,VF3_TPHR_CAP_ST_TABLE_LOC=0x0,VF3_TPHR_CAP_ST_TABLE_SIZE=0x000,VF3_TPHR_CAP_VER=0x1,VF4_TPHR_CAP_ST_MODE_SEL=0x0,VF4_TPHR_CAP_ST_TABLE_LOC=0x0,VF4_TPHR_CAP_ST_TABLE_SIZE=0x000,VF4_TPHR_CAP_VER=0x1,VF5_TPHR_CAP_ST_MODE_SEL=0x0,VF5_T" & 
"PHR_CAP_ST_TABLE_LOC=0x0,VF5_TPHR_CAP_ST_TABLE_SIZE=0x000,VF5_TPHR_CAP_VER=0x1,PF0_TPHR_CAP_DEV_SPECIFIC_MODE=TRUE,PF0_TPHR_CAP_INT_VEC_MODE=FALSE,PF1_TPHR_CAP_DEV_SPECIFIC_MODE=TRUE,PF1_TPHR_CAP_INT_VEC_MODE=FALSE,VF0_TPHR_CAP_DEV_SPECIFIC_MODE=TRUE,VF0_TPHR_CAP_INT_VEC_MODE=FALSE,VF1_TPHR_CAP_DEV_SPECIFIC_MODE=TRUE,VF1_TPHR_CAP_INT_VEC_MODE=FALSE,VF2_TPHR_CAP_DEV_SPECIFIC_MODE=TRUE,VF2_TPHR_CAP_INT_VEC_MODE=FALSE,VF3_TPHR_CAP_DEV_SPECIFIC_MODE=TRUE,VF3_TPHR_CAP_INT_VEC_MODE=FALSE,VF4_TPHR_CAP_" & 
"DEV_SPECIFIC_MODE=TRUE,VF4_TPHR_CAP_INT_VEC_MODE=FALSE,VF5_TPHR_CAP_DEV_SPECIFIC_MODE=TRUE,VF5_TPHR_CAP_INT_VEC_MODE=FALSE,PF0_SECONDARY_PCIE_CAP_NEXTPTR=0x300,MCAP_CAP_NEXTPTR=0x000,PF0_VC_CAP_NEXTPTR=0x000,SPARE_WORD1=0x00000000,PF1_AER_CAP_ECRC_CHECK_CAPABLE=FALSE,PF1_AER_CAP_ECRC_GEN_CAPABLE=FALSE,PF1_AER_CAP_NEXTPTR=0x000,PF1_ARI_CAP_NEXTPTR=0x000,PF1_BAR0_APERTURE_SIZE=0x00,PF1_BAR0_CONTROL=0x0,PF1_BAR1_APERTURE_SIZE=0x00,PF1_BAR1_CONTROL=0x0,PF1_BAR2_APERTURE_SIZE=0x00,PF1_BAR2_CONTROL=0x" & 
"0,PF1_BAR3_APERTURE_SIZE=0x00,PF1_BAR3_CONTROL=0x0,PF1_BAR4_APERTURE_SIZE=0x00,PF1_BAR4_CONTROL=0x0,PF1_BAR5_APERTURE_SIZE=0x00,PF1_BAR5_CONTROL=0x0,PF1_CAPABILITY_POINTER=0xC0,PF1_CLASS_CODE=0x060A00,PF1_DEVICE_ID=0x8011,PF1_DEV_CAP_MAX_PAYLOAD_SIZE=0x2,PF1_DPA_CAP_NEXTPTR=0x000,PF1_DSN_CAP_NEXTPTR=0x000,PF1_EXPANSION_ROM_APERTURE_SIZE=0x00,PF1_EXPANSION_ROM_ENABLE=FALSE,PF1_INTERRUPT_PIN=0x0,PF1_MSIX_CAP_NEXTPTR=0x00,PF1_MSIX_CAP_PBA_BIR=0,PF1_MSIX_CAP_PBA_OFFSET=0x00000000,PF1_MSIX_CAP_TABLE_" & 
"BIR=0,PF1_MSIX_CAP_TABLE_OFFSET=0x00000000,PF1_MSIX_CAP_TABLE_SIZE=0x000,PF1_MSI_CAP_MULTIMSGCAP=0,PF1_MSI_CAP_NEXTPTR=0x00,PF1_PB_CAP_NEXTPTR=0x000,PF1_PM_CAP_NEXTPTR=0x00,PF1_RBAR_CAP_ENABLE=FALSE,PF1_RBAR_CAP_NEXTPTR=0x000,PF1_REVISION_ID=0x00,PF1_SRIOV_BAR0_APERTURE_SIZE=0x00,PF1_SRIOV_BAR0_CONTROL=0x0,PF1_SRIOV_BAR1_APERTURE_SIZE=0x00,PF1_SRIOV_BAR1_CONTROL=0x0,PF1_SRIOV_BAR2_APERTURE_SIZE=0x00,PF1_SRIOV_BAR2_CONTROL=0x0,PF1_SRIOV_BAR3_APERTURE_SIZE=0x00,PF1_SRIOV_BAR3_CONTROL=0x0,PF1_SRIOV" & 
"_BAR4_APERTURE_SIZE=0x00,PF1_SRIOV_BAR4_CONTROL=0x0,PF1_SRIOV_BAR5_APERTURE_SIZE=0x00,PF1_SRIOV_BAR5_CONTROL=0x0,PF1_SRIOV_CAP_INITIAL_VF=0x0000,PF1_SRIOV_CAP_NEXTPTR=0x000,PF1_SRIOV_CAP_TOTAL_VF=0x0000,PF1_SRIOV_CAP_VER=0x0,PF1_SRIOV_FIRST_VF_OFFSET=0x0000,PF1_SRIOV_FUNC_DEP_LINK=0x0001,PF1_SRIOV_SUPPORTED_PAGE_SIZE=0x00000553,PF1_SRIOV_VF_DEVICE_ID=0x0000,PF1_SUBSYSTEM_ID=0x0007,PF1_TPHR_CAP_ENABLE=FALSE,PF1_TPHR_CAP_NEXTPTR=0x000,PL_UPSTREAM_FACING=FALSE,en_msi_per_vec_masking=FALSE,SRIOV_CAP" & 
"_ENABLE=FALSE,TL_CREDITS_CD=0x3E0,TL_CREDITS_CH=0x20,TL_CREDITS_NPD=0x028,TL_CREDITS_NPH=0x20,TL_CREDITS_PD=0x198,TL_CREDITS_PH=0x20,TL_EXTENDED_CFG_EXTEND_INTERFACE_ENABLE=FALSE,ACS_EXT_CAP_ENABLE=FALSE,ACS_CAP_NEXTPTR=0x000,TL_LEGACY_MODE_ENABLE=FALSE,TL_PF_ENABLE_REG=0x0,VF0_CAPABILITY_POINTER=0x00,VF0_MSIX_CAP_PBA_BIR=0,VF0_MSIX_CAP_PBA_OFFSET=0x00000000,VF0_MSIX_CAP_TABLE_BIR=0,VF0_MSIX_CAP_TABLE_OFFSET=0x00000000,VF0_MSIX_CAP_TABLE_SIZE=0x000,VF0_MSI_CAP_MULTIMSGCAP=0,VF0_PM_CAP_NEXTPTR=0x" & 
"00,VF1_MSIX_CAP_PBA_BIR=0,VF1_MSIX_CAP_PBA_OFFSET=0x00000000,VF1_MSIX_CAP_TABLE_BIR=0,VF1_MSIX_CAP_TABLE_OFFSET=0x00000000,VF1_MSIX_CAP_TABLE_SIZE=0x000,VF1_MSI_CAP_MULTIMSGCAP=0,VF1_PM_CAP_NEXTPTR=0x00,VF2_MSIX_CAP_PBA_BIR=0,VF2_MSIX_CAP_PBA_OFFSET=0x00000000,VF2_MSIX_CAP_TABLE_BIR=0,VF2_MSIX_CAP_TABLE_OFFSET=0x00000000,VF2_MSIX_CAP_TABLE_SIZE=0x000,VF2_MSI_CAP_MULTIMSGCAP=0,VF2_PM_CAP_NEXTPTR=0x00,VF3_MSIX_CAP_PBA_BIR=0,VF3_MSIX_CAP_PBA_OFFSET=0x00000000,VF3_MSIX_CAP_TABLE_BIR=0,VF3_MSIX_CAP_T" & 
"ABLE_OFFSET=0x00000000,VF3_MSIX_CAP_TABLE_SIZE=0x000,VF3_MSI_CAP_MULTIMSGCAP=0,VF3_PM_CAP_NEXTPTR=0x00,VF4_MSIX_CAP_PBA_BIR=0,VF4_MSIX_CAP_PBA_OFFSET=0x00000000,VF4_MSIX_CAP_TABLE_BIR=0,VF4_MSIX_CAP_TABLE_OFFSET=0x00000000,VF4_MSIX_CAP_TABLE_SIZE=0x000,VF4_MSI_CAP_MULTIMSGCAP=0,VF4_PM_CAP_NEXTPTR=0x00,VF5_MSIX_CAP_PBA_BIR=0,VF5_MSIX_CAP_PBA_OFFSET=0x00000000,VF5_MSIX_CAP_TABLE_BIR=0,VF5_MSIX_CAP_TABLE_OFFSET=0x00000000,VF5_MSIX_CAP_TABLE_SIZE=0x000,VF5_MSI_CAP_MULTIMSGCAP=0,VF5_PM_CAP_NEXTPTR=0x" & 
"00,COMPLETION_SPACE=16KB,gen_x0y0_xdc=0,gen_x0y1_xdc=0,gen_x0y2_xdc=1,gen_x0y3_xdc=0,gen_x0y4_xdc=0,gen_x0y5_xdc=0,xlnx_ref_board=0,pcie_blk_locn=2,PIPE_SIM=FALSE,AXISTEN_IF_ENABLE_CLIENT_TAG=TRUE,PCIE_USE_MODE=2.0,PCIE_FAST_CONFIG=NONE,EXT_STARTUP_PRIMITIVE=FALSE,PL_INTERFACE=FALSE,PCIE_CONFIGURATION=FALSE,CFG_STATUS_IF=FALSE,GT_TX_PD=FALSE,TX_FC_IF=FALSE,CFG_EXT_IF=TRUE,CFG_FC_IF=FALSE,PER_FUNC_STATUS_IF=FALSE,CFG_MGMT_IF=FALSE,RCV_MSG_IF=FALSE,CFG_TX_MSG_IF=FALSE,CFG_CTL_IF=FALSE,MSI_EN=FALSE" & 
",MSIX_EN=FALSE,PCIE3_DRP=FALSE,DIS_GT_WIZARD=FALSE,TRANSCEIVER_CTRL_STATUS_PORTS=FALSE,SHARED_LOGIC=1,DEDICATE_PERST=FALSE,SYS_RESET_POLARITY=0,MCAP_ENABLEMENT=NONE,MCAP_FPGA_BITSTREAM_VERSION=0x00000000,PHY_LP_TXPRESET=4,EXT_CH_GT_DRP=FALSE,EN_GT_SELECTION=TRUE,SELECT_QUAD=GTH_Quad_227,silicon_revision=Production,DEV_PORT_TYPE=2,RX_DETECT=0,ENABLE_IBERT=FALSE,DBG_DESCRAMBLE_EN=FALSE,ENABLE_JTAG_DBG=FALSE,AXISTEN_IF_CC_PARITY_CHK=FALSE,AXISTEN_IF_RQ_PARITY_CHK=FALSE,ENABLE_AUTO_RXEQ=FALSE,GTWIZ_" & 
"IN_CORE=1,INS_LOSS_PROFILE=Add-in_Card,PM_ENABLE_L23_ENTRY=FALSE,BMD_PIO_MODE=FALSE,MULT_PF_DES=TRUE,ENABLE_GT_V1_5=FALSE,EXT_XVC_VSEC_ENABLE=FALSE,GT_DRP_CLK_SRC=0,FREE_RUN_FREQ=0}";
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
  ATTRIBUTE X_INTERFACE_INFO OF int_qpll1outclk_out: SIGNAL IS "xilinx.com:display_pcie3_ultrascale:int_shared_logic:1.0 pcie3_us_int_shared_logic ints_qpll1outclk_out";
  ATTRIBUTE X_INTERFACE_INFO OF int_qpll1outrefclk_out: SIGNAL IS "xilinx.com:display_pcie3_ultrascale:int_shared_logic:1.0 pcie3_us_int_shared_logic ints_qpll1outrefclk_out";
  ATTRIBUTE X_INTERFACE_INFO OF int_qpll1lock_out: SIGNAL IS "xilinx.com:display_pcie3_ultrascale:int_shared_logic:1.0 pcie3_us_int_shared_logic ints_qpll1lock_out";
  ATTRIBUTE X_INTERFACE_PARAMETER OF sys_reset: SIGNAL IS "XIL_INTERFACENAME RST.sys_rst, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF sys_reset: SIGNAL IS "xilinx.com:signal:reset:1.0 RST.sys_rst RST";
  ATTRIBUTE X_INTERFACE_PARAMETER OF sys_clk_gt: SIGNAL IS "XIL_INTERFACENAME CLK.sys_clk_gt, FREQ_HZ 100000000, PHASE 0.000, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF sys_clk_gt: SIGNAL IS "xilinx.com:signal:clock:1.0 CLK.sys_clk_gt CLK";
  ATTRIBUTE X_INTERFACE_PARAMETER OF sys_clk: SIGNAL IS "XIL_INTERFACENAME CLK.sys_clk, FREQ_HZ 100000000, PHASE 0.000, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF sys_clk: SIGNAL IS "xilinx.com:signal:clock:1.0 CLK.sys_clk CLK";
  ATTRIBUTE X_INTERFACE_INFO OF cfg_interrupt_sent: SIGNAL IS "xilinx.com:interface:pcie3_cfg_interrupt:1.0 pcie3_cfg_interrupt SENT";
  ATTRIBUTE X_INTERFACE_INFO OF cfg_interrupt_pending: SIGNAL IS "xilinx.com:interface:pcie3_cfg_interrupt:1.0 pcie3_cfg_interrupt PENDING";
  ATTRIBUTE X_INTERFACE_INFO OF cfg_interrupt_int: SIGNAL IS "xilinx.com:interface:pcie3_cfg_interrupt:1.0 pcie3_cfg_interrupt INTx_VECTOR";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_cc_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_cc TVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_cc_tuser: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_cc TUSER";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_cc_tready: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_cc TREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_cc_tlast: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_cc TLAST";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_cc_tkeep: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_cc TKEEP";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axis_cc_tdata: SIGNAL IS "XIL_INTERFACENAME s_axis_cc, TDATA_NUM_BYTES 16, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 33, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 1, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.000, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_cc_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_cc TDATA";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_cq_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_cq TVALID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_cq_tuser: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_cq TUSER";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_cq_tready: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_cq TREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_cq_tlast: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_cq TLAST";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_cq_tkeep: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_cq TKEEP";
  ATTRIBUTE X_INTERFACE_PARAMETER OF m_axis_cq_tdata: SIGNAL IS "XIL_INTERFACENAME m_axis_cq, TDATA_NUM_BYTES 16, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 85, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 1, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.000, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_cq_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_cq TDATA";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_rc_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_rc TVALID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_rc_tuser: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_rc TUSER";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_rc_tready: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_rc TREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_rc_tlast: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_rc TLAST";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_rc_tkeep: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_rc TKEEP";
  ATTRIBUTE X_INTERFACE_PARAMETER OF m_axis_rc_tdata: SIGNAL IS "XIL_INTERFACENAME m_axis_rc, TDATA_NUM_BYTES 16, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 75, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 1, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.000, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_rc_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 m_axis_rc TDATA";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_rq_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_rq TVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_rq_tuser: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_rq TUSER";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_rq_tready: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_rq TREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_rq_tlast: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_rq TLAST";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_rq_tkeep: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_rq TKEEP";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axis_rq_tdata: SIGNAL IS "XIL_INTERFACENAME s_axis_rq, TDATA_NUM_BYTES 16, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 60, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 1, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.000, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_rq_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 s_axis_rq TDATA";
  ATTRIBUTE X_INTERFACE_PARAMETER OF user_reset: SIGNAL IS "XIL_INTERFACENAME RST.user_reset, POLARITY ACTIVE_HIGH, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF user_reset: SIGNAL IS "xilinx.com:signal:reset:1.0 RST.user_reset RST";
  ATTRIBUTE X_INTERFACE_PARAMETER OF user_clk: SIGNAL IS "XIL_INTERFACENAME CLK.user_clk, ASSOCIATED_BUSIF m_axis_cq:s_axis_cc:s_axis_rq:m_axis_rc, FREQ_HZ 125000000, ASSOCIATED_RESET user_reset, PHASE 0.000, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF user_clk: SIGNAL IS "xilinx.com:signal:clock:1.0 CLK.user_clk CLK";
  ATTRIBUTE X_INTERFACE_INFO OF pci_exp_rxp: SIGNAL IS "xilinx.com:interface:pcie_7x_mgt:1.0 pcie_7x_mgt rxp";
  ATTRIBUTE X_INTERFACE_INFO OF pci_exp_rxn: SIGNAL IS "xilinx.com:interface:pcie_7x_mgt:1.0 pcie_7x_mgt rxn";
  ATTRIBUTE X_INTERFACE_INFO OF pci_exp_txp: SIGNAL IS "xilinx.com:interface:pcie_7x_mgt:1.0 pcie_7x_mgt txp";
  ATTRIBUTE X_INTERFACE_INFO OF pci_exp_txn: SIGNAL IS "xilinx.com:interface:pcie_7x_mgt:1.0 pcie_7x_mgt txn";
BEGIN
  U0 : Pcie_nvme0_pcie3_uscale_core_top
    GENERIC MAP (
      PL_LINK_CAP_MAX_LINK_SPEED => 4,
      PL_LINK_CAP_MAX_LINK_WIDTH => 4,
      USER_CLK_FREQ => 3,
      CORE_CLK_FREQ => 1,
      PLL_TYPE => 2,
      PF0_LINK_CAP_ASPM_SUPPORT => 0,
      C_DATA_WIDTH => 128,
      REF_CLK_FREQ => 0,
      PCIE_LINK_SPEED => 3,
      KEEP_WIDTH => 4,
      ARI_CAP_ENABLE => "FALSE",
      PF0_ARI_CAP_NEXT_FUNC => X"00",
      AXISTEN_IF_CC_ALIGNMENT_MODE => "FALSE",
      AXISTEN_IF_CQ_ALIGNMENT_MODE => "FALSE",
      AXISTEN_IF_RC_ALIGNMENT_MODE => "FALSE",
      AXISTEN_IF_RC_STRADDLE => "FALSE",
      AXISTEN_IF_RQ_ALIGNMENT_MODE => "FALSE",
      AXISTEN_IF_ENABLE_MSG_ROUTE => X"2FFFF",
      AXISTEN_IF_ENABLE_RX_MSG_INTFC => "FALSE",
      PF0_AER_CAP_ECRC_CHECK_CAPABLE => "FALSE",
      PF0_AER_CAP_ECRC_GEN_CAPABLE => "FALSE",
      PF0_AER_CAP_NEXTPTR => X"300",
      PF0_ARI_CAP_NEXTPTR => X"000",
      VF0_ARI_CAP_NEXTPTR => X"000",
      VF1_ARI_CAP_NEXTPTR => X"000",
      VF2_ARI_CAP_NEXTPTR => X"000",
      VF3_ARI_CAP_NEXTPTR => X"000",
      VF4_ARI_CAP_NEXTPTR => X"000",
      VF5_ARI_CAP_NEXTPTR => X"000",
      PF0_BAR0_APERTURE_SIZE => X"09",
      PF0_BAR0_CONTROL => X"4",
      PF0_BAR1_APERTURE_SIZE => X"00",
      PF0_BAR1_CONTROL => X"0",
      PF0_BAR2_APERTURE_SIZE => X"00",
      PF0_BAR2_CONTROL => X"0",
      PF0_BAR3_APERTURE_SIZE => X"00",
      PF0_BAR3_CONTROL => X"0",
      PF0_BAR4_APERTURE_SIZE => X"00",
      PF0_BAR4_CONTROL => X"0",
      PF0_BAR5_APERTURE_SIZE => X"00",
      PF0_BAR5_CONTROL => X"0",
      PF0_CAPABILITY_POINTER => X"C0",
      PF0_CLASS_CODE => X"060A00",
      PF0_VENDOR_ID => X"10EE",
      PF0_DEVICE_ID => X"8124",
      PF0_DEV_CAP2_128B_CAS_ATOMIC_COMPLETER_SUPPORT => "FALSE",
      PF0_DEV_CAP2_32B_ATOMIC_COMPLETER_SUPPORT => "FALSE",
      PF0_DEV_CAP2_64B_ATOMIC_COMPLETER_SUPPORT => "FALSE",
      PF0_DEV_CAP2_LTR_SUPPORT => "FALSE",
      PF0_DEV_CAP2_OBFF_SUPPORT => X"0",
      PF0_DEV_CAP2_TPH_COMPLETER_SUPPORT => "FALSE",
      PF0_DEV_CAP_EXT_TAG_SUPPORTED => "FALSE",
      PF0_DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE => "FALSE",
      PF0_DEV_CAP_MAX_PAYLOAD_SIZE => X"3",
      PF0_DPA_CAP_NEXTPTR => X"000",
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION0 => X"00",
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION1 => X"00",
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION2 => X"00",
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION3 => X"00",
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION4 => X"00",
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION5 => X"00",
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION6 => X"00",
      PF0_DPA_CAP_SUB_STATE_POWER_ALLOCATION7 => X"00",
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION0 => X"00",
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION1 => X"00",
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION2 => X"00",
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION3 => X"00",
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION4 => X"00",
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION5 => X"00",
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION6 => X"00",
      PF1_DPA_CAP_SUB_STATE_POWER_ALLOCATION7 => X"00",
      PF0_DSN_CAP_NEXTPTR => X"300",
      PF0_EXPANSION_ROM_APERTURE_SIZE => X"00",
      PF0_EXPANSION_ROM_ENABLE => "FALSE",
      PF0_INTERRUPT_PIN => X"0",
      PF0_LINK_STATUS_SLOT_CLOCK_CONFIG => "TRUE",
      PF0_LTR_CAP_NEXTPTR => X"000",
      PF0_MSIX_CAP_NEXTPTR => X"00",
      PF0_MSIX_CAP_PBA_BIR => 0,
      PF0_MSIX_CAP_PBA_OFFSET => X"00000000",
      PF0_MSIX_CAP_TABLE_BIR => 0,
      PF0_MSIX_CAP_TABLE_OFFSET => X"00000000",
      PF0_MSIX_CAP_TABLE_SIZE => X"000",
      PF0_MSI_CAP_MULTIMSGCAP => 0,
      PF0_MSI_CAP_NEXTPTR => X"00",
      PF0_PB_CAP_NEXTPTR => X"000",
      PF0_PM_CAP_NEXTPTR => X"00",
      PF0_PM_CAP_PMESUPPORT_D0 => "FALSE",
      PF0_PM_CAP_PMESUPPORT_D1 => "FALSE",
      PF0_PM_CAP_PMESUPPORT_D3HOT => "FALSE",
      PF0_PM_CAP_SUPP_D1_STATE => "FALSE",
      PF0_RBAR_CAP_ENABLE => "FALSE",
      PF0_RBAR_CAP_NEXTPTR => X"000",
      PF0_RBAR_CAP_SIZE0 => X"00000",
      PF0_RBAR_CAP_SIZE1 => X"00000",
      PF0_RBAR_CAP_SIZE2 => X"00000",
      PF1_RBAR_CAP_SIZE0 => X"00000",
      PF1_RBAR_CAP_SIZE1 => X"00000",
      PF1_RBAR_CAP_SIZE2 => X"00000",
      PF0_REVISION_ID => X"00",
      PF0_SRIOV_BAR0_APERTURE_SIZE => X"00",
      PF0_SRIOV_BAR0_CONTROL => X"0",
      PF0_SRIOV_BAR1_APERTURE_SIZE => X"00",
      PF0_SRIOV_BAR1_CONTROL => X"0",
      PF0_SRIOV_BAR2_APERTURE_SIZE => X"00",
      PF0_SRIOV_BAR2_CONTROL => X"0",
      PF0_SRIOV_BAR3_APERTURE_SIZE => X"00",
      PF0_SRIOV_BAR3_CONTROL => X"0",
      PF0_SRIOV_BAR4_APERTURE_SIZE => X"00",
      PF0_SRIOV_BAR4_CONTROL => X"0",
      PF0_SRIOV_BAR5_APERTURE_SIZE => X"00",
      PF0_SRIOV_BAR5_CONTROL => X"0",
      PF0_SRIOV_CAP_INITIAL_VF => X"0000",
      PF0_SRIOV_CAP_NEXTPTR => X"000",
      PF0_SRIOV_CAP_TOTAL_VF => X"0000",
      PF0_SRIOV_CAP_VER => X"0",
      PF0_SRIOV_FIRST_VF_OFFSET => X"0000",
      PF0_SRIOV_FUNC_DEP_LINK => X"0000",
      PF0_SRIOV_SUPPORTED_PAGE_SIZE => X"00000553",
      PF0_SRIOV_VF_DEVICE_ID => X"0000",
      PF0_SUBSYSTEM_VENDOR_ID => X"10EE",
      PF0_SUBSYSTEM_ID => X"0007",
      PF0_TPHR_CAP_ENABLE => "FALSE",
      PF0_TPHR_CAP_NEXTPTR => X"300",
      VF0_TPHR_CAP_NEXTPTR => X"000",
      VF1_TPHR_CAP_NEXTPTR => X"000",
      VF2_TPHR_CAP_NEXTPTR => X"000",
      VF3_TPHR_CAP_NEXTPTR => X"000",
      VF4_TPHR_CAP_NEXTPTR => X"000",
      VF5_TPHR_CAP_NEXTPTR => X"000",
      PF0_TPHR_CAP_ST_MODE_SEL => X"0",
      PF0_TPHR_CAP_ST_TABLE_LOC => X"0",
      PF0_TPHR_CAP_ST_TABLE_SIZE => X"000",
      PF0_TPHR_CAP_VER => X"1",
      PF1_TPHR_CAP_ST_MODE_SEL => X"0",
      PF1_TPHR_CAP_ST_TABLE_LOC => X"0",
      PF1_TPHR_CAP_ST_TABLE_SIZE => X"000",
      PF1_TPHR_CAP_VER => X"1",
      VF0_TPHR_CAP_ST_MODE_SEL => X"0",
      VF0_TPHR_CAP_ST_TABLE_LOC => X"0",
      VF0_TPHR_CAP_ST_TABLE_SIZE => X"000",
      VF0_TPHR_CAP_VER => X"1",
      VF1_TPHR_CAP_ST_MODE_SEL => X"0",
      VF1_TPHR_CAP_ST_TABLE_LOC => X"0",
      VF1_TPHR_CAP_ST_TABLE_SIZE => X"000",
      VF1_TPHR_CAP_VER => X"1",
      VF2_TPHR_CAP_ST_MODE_SEL => X"0",
      VF2_TPHR_CAP_ST_TABLE_LOC => X"0",
      VF2_TPHR_CAP_ST_TABLE_SIZE => X"000",
      VF2_TPHR_CAP_VER => X"1",
      VF3_TPHR_CAP_ST_MODE_SEL => X"0",
      VF3_TPHR_CAP_ST_TABLE_LOC => X"0",
      VF3_TPHR_CAP_ST_TABLE_SIZE => X"000",
      VF3_TPHR_CAP_VER => X"1",
      VF4_TPHR_CAP_ST_MODE_SEL => X"0",
      VF4_TPHR_CAP_ST_TABLE_LOC => X"0",
      VF4_TPHR_CAP_ST_TABLE_SIZE => X"000",
      VF4_TPHR_CAP_VER => X"1",
      VF5_TPHR_CAP_ST_MODE_SEL => X"0",
      VF5_TPHR_CAP_ST_TABLE_LOC => X"0",
      VF5_TPHR_CAP_ST_TABLE_SIZE => X"000",
      VF5_TPHR_CAP_VER => X"1",
      PF0_TPHR_CAP_DEV_SPECIFIC_MODE => "TRUE",
      PF0_TPHR_CAP_INT_VEC_MODE => "FALSE",
      PF1_TPHR_CAP_DEV_SPECIFIC_MODE => "TRUE",
      PF1_TPHR_CAP_INT_VEC_MODE => "FALSE",
      VF0_TPHR_CAP_DEV_SPECIFIC_MODE => "TRUE",
      VF0_TPHR_CAP_INT_VEC_MODE => "FALSE",
      VF1_TPHR_CAP_DEV_SPECIFIC_MODE => "TRUE",
      VF1_TPHR_CAP_INT_VEC_MODE => "FALSE",
      VF2_TPHR_CAP_DEV_SPECIFIC_MODE => "TRUE",
      VF2_TPHR_CAP_INT_VEC_MODE => "FALSE",
      VF3_TPHR_CAP_DEV_SPECIFIC_MODE => "TRUE",
      VF3_TPHR_CAP_INT_VEC_MODE => "FALSE",
      VF4_TPHR_CAP_DEV_SPECIFIC_MODE => "TRUE",
      VF4_TPHR_CAP_INT_VEC_MODE => "FALSE",
      VF5_TPHR_CAP_DEV_SPECIFIC_MODE => "TRUE",
      VF5_TPHR_CAP_INT_VEC_MODE => "FALSE",
      PF0_SECONDARY_PCIE_CAP_NEXTPTR => X"300",
      MCAP_CAP_NEXTPTR => X"000",
      PF0_VC_CAP_NEXTPTR => X"000",
      SPARE_WORD1 => X"00000000",
      PF1_AER_CAP_ECRC_CHECK_CAPABLE => "FALSE",
      PF1_AER_CAP_ECRC_GEN_CAPABLE => "FALSE",
      PF1_AER_CAP_NEXTPTR => X"000",
      PF1_ARI_CAP_NEXTPTR => X"000",
      PF1_BAR0_APERTURE_SIZE => X"00",
      PF1_BAR0_CONTROL => X"0",
      PF1_BAR1_APERTURE_SIZE => X"00",
      PF1_BAR1_CONTROL => X"0",
      PF1_BAR2_APERTURE_SIZE => X"00",
      PF1_BAR2_CONTROL => X"0",
      PF1_BAR3_APERTURE_SIZE => X"00",
      PF1_BAR3_CONTROL => X"0",
      PF1_BAR4_APERTURE_SIZE => X"00",
      PF1_BAR4_CONTROL => X"0",
      PF1_BAR5_APERTURE_SIZE => X"00",
      PF1_BAR5_CONTROL => X"0",
      PF1_CAPABILITY_POINTER => X"C0",
      PF1_CLASS_CODE => X"060A00",
      PF1_DEVICE_ID => X"8011",
      PF1_DEV_CAP_MAX_PAYLOAD_SIZE => X"2",
      PF1_DPA_CAP_NEXTPTR => X"000",
      PF1_DSN_CAP_NEXTPTR => X"000",
      PF1_EXPANSION_ROM_APERTURE_SIZE => X"00",
      PF1_EXPANSION_ROM_ENABLE => "FALSE",
      PF1_INTERRUPT_PIN => X"0",
      PF1_MSIX_CAP_NEXTPTR => X"00",
      PF1_MSIX_CAP_PBA_BIR => 0,
      PF1_MSIX_CAP_PBA_OFFSET => X"00000000",
      PF1_MSIX_CAP_TABLE_BIR => 0,
      PF1_MSIX_CAP_TABLE_OFFSET => X"00000000",
      PF1_MSIX_CAP_TABLE_SIZE => X"000",
      PF1_MSI_CAP_MULTIMSGCAP => 0,
      PF1_MSI_CAP_NEXTPTR => X"00",
      PF1_PB_CAP_NEXTPTR => X"000",
      PF1_PM_CAP_NEXTPTR => X"00",
      PF1_RBAR_CAP_ENABLE => "FALSE",
      PF1_RBAR_CAP_NEXTPTR => X"000",
      PF1_REVISION_ID => X"00",
      PF1_SRIOV_BAR0_APERTURE_SIZE => X"00",
      PF1_SRIOV_BAR0_CONTROL => X"0",
      PF1_SRIOV_BAR1_APERTURE_SIZE => X"00",
      PF1_SRIOV_BAR1_CONTROL => X"0",
      PF1_SRIOV_BAR2_APERTURE_SIZE => X"00",
      PF1_SRIOV_BAR2_CONTROL => X"0",
      PF1_SRIOV_BAR3_APERTURE_SIZE => X"00",
      PF1_SRIOV_BAR3_CONTROL => X"0",
      PF1_SRIOV_BAR4_APERTURE_SIZE => X"00",
      PF1_SRIOV_BAR4_CONTROL => X"0",
      PF1_SRIOV_BAR5_APERTURE_SIZE => X"00",
      PF1_SRIOV_BAR5_CONTROL => X"0",
      PF1_SRIOV_CAP_INITIAL_VF => X"0000",
      PF1_SRIOV_CAP_NEXTPTR => X"000",
      PF1_SRIOV_CAP_TOTAL_VF => X"0000",
      PF1_SRIOV_CAP_VER => X"0",
      PF1_SRIOV_FIRST_VF_OFFSET => X"0000",
      PF1_SRIOV_FUNC_DEP_LINK => X"0001",
      PF1_SRIOV_SUPPORTED_PAGE_SIZE => X"00000553",
      PF1_SRIOV_VF_DEVICE_ID => X"0000",
      PF1_SUBSYSTEM_ID => X"0007",
      PF1_TPHR_CAP_ENABLE => "FALSE",
      PF1_TPHR_CAP_NEXTPTR => X"000",
      PL_UPSTREAM_FACING => "FALSE",
      en_msi_per_vec_masking => "FALSE",
      SRIOV_CAP_ENABLE => "FALSE",
      TL_CREDITS_CD => X"3E0",
      TL_CREDITS_CH => X"20",
      TL_CREDITS_NPD => X"028",
      TL_CREDITS_NPH => X"20",
      TL_CREDITS_PD => X"198",
      TL_CREDITS_PH => X"20",
      TL_EXTENDED_CFG_EXTEND_INTERFACE_ENABLE => "FALSE",
      ACS_EXT_CAP_ENABLE => "FALSE",
      ACS_CAP_NEXTPTR => X"000",
      TL_LEGACY_MODE_ENABLE => "FALSE",
      TL_PF_ENABLE_REG => X"0",
      VF0_CAPABILITY_POINTER => X"00",
      VF0_MSIX_CAP_PBA_BIR => 0,
      VF0_MSIX_CAP_PBA_OFFSET => X"00000000",
      VF0_MSIX_CAP_TABLE_BIR => 0,
      VF0_MSIX_CAP_TABLE_OFFSET => X"00000000",
      VF0_MSIX_CAP_TABLE_SIZE => X"000",
      VF0_MSI_CAP_MULTIMSGCAP => 0,
      VF0_PM_CAP_NEXTPTR => X"00",
      VF1_MSIX_CAP_PBA_BIR => 0,
      VF1_MSIX_CAP_PBA_OFFSET => X"00000000",
      VF1_MSIX_CAP_TABLE_BIR => 0,
      VF1_MSIX_CAP_TABLE_OFFSET => X"00000000",
      VF1_MSIX_CAP_TABLE_SIZE => X"000",
      VF1_MSI_CAP_MULTIMSGCAP => 0,
      VF1_PM_CAP_NEXTPTR => X"00",
      VF2_MSIX_CAP_PBA_BIR => 0,
      VF2_MSIX_CAP_PBA_OFFSET => X"00000000",
      VF2_MSIX_CAP_TABLE_BIR => 0,
      VF2_MSIX_CAP_TABLE_OFFSET => X"00000000",
      VF2_MSIX_CAP_TABLE_SIZE => X"000",
      VF2_MSI_CAP_MULTIMSGCAP => 0,
      VF2_PM_CAP_NEXTPTR => X"00",
      VF3_MSIX_CAP_PBA_BIR => 0,
      VF3_MSIX_CAP_PBA_OFFSET => X"00000000",
      VF3_MSIX_CAP_TABLE_BIR => 0,
      VF3_MSIX_CAP_TABLE_OFFSET => X"00000000",
      VF3_MSIX_CAP_TABLE_SIZE => X"000",
      VF3_MSI_CAP_MULTIMSGCAP => 0,
      VF3_PM_CAP_NEXTPTR => X"00",
      VF4_MSIX_CAP_PBA_BIR => 0,
      VF4_MSIX_CAP_PBA_OFFSET => X"00000000",
      VF4_MSIX_CAP_TABLE_BIR => 0,
      VF4_MSIX_CAP_TABLE_OFFSET => X"00000000",
      VF4_MSIX_CAP_TABLE_SIZE => X"000",
      VF4_MSI_CAP_MULTIMSGCAP => 0,
      VF4_PM_CAP_NEXTPTR => X"00",
      VF5_MSIX_CAP_PBA_BIR => 0,
      VF5_MSIX_CAP_PBA_OFFSET => X"00000000",
      VF5_MSIX_CAP_TABLE_BIR => 0,
      VF5_MSIX_CAP_TABLE_OFFSET => X"00000000",
      VF5_MSIX_CAP_TABLE_SIZE => X"000",
      VF5_MSI_CAP_MULTIMSGCAP => 0,
      VF5_PM_CAP_NEXTPTR => X"00",
      COMPLETION_SPACE => "16KB",
      gen_x0y0_xdc => 0,
      gen_x0y1_xdc => 0,
      gen_x0y2_xdc => 1,
      gen_x0y3_xdc => 0,
      gen_x0y4_xdc => 0,
      gen_x0y5_xdc => 0,
      xlnx_ref_board => 0,
      pcie_blk_locn => 2,
      PIPE_SIM => "FALSE",
      AXISTEN_IF_ENABLE_CLIENT_TAG => "TRUE",
      PCIE_USE_MODE => "2.0",
      PCIE_FAST_CONFIG => "NONE",
      EXT_STARTUP_PRIMITIVE => "FALSE",
      PL_INTERFACE => "FALSE",
      PCIE_CONFIGURATION => "FALSE",
      CFG_STATUS_IF => "FALSE",
      GT_TX_PD => "FALSE",
      TX_FC_IF => "FALSE",
      CFG_EXT_IF => "TRUE",
      CFG_FC_IF => "FALSE",
      PER_FUNC_STATUS_IF => "FALSE",
      CFG_MGMT_IF => "FALSE",
      RCV_MSG_IF => "FALSE",
      CFG_TX_MSG_IF => "FALSE",
      CFG_CTL_IF => "FALSE",
      MSI_EN => "FALSE",
      MSIX_EN => "FALSE",
      PCIE3_DRP => "FALSE",
      DIS_GT_WIZARD => "FALSE",
      TRANSCEIVER_CTRL_STATUS_PORTS => "FALSE",
      SHARED_LOGIC => 1,
      DEDICATE_PERST => "FALSE",
      SYS_RESET_POLARITY => 0,
      MCAP_ENABLEMENT => "NONE",
      MCAP_FPGA_BITSTREAM_VERSION => X"00000000",
      PHY_LP_TXPRESET => 4,
      EXT_CH_GT_DRP => "FALSE",
      EN_GT_SELECTION => "TRUE",
      SELECT_QUAD => "GTH_Quad_227",
      silicon_revision => "Production",
      DEV_PORT_TYPE => 2,
      RX_DETECT => 0,
      ENABLE_IBERT => "FALSE",
      DBG_DESCRAMBLE_EN => "FALSE",
      ENABLE_JTAG_DBG => "FALSE",
      AXISTEN_IF_CC_PARITY_CHK => "FALSE",
      AXISTEN_IF_RQ_PARITY_CHK => "FALSE",
      ENABLE_AUTO_RXEQ => "FALSE",
      GTWIZ_IN_CORE => 1,
      INS_LOSS_PROFILE => "Add-in_Card",
      PM_ENABLE_L23_ENTRY => "FALSE",
      BMD_PIO_MODE => "FALSE",
      MULT_PF_DES => "TRUE",
      ENABLE_GT_V1_5 => "FALSE",
      EXT_XVC_VSEC_ENABLE => "FALSE",
      GT_DRP_CLK_SRC => 0,
      FREE_RUN_FREQ => 0
    )
    PORT MAP (
      pci_exp_txn => pci_exp_txn,
      pci_exp_txp => pci_exp_txp,
      pci_exp_rxn => pci_exp_rxn,
      pci_exp_rxp => pci_exp_rxp,
      user_clk => user_clk,
      user_reset => user_reset,
      user_lnk_up => user_lnk_up,
      gt_tx_powerdown => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 3)),
      s_axis_rq_tdata => s_axis_rq_tdata,
      s_axis_rq_tkeep => s_axis_rq_tkeep,
      s_axis_rq_tlast => s_axis_rq_tlast,
      s_axis_rq_tready => s_axis_rq_tready,
      s_axis_rq_tuser => s_axis_rq_tuser,
      s_axis_rq_tvalid => s_axis_rq_tvalid,
      m_axis_rc_tdata => m_axis_rc_tdata,
      m_axis_rc_tkeep => m_axis_rc_tkeep,
      m_axis_rc_tlast => m_axis_rc_tlast,
      m_axis_rc_tready => m_axis_rc_tready,
      m_axis_rc_tuser => m_axis_rc_tuser,
      m_axis_rc_tvalid => m_axis_rc_tvalid,
      m_axis_cq_tdata => m_axis_cq_tdata,
      m_axis_cq_tkeep => m_axis_cq_tkeep,
      m_axis_cq_tlast => m_axis_cq_tlast,
      m_axis_cq_tready => m_axis_cq_tready,
      m_axis_cq_tuser => m_axis_cq_tuser,
      m_axis_cq_tvalid => m_axis_cq_tvalid,
      s_axis_cc_tdata => s_axis_cc_tdata,
      s_axis_cc_tkeep => s_axis_cc_tkeep,
      s_axis_cc_tlast => s_axis_cc_tlast,
      s_axis_cc_tready => s_axis_cc_tready,
      s_axis_cc_tuser => s_axis_cc_tuser,
      s_axis_cc_tvalid => s_axis_cc_tvalid,
      pcie_cq_np_req => '1',
      cfg_mgmt_addr => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 19)),
      cfg_mgmt_write => '0',
      cfg_mgmt_write_data => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 32)),
      cfg_mgmt_byte_enable => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      cfg_mgmt_read => '0',
      cfg_mgmt_type1_cfg_reg_access => '0',
      cfg_msg_transmit => '0',
      cfg_msg_transmit_type => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 3)),
      cfg_msg_transmit_data => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 32)),
      cfg_fc_sel => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 3)),
      cfg_per_func_status_control => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 3)),
      cfg_per_function_number => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      cfg_per_function_output_request => '0',
      cfg_dsn => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 64)),
      cfg_power_state_change_ack => '0',
      cfg_err_cor_in => '0',
      cfg_err_uncor_in => '0',
      cfg_flr_done => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      cfg_vf_flr_done => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 8)),
      cfg_link_training_enable => '1',
      cfg_ext_read_data => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 32)),
      cfg_ext_read_data_valid => '0',
      cfg_interrupt_int => cfg_interrupt_int,
      cfg_interrupt_pending => cfg_interrupt_pending,
      cfg_interrupt_sent => cfg_interrupt_sent,
      cfg_interrupt_msi_select => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      cfg_interrupt_msi_int => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 32)),
      cfg_interrupt_msi_pending_status => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 32)),
      cfg_interrupt_msi_pending_status_data_enable => '0',
      cfg_interrupt_msi_pending_status_function_num => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      cfg_interrupt_msi_attr => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 3)),
      cfg_interrupt_msi_tph_present => '0',
      cfg_interrupt_msi_tph_type => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 2)),
      cfg_interrupt_msi_tph_st_tag => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 9)),
      cfg_interrupt_msi_function_number => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      cfg_interrupt_msix_data => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 32)),
      cfg_interrupt_msix_address => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 64)),
      cfg_interrupt_msix_int => '0',
      cfg_config_space_enable => '1',
      cfg_req_pm_transition_l23_ready => '0',
      cfg_hot_reset_in => '0',
      cfg_ds_port_number => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 8)),
      cfg_ds_bus_number => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 8)),
      cfg_ds_device_number => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 5)),
      cfg_ds_function_number => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 3)),
      cfg_subsys_vend_id => X"10EE",
      drp_clk => '1',
      drp_en => '0',
      drp_we => '0',
      drp_addr => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 10)),
      drp_di => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 16)),
      user_tph_stt_address => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 5)),
      user_tph_function_num => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      user_tph_stt_read_enable => '0',
      sys_clk => sys_clk,
      sys_clk_gt => sys_clk_gt,
      sys_reset => sys_reset,
      conf_req_type => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 2)),
      conf_req_reg_num => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      conf_req_data => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 32)),
      conf_req_valid => '0',
      mcap_eos_in => '0',
      startup_do => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      startup_dts => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      startup_fcsbo => '0',
      startup_fcsbts => '0',
      startup_gsr => '0',
      startup_gts => '0',
      startup_keyclearb => '1',
      startup_pack => '0',
      startup_usrcclko => '0',
      startup_usrcclkts => '1',
      startup_usrdoneo => '0',
      startup_usrdonets => '1',
      cap_gnt => '1',
      cap_rel => '0',
      pl_eq_reset_eieos_count => '0',
      pl_gen2_upstream_prefer_deemph => '0',
      pcie_perstn1_in => '0',
      ext_qpll1lock_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      ext_qpll1outclk_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      ext_qpll1outrefclk_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      int_qpll1lock_out => int_qpll1lock_out,
      int_qpll1outrefclk_out => int_qpll1outrefclk_out,
      int_qpll1outclk_out => int_qpll1outclk_out,
      common_commands_in => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 26)),
      pipe_rx_0_sigs => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 84)),
      pipe_rx_1_sigs => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 84)),
      pipe_rx_2_sigs => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 84)),
      pipe_rx_3_sigs => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 84)),
      pipe_rx_4_sigs => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 84)),
      pipe_rx_5_sigs => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 84)),
      pipe_rx_6_sigs => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 84)),
      pipe_rx_7_sigs => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 84)),
      gt_pcieuserratedone => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      gt_loopback => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 12)),
      gt_txprbsforceerr => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      gt_txinhibit => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      gt_txprbssel => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 16)),
      gt_rxprbssel => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 16)),
      gt_rxprbscntreset => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      gt_dmonfiforeset => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      gt_dmonitorclk => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      ext_ch_gt_drpaddr => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 36)),
      ext_ch_gt_drpen => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      ext_ch_gt_drpdi => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 64)),
      ext_ch_gt_drpwe => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxdlysresetdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxelecidle_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxoutclk_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxphaligndone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxpmaresetdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxprbserr_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxprbslocked_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxprgdivresetdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxratedone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxresetdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxsyncdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxvalid_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      txdlysresetdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      txoutclk_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      txphaligndone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      txphinitdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      txpmaresetdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      txprgdivresetdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      txresetdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      txsyncout_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      txsyncdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      cplllock_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      eyescandataerror_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      gtpowergood_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      pcierategen3_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      pcierateidle_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      pciesynctxsyncdone_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      pcieusergen3rdy_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      pcieuserphystatusrst_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      pcieuserratestart_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      phystatus_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxbyteisaligned_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxbyterealign_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxcdrlock_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      rxcommadet_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      gthtxn_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      gthtxp_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      drprdy_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 4)),
      pcierateqpllpd_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 8)),
      pcierateqpllreset_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 8)),
      rxclkcorcnt_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 8)),
      bufgtce_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 12)),
      bufgtcemask_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 12)),
      bufgtreset_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 12)),
      bufgtrstmask_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 12)),
      rxbufstatus_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 12)),
      rxstatus_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 12)),
      rxctrl2_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 32)),
      rxctrl3_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 32)),
      bufgtdiv_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 36)),
      pcsrsvdout_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 48)),
      drpdo_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 64)),
      rxctrl0_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 64)),
      rxctrl1_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 64)),
      dmonitorout_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 68)),
      rxdata_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 512)),
      qpll1lock_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      qpll1outclk_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      qpll1outrefclk_out => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      free_run_clock => '0',
      phy_rdy_out => phy_rdy_out
    );
END Pcie_nvme0_arch;
