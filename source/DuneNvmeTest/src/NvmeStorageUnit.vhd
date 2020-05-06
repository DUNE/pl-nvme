--------------------------------------------------------------------------------
--	NvmeStorageUnit.vhd Nvme storage access module
--	T.Barnaby, Beam Ltd. 2020-02-28
-------------------------------------------------------------------------------
--!
--! @class	NvmeStorageUnit
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-02-28
--! @version	0.0.1
--!
--! @brief
--! This is the main Nvme control module.
--!
--! @details
--! Communication is performed over an AXI lite bus and AXI request and reply streams.
--! The AXI lite bus interface provides access to high level control and status registers.
--! The AXI streams allow communication with the Nvme storage device itself.
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
use work.NvmeStorageIntPkg.all;

entity NvmeStorageUnit is
generic(
	Simulate	: boolean	:= False;		--! Generate simulation core
	ClockPeriod	: time		:= 8 ns;		--! Clock period for timers (125 MHz)
	BlockSize	: integer	:= NvmeStorageBlockSize	--! System block size
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	axilIn		: in AxilToSlaveType;			--! Axil bus input signals
	axilOut		: out AxilToMasterType;			--! Axil bus output signals

	-- From host to NVMe request/reply streams
	hostSend	: inout AxisStreamType := AxisInput;	--! Host request stream
	hostRecv	: inout AxisStreamType := AxisOutput;	--! Host reply stream

	-- AXIS data stream input
	dataEnabledOut	: out std_logic;			--! Indicates that data ingest is enabled
	dataIn		: inout AxisStreamType := AxisInput;	--! Raw data to save stream

	-- NVMe interface
	nvme_clk_p	: in std_logic;				--! Nvme external clock +ve
	nvme_clk_n	: in std_logic;				--! Nvme external clock -ve
	nvme_reset_n	: out std_logic;			--! Nvme reset output to reset NVMe devices
	nvme_exp_txp	: out std_logic_vector(3 downto 0);	--! nvme PCIe TX plus lanes
	nvme_exp_txn	: out std_logic_vector(3 downto 0);	--! nvme PCIe TX minus lanes
	nvme_exp_rxp	: in std_logic_vector(3 downto 0);	--! nvme PCIe RX plus lanes
	nvme_exp_rxn	: in std_logic_vector(3 downto 0);	--! nvme PCIe RX minus lanes

	-- Debug
	leds		: out std_logic_vector(3 downto 0)
);
end;

architecture Behavioral of NvmeStorageUnit is

constant TCQ		: time := 1 ns;
constant NumStreams	: integer := 8;
constant ResetCycles	: integer := (100 ms / ClockPeriod);

component AxilClockConverter is
generic(
	Simulate	: boolean	:= Simulate
);
port (
	clk0		: in std_logic;
	reset0		: in std_logic;

	-- Bus0
	axil0In		: in AxilToSlaveType;
	axil0Out	: out AxilToMasterType;

	clk1		: in std_logic;
	reset1		: in std_logic;

	-- Bus1
	axil1Out	: out AxilToSlaveType;
	axil1In		: in AxilToMasterType
);
end component;

component AxisClockConverter is
generic(
	Simulate	: boolean	:= Simulate
);
port (
	clkRx		: in std_logic;
	resetRx		: in std_logic;
	streamRx	: inout AxisStreamType := AxisInput;                        

	clkTx		: in std_logic;
	resetTx		: in std_logic;
	streamTx	: inout AxisStreamType := AxisOutput
);
end component;

component Pcie_nvme0
	port (
	pci_exp_txn : out std_logic_vector(3 downto 0);
	pci_exp_txp : out std_logic_vector(3 downto 0);
	pci_exp_rxn : in std_logic_vector(3 downto 0);
	pci_exp_rxp : in std_logic_vector(3 downto 0);
	user_clk : out std_logic;
	user_reset : out std_logic;
	user_lnk_up : out std_logic;
	s_axis_rq_tdata : in std_logic_vector(127 downto 0);
	s_axis_rq_tkeep : in std_logic_vector(3 downto 0);
	s_axis_rq_tlast : in std_logic;
	s_axis_rq_tready : out std_logic_vector(3 downto 0);
	s_axis_rq_tuser : in std_logic_vector(59 downto 0);
	s_axis_rq_tvalid : in std_logic;
	
	m_axis_rc_tdata : out std_logic_vector(127 downto 0);
	m_axis_rc_tkeep : out std_logic_vector(3 downto 0);
	m_axis_rc_tlast : out std_logic;
	m_axis_rc_tready : in std_logic;
	m_axis_rc_tuser : out std_logic_vector(74 downto 0);
	m_axis_rc_tvalid : out std_logic;
	
	m_axis_cq_tdata : out std_logic_vector(127 downto 0);
	m_axis_cq_tkeep : out std_logic_vector(3 downto 0);
	m_axis_cq_tlast : out std_logic;
	m_axis_cq_tready : in std_logic;
	m_axis_cq_tuser : out std_logic_vector(84 downto 0);
	m_axis_cq_tvalid : out std_logic;
	
	s_axis_cc_tdata : in std_logic_vector(127 downto 0);
	s_axis_cc_tkeep : in std_logic_vector(3 downto 0);
	s_axis_cc_tlast : in std_logic;
	s_axis_cc_tready : out std_logic_vector(3 downto 0);
	s_axis_cc_tuser : in std_logic_vector(32 downto 0);
	s_axis_cc_tvalid : in std_logic;
	pcie_rq_seq_num : out std_logic_vector(3 downto 0);
	pcie_rq_seq_num_vld : out std_logic;
	pcie_rq_tag : out std_logic_vector(5 downto 0);
	pcie_rq_tag_av : out std_logic_vector(1 downto 0);
	pcie_rq_tag_vld : out std_logic;
	pcie_tfc_nph_av : out std_logic_vector(1 downto 0);
	pcie_tfc_npd_av : out std_logic_vector(1 downto 0);
	pcie_cq_np_req : in std_logic;
	pcie_cq_np_req_count : out std_logic_vector(5 downto 0);

	cfg_phy_link_down : out std_logic;
	cfg_phy_link_status : out std_logic_vector(1 downto 0);
	cfg_negotiated_width : out std_logic_vector(3 downto 0);
	cfg_current_speed : out std_logic_vector(2 downto 0);
	cfg_max_payload : out std_logic_vector(2 downto 0);
	cfg_max_read_req : out std_logic_vector(2 downto 0);
	cfg_function_status : out std_logic_vector(15 downto 0);
	cfg_function_power_state : out std_logic_vector(11 downto 0);
	cfg_vf_status : out std_logic_vector(15 downto 0);
	cfg_vf_power_state : out std_logic_vector(23 downto 0);
	cfg_link_power_state : out std_logic_vector(1 downto 0);

	cfg_mgmt_addr : in std_logic_vector(18 downto 0);
	cfg_mgmt_write : in std_logic;
	cfg_mgmt_write_data : in std_logic_vector(31 downto 0);
	cfg_mgmt_byte_enable : in std_logic_vector(3 downto 0);
	cfg_mgmt_read : in std_logic;
	cfg_mgmt_read_data : out std_logic_vector(31 downto 0);
	cfg_mgmt_read_write_done : out std_logic;
	cfg_mgmt_type1_cfg_reg_access : in std_logic;

	cfg_err_cor_out : out std_logic;
	cfg_err_nonfatal_out : out std_logic;
	cfg_err_fatal_out : out std_logic;
	cfg_ltr_enable : out std_logic;
	cfg_ltssm_state : out std_logic_vector(5 downto 0);
	cfg_rcb_status : out std_logic_vector(3 downto 0);
	cfg_dpa_substate_change : out std_logic_vector(3 downto 0);
	cfg_obff_enable : out std_logic_vector(1 downto 0);
	cfg_pl_status_change : out std_logic;
	cfg_tph_requester_enable : out std_logic_vector(3 downto 0);
	cfg_tph_st_mode : out std_logic_vector(11 downto 0);
	cfg_vf_tph_requester_enable : out std_logic_vector(7 downto 0);
	cfg_vf_tph_st_mode : out std_logic_vector(23 downto 0);
	cfg_fc_ph : out std_logic_vector(7 downto 0);
	cfg_fc_pd : out std_logic_vector(11 downto 0);
	cfg_fc_nph : out std_logic_vector(7 downto 0);
	cfg_fc_npd : out std_logic_vector(11 downto 0);
	cfg_fc_cplh : out std_logic_vector(7 downto 0);
	cfg_fc_cpld : out std_logic_vector(11 downto 0);
	cfg_fc_sel : in std_logic_vector(2 downto 0);

	cfg_interrupt_int : in std_logic_vector(3 downto 0);
	cfg_interrupt_pending : in std_logic_vector(3 downto 0);
	cfg_interrupt_sent : out std_logic;

	sys_clk : in std_logic;
	sys_clk_gt : in std_logic;
	sys_reset : in std_logic;
	phy_rdy_out : out std_logic
	);
end component;

component NvmeConfig is
generic(
	ClockPeriod	: time := ClockPeriod			--! Clock period for timers (125 MHz)
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	configStart	: in std_logic;				--! Start the initialisation (1 clk cycle only)
	configComplete	: out std_logic;			--! Initialisation is complete

	-- From host to NVMe request/reply streams
	streamOut	: inout AxisStreamType := AxisOutput;	--! Nvme request stream
	streamIn	: inout AxisStreamType := AxisInput	--! Nvme reply stream
);
end component;

component NvmeQueues is
generic(
	NumQueueEntries	: integer	:= 8;			--! The number of entries per queue
	Simulate	: boolean	:= False
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisStreamType := AxisInput;	--! Request queue entries
	streamOut	: inout AxisStreamType := AxisOutput	--! replies and requests
);
end component;

component NvmeStreamMux is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	stream1In	: inout AxisStreamType := AxisInput;	--! Single multiplexed Input stream
	stream1Out	: inout AxisStreamType := AxisOutput;	--! Single multiplexed Ouput stream

	stream2Out	: inout AxisStreamType := AxisOutput;	--! Host Requests output stream
	stream2In	: inout AxisStreamType := AxisInput;	--! Host Replies input stream

	stream3In	: inout AxisStreamType := AxisInput;	--! Nvme Requests input stream
	stream3Out	: inout AxisStreamType := AxisOutput	--! Nvme replies output stream
);
end component;

component NvmeSim is
generic(
	Simulate	: boolean := True;
	BlockSize	: integer := BlockSize			--! System block size
);
port (
	clk		: in std_logic;
	reset		: in std_logic;

	-- AXIS Interface to PCIE
	hostReq		: inout AxisStreamType := AxisInput;
	hostReply	: inout AxisStreamType := AxisOutput;                        
	
	-- From Nvme reqeuest and reply stream
	nvmeReq		: inout AxisStreamType := AxisOutput;
	nvmeReply	: inout AxisStreamType := AxisInput
);
end component;

component StreamSwitch is
generic(
	NumStreams	: integer	:= NumStreams		--! The number of stream
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisArrayType(0 to NumStreams-1) := (others => AxisInput);	--! Input stream
	streamOut	: inout AxisArrayType(0 to NumStreams-1) := (others => AxisOutput)	--! Output stream
);
end component;

component NvmeWrite is
generic(
	Simulate	: boolean := Simulate;			--! Generate simulation core
	BlockSize	: integer := BlockSize			--! System block size
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	enable		: in std_logic;				--! Enable the data writing process
	dataIn		: inout AxisStreamType := AxisInput;	--! Raw data to save stream

	-- To Nvme Request/reply streams
	requestOut	: inout AxisStreamType := AxisOutput;	--! To Nvme request stream (3)
	replyIn		: inout AxisStreamType := AxisInput;	--! from Nvme reply stream

	-- From Nvme Request/reply streams
	memReqIn	: inout AxisStreamType := AxisInput;	--! From Nvme request stream (4)
	memReplyOut	: inout AxisStreamType := AxisOutput;	--! To Nvme reply stream
	
	regAddress	: in unsigned(1 downto 0);		--! Status register to read
	regData		: out std_logic_vector(31 downto 0)	--! Status register contents
);
end component;

signal reset_local_run		: std_logic := '0';
signal reset_local_done		: std_logic := '0';
signal reset_local_active	: std_logic := '0';
signal reset_local_counter	: integer range 0 to ResetCycles := 0;
signal reset_local		: std_logic := '0';
signal axil1Out			: AxilToMasterType;
signal axil1In			: AxilToSlaveType;

-- Streams
signal streamSend		: AxisArrayType(0 to NumStreams-1);
signal streamRecv		: AxisArrayType(0 to NumStreams-1);

alias nvmeSend			is streamSend(0);
alias nvmeRecv			is streamRecv(0);
alias hostSend1			is streamSend(1);
alias hostRecv1			is streamRecv(1);
alias queueSend			is streamSend(2);
alias queueRecv			is streamRecv(2);
alias configSend		is streamSend(3);
alias configRecv		is streamRecv(3);
alias writeSend			is streamSend(4);
alias writeRecv			is streamRecv(4);
alias writeMemSend		is streamSend(5);
alias writeMemRecv		is streamRecv(5);

signal dataIn1			: AxisStreamType;
signal streamNone		: AxisStreamType := AxisOutput;
signal streamSink		: AxisStreamType := AxisSink;

-- Nvme PCIe interface
signal hostReq			: AxisStreamType;
signal hostReq_ready		: std_logic_vector(3 downto 0);
signal hostReq_morethan1	: std_logic;
signal hostReq_user		: std_logic_vector(59 downto 0);
signal hostReq_keep		: std_logic_vector(3 downto 0);

signal hostReply		: AxisStreamType;
signal hostReply_keep		: std_logic_vector(3 downto 0);

signal nvmeReq			: AxisStreamType;
signal nvmeReq_keep		: std_logic_vector(3 downto 0);

signal nvmeReply		: AxisStreamType;
signal nvmeReply_ready		: std_logic_vector(3 downto 0);
signal nvmeReply_user		: std_logic_vector(32 downto 0);
signal nvmeReply_keep		: std_logic_vector(3 downto 0);

-- Register interface
constant RegWidth		: integer := 32;
subtype RegDataType		is std_logic_vector(RegWidth-1 downto 0);

type StateType			is (STATE_START, STATE_IDLE, STATE_WRITE, STATE_READ1, STATE_READ2);
signal state			: StateType := STATE_START;

signal address			: std_logic_vector(3 downto 0) := (others => '0');
signal reg_id			: RegDataType := x"56010200";
signal reg_control		: RegDataType := (others => '0');
signal reg_status		: RegDataType := (others => '0');
signal reg_nvmeWrite		: RegDataType := (others => '0');

-- Nvme configuration signals
signal configStart		: std_logic := 'U';
signal configStartDone		: std_logic := 'U';
signal configComplete		: std_logic := 'U';

-- Nvme data write signals
signal writeEnable		: std_logic := 'U';


-- Pcie_nvme signals
signal nvme_clk			: std_logic := 'U';
signal nvme_clk_gt		: std_logic := 'U';
signal nvme_reset_local_n	: std_logic := '0';
signal nvme_user_clk		: std_logic := 'U';
signal nvme_user_reset		: std_logic := 'U';

signal cfg_mgmt_addr			: std_logic_vector(18 downto 0);
signal cfg_mgmt_write			: std_logic;
signal cfg_mgmt_write_data		: std_logic_vector(31 downto 0);
signal cfg_mgmt_read			: std_logic;
signal cfg_mgmt_read_data		: std_logic_vector(31 downto 0);
signal cfg_mgmt_read_write_done		: std_logic;
signal cfg_mgmt_type1_cfg_reg_access	: std_logic;

signal dummy1			: AxisStreamType := AxisInput;
signal dummy2			: AxisStreamType := AxisOutput;
signal dummy3			: AxisStreamType := AxisOutput;


begin
	-- AXI Lite bus clock domain crossing
	axilClockConverter0 : AxilClockConverter
	port map (
		clk0		=> clk,
		reset0		=> reset,

		-- Bus0
		axil0In		=> axilIn,
		axil0Out	=> axilOut,

		--clk1		=> nvme_user_clk,
		--reset1	=> nvme_user_reset,
		clk1		=> clk,
		reset1		=> reset,

		-- Bus1
		axil1In		=> axil1Out,
		axil1Out	=> axil1In
	);

	axisClockConverter0 :  AxisClockConverter
	port map (
		clkRx		=> clk,
		resetRx		=> reset,
		streamRx	=> hostSend,

		clkTx		=> nvme_user_clk,
		resetTx		=> nvme_user_reset,
		streamTx	=> hostSend1
	);

	axisClockConverter1 :  AxisClockConverter
	port map (
		clkRx		=> nvme_user_clk,
		resetRx		=> nvme_user_reset,
		streamRx	=> hostRecv1,

		clkTx		=> clk,
		resetTx		=> reset,
		streamTx	=> hostRecv
	);
	
	axisClockConverter2 :  AxisClockConverter
	port map (
		clkRx		=> clk,
		resetRx		=> reset,
		streamRx	=> dataIn,

		clkTx		=> nvme_user_clk,
		resetTx		=> nvme_user_reset,
		streamTx	=> dataIn1
	);

	
	-- Register access
	axil1Out.rdata <=	reg_id when address = "0000" else
				reg_control when address = "0001" else
				reg_status when address = "0010" else
				reg_nvmeWrite when(address(3 downto 2) = "10") else
				x"FFFFFFFF";
	
	-- Status register bits
	reg_status(0)		<= reset_local_run;
	reg_status(1)		<= configComplete;
	reg_status(2)		<= '0';
	reg_status(31 downto 3)	<= (others => '0');
		
	-- Always return OK to read and write requests
	axil1Out.rresp <= "00";
	axil1Out.bresp <= "00";
	axil1Out.bvalid <= '1';

	-- Process register access
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				reg_control	<= (others => '0');
				axil1Out.arready	<= '0';
				axil1Out.rvalid	<= '0';
				axil1Out.awready	<= '0';
				axil1Out.wready	<= '0';
				state		<= STATE_IDLE;
			else
				if(reset_local_done = '1') then
					reset_local_run <= '0';
				end if;
				
				case(state) is
				when STATE_START =>
					axil1Out.arready	<= '0';
					axil1Out.rvalid		<= '0';
					axil1Out.awready	<= '0';
					axil1Out.wready		<= '0';
					state			<= STATE_IDLE;

				when STATE_IDLE =>
					if(axil1In.awvalid= '1') then
						address			<= axil1In.awaddr(5 downto 2);
						axil1Out.awready	<= '1';
						state			<= STATE_WRITE;

					elsif(axil1In.arvalid= '1') then
						address			<= axil1In.araddr(5 downto 2);
						axil1Out.arready	<= '1';
						state			<= STATE_READ1;
					end if;

				when STATE_WRITE =>
					axil1Out.awready	<= '0';

					if(axil1In.wvalid = '1') then
						if(address = "0001") then
							if(axil1In.wdata(0) = '1') then
								reg_control	<= (others => '0');
								reset_local_run	<= '1';
							else
								reg_control <= axil1In.wdata;
							end if;
						end if;

						axil1Out.wready	<= '1';
						state		<= STATE_START;
					end if;

				when STATE_READ1 =>
					axil1Out.arready	<= '0';
					axil1Out.rvalid		<= '1';
					state			<= STATE_READ2;

				when STATE_READ2 =>
					if(axil1In.rready = '1') then
						axil1Out.rvalid	<= '0';
						state		<= STATE_START;
					end if;
				end case;
				
			end if;
		end if;
	end process; 
	
	-- Perform reset of Nvme subsystem. This implements a 100ms reset suitable for the Nvme Pcie reset.
	-- Local state machines and external Nvme devices use this reset_local signal.
	reset_local		<= reset or reset_local_active;
	nvme_reset_local_n	<= not reset_local;
	nvme_reset_n		<= nvme_reset_local_n;
	
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				reset_local_active <= '0';
				reset_local_done <= '0';
			else
				if((reset_local_done = '1') and (reset_local_run = '0')) then
					reset_local_done <= '0';
				end if;
				
				if((reset_local_done = '0') and (reset_local_run = '1') and (reset_local_active = '0')) then
					reset_local_counter	<= ResetCycles;
					reset_local_active	<= '1';

				elsif(reset_local_active = '1') then
					if(reset_local_counter = 0) then
						reset_local_active	<= '0';
						reset_local_done	<= '1';
					else
						reset_local_counter <= reset_local_counter - 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- Host to Nvme stream Mux/DeMux
	nvmeStreamMux0 : NvmeStreamMux
	port map (
		clk		=> nvme_user_clk,
		reset		=> nvme_user_reset,

		stream1In	=> nvmeRecv,
		stream1Out	=> nvmeSend,

		stream2Out	=> hostReq,
		stream2In	=> hostReply,
		
		stream3In	=> nvmeReq,
		stream3Out	=> nvmeReply
	);

	sim: if (Simulate = True) generate
	nvme_user_clk	<= clk;
	nvme_user_reset	<= reset_local;

	nvmeSim0 : NvmeSim
	port map (
		clk		=> nvme_user_clk,
		reset		=> nvme_user_reset,

		hostReq		=> hostReq,
		hostReply	=> hostReply,

		nvmeReq		=> nvmeReq,
		nvmeReply	=> nvmeReply
	);
	end generate;
	
	synth: if (Simulate = False) generate
	-- NVME PCIE Clock, 100MHz
	nvme_clk_buf0 : IBUFDS_GTE3
	port map (
		I       => nvme_clk_p,
		IB      => nvme_clk_n,
		O       => nvme_clk_gt,
		ODIV2   => nvme_clk,
		CEB     => '0'
	);
	
	-- The PCIe to NVMe interface
	pcie_nvme_0 : Pcie_nvme0
	port map (
		sys_clk			=> nvme_clk,
		sys_clk_gt		=> nvme_clk_gt,
		sys_reset		=> nvme_reset_local_n,
		phy_rdy_out		=> leds(0),

		pci_exp_txn		=> nvme_exp_txn,
		pci_exp_txp		=> nvme_exp_txp,
		pci_exp_rxn		=> nvme_exp_rxn,
		pci_exp_rxp		=> nvme_exp_rxp,

		user_clk		=> nvme_user_clk,
		user_reset		=> nvme_user_reset,
		user_lnk_up		=> leds(1),

		s_axis_rq_tdata		=> hostReq.data,
		--s_axis_rq_tkeep	=> hostReq.keep(1 downto 0),
		s_axis_rq_tkeep		=> hostReq_keep,
		s_axis_rq_tlast		=> hostReq.last,
		s_axis_rq_tready	=> hostReq_ready,
		s_axis_rq_tuser		=> hostReq_user,
		s_axis_rq_tvalid	=> hostReq.valid,
		
		m_axis_rc_tdata		=> hostReply.data,
		m_axis_rc_tkeep		=> hostReply_keep,
		m_axis_rc_tlast		=> hostReply.last,
		m_axis_rc_tready	=> hostReply.ready,
		--m_axis_rc_tuser	=> hostReply_user,
		m_axis_rc_tvalid	=> hostReply.valid,
		
		m_axis_cq_tdata		=> nvmeReq.data,
		m_axis_cq_tkeep		=> nvmeReq_keep,
		m_axis_cq_tlast		=> nvmeReq.last,
		m_axis_cq_tready	=> nvmeReq.ready,
		--m_axis_cq_tuser	=> nvmeReq_user,
		m_axis_cq_tvalid	=> nvmeReq.valid,
		
		s_axis_cc_tdata		=> nvmeReply.data,
		s_axis_cc_tkeep		=> nvmeReply_keep,
		s_axis_cc_tlast		=> nvmeReply.last,
		s_axis_cc_tready	=> nvmeReply_ready,
		s_axis_cc_tuser		=> nvmeReply_user,
		s_axis_cc_tvalid	=> nvmeReply.valid,

		--pcie_rq_seq_num		=> pcie_rq_seq_num,
		--pcie_rq_seq_num_vld		=> pcie_rq_seq_num_vld,
		--pcie_rq_tag			=> pcie_rq_tag,
		--pcie_rq_tag_av		=> pcie_rq_tag_av,
		--pcie_rq_tag_vld		=> pcie_rq_tag_vld,
		--pcie_tfc_nph_av		=> pcie_tfc_nph_av,
		--pcie_tfc_npd_av		=> pcie_tfc_npd_av,
		pcie_cq_np_req			=> '1',					-- ?
		--pcie_cq_np_req_count		=> pcie_cq_np_req_count,

		--cfg_phy_link_down		=> --cfg_phy_link_down,
		--cfg_phy_link_status		=> --cfg_phy_link_status,
		--cfg_negotiated_width		=> --cfg_negotiated_width,
		--cfg_current_speed		=> --cfg_current_speed,
		--cfg_max_payload		=> --cfg_max_payload,
		--cfg_max_read_req		=> --cfg_max_read_req,
		--cfg_function_status		=> --cfg_function_status,
		--cfg_function_power_state	=> --cfg_function_power_state,
		--cfg_vf_status			=> --cfg_vf_status,
		--cfg_vf_power_state		=> --cfg_vf_power_state,
		--cfg_link_power_state		=> --cfg_link_power_state,

		cfg_mgmt_addr			=> cfg_mgmt_addr,
		cfg_mgmt_write			=> cfg_mgmt_write,
		cfg_mgmt_write_data		=> cfg_mgmt_write_data,
		cfg_mgmt_byte_enable		=> "1111",
		cfg_mgmt_read			=> cfg_mgmt_read,
		cfg_mgmt_read_data		=> cfg_mgmt_read_data,
		cfg_mgmt_read_write_done	=> cfg_mgmt_read_write_done,
		cfg_mgmt_type1_cfg_reg_access	=> cfg_mgmt_type1_cfg_reg_access,

		--cfg_err_cor_out		=> --cfg_err_cor_out,
		--cfg_err_nonfatal_out		=> --cfg_err_nonfatal_out,
		--cfg_err_fatal_out		=> --cfg_err_fatal_out,
		--cfg_local_error		=> --cfg_local_error,
		--cfg_ltr_enable		=> --cfg_ltr_enable,
		--cfg_ltssm_state		=> --cfg_ltssm_state,
		--cfg_rcb_status		=> --cfg_rcb_status,
		--cfg_dpa_substate_change	=> --cfg_dpa_substate_change,
		--cfg_obff_enable		=> --cfg_obff_enable,
		--cfg_pl_status_change		=> --cfg_pl_status_change,
		--cfg_tph_requester_enable	=> --cfg_tph_requester_enable,
		--cfg_tph_st_mode		=> --cfg_tph_st_mode,
		--cfg_vf_tph_requester_enable	=> --cfg_vf_tph_requester_enable,
		--cfg_vf_tph_st_mode		=> --cfg_vf_tph_st_mode,
		--cfg_fc_ph			=> --cfg_fc_ph,
		--cfg_fc_pd			=> --cfg_fc_pd,
		--cfg_fc_nph			=> --cfg_fc_nph,
		--cfg_fc_npd			=> --cfg_fc_npd,
		--cfg_fc_cplh			=> --cfg_fc_cplh,
		--cfg_fc_cpld			=> --cfg_fc_cpld,
		cfg_fc_sel			=> "000",				-- ?


		cfg_interrupt_int			=> "0000",			-- ?
		cfg_interrupt_pending			=> "0000"
		--cfg_interrupt_sent			=> --cfg_interrupt_sent,
	);

	-- Interface between Axis streams and PCIe Gen3 streams
	hostReq.ready <= hostReq_ready(0);

	-- The last_be bits in hostReq_user should be 0 when reading/writing less than 2 words due to the daft PCIe Gen3 core.
	-- This code peeks at the PCIe TLP headers numDwords field and sets the be bits appropriately. Only valid in the first
	-- beat of the 128bit wide data stream packet.
	-- Warning: This may not be valid for message and atomic packets.
	--hostReq_morethan1 <= reg_control(31);
	hostReq_morethan1 <= '1' when(unsigned(hostReq.data(74 downto 64)) > 1) else '0';
	hostReq_user <= x"00000000" & "0000" & "00000000" & "0" & "00" & "0" & "0" & "000" & "1111" & "1111" when(hostReq_morethan1 = '1')
		else x"00000000" & "0000" & "00000000" & "0" & "00" & "0" & "0" & "000" & "0000" & "1111";

	hostReq_keep <= hostReq.keep(12) & hostReq.keep(8) & hostReq.keep(4) & hostReq.keep(0);	-- Indicate which words are present

	hostReply.keep <= concat(hostReply_keep(3), 4) & concat(hostReply_keep(2), 4) & concat(hostReply_keep(1), 4) & concat(hostReply_keep(0), 4);
	
	nvmeReq.keep <= concat(nvmeReq_keep(3), 4) & concat(nvmeReq_keep(2), 4) & concat(nvmeReq_keep(1), 4) & concat(nvmeReq_keep(0), 4);

	nvmeReply.ready <= nvmeReply_ready(0) and nvmeReply_ready(1) and nvmeReply_ready(2) and nvmeReply_ready(3);
	nvmeReply_user <= (others => '0');
	nvmeReply_keep <= nvmeReply.keep(12) & nvmeReply.keep(8) & nvmeReply.keep(4) & nvmeReply.keep(0);	-- Indicate which words are present
	
	cfg_mgmt_addr <= (others => '0');
	cfg_mgmt_write <= '0';
	cfg_mgmt_write_data <= (others => '0');
	cfg_mgmt_read <= '0';
	cfg_mgmt_type1_cfg_reg_access <= '0';
	

	leds(2) <= '0';
	leds(3) <= '0';
	end generate;
	
	-- Raw Host to Nvme communications
	gen02: if false generate
		axisConnect(nvmeRecv, hostSend1);
		axisConnect(hostRecv1, nvmeSend);
	end generate;
	
	-- Full switched communications
	gen03: if true generate
	set1: for i in 6 to 7 generate
		streamSend(i).valid	<= '0';
		streamRecv(i).ready	<= '1';
	end generate;

	streamSwitch0 : StreamSwitch
	port map (
		clk		=> nvme_user_clk,
		reset		=> nvme_user_reset,

		streamIn	=> streamSend,
		streamOut	=> streamRecv
	);
	
	nvmeQueues0: NvmeQueues
	port map (
		clk		=> nvme_user_clk,
		reset		=> nvme_user_reset,

		streamIn	=> queueRecv,
		streamOut	=> queueSend
	);

	nvmeConfig0: NvmeConfig
	port map (
		clk		=> nvme_user_clk,
		reset		=> nvme_user_reset,

		configStart	=> configStart,
		configComplete	=> configComplete,

		streamOut	=> configSend,
		streamIn	=> configRecv
	);

	-- Start config after reset
	process(nvme_user_clk)
	begin
		if(rising_edge(nvme_user_clk)) then
			if(nvme_user_reset = '1') then
				configStart	<= '0';
				configStartDone	<= '0';
			else
				if((configStartDone = '0') and (configComplete = '0') and (reg_control(1) = '1')) then
				--if(configStartDone = '0') then
					configStart	<= '1' after TCQ;	-- Start the Nvme configuration
					configStartDone	<= '1';
				else
					configStart	<= '0' after TCQ;
				end if;
			end if;
		end if;
	end process;
	
	-- The Data write processing
	writeEnable	<= reg_control(2);
	dataEnabledOut	<= writeEnable;
	
	nvmeWrite0: NvmeWrite
	port map (
		clk		=> nvme_user_clk,
		reset		=> nvme_user_reset,

		enable		=> writeEnable,
		dataIn		=> dataIn1,

		requestOut	=> writeSend,
		replyIn		=> writeRecv,

		memReqIn	=> writeMemRecv,
		memReplyOut	=> writeMemSend,
		
		regAddress	=> unsigned(address(1 downto 0)),
		regData		=> reg_nvmeWrite
	);

	end generate;
	
end;
