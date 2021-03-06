--------------------------------------------------------------------------------
-- NvmeStorageUnit.vhd Nvme storage access module
-------------------------------------------------------------------------------
--!
--! @class	NvmeStorageUnit
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-12
--! @version	1.0.0
--!
--! @brief
--! This is the main Nvme control module for a single Nvme device.
--!
--! @details
--! This module manages a single Nvme device. It is controlled via a simple register access interface
--! and an optional bi-directional PCIe packet stream.
--! An AXI4 data stream, blocked into BlockSize Bytes using the "last" signal, is written sequentially
--! to the Nvme device's blocks. The DataChunkStart and DataChunkSize registers define the starting block number
--! and the number of blocks to write.
--! It accepts a 250 MHz clock input to which all input and output signals are syncronised with.
--! Internally it uses a 250 MHz clock generated from the Nvme devices PCIe clock. The module
--! handles the necessary clock domain crossings for this.
--! The PcieCore parameter defines which Pcie Gen3 IP block to use allowing muliple NvmeStorageUnit's to be used
--! in a design. Note that this is required due to the nature of the Xilinx Pcie Gen3 IP blocks implementation.
--! It would be nice to use a generic Xilinx Pcie Gen3 IP component and set the locations of this in a system
--! constraints file.
--! The Platform parameter is available to handle alternative Pcie hard block interface types.
--! The UseConfigure parameter sets the system to automatically configure the Nvme device on reset.
--! Parameters for the actual Nvme device in use need to be set in the NvmeBlockSize, NvmeTotalBlocks and
--! NvmeRegStride parameters.
--! See the NvmeStorageManual for more details.
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
	Platform	: string	:= "Ultrascale";	--! The underlying target platform
	ClockPeriod	: time		:= 4 ns;		--! Clock period for timers (250 MHz)
	BlockSize	: integer	:= NvmeStorageBlockSize;	--! System block size
	PcieCore	: integer	:= 0;			--! The Pcie hardblock block to use
	UseConfigure	: boolean	:= False;		--! The module configures the Nvme's on reset
	NvmeBlockSize	: integer	:= 512;			--! The NVMe's formatted block size
	NvmeTotalBlocks	: integer	:= 104857600;		--! The total number of 4k blocks available (400G)
	NvmeRegStride	: integer	:= 4			--! The doorbell register stride
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	regWrite	: in std_logic;				--! Enable write to register
	regAddress	: in unsigned(5 downto 0);		--! Register to read/write
	regDataIn	: in std_logic_vector(31 downto 0);	--! Register write data
	regDataOut	: out std_logic_vector(31 downto 0);	--! Register contents

	-- From host to NVMe request/reply streams
	hostSend	: inout AxisStreamType := AxisStreamInput;	--! Host request stream
	hostRecv	: inout AxisStreamType := AxisStreamOutput;	--! Host reply stream

	-- AXIS data stream input
	dataEnabledOut	: out std_logic;			--! Indicates that data ingest is enabled
	dataIn		: inout AxisStreamType := AxisStreamInput;	--! Raw data to save stream

	-- NVMe interface
	nvme_clk	: in std_logic;				--! Nvme external clock
	nvme_clk_gt	: in std_logic;				--! Nvme external GT clock
	nvme_reset_n	: out std_logic;			--! Nvme reset output to reset NVMe devices

	nvme_exp_txp	: out std_logic_vector(3 downto 0);	--! nvme PCIe TX plus lanes
	nvme_exp_txn	: out std_logic_vector(3 downto 0);	--! nvme PCIe TX minus lanes
	nvme_exp_rxp	: in std_logic_vector(3 downto 0);	--! nvme PCIe RX plus lanes
	nvme_exp_rxn	: in std_logic_vector(3 downto 0);	--! nvme PCIe RX minus lanes

	-- Debug
	leds		: out std_logic_vector(2 downto 0)
);
end;

architecture Behavioral of NvmeStorageUnit is

constant TCQ		: time := 1 ns;
constant NumStreams	: integer := 8;
constant ResetCycles	: integer := (100 ms / ClockPeriod);

component RegAccessClockConvertor is
port (
	clk1		: in std_logic;				--! The interface clock line
	reset1		: in std_logic;				--! The active high reset line
	
	regWrite1	: in std_logic;				--! Enable write to register
	regAddress1	: in unsigned(5 downto 0);		--! Register to read/write
	regDataIn1	: in std_logic_vector(31 downto 0);	--! Register write data
	regDataOut1	: out std_logic_vector(31 downto 0);	--! Register contents

	clk2		: in std_logic;				--! The interface clock line
	reset2		: in std_logic;				--! The active high reset line

	regWrite2	: out std_logic;				--! Enable write to register
	regAddress2	: out unsigned(5 downto 0);		--! Register to read/write
	regDataIn2	: out std_logic_vector(31 downto 0);	--! Register write data
	regDataOut2	: in std_logic_vector(31 downto 0)	--! Register contents
);
end component;

component AxisClockConverter is
generic(
	Simulate	: boolean	:= Simulate
);
port (
	clkRx		: in std_logic;
	resetRx		: in std_logic;
	streamRx	: inout AxisStreamType := AxisStreamInput;                        

	clkTx		: in std_logic;
	resetTx		: in std_logic;
	streamTx	: inout AxisStreamType := AxisStreamOutput
);
end component;

component CdcSingle is
port (
	clk1		: in std_logic;				--! The interface clock line
	signal1		: in std_logic;				--! The signal to pass

	clk2		: in std_logic;				--! The interface clock line
	reset2		: in std_logic;				--! The active high reset line
	signal2		: out std_logic				--! The signals passed
);
end component;

-- The Xilinx PCIe Gen3 hardblock to communicate with the NVMe 0 device
--! @class	Pcie_nvme0
--! @brief	The Xilinx PCIe Gen3 hard block interface to NVMe device
--! @details	See the Xilinx documentation for details of this IP block
component Pcie_nvme0
port (
	pci_exp_txn : out std_logic_vector ( 3 downto 0 );
	pci_exp_txp : out std_logic_vector ( 3 downto 0 );
	pci_exp_rxn : in std_logic_vector ( 3 downto 0 );
	pci_exp_rxp : in std_logic_vector ( 3 downto 0 );
	user_clk : out std_logic;
	user_reset : out std_logic;
	user_lnk_up : out std_logic;
	s_axis_rq_tdata : in std_logic_vector ( 127 downto 0 );
	s_axis_rq_tkeep : in std_logic_vector ( 3 downto 0 );
	s_axis_rq_tlast : in std_logic;
	s_axis_rq_tready : out std_logic_vector ( 3 downto 0 );
	s_axis_rq_tuser : in std_logic_vector ( 59 downto 0 );
	s_axis_rq_tvalid : in std_logic;
	m_axis_rc_tdata : out std_logic_vector ( 127 downto 0 );
	m_axis_rc_tkeep : out std_logic_vector ( 3 downto 0 );
	m_axis_rc_tlast : out std_logic;
	m_axis_rc_tready : in std_logic;
	m_axis_rc_tuser : out std_logic_vector ( 74 downto 0 );
	m_axis_rc_tvalid : out std_logic;
	m_axis_cq_tdata : out std_logic_vector ( 127 downto 0 );
	m_axis_cq_tkeep : out std_logic_vector ( 3 downto 0 );
	m_axis_cq_tlast : out std_logic;
	m_axis_cq_tready : in std_logic;
	m_axis_cq_tuser : out std_logic_vector ( 84 downto 0 );
	m_axis_cq_tvalid : out std_logic;
	s_axis_cc_tdata : in std_logic_vector ( 127 downto 0 );
	s_axis_cc_tkeep : in std_logic_vector ( 3 downto 0 );
	s_axis_cc_tlast : in std_logic;
	s_axis_cc_tready : out std_logic_vector ( 3 downto 0 );
	s_axis_cc_tuser : in std_logic_vector ( 32 downto 0 );
	s_axis_cc_tvalid : in std_logic;
	cfg_interrupt_int : in std_logic_vector ( 3 downto 0 );
	cfg_interrupt_pending : in std_logic_vector ( 3 downto 0 );
	cfg_interrupt_sent : out std_logic;
	sys_clk : in std_logic;
	sys_clk_gt : in std_logic;
	sys_reset : in std_logic;
	int_qpll1lock_out : out std_logic_vector ( 0 to 0 );
	int_qpll1outrefclk_out : out std_logic_vector ( 0 to 0 );
	int_qpll1outclk_out : out std_logic_vector ( 0 to 0 );
	phy_rdy_out : out std_logic
);
end component;

-- The Xilinx PCIe Gen3 hardblock to communicate with the NVMe 1 device
component Pcie_nvme1
port (
	pci_exp_txn : out std_logic_vector ( 3 downto 0 );
	pci_exp_txp : out std_logic_vector ( 3 downto 0 );
	pci_exp_rxn : in std_logic_vector ( 3 downto 0 );
	pci_exp_rxp : in std_logic_vector ( 3 downto 0 );
	user_clk : out std_logic;
	user_reset : out std_logic;
	user_lnk_up : out std_logic;
	s_axis_rq_tdata : in std_logic_vector ( 127 downto 0 );
	s_axis_rq_tkeep : in std_logic_vector ( 3 downto 0 );
	s_axis_rq_tlast : in std_logic;
	s_axis_rq_tready : out std_logic_vector ( 3 downto 0 );
	s_axis_rq_tuser : in std_logic_vector ( 59 downto 0 );
	s_axis_rq_tvalid : in std_logic;
	m_axis_rc_tdata : out std_logic_vector ( 127 downto 0 );
	m_axis_rc_tkeep : out std_logic_vector ( 3 downto 0 );
	m_axis_rc_tlast : out std_logic;
	m_axis_rc_tready : in std_logic;
	m_axis_rc_tuser : out std_logic_vector ( 74 downto 0 );
	m_axis_rc_tvalid : out std_logic;
	m_axis_cq_tdata : out std_logic_vector ( 127 downto 0 );
	m_axis_cq_tkeep : out std_logic_vector ( 3 downto 0 );
	m_axis_cq_tlast : out std_logic;
	m_axis_cq_tready : in std_logic;
	m_axis_cq_tuser : out std_logic_vector ( 84 downto 0 );
	m_axis_cq_tvalid : out std_logic;
	s_axis_cc_tdata : in std_logic_vector ( 127 downto 0 );
	s_axis_cc_tkeep : in std_logic_vector ( 3 downto 0 );
	s_axis_cc_tlast : in std_logic;
	s_axis_cc_tready : out std_logic_vector ( 3 downto 0 );
	s_axis_cc_tuser : in std_logic_vector ( 32 downto 0 );
	s_axis_cc_tvalid : in std_logic;
	cfg_interrupt_int : in std_logic_vector ( 3 downto 0 );
	cfg_interrupt_pending : in std_logic_vector ( 3 downto 0 );
	cfg_interrupt_sent : out std_logic;
	sys_clk : in std_logic;
	sys_clk_gt : in std_logic;
	sys_reset : in std_logic;
	int_qpll1lock_out : out std_logic_vector ( 0 to 0 );
	int_qpll1outrefclk_out : out std_logic_vector ( 0 to 0 );
	int_qpll1outclk_out : out std_logic_vector ( 0 to 0 );
	phy_rdy_out : out std_logic
);
end component;

component StreamSwitch is
generic(
	NumStreams	: integer	:= NumStreams		--! The number of stream
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisStreamArrayType(0 to NumStreams-1) := (others => AxisStreamInput);	--! Input stream
	streamOut	: inout AxisStreamArrayType(0 to NumStreams-1) := (others => AxisStreamOutput)	--! Output stream
);
end component;

component NvmeQueues is
generic(
	NumQueueEntries	: integer	:= NvmeQueueNum;	--! The number of entries per queue
	NvmeRegStride	: integer	:= NvmeRegStride;	--! The doorbell register stride
	Simulate	: boolean	:= False
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisStreamType := AxisStreamInput;	--! Request queue entries
	streamOut	: inout AxisStreamType := AxisStreamOutput	--! replies and requests
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
	streamOut	: inout AxisStreamType := AxisStreamOutput;	--! Nvme request stream
	streamIn	: inout AxisStreamType := AxisStreamInput	--! Nvme reply stream
);
end component;

component PcieStreamMux is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	stream1In	: inout AxisStreamType := AxisStreamInput;	--! Single multiplexed Input stream
	stream1Out	: inout AxisStreamType := AxisStreamOutput;	--! Single multiplexed Ouput stream

	stream2Out	: inout AxisStreamType := AxisStreamOutput;	--! Host Requests output stream
	stream2In	: inout AxisStreamType := AxisStreamInput;	--! Host Replies input stream

	stream3In	: inout AxisStreamType := AxisStreamInput;	--! Nvme Requests input stream
	stream3Out	: inout AxisStreamType := AxisStreamOutput	--! Nvme replies output stream
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
	hostReq		: inout AxisStreamType := AxisStreamInput;
	hostReply	: inout AxisStreamType := AxisStreamOutput;                        
	
	-- From Nvme reqeuest and reply stream
	nvmeReq		: inout AxisStreamType := AxisStreamOutput;
	nvmeReply	: inout AxisStreamType := AxisStreamInput
);
end component;

component NvmeWrite is
generic(
	Simulate	: boolean := Simulate;			--! Generate simulation core
	ClockPeriod	: time := ClockPeriod;			--! The clocks period
	BlockSize	: integer := BlockSize;			--! System block size
	NvmeBlockSize	: integer := NvmeBlockSize;		--! The NVMe's formatted block size
	NvmeTotalBlocks	: integer := NvmeTotalBlocks		--! The total number of 4k blocks available
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	enable		: in std_logic;				--! Enable the data writing process
	dataIn		: inout AxisStreamType := AxisStreamInput;	--! Raw data to save stream

	waitingForData	: out std_logic;			--! Set when dataIn is empty so other tasks can be run.
	complete	: out std_logic;			--! Set when capture process is complete

	-- To Nvme Request/reply streams
	requestOut	: inout AxisStreamType := AxisStreamOutput;	--! To Nvme request stream (3)
	replyIn		: inout AxisStreamType := AxisStreamInput;	--! from Nvme reply stream

	-- From Nvme Request/reply streams
	memReqIn	: inout AxisStreamType := AxisStreamInput;	--! From Nvme request stream (4)
	memReplyOut	: inout AxisStreamType := AxisStreamOutput;	--! To Nvme reply stream
	
	regWrite	: in std_logic;				--! Enable write to register
	regAddress	: in unsigned(3 downto 0);		--! Register to read/write
	regDataIn	: in std_logic_vector(31 downto 0);	--! Register write data
	regDataOut	: out std_logic_vector(31 downto 0)	--! Register contents
);
end component;

component NvmeRead is
generic(
	Simulate	: boolean := False;			--! Generate simulation core
	BlockSize	: integer := NvmeStorageBlockSize;	--! System block size
	NvmeBlockSize	: integer := NvmeBlockSize;		--! The NVMe's formatted block size
	NvmeTotalBlocks	: integer := NvmeTotalBlocks		--! The total number of 4k blocks available
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	enable		: in std_logic;				--! Enable operation, used to limit bandwidth used

	-- To Nvme Request/reply streams
	requestOut	: inout AxisStreamType := AxisStreamOutput;	--! To Nvme request stream (3)
	replyIn		: inout AxisStreamType := AxisStreamInput;	--! from Nvme reply stream

	regWrite	: in std_logic;				--! Enable write to register
	regAddress	: in unsigned(3 downto 0);		--! Register to read/write
	regDataIn	: in std_logic_vector(31 downto 0);	--! Register write data
	regDataOut	: out std_logic_vector(31 downto 0)	--! Register contents
);
end component;

signal reset_local		: std_logic := '0';
signal reset_local_active	: std_logic := '0';
signal reset_local_counter	: integer range 0 to ResetCycles := 0;

-- Streams
signal streamSend		: AxisStreamArrayType(0 to NumStreams-1);
signal streamRecv		: AxisStreamArrayType(0 to NumStreams-1);

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
alias readSend			is streamSend(6);
alias readRecv			is streamRecv(6);

signal dataIn1			: AxisStreamType;
signal streamNone		: AxisStreamType := AxisStreamOutput;
signal streamSink		: AxisStreamType := AxisStreamSink;

-- Nvme PCIe interface
signal hostReq			: AxisStreamType;
signal hostReq_ready		: std_logic_vector(3 downto 0);
signal hostReq_morethan1	: std_logic;
signal hostReq_user		: std_logic_vector(59 downto 0);

signal hostReply		: AxisStreamType;

signal nvmeReq			: AxisStreamType;

signal nvmeReply		: AxisStreamType;
signal nvmeReply_ready		: std_logic_vector(3 downto 0);
signal nvmeReply_user		: std_logic_vector(32 downto 0);

-- Register interface
constant RegWidth		: integer := 32;
subtype RegDataType		is std_logic_vector(RegWidth-1 downto 0);

type StateType			is (STATE_START, STATE_IDLE, STATE_WRITE, STATE_READ1, STATE_READ2);
signal state			: StateType := STATE_START;

signal regWrite1		: std_logic;				--! Enable write to register
signal regAddress1		: unsigned(5 downto 0) := (others => '0');	--! Register to read/write
signal regDataIn1		: std_logic_vector(31 downto 0);	--! Register write data
signal regDataOut0		: std_logic_vector(31 downto 0);	--! Register contents
signal regDataOut1		: std_logic_vector(31 downto 0);	--! Register contents

signal reg_id			: RegDataType := x"56010001";
signal reg_control		: RegDataType := (others => '0');
signal reg_status		: RegDataType := (others => '0');
signal reg_totalBlocks		: RegDataType := to_stl(NvmeTotalBlocks, RegWidth);
signal reg_blocksLost		: RegDataType := (others => '0');
signal reg_nvmeWrite		: RegDataType := (others => '0');
signal reg_nvmeRead		: RegDataType := (others => '0');
signal nvmeWrite_write		: std_logic := '0';
signal nvmeRead_write		: std_logic := '0';

-- Nvme configuration signals
signal configStart		: std_logic := 'U';
signal configStartDone		: std_logic := 'U';
signal configComplete		: std_logic := 'U';

-- Nvme data write signals
signal writeEnable		: std_logic := 'U';
signal waitingForData		: std_logic := 'U';
signal dataEnabledOut1		: std_logic := 'U';
signal writeComplete		: std_logic := 'U';

-- Status signals
signal phy_rdy_out		: std_logic := 'U';
signal user_lnk_up		: std_logic := 'U';

-- Pcie_nvme signals
signal nvme_reset_local_n	: std_logic := '0';
signal nvme_user_clk		: std_logic := 'U';
signal nvme_user_reset		: std_logic := 'U';

attribute keep	: string;
attribute keep	of reset_local : signal is "true";
attribute keep	of nvme_reset_local_n : signal is "true";

begin
	-- Register access over clock domain crossing
	regClockConvertor : RegAccessClockConvertor
	port map (
		clk1		=> clk,
		reset1		=> reset,

		regWrite1	=> regWrite,
		regAddress1	=> regAddress,
		regDataIn1	=> regDataIn,
		regDataOut1	=> regDataOut0,

		clk2		=> nvme_user_clk,
		reset2		=> nvme_user_reset,

		regWrite2	=> regWrite1,
		regAddress2	=> regAddress1,
		regDataIn2	=> regDataIn1,
		regDataOut2	=> regDataOut1
	);

	-- Host request packets across clock domain crossing
	axisClockConverter0 :  AxisClockConverter
	port map (
		clkRx		=> clk,
		resetRx		=> reset,
		streamRx	=> hostSend,

		clkTx		=> nvme_user_clk,
		resetTx		=> nvme_user_reset,
		streamTx	=> hostSend1
	);

	-- Host reply packets across clock domain crossing
	axisClockConverter1 :  AxisClockConverter
	port map (
		clkRx		=> nvme_user_clk,
		resetRx		=> nvme_user_reset,
		streamRx	=> hostRecv1,

		clkTx		=> clk,
		resetTx		=> reset,
		streamTx	=> hostRecv
	);
	
	-- Data stream across clock domain crossing
	axisClockConverter2 :  AxisClockConverter
	port map (
		clkRx		=> clk,
		resetRx		=> "not"(dataEnabledOut1),
		streamRx	=> dataIn,

		clkTx		=> nvme_user_clk,
		resetTx		=> "not"(writeEnable),
		streamTx	=> dataIn1
	);
	
	-- Data enable signal across clock domains
	cdc0: CdcSingle
	port map (
		clk1		=> nvme_user_clk,
		signal1		=> writeEnable,

		clk2		=> clk,
		reset2		=> reset,
		signal2		=> dataEnabledOut1
	);

	dataEnabledOut <= dataEnabledOut1;

	-- Register access
	regDataOut1 <= reg_id when(regAddress1 = 0) else
			reg_control when(regAddress1 = 1) else
			reg_status when(regAddress1 = 2) else
			reg_totalBlocks when(regAddress1 = 3) else
			reg_blocksLost when(regAddress1 = 4) else
			reg_nvmeWrite when((regAddress1 >= 16) and (regAddress1 < 32)) else
			reg_nvmeRead when((regAddress1 >= 32) and (regAddress1 < 48)) else
			x"FFFFFFFF";

	regDataOut <= zeros(31) & reset_local_active when(reset_local_active = '1') else regDataOut0;
	nvmeWrite_write <= regWrite1 when((regAddress1 >= 16) and (regAddress1 < 32)) else '0';
	nvmeRead_write <= regWrite1 when((regAddress1 >= 32) and (regAddress1 < 48)) else '0';
	
	-- Status register bits
	reg_status(0)		<= '0';
	reg_status(1)		<= configComplete;
	reg_status(2)		<= reg_control(2);
	reg_status(3)		<= writeComplete;
	reg_status(4)		<= '0';				-- Error: ideally needs seting from various sources
	reg_status(29 downto 5)	<= (others => '0');
	reg_status(30)		<= phy_rdy_out;
	reg_status(31)		<= user_lnk_up;
	
	-- Perform reset of Nvme subsystem. This implements a 100ms reset suitable for the Nvme Pcie reset.
	-- Local state machines and external Nvme devices use this reset_local signal.
	-- Note this is asynchronous as generated by an external reset signal or on an interface clock
	-- It would be possible to synchronise this to nvme_clk but a BUFG_GT buffer would be needed to
	-- access the clock line for this. It is only used by the Pcie Gen3 hard block which expects an
	-- asynchronous reset. The nvme_user_reset is generated by the hard block.
	reset_local		<= reset or reset_local_active;
	nvme_reset_local_n	<= not reset_local;
	nvme_reset_n		<= nvme_reset_local_n;

	-- Process reset
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				reset_local_active <= '0';
			else
				if((regWrite = '1') and (regAddress = 1)) then
					if(regDataIn(0) = '1') then
						reset_local_counter	<= ResetCycles;
						reset_local_active	<= '1';
					end if;
				end if;
				
				if(reset_local_active = '1') then
					if(reset_local_counter = 0) then
						reset_local_active	<= '0';
					else
						reset_local_counter <= reset_local_counter - 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- Process register access
	process(nvme_user_clk)
	begin
		if(rising_edge(nvme_user_clk)) then
			if(nvme_user_reset = '1') then
				reg_control	<= (others => '0');
			else
				if(regWrite1 = '1') then
					if(regAddress1 = 1) then
						reg_control <= regDataIn1;
					end if;
				end if;
			end if;
		end if;
	end process; 
	
	-- Host to Nvme stream Mux/DeMux
	pcieStreamMux0 : PcieStreamMux
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

	genpci0: if(PcieCore = 0) generate
	--! The PCIe to NVMe 0 interface
	pcie_nvme_0 : Pcie_nvme0
	port map (
		sys_clk			=> nvme_clk,
		sys_clk_gt		=> nvme_clk_gt,
		sys_reset		=> nvme_reset_local_n,
		phy_rdy_out		=> phy_rdy_out,

		pci_exp_txn		=> nvme_exp_txn,
		pci_exp_txp		=> nvme_exp_txp,
		pci_exp_rxn		=> nvme_exp_rxn,
		pci_exp_rxp		=> nvme_exp_rxp,

		user_clk		=> nvme_user_clk,
		user_reset		=> nvme_user_reset,
		user_lnk_up		=> user_lnk_up,

		s_axis_rq_tdata		=> hostReq.data,
		s_axis_rq_tkeep		=> hostReq.keep,
		s_axis_rq_tlast		=> hostReq.last,
		s_axis_rq_tready	=> hostReq_ready,
		s_axis_rq_tuser		=> hostReq_user,
		s_axis_rq_tvalid	=> hostReq.valid,
		
		m_axis_rc_tdata		=> hostReply.data,
		m_axis_rc_tkeep		=> hostReply.keep,
		m_axis_rc_tlast		=> hostReply.last,
		m_axis_rc_tready	=> hostReply.ready,
		--m_axis_rc_tuser	=> hostReply_user,
		m_axis_rc_tvalid	=> hostReply.valid,
		
		m_axis_cq_tdata		=> nvmeReq.data,
		m_axis_cq_tkeep		=> nvmeReq.keep,
		m_axis_cq_tlast		=> nvmeReq.last,
		m_axis_cq_tready	=> nvmeReq.ready,
		--m_axis_cq_tuser	=> nvmeReq_user,
		m_axis_cq_tvalid	=> nvmeReq.valid,
		
		s_axis_cc_tdata		=> nvmeReply.data,
		s_axis_cc_tkeep		=> nvmeReply.keep,
		s_axis_cc_tlast		=> nvmeReply.last,
		s_axis_cc_tready	=> nvmeReply_ready,
		s_axis_cc_tuser		=> nvmeReply_user,
		s_axis_cc_tvalid	=> nvmeReply.valid,

		cfg_interrupt_int	=> "0000",
		cfg_interrupt_pending	=> "0000"
		--cfg_interrupt_sent	=> --cfg_interrupt_sent,
	);
	end generate;
	
	genpci1: if(PcieCore = 1) generate
	--! The PCIe to NVMe 1 interface
	pcie_nvme_1 : Pcie_nvme1
	port map (
		sys_clk			=> nvme_clk,
		sys_clk_gt		=> nvme_clk_gt,
		sys_reset		=> nvme_reset_local_n,
		phy_rdy_out		=> phy_rdy_out,

		pci_exp_txn		=> nvme_exp_txn,
		pci_exp_txp		=> nvme_exp_txp,
		pci_exp_rxn		=> nvme_exp_rxn,
		pci_exp_rxp		=> nvme_exp_rxp,

		user_clk		=> nvme_user_clk,
		user_reset		=> nvme_user_reset,
		user_lnk_up		=> user_lnk_up,

		s_axis_rq_tdata		=> hostReq.data,
		s_axis_rq_tkeep		=> hostReq.keep,
		s_axis_rq_tlast		=> hostReq.last,
		s_axis_rq_tready	=> hostReq_ready,
		s_axis_rq_tuser		=> hostReq_user,
		s_axis_rq_tvalid	=> hostReq.valid,
		
		m_axis_rc_tdata		=> hostReply.data,
		m_axis_rc_tkeep		=> hostReply.keep,
		m_axis_rc_tlast		=> hostReply.last,
		m_axis_rc_tready	=> hostReply.ready,
		--m_axis_rc_tuser	=> hostReply_user,
		m_axis_rc_tvalid	=> hostReply.valid,
		
		m_axis_cq_tdata		=> nvmeReq.data,
		m_axis_cq_tkeep		=> nvmeReq.keep,
		m_axis_cq_tlast		=> nvmeReq.last,
		m_axis_cq_tready	=> nvmeReq.ready,
		--m_axis_cq_tuser	=> nvmeReq_user,
		m_axis_cq_tvalid	=> nvmeReq.valid,
		
		s_axis_cc_tdata		=> nvmeReply.data,
		s_axis_cc_tkeep		=> nvmeReply.keep,
		s_axis_cc_tlast		=> nvmeReply.last,
		s_axis_cc_tready	=> nvmeReply_ready,
		s_axis_cc_tuser		=> nvmeReply_user,
		s_axis_cc_tvalid	=> nvmeReply.valid,

		cfg_interrupt_int	=> "0000",
		cfg_interrupt_pending	=> "0000"
		--cfg_interrupt_sent	=> --cfg_interrupt_sent,
	);
	end generate;
	
	
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

	nvmeReply.ready <= nvmeReply_ready(0) and nvmeReply_ready(1) and nvmeReply_ready(2) and nvmeReply_ready(3);
	nvmeReply_user <= (others => '0');

	leds(0) <= phy_rdy_out;
	leds(1) <= user_lnk_up;
	leds(2) <= '0';
	end generate;
	
	-- Raw Host to Nvme communications
	gen02: if false generate
		axisConnect(nvmeRecv, hostSend1);
		axisConnect(hostRecv1, nvmeSend);
	end generate;
	
	-- Full switched communications
	set1: for i in 7 to 7 generate
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
				if(UseConfigure and (configStartDone = '0')) then
					configStart	<= '1';		-- Start the Nvme configuration
					configStartDone	<= '1';
				elsif((configStartDone = '0') and (configComplete = '0') and (reg_control(1) = '1')) then
					configStart	<= '1';		-- Start the Nvme configuration
					configStartDone	<= '1';
				else
					configStart	<= '0';
				end if;
			end if;
		end if;
	end process;
	
	-- The Data write processing
	writeEnable	<= reg_control(2);
	
	nvmeWrite0: NvmeWrite
	port map (
		clk		=> nvme_user_clk,
		reset		=> nvme_user_reset,

		enable		=> writeEnable,
		dataIn		=> dataIn1,

		waitingForData	=> waitingForData,
		complete	=> writeComplete,
		
		requestOut	=> writeSend,
		replyIn		=> writeRecv,

		memReqIn	=> writeMemRecv,
		memReplyOut	=> writeMemSend,

		regWrite	=> nvmeWrite_write,
		regAddress	=> regAddress1(3 downto 0),
		regDataIn	=> regDataIn1,
		regDataOut	=> reg_nvmeWrite
	);

	-- The Data read processing
	nvmeRead0: NvmeRead
	port map (
		clk		=> nvme_user_clk,
		reset		=> nvme_user_reset,

		enable		=> waitingForData,

		requestOut	=> readSend,
		replyIn		=> readRecv,

		regWrite	=> nvmeRead_write,
		regAddress	=> regAddress1(3 downto 0),
		regDataIn	=> regDataIn1,
		regDataOut	=> reg_nvmeRead
	);
end;
