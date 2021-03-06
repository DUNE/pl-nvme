--------------------------------------------------------------------------------
-- DuneNvmeTestTop.vhd Simple NVMe access test system
--------------------------------------------------------------------------------
--!
--! @class	DuneNvmeTestOsperoTop
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-12
--! @version	1.0.0
--!
--! @brief
--! This module implements a complete test design for the NvmeStorage system with
--! the KCU104 and Ospero OP47 boards.
--!
--! @details
--! The FPGA bit file produced allows a host computer to access a NVMe storage device
--! connected to the FPGA via the hosts PCIe interface. It has a simple test data source
--! and allows a host computer program to communicate with the NVMe device for research
--! and development test work.
--! See the DuneNvmeStorageManual for more details.
--! 
--!
--! @copyright GNU GPL License
--! Copyright (c) Beam Ltd, All rights reserved. <br>
--! This code is free software: you can redistribute it and/or modify
--! it under the terms of the GNU General Public License as published by
--! the Free Software Foundation, either version 3 of the License, or
--! (at your option) any later version.
--! This program is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--! GNU General Public License for more details. <br>
--! You should have received a copy of the GNU General Public License
--! along with this code. If not, see <https://www.gnu.org/licenses/>.
--!
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.NvmeStoragePkg.all;

entity DuneNvmeTestOsperoTop is
generic(
	Simulate	: boolean	:= False
);
port (
	sys_clk_p	: in std_logic;
	sys_clk_n	: in std_logic;
	sys_reset	: in std_logic;

	pci_clk_p	: in std_logic;
	pci_clk_n	: in std_logic;
	pci_reset_n	: in std_logic;
	
	pci_exp_txp	: out std_logic_vector(3 downto 0);
	pci_exp_txn	: out std_logic_vector(3 downto 0);
	pci_exp_rxp	: in std_logic_vector(3 downto 0);
	pci_exp_rxn	: in std_logic_vector(3 downto 0);

	nvme0_clk_p	: in std_logic;
	nvme0_clk_n	: in std_logic;
	nvme0_reset	: out std_logic;

	nvme0_exp_txp	: out std_logic_vector(3 downto 0);
	nvme0_exp_txn	: out std_logic_vector(3 downto 0);
	nvme0_exp_rxp	: in std_logic_vector(3 downto 0);
	nvme0_exp_rxn	: in std_logic_vector(3 downto 0);

	nvme1_clk_p	: in std_logic;
	nvme1_clk_n	: in std_logic;
	nvme1_reset	: out std_logic;

	nvme1_exp_txp	: out std_logic_vector(3 downto 0);
	nvme1_exp_txn	: out std_logic_vector(3 downto 0);
	nvme1_exp_rxp	: in std_logic_vector(3 downto 0);
	nvme1_exp_rxn	: in std_logic_vector(3 downto 0);

	leds		: out std_logic_vector(7 downto 0)
);
end;

architecture Behavioral of DuneNvmeTestOsperoTop is

component Clk_core is                   
port (
	clk_in1_p	: in std_logic; 
	clk_in1_n	: in std_logic;
	clk_out1	: out std_logic;
	locked		: out std_logic
);                                     
end component;                 

--! @class	Pcie_host
--! @brief	The Xilinx PCIe XDMA endpoint for host communications with the FPGA
--! @details	See the Xilinx documentation for details of this IP block
component Pcie_host
port (
	sys_clk : in std_logic;
	sys_clk_gt : in std_logic;
	sys_rst_n : in std_logic;
	user_lnk_up : out std_logic;
	pci_exp_txp : out std_logic_vector(3 downto 0);
	pci_exp_txn : out std_logic_vector(3 downto 0);
	pci_exp_rxp : in std_logic_vector(3 downto 0);
	pci_exp_rxn : in std_logic_vector(3 downto 0);
	axi_aclk : out std_logic;
	axi_aresetn : out std_logic;
	usr_irq_req : in std_logic_vector(0 downto 0);
	usr_irq_ack : out std_logic_vector(0 downto 0);
	msi_enable : out std_logic;
	msi_vector_width : out std_logic_vector(2 downto 0);
	m_axil_awaddr : out std_logic_vector(31 downto 0);
	m_axil_awprot : out std_logic_vector(2 downto 0);
	m_axil_awvalid : out std_logic;
	m_axil_awready : in std_logic;
	m_axil_wdata : out std_logic_vector(31 downto 0);
	m_axil_wstrb : out std_logic_vector(3 downto 0);
	m_axil_wvalid : out std_logic;
	m_axil_wready : in std_logic;
	m_axil_bvalid : in std_logic;
	m_axil_bresp : in std_logic_vector(1 downto 0);
	m_axil_bready : out std_logic;
	m_axil_araddr : out std_logic_vector(31 downto 0);
	m_axil_arprot : out std_logic_vector(2 downto 0);
	m_axil_arvalid : out std_logic;
	m_axil_arready : in std_logic;
	m_axil_rdata : in std_logic_vector(31 downto 0);
	m_axil_rresp : in std_logic_vector(1 downto 0);
	m_axil_rvalid : in std_logic;
	m_axil_rready : out std_logic;
	cfg_mgmt_addr : in std_logic_vector(18 downto 0);
	cfg_mgmt_write : in std_logic;
	cfg_mgmt_write_data : in std_logic_vector(31 downto 0);
	cfg_mgmt_byte_enable : in std_logic_vector(3 downto 0);
	cfg_mgmt_read : in std_logic;
	cfg_mgmt_read_data : out std_logic_vector(31 downto 0);
	cfg_mgmt_read_write_done : out std_logic;
	cfg_mgmt_type1_cfg_reg_access : in std_logic;
	s_axis_c2h_tdata_0 : in std_logic_vector(127 downto 0);
	s_axis_c2h_tlast_0 : in std_logic;
	s_axis_c2h_tvalid_0 : in std_logic;
	s_axis_c2h_tready_0 : out std_logic;
	s_axis_c2h_tkeep_0 : in std_logic_vector(15 downto 0);
	m_axis_h2c_tdata_0 : out std_logic_vector(127 downto 0);
	m_axis_h2c_tlast_0 : out std_logic;
	m_axis_h2c_tvalid_0 : out std_logic;
	m_axis_h2c_tready_0 : in std_logic;
	m_axis_h2c_tkeep_0 : out std_logic_vector(15 downto 0);

	int_qpll1lock_out : out std_logic_vector(0 to 0);
	int_qpll1outrefclk_out : out std_logic_vector(0 to 0);
	int_qpll1outclk_out : out std_logic_vector(0 to 0)
);
end component;

-- Clock and controls
signal sys_clk			: std_logic := 'U';

signal pci_clk			: std_logic := 'U';
signal pci_clk_gt		: std_logic := 'U';
signal nvme0_clk		: std_logic := 'U';
signal nvme0_clk_gt		: std_logic := 'U';
signal nvme0_reset_n		: std_logic := 'U';
signal nvme1_clk		: std_logic := 'U';
signal nvme1_clk_gt		: std_logic := 'U';
signal nvme1_reset_n		: std_logic := 'U';

signal leds_l			: std_logic_vector(7 downto 0) := (others => '0');

signal axil_clk			: std_logic;
signal axil_reset_n		: std_logic;
signal axil_reset		: std_logic;

signal axil			: AxilBusType;			--! The AXI lite bus
signal hostSend			: AxisType;			--! AXI stream to send requests from the host
signal hostSend_ready		: std_logic;
signal hostRecv			: AxisType;			--! AXI stream for replies to the host
signal hostrecv_ready		: std_logic;
signal dataStream		: AxisDataStreamType;		--! AXI stream for test data
signal dataStream_ready		: std_logic;
signal dataEnabled		: std_logic;			--! Enabled signal for test data

begin
	-- System clock just used for a boot reset if needed
	sys_clk_buf : Clk_core port map (
		clk_in1_p	=> sys_clk_p,
		clk_in1_n	=> sys_clk_n,
		clk_out1	=> sys_clk
	);

	-- PCIE Clock, 100MHz
	pci_clk_buf0 : IBUFDS_GTE3 port map (
		I       => pci_clk_p,
		IB      => pci_clk_n,
		O       => pci_clk_gt,
		ODIV2   => pci_clk,
		CEB     => '0'
	);
	
	-- NVME0 PCIE Clock, 100MHz.
	nvme_clk_buf0 : IBUFDS_GTE3 port map (
		I       => nvme0_clk_p,
		IB      => nvme0_clk_n,
		O       => nvme0_clk_gt,
		ODIV2   => nvme0_clk,
		CEB     => '0'
	);
	
	-- NVME1 PCIE Clock, 100MHz.
	nvme_clk_buf1 : IBUFDS_GTE3 port map (
		I       => nvme1_clk_p,
		IB      => nvme1_clk_n,
		O       => nvme1_clk_gt,
		ODIV2   => nvme1_clk,
		CEB     => '0'
	);

	nvme0_reset <= not nvme0_reset_n;
	nvme1_reset <= not nvme1_reset_n;
	
	-- The PCIe interface to the host
	pcie_host0 : Pcie_host
	port map (
		sys_clk			=> pci_clk,
		sys_clk_gt		=> pci_clk_gt,
		sys_rst_n		=> pci_reset_n,
		pci_exp_txp		=> pci_exp_txp,
		pci_exp_txn		=> pci_exp_txn,
		pci_exp_rxp		=> pci_exp_rxp,
		pci_exp_rxn		=> pci_exp_rxn,
		
		user_lnk_up		=> leds_l(7),

		usr_irq_req		=> (others => '0'),
		--usr_irq_ack		=> usr_irq_ack,
		--msi_enable		=> msi_enable,
		--msi_vector_width	=> msi_vector_width,

		axi_aclk		=> axil_clk,
		axi_aresetn		=> axil_reset_n,

		m_axil_awaddr		=> axil.toSlave.awaddr,
		m_axil_awprot		=> axil.toSlave.awprot,
		m_axil_awvalid		=> axil.toSlave.awvalid,
		m_axil_awready		=> axil.toMaster.awready,
		m_axil_wdata		=> axil.toSlave.wdata,
		m_axil_wstrb		=> axil.toSlave.wstrb,
		m_axil_wvalid		=> axil.toSlave.wvalid,
		m_axil_wready		=> axil.toMaster.wready,
		m_axil_bvalid		=> axil.toMaster.bvalid,
		m_axil_bresp		=> axil.toMaster.bresp,
		m_axil_bready		=> axil.toSlave.bready,
		m_axil_araddr		=> axil.toSlave.araddr,
		m_axil_arprot		=> axil.toSlave.arprot,
		m_axil_arvalid		=> axil.toSlave.arvalid,
		m_axil_arready		=> axil.toMaster.arready,
		m_axil_rdata		=> axil.toMaster.rdata,
		m_axil_rresp		=> axil.toMaster.rresp,
		m_axil_rvalid		=> axil.toMaster.rvalid,
		m_axil_rready		=> axil.toSlave.rready,
		
		cfg_mgmt_addr		=> (others => '0'),
		cfg_mgmt_write		=> '0',
		cfg_mgmt_write_data	=> (others => '0'),
		cfg_mgmt_byte_enable	=> (others => '0'),
		cfg_mgmt_read		=> '0',
		--cfg_mgmt_read_data		=> cfg_mgmt_read_data,
		--cfg_mgmt_read_write_done	=> cfg_mgmt_read_write_done,
		cfg_mgmt_type1_cfg_reg_access	=> '0',

		s_axis_c2h_tdata_0	=> hostRecv.data,
		s_axis_c2h_tlast_0	=> hostRecv.last,
		s_axis_c2h_tvalid_0	=> hostRecv.valid,
		s_axis_c2h_tready_0	=> hostRecv_ready,
		s_axis_c2h_tkeep_0	=> hostRecv.keep,

		m_axis_h2c_tdata_0	=> hostSend.data,
		m_axis_h2c_tlast_0	=> hostSend.last,
		m_axis_h2c_tvalid_0	=> hostSend.valid,
		m_axis_h2c_tready_0	=> hostSend_ready,
		m_axis_h2c_tkeep_0	=> hostSend.keep
	);

	-- NVME Storage interface
	axil_reset <= not axil_reset_n;
	
	nvmeStorage0 : NvmeStorage
	generic map (
		Simulate	=> False,			--! Generate simulation core
		Platform	=> "Ultrascale",		--! The underlying target platform
		ClockPeriod	=> 4 ns,			--! Clock period for timers (250 MHz)
		BlockSize	=> NvmeStorageBlockSize,	--! System block size
		NumBlocksDrop	=> 2,				--! The number of blocks to drop at a time
		UseConfigure	=> False,			--! The module configures the Nvme's on reset
		NvmeBlockSize	=> 512,				--! The NVMe's formatted block size
		NvmeTotalBlocks	=> 104857600,			--! The total number of 4k blocks available (400G)
		NvmeRegStride	=> 4				--! The doorbell register stride
	)
	port map (
		clk		=> axil_clk,
		reset		=> axil_reset,

		-- Control and status interface
		axilIn		=> axil.toSlave,
		axilOut		=> axil.toMaster,

		-- From host to NVMe request/reply streams
		hostSend	=> hostSend,
		hostSend_ready	=> hostSend_ready,
		hostRecv	=> hostRecv,
		hostRecv_ready	=> hostRecv_ready,

		-- AXIS data stream input
		dataDropBlocks	=> '0',
		dataEnabledOut	=> dataEnabled,
		dataIn		=> dataStream,
		dataIn_ready	=> dataStream_ready,

		-- NVMe interface
		nvme0_clk	=> nvme0_clk,
		nvme0_clk_gt	=> nvme0_clk_gt,
		nvme0_reset_n	=> nvme0_reset_n,
		nvme0_exp_txp	=> nvme0_exp_txp,
		nvme0_exp_txn	=> nvme0_exp_txn,
		nvme0_exp_rxp	=> nvme0_exp_rxp,
		nvme0_exp_rxn	=> nvme0_exp_rxn,

		nvme1_clk	=> nvme1_clk,
		nvme1_clk_gt	=> nvme1_clk_gt,
		nvme1_reset_n	=> nvme1_reset_n,
		nvme1_exp_txp	=> nvme1_exp_txp,
		nvme1_exp_txn	=> nvme1_exp_txn,
		nvme1_exp_rxp	=> nvme1_exp_rxp,
		nvme1_exp_rxn	=> nvme1_exp_rxn,

		-- Debug
		leds		=> leds_l(5 downto 0)
	);

	-- The test data interface
	testData0 : TestData
	port map (
		clk		=> axil_clk,
		reset		=> axil_reset,

		enable		=> dataEnabled,

		dataOut		=> dataStream,
		dataOutReady	=> dataStream_ready
	);

	-- Led buffers
	obuf_leds: for i in 0 to 7 generate
		obuf_led_i: OBUF port map (I => leds_l(i), O => leds(i));
	end generate;

	leds_l(6) <= '0';
end;

