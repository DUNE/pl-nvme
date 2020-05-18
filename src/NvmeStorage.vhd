--------------------------------------------------------------------------------
-- NvmeStorage.vhd Nvme storage access module
-------------------------------------------------------------------------------
--!
--! @class	NvmeStorage
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-12
--! @version	0.5.1
--!
--! @brief
--! This is the main top level NvmeStorage module that provides access to the NVMe devices
--! over the Axil bus and Axis request/reply streams.
--!
--! @details
--! The main Nvme working module is NvmeStorageUnit. This NvmeStorage module splits the incomming
--! data stream into two at the NvmeStoargeBlock level (8k) passing alternate blocks into the two
--! NvmeStorageUnit engines.
--! At the moment, during development, it just passes the data through to a single NvmeStorageUnit module.
--! See the DuneNvmeStorageManual for more details.
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

entity NvmeStorage is
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
	hostSend	: in AxisType;				--! Host request stream
	hostSendReady	: out std_logic;			--! Host request stream ready line
	hostRecv	: out AxisType;				--! Host reply stream
	hostRecvReady	: in std_logic;				--! Host reply stream ready line

	-- AXIS data stream input
	dataEnabledOut	: out std_logic;			--! Indicates that data ingest is enabled
	dataIn		: in AxisDataStreamType;		--! Raw data input stream
	dataIn_ready	: out std_logic;			--! Raw data input ready

	-- NVMe interface
	nvme_clk_p	: in std_logic;				--! Nvme external clock +ve
	nvme_clk_n	: in std_logic;				--! Nvme external clock -ve
	nvme_reset_n	: out std_logic;			--! Nvme reset output to reset NVMe devices

	nvme0_exp_txp	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX plus lanes
	nvme0_exp_txn	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX minus lanes
	nvme0_exp_rxp	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX plus lanes
	nvme0_exp_rxn	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX minus lanes

	nvme1_exp_txp	: out std_logic_vector(3 downto 0);	--! Nvme1 PCIe TX plus lanes
	nvme1_exp_txn	: out std_logic_vector(3 downto 0);	--! Nvme1 PCIe TX minus lanes
	nvme1_exp_rxp	: in std_logic_vector(3 downto 0);	--! Nvme1 PCIe RX plus lanes
	nvme1_exp_rxn	: in std_logic_vector(3 downto 0);	--! Nvme1 PCIe RX minus lanes

	-- Debug
	leds		: out std_logic_vector(5 downto 0)
);
end;

architecture Behavioral of NvmeStorage is

component NvmeStorageUnit is
generic(
	Simulate	: boolean	:= Simulate;		--! Generate simulation core
	ClockPeriod	: time		:= ClockPeriod;		--! Clock period for timers (125 MHz)
	BlockSize	: integer	:= BlockSize;		--! System block size
	PcieBlock	: integer	:= 0			--! The Pcie hardblock block to use
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
	dataEnabledOut	: out std_logic;				--! Indicates that data ingest is enabled
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
end component;

component AxisDataConvertFifo is
generic(
	Simulate	: boolean	:= False;		--! Enable simulation core
	FifoSizeBytes	: integer	:= BlockSize		--! The Fifo size in bytes
);
port (
	clk		: in std_logic;
	reset		: in std_logic;

	streamRx	: in AxisDataStreamType;
	streamRx_ready	: out std_logic;

	streamTx	: inout AxisStreamType := AxisStreamOutput
);
end component;

component NvmeStreamMux is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	hostIn		: inout AxisStreamType := AxisStreamInput;	--! Host multiplexed Input stream
	hostOut		: inout AxisStreamType := AxisStreamOutput;	--! Host multiplexed Ouput stream

	nvme0In		: inout AxisStreamType := AxisStreamInput;	--! Nvme0 Replies input stream
	nvme0Out	: inout AxisStreamType := AxisStreamOutput;	--! Nvme0 Requests output stream

	nvme1In		: inout AxisStreamType := AxisStreamInput;	--! Nvme1 Requests input stream
	nvme1Out	: inout AxisStreamType := AxisStreamOutput	--! Nvme1 replies output stream
);
end component;

constant TCQ		: time := 1 ns;

signal nvme_clk		: std_logic := 'U';
signal nvme_clk_gt	: std_logic := 'U';

signal hostSend0	: AxisStreamType;
signal hostRecv0	: AxisStreamType;

signal axilIn0		: AxilToSlaveType;
signal axilOut0		: AxilToMasterType;
signal data0		: AxisStreamType := AxisStreamOutput;
signal nvme0Send	: AxisStreamType;
signal nvme0Recv	: AxisStreamType;

signal axilIn1		: AxilToSlaveType;
signal axilOut1		: AxilToMasterType;
signal data1		: AxisStreamType := AxisStreamOutput;
signal nvme1Send	: AxisStreamType;
signal nvme1Recv	: AxisStreamType;

signal regWrite		: std_logic := '0';					--! Enable write to register
signal regAddress	: unsigned(9 downto 0) := (others => '0');		--! Register to read/write
signal regWrite0	: std_logic := '0';
signal regWrite1	: std_logic := '0';
signal readNvme1	: std_logic := '0';
signal regDataOut0	: std_logic_vector(31 downto 0);
signal regDataOut1	: std_logic_vector(31 downto 0);

signal enabled_n	: std_logic := '0';
signal dataSelect	: std_logic := '0';
signal dataIn_ready_l	: std_logic := 'U';
signal dataIn0		: AxisDataStreamType;
signal dataIn0_ready	: std_logic := 'U';
signal dataIn1		: AxisDataStreamType;
signal dataIn1_ready	: std_logic := 'U';

signal dataEnabledOut0	: std_logic := 'U';
signal dataEnabledOut1	: std_logic := 'U';

function busPass(axil: AxilToSlaveType; enable: std_logic) return AxilToSlaveType is
variable ret: AxilToSlaveType;
begin
	ret.awaddr	:= axil.awaddr;
	ret.awprot	:= axil.awprot;
	ret.awvalid	:= axil.awvalid;
	ret.wdata	:= axil.wdata;
	ret.wstrb	:= axil.wstrb;
	if(enable = '1') then
		ret.wvalid := axil.wvalid;
	else
		ret.wvalid := '0';
	end if;
	ret.bready	:= axil.bready;
	ret.araddr	:= axil.araddr;
	ret.arprot	:= axil.arprot;
	ret.arvalid	:= axil.arvalid;
	ret.rready	:= axil.rready;
	
	return ret;
end;

begin
	-- NVME PCIE Clock, 100MHz
	nvme_clk_buf0 : IBUFDS_GTE3
	port map (
		I       => nvme_clk_p,
		IB      => nvme_clk_n,
		O       => nvme_clk_gt,
		ODIV2   => nvme_clk,
		CEB     => '0'
	);
	
	-- Register processing. Depending on the read or write address set, pass to appropriate NvmeStorageUnit module.
	-- Bus ready returns		
	axilOut.awready	<= axilIn.awvalid;
	axilOut.arready	<= axilIn.arvalid;
	axilOut.rvalid	<= '1';
	axilOut.wready	<= axilIn.wvalid;

	-- Always return OK to read and write requests
	axilOut.rresp	<= "00";
	axilOut.bresp	<= "00";
	axilOut.bvalid	<= '1';

	regWrite	<= axilIn.wvalid;
	
	regWrite0	<= regWrite when(regAddress < 512) else '0';
	regWrite1	<= regWrite when((regAddress < 256) or (regAddress >= 512)) else '0';
	readNvme1	<= '1' when(regAddress >= 512) else '0';
	axilOut.rdata	<= regDataOut1 when(readNvme1 = '1') else regDataOut0;

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				regAddress <= (others => '0');
			else
				if(axilIn.awvalid = '1') then
					regAddress <= unsigned(axilIn.awaddr(9 downto 0));
				elsif(axilIn.arvalid = '1') then
					regAddress <= unsigned(axilIn.araddr(9 downto 0));
				end if;
			end if;
		end if;
	end process;
	
	-- Connect to local Axis stream style
	enabled_n	<= not dataEnabledOut0;
	dataEnabledOut	<= dataEnabledOut0;

	dataIn_ready_l	<= '0' when(enabled_n = '1') else dataIn0_ready when(dataSelect = '0') else dataIn1_ready;
	dataIn_ready	<= dataIn_ready_l;

	dataIn0.valid	<= dataIn.valid when(dataSelect = '0') else '0';
	dataIn0.last	<= dataIn.last;
	dataIn0.data	<= dataIn.data;

	dataIn1.valid	<= dataIn.valid when(dataSelect = '1') else '0';
	dataIn1.last	<= dataIn.last;
	dataIn1.data	<= dataIn.data;

	dataConvert0 : AxisDataConvertFifo
	port map (
		clk		=> clk,
		reset		=> enabled_n,

		streamRx	=> dataIn0,
		streamRx_ready	=> dataIn0_ready,

		streamTx	=> data0
	);

	dataConvert1 : AxisDataConvertFifo
	port map (
		clk		=> clk,
		reset		=> enabled_n,

		streamRx	=> dataIn1,
		streamRx_ready	=> dataIn1_ready,

		streamTx	=> data1
	);

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				dataSelect <= '0';
			else
				if((dataIn.valid = '1') and (dataIn.last = '1') and (dataIn_ready_l = '1')) then
					dataSelect <= not dataSelect;
				end if;
			end if;
		end if;
	end process;

	-- Connect to local Axis stream style
	axisConnect(hostSend0, hostSend, hostSendReady);
	axisConnect(hostRecv, hostRecvReady, hostRecv0);

	nvmeStreamMux0 : NvmeStreamMux
	port map (
		clk		=> clk,
		reset		=> reset,

		hostIn		=> hostSend0,
		hostOut		=> hostRecv0,

		nvme0In		=> nvme0Send,
		nvme0Out	=> nvme0Recv,

		nvme1In		=> nvme1Send,
		nvme1Out	=> nvme1Recv
	);

	nvmeStorageUnit0 : NvmeStorageUnit
	generic map (
		PcieBlock	=> 0			--! The Pcie hardblock block to use
	)
	port map (
		clk		=> clk,
		reset		=> reset,

		regWrite	=> regWrite0,	
		regAddress	=> regAddress(7 downto 2),
		regDataIn	=> axilIn.wdata,
		regDataOut	=> regDataOut0,

		hostSend	=> nvme0Recv,
		hostRecv	=> nvme0Send,
		
		dataEnabledOut	=> dataEnabledOut0,
		dataIn		=> data0,

		-- NVMe interface
		nvme_clk	=> nvme_clk,
		nvme_clk_gt	=> nvme_clk_gt,
		nvme_exp_txp	=> nvme0_exp_txp,
		nvme_exp_txn	=> nvme0_exp_txn,
		nvme_exp_rxp	=> nvme0_exp_rxp,
		nvme_exp_rxn	=> nvme0_exp_rxn,

		leds		=> leds(2 downto 0)
	);

	nvmeStorageUnit1 : NvmeStorageUnit
	generic map (
		PcieBlock	=> 1			--! The Pcie hardblock block to use
	)
	port map (
		clk		=> clk,
		reset		=> reset,

		regWrite	=> regWrite1,
		regAddress	=> regAddress(7 downto 2),
		regDataIn	=> axilIn.wdata,
		regDataOut	=> regDataOut1,

		hostSend	=> nvme1Recv,
		hostRecv	=> nvme1Send,
		
		dataEnabledOut	=> dataEnabledOut1,
		dataIn		=> data1,

		-- NVMe interface
		nvme_clk	=> nvme_clk,
		nvme_clk_gt	=> nvme_clk_gt,
		nvme_exp_txp	=> nvme1_exp_txp,
		nvme_exp_txn	=> nvme1_exp_txn,
		nvme_exp_rxp	=> nvme1_exp_rxp,
		nvme_exp_rxn	=> nvme1_exp_rxn,

		leds		=> leds(5 downto 3)
	);
end;
