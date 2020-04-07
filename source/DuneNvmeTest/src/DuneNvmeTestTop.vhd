--------------------------------------------------------------------------------
--	DuneNvmeTestTop.vhd Simple NVMe access test system
--	T.Barnaby, Beam Ltd. 2020-02-18
--------------------------------------------------------------------------------
--!
--! @class	DuneNvmeTestTop
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-02-18
--! @version	0.0.1
--!
--! @brief
--! This FPGA bit file allows a host computer to access a NVMe storage device
--!  connected to the FPGA via the hosts PCIe interface. It allows a host computer
--!  program to communicate with the NVMe device for research and developemnt test work.
--!
--! @details
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
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.AxiPkg.all;

entity DuneNvmeTestTop is
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

	nvme_clk_p	: in std_logic;
	nvme_clk_n	: in std_logic;
	nvme_reset_n	: out std_logic;
	nvme0_exp_txp	: out std_logic_vector(3 downto 0);
	nvme0_exp_txn	: out std_logic_vector(3 downto 0);
	nvme0_exp_rxp	: in std_logic_vector(3 downto 0);
	nvme0_exp_rxn	: in std_logic_vector(3 downto 0);

	leds		: out std_logic_vector(7 downto 0)
);
end;

architecture Behavioral of DuneNvmeTestTop is

component Clk_core is                   
	port (
		clk_in1_p	: in std_logic; 
		clk_in1_n	: in std_logic;
		clk_out1	: out std_logic
	);                                     
end component;                 

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

	s_axis_c2h_tdata_1 : in std_logic_vector(127 downto 0);
	s_axis_c2h_tlast_1 : in std_logic;
	s_axis_c2h_tvalid_1 : in std_logic;
	s_axis_c2h_tready_1 : out std_logic;
	s_axis_c2h_tkeep_1 : in std_logic_vector(15 downto 0);
	m_axis_h2c_tdata_1 : out std_logic_vector(127 downto 0);
	m_axis_h2c_tlast_1 : out std_logic;
	m_axis_h2c_tvalid_1 : out std_logic;
	m_axis_h2c_tready_1 : in std_logic;
	m_axis_h2c_tkeep_1 : out std_logic_vector(15 downto 0)

	);
end component;

component blk_mem_gen_0
	port (
	rsta_busy : out std_logic;
	rstb_busy : out std_logic;
	s_aclk : in std_logic;
	s_aresetn : in std_logic;
	s_axi_awaddr : in std_logic_vector(31 downto 0);
	s_axi_awvalid : in std_logic;
	s_axi_awready : out std_logic;
	s_axi_wdata : in std_logic_vector(31 downto 0);
	s_axi_wstrb : in std_logic_vector(3 downto 0);
	s_axi_wvalid : in std_logic;
	s_axi_wready : out std_logic;
	s_axi_bresp : out std_logic_vector(1 downto 0);
	s_axi_bvalid : out std_logic;
	s_axi_bready : in std_logic;
	s_axi_araddr : in std_logic_vector(31 downto 0);
	s_axi_arvalid : in std_logic;
	s_axi_arready : out std_logic;
	s_axi_rdata : out std_logic_vector(31 downto 0);
	s_axi_rresp : out std_logic_vector(1 downto 0);
	s_axi_rvalid : out std_logic;
	s_axi_rready : in std_logic
	);
end component;

component NvmeStorage is
generic(
	Simulate	: boolean	:= False
);
port (
	clk		: in std_logic;
	reset		: in std_logic;

	-- Control and status interface
	axilIn		: in AxilToSlave;
	axilOut		: out AxilToMaster;

	-- From host to NVMe request/reply streams
	hostReq		: inout AxisStream	:= AxisInput;
	hostReply	: inout AxisStream	:= AxisOutput;                        
	
	-- From Nvme to host request/reply streams
	nvmeReq		: inout AxisStream	:= AxisOutput;
	nvmeReply	: inout AxisStream	:= AxisInput;                        
	
	-- AXIS data stream input
	--dataRx	: inout AxisStream	:= AxisInput;
	
	-- NVMe interface
	nvme_clk_p	: in std_logic;
	nvme_clk_n	: in std_logic;
	nvme_reset_n	: out std_logic;
	nvme0_exp_txp	: out std_logic_vector(3 downto 0);
	nvme0_exp_txn	: out std_logic_vector(3 downto 0);
	nvme0_exp_rxp	: in std_logic_vector(3 downto 0);
	nvme0_exp_rxn	: in std_logic_vector(3 downto 0);

	-- Debug
	leds		: out std_logic_vector(3 downto 0)
);
end component;

-- Clock and controls
signal sys_clk			: std_logic := 'U';
signal sys_reset_buf_n		: std_logic := 'U';

signal pci_clk			: std_logic := 'U';
signal pci_clk_gt		: std_logic := 'U';
signal leds_l			: std_logic_vector(7 downto 0) := (others => '0');

signal reset_n			: std_logic := '0';
signal boot_reset		: std_logic := '1';
constant boot_reset_count	: natural := 2000000;	-- 10ms

signal axil_clk			: std_logic;
signal axil_reset_n		: std_logic;
signal axil_reset		: std_logic;

--signal usr_irq_req		: std_logic;
--signal usr_irq_ack		: std_logic;
--signal msi_enable		: std_logic;
--signal msi_vector_width	: std_logic;

signal axil			: AxilBus;
signal hostReq			: AxisStream;
signal hostReply		: AxisStream;
signal nvmeReq			: AxisStream;
signal nvmeReply		: AxisStream;

begin
	-- System clock just used for a boot reset
	sys_clk_buf : Clk_core port map (
		clk_in1_p	=> sys_clk_p,
		clk_in1_n	=> sys_clk_n,
		clk_out1	=> sys_clk
	);

	reset_n <= not (sys_reset or not pci_reset_n or boot_reset);
	--reset_n <= not (sys_reset or not pci_reset_n);

	sys_reset_buf : BUFG port map (
		I		=> reset_n,
		O		=> sys_reset_buf_n
	);


	-- PCIE Clock, 100MHz
	pci_clk_buf0 : IBUFDS_GTE3 port map(
		I       => pci_clk_p,
		IB      => pci_clk_n,
		O       => pci_clk_gt,
		ODIV2   => pci_clk,
		CEB     => '0'
	);
	
	-- Boot Reset from power up
	process(sys_clk, boot_reset)
		variable count : natural range 0 to boot_reset_count;
	begin
		if(rising_edge(sys_clk)) then
			if(boot_reset = '1') then
				if(count >= boot_reset_count) then
					boot_reset	<= '0';
					count		:= 0;
				else
					count		:= count + 1;
				end if;
			end if;
		end if;
	end process; 

	-- The PCIe interface to the host
	pcie_host0 : Pcie_host
	port map (
		sys_clk			=> pci_clk,
		sys_clk_gt		=> pci_clk_gt,
		sys_rst_n		=> sys_reset_buf_n,
		pci_exp_txp		=> pci_exp_txp,
		pci_exp_txn		=> pci_exp_txn,
		pci_exp_rxp		=> pci_exp_rxp,
		pci_exp_rxn		=> pci_exp_rxn,
		
		user_lnk_up		=> leds_l(7),

		usr_irq_req		=> (others		=> '0'),
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

		s_axis_c2h_tdata_0	=> hostReply.data,
		s_axis_c2h_tlast_0	=> hostReply.last,
		s_axis_c2h_tvalid_0	=> hostReply.valid,
		s_axis_c2h_tready_0	=> hostReply.ready,
		s_axis_c2h_tkeep_0	=> hostReply.keep,
		m_axis_h2c_tdata_0	=> hostReq.data,
		m_axis_h2c_tlast_0	=> hostReq.last,
		m_axis_h2c_tvalid_0	=> hostReq.valid,
		m_axis_h2c_tready_0	=> hostReq.ready,
		m_axis_h2c_tkeep_0	=> hostReq.keep,

		s_axis_c2h_tdata_1	=> nvmeReq.data,
		s_axis_c2h_tlast_1	=> nvmeReq.last,
		s_axis_c2h_tvalid_1	=> nvmeReq.valid,
		s_axis_c2h_tready_1	=> nvmeReq.ready,
		s_axis_c2h_tkeep_1	=> nvmeReq.keep,
		m_axis_h2c_tdata_1	=> nvmeReply.data,
		m_axis_h2c_tlast_1	=> nvmeReply.last,
		m_axis_h2c_tvalid_1	=> nvmeReply.valid,
		m_axis_h2c_tready_1	=> nvmeReply.ready,
		m_axis_h2c_tkeep_1	=> nvmeReply.keep
	);

	zap10: if false generate
	-- Echo back AXI streaming ports
	hostReply.valid	<= hostReq.valid;   
	hostReply.last	<= hostReq.last;   
	hostReply.keep	<= hostReq.keep;   
	hostReply.data	<= hostReq.data;  
	hostReq.ready	<= hostReply.ready;

	nvmeReply.valid	<= nvmeReq.valid;   
	nvmeReply.last	<= nvmeReq.last;   
	nvmeReply.keep	<= nvmeReq.keep;   
	nvmeReply.data	<= nvmeReq.data;  
	nvmeReq.ready	<= nvmeReply.ready;
	end generate;

	zap11: if false generate
	-- Test Axil bus interface using blockram write/read accesses
	bram0 : blk_mem_gen_0
	port map (
		--rsta_busy		=> rsta_busy,
		--rstb_busy		=> rstb_busy,
		s_aclk			=> axil_clk,
		s_aresetn		=> axil_reset_n,
		
		s_axi_awaddr		=> axil.toSlave.awaddr,
		s_axi_awvalid		=> axil.toSlave.awvalid,
		s_axi_awready		=> axil.toMaster.awready,
		s_axi_wdata		=> axil.toSlave.wdata,
		s_axi_wstrb		=> axil.toSlave.wstrb,
		s_axi_wvalid		=> axil.toSlave.wvalid,
		s_axi_wready		=> axil.toMaster.wready,
		s_axi_bresp		=> axil.toMaster.bresp,
		s_axi_bvalid		=> axil.toMaster.bvalid,
		s_axi_bready		=> axil.toSlave.bready,
		s_axi_araddr		=> axil.toSlave.araddr,
		s_axi_arvalid		=> axil.toSlave.arvalid,
		s_axi_arready		=> axil.toMaster.arready,
		s_axi_rdata		=> axil.toMaster.rdata,
		s_axi_rresp		=> axil.toMaster.rresp,
		s_axi_rvalid		=> axil.toMaster.rvalid,
		s_axi_rready		=> axil.toSlave.rready
	);	
	end generate;
	
	zap13: if true generate
	-- NVME Storage interface
	axil_reset <= not axil_reset_n;
	
	nvmeStorage0 : NvmeStorage
	port map (
		clk		=> axil_clk,
		reset		=> axil_reset,

		-- Control and status interface
		axilIn		=> axil.toSlave,
		axilOut		=> axil.toMaster,

		-- AXIS Interface to PCIE
		hostReply	=> hostReply,
		hostReq		=> hostReq,

		-- From Nvme reqeuest and reply stream
		nvmeReq		=> nvmeReq,
		nvmeReply	=> nvmeReply,

		-- AXIS data stream input
		--dataRx	=> dataRx,

		-- NVMe interface
		nvme_clk_p	=> nvme_clk_p,
		nvme_clk_n	=> nvme_clk_n,
		nvme_reset_n	=> nvme_reset_n,
		nvme0_exp_txp	=> nvme0_exp_txp,
		nvme0_exp_txn	=> nvme0_exp_txn,
		nvme0_exp_rxp	=> nvme0_exp_rxp,
		nvme0_exp_rxn	=> nvme0_exp_rxn,

		-- Debug
		leds		=> leds_l(3 downto 0)
	);
	end generate;

	-- Led buffers
	obuf_leds: for i in 0 to 7 generate
		obuf_led_i: OBUF port map (I => leds_l(i), O => leds(i));
	end generate;

	leds_l(4) <= sys_reset_buf_n;
end;

