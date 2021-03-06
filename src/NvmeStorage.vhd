--------------------------------------------------------------------------------
-- NvmeStorage.vhd Nvme storage access module
-------------------------------------------------------------------------------
--!
--! @class	NvmeStorage
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-12
--! @version	1.0.0
--!
--! @brief
--! This is the main top level NvmeStorage module that provides access to the NVMe devices
--! over the Axil bus and Axis request/reply streams.
--!
--! @details
--! The main Nvme working module is NvmeStorageUnit. This NvmeStorage module splits the incomming
--! data stream into two at the NvmeStoargeBlock level (4k) passing alternate blocks into the two
--! NvmeStorageUnit engines.
--! It passes register access signals to both NvmeStorageUnit's and multiplexes/de-multiplexes the
--! AXI4 Streams from/to these.
--!
--! The module accepts a 250 MHz clock input to which all input and output signals are syncronised with.
--! The Platform parameter is available to handle alternative Pcie hard block interface types.
--! The UseConfigure parameter sets the system to automatically configure the Nvme device on reset.
--! Parameters for the actual Nvme device in use need to be set in the NvmeBlockSize, NvmeTotalBlocks and
--! NvmeRegStride parameters.
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
	Simulate	: boolean	:= False;			--! Generate simulation core
	Platform	: string	:= "Ultrascale";		--! The underlying target platform
	ClockPeriod	: time		:= 4 ns;			--! Clock period for timers (250 MHz)
	BlockSize	: integer	:= NvmeStorageBlockSize;	--! System block size
	NumBlocksDrop	: integer	:= 2;				--! The number of blocks to drop at a time
	UseConfigure	: boolean	:= False;			--! The module configures the Nvme's on reset
	NvmeBlockSize	: integer	:= 512;				--! The NVMe's formatted block size
	NvmeTotalBlocks	: integer	:= 104857600;			--! The total number of 4k blocks available (400 G)
	NvmeRegStride	: integer	:= 4				--! The doorbell register stride
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	axilIn		: in AxilToSlaveType;			--! Axil bus input signals
	axilOut		: out AxilToMasterType;			--! Axil bus output signals

	-- From host to NVMe request/reply streams
	hostSend	: in AxisType;				--! Host request stream
	hostSend_ready	: out std_logic;			--! Host request stream ready line
	hostRecv	: out AxisType;				--! Host reply stream
	hostRecv_ready	: in std_logic;				--! Host reply stream ready line

	-- AXIS data stream input
	dataDropBlocks	: in std_logic;				--! If set to '1' drop complete input blocks and account for the loss
	dataEnabledOut	: out std_logic;			--! Indicates that data ingest is enabled
	dataIn		: in AxisDataStreamType;		--! Raw data input stream
	dataIn_ready	: out std_logic;			--! Raw data input ready

	-- NVMe interface
	nvme0_clk	: in std_logic;				--! Nvme0 external clock
	nvme0_clk_gt	: in std_logic;				--! Nvme0 external GT clock
	nvme0_reset_n	: out std_logic;			--! Nvme0 reset output to reset NVMe device
	nvme0_exp_txp	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX plus lanes
	nvme0_exp_txn	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX minus lanes
	nvme0_exp_rxp	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX plus lanes
	nvme0_exp_rxn	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX minus lanes

	nvme1_clk	: in std_logic;				--! Nvme1 external clock
	nvme1_clk_gt	: in std_logic;				--! Nvme1 external GT clock
	nvme1_reset_n	: out std_logic;			--! Nvme1 reset output to reset NVMe device
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
	Platform	: string	:= Platform;		--! The underlying target platform
	ClockPeriod	: time		:= ClockPeriod;		--! Clock period for timers (250 MHz)
	BlockSize	: integer	:= BlockSize;		--! System block size
	PcieCore	: integer	:= 0;			--! The Pcie hardblock block to use
	UseConfigure	: boolean	:= UseConfigure;	--! The module configures the Nvme's on reset
	NvmeBlockSize	: integer	:= NvmeBlockSize;	--! The NVMe's formatted block size
	NvmeTotalBlocks	: integer	:= NvmeTotalBlocks;	--! The total number of 4k blocks available
	NvmeRegStride	: integer	:= NvmeRegStride	--! The doorbell register stride
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
	Simulate	: boolean	:= Simulate;		--! Enable simulation core
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
	clk		: in std_logic;					--! The interface clock line
	reset		: in std_logic;					--! The active high reset line
	
	hostIn		: inout AxisStreamType := AxisStreamInput;	--! Host multiplexed Input stream
	hostOut		: inout AxisStreamType := AxisStreamOutput;	--! Host multiplexed Ouput stream

	nvme0In		: inout AxisStreamType := AxisStreamInput;	--! Nvme0 Replies input stream
	nvme0Out	: inout AxisStreamType := AxisStreamOutput;	--! Nvme0 Requests output stream

	nvme1In		: inout AxisStreamType := AxisStreamInput;	--! Nvme1 Requests input stream
	nvme1Out	: inout AxisStreamType := AxisStreamOutput	--! Nvme1 replies output stream
);
end component;

constant TCQ		: time := 1 ns;

signal reset_l		: std_logic := '0';
signal wvalid_delay	: std_logic := '0';
signal rvalid_delay	: unsigned(5 downto 0) := (others => '0');

signal hostSend0	: AxisStreamType;
signal hostRecv0	: AxisStreamType;

signal data0		: AxisStreamType := AxisStreamOutput;
signal nvme0Send	: AxisStreamType;
signal nvme0Recv	: AxisStreamType;

signal data1		: AxisStreamType := AxisStreamOutput;
signal nvme1Send	: AxisStreamType;
signal nvme1Recv	: AxisStreamType;

signal regControl	: std_logic_vector(31 downto 0) := (others => '0');	--! Control register
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

signal dropCount	: integer range 0 to NumBlocksDrop := 0;
signal dropBlocks	: std_logic := '0';
signal regBlocksLost	: unsigned(31 downto 0) := (others => '0');

begin
	-- Register processing. Depending on the read or write address set, pass to appropriate NvmeStorageUnit module.
	-- Bus ready returns		
	axilOut.awready	<= axilIn.awvalid;
	axilOut.arready	<= axilIn.arvalid;
	axilOut.rvalid	<= rvalid_delay(5);
	axilOut.wready	<= axilIn.wvalid and wvalid_delay;

	-- Always return OK to read and write requests
	axilOut.rresp	<= "00";
	axilOut.bresp	<= "00";
	axilOut.bvalid	<= '1';

	reset_l		<= reset or regControl(0);
	regWrite	<= wvalid_delay;		-- Delayed to make sure bits are stable across CDC
	
	regWrite0	<= regWrite when(regAddress < 512) else '0';
	regWrite1	<= regWrite when((regAddress < 256) or (regAddress >= 512)) else '0';
	readNvme1	<= '1' when(regAddress >= 512) else '0';
	axilOut.rdata	<= to_stl(regBlocksLost) when(regAddress = 16) else regDataOut1 when(readNvme1 = '1') else regDataOut0;

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				regControl	<= (others => '0');	
				regAddress	<= (others => '0');
				rvalid_delay	<= (others => '0');
				wvalid_delay	<= '0';
			else
				if(axilIn.awvalid = '1') then
					regAddress <= unsigned(axilIn.awaddr(9 downto 0));
				elsif(axilIn.arvalid = '1') then
					regAddress <= unsigned(axilIn.araddr(9 downto 0));
					rvalid_delay <= to_unsigned(1, rvalid_delay'length);
				else
					-- rvalid delay to handle clock domain crossing latency
					rvalid_delay <= shift_left(rvalid_delay, 1);
				end if;
				
				-- Control register
				if((regWrite = '1') and (regAddress = 4)) then
					regControl <= axilIn.wdata;
				end if;
				
				wvalid_delay <= axilIn.wvalid;
			end if;
		end if;
	end process;
	
	-- Connect to local Axis stream style
	enabled_n	<= not dataEnabledOut0;
	dataEnabledOut	<= dataEnabledOut0;

	-- Pass altenating blocks in the data input stream to the two NvmeStorageUnits
	dataIn_ready_l	<= '0' when(enabled_n = '1') else '1' when(dropBlocks = '1') else dataIn0_ready when(dataSelect = '0') else dataIn1_ready;
	dataIn_ready	<= dataIn_ready_l;

	dataIn0.valid	<= dataIn.valid when((dropBlocks = '0') and (dataSelect = '0')) else '0';
	dataIn0.last	<= dataIn.last;
	dataIn0.data	<= dataIn.data;

	dataIn1.valid	<= dataIn.valid when((dropBlocks = '0') and (dataSelect = '1')) else '0';
	dataIn1.last	<= dataIn.last;
	dataIn1.data	<= dataIn.data;

	--! Store incomming block for Nvme0
	dataConvert0 : AxisDataConvertFifo
	port map (
		clk		=> clk,
		reset		=> enabled_n,

		streamRx	=> dataIn0,
		streamRx_ready	=> dataIn0_ready,

		streamTx	=> data0
	);

	--! Store incomming block for Nvme1
	dataConvert1 : AxisDataConvertFifo
	port map (
		clk		=> clk,
		reset		=> enabled_n,

		streamRx	=> dataIn1,
		streamRx_ready	=> dataIn1_ready,

		streamTx	=> data1
	);
	
	--! Implement input block dropping on request.
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset_l = '1') then
				dataSelect	<= '0';
				dropCount	<= 0;
				dropBlocks	<= '0';
				regBlocksLost	<= (others => '0');
			else
				if((dataIn.valid = '1') and (dataIn.last = '1') and (dataIn_ready_l = '1')) then
					dataSelect <= not dataSelect;
					
					-- Handle dropping of complete blocks
					if(dropCount = 0) then
						-- Drop data starting with Nvme0
						if(dataSelect = '1') then
							if(dataDropBlocks = '1') then
								dropCount	<= NumBlocksDrop - 1;
								regBlocksLost	<= regBlocksLost + 1;
								dropBlocks	<= '1';
							else
								dropBlocks	<= '0';
							end if;
						end if;
					else
						regBlocksLost	<= regBlocksLost + 1;
						dropCount	<= dropCount - 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- Connect to local Axis stream style
	axisConnect(hostSend0, hostSend, hostSend_ready);
	axisConnect(hostRecv, hostRecv_ready, hostRecv0);

	--! Multiplex/de-multiplex Pcie packet streams to the two NvmeStorageUnits
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

	--! Nvme0 storage unit
	nvmeStorageUnit0 : NvmeStorageUnit
	generic map (
		PcieCore	=> 0			--! The Pcie hardblock block to use
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
		nvme_clk	=> nvme0_clk,
		nvme_clk_gt	=> nvme0_clk_gt,
		nvme_reset_n	=> nvme0_reset_n,
		nvme_exp_txp	=> nvme0_exp_txp,
		nvme_exp_txn	=> nvme0_exp_txn,
		nvme_exp_rxp	=> nvme0_exp_rxp,
		nvme_exp_rxn	=> nvme0_exp_rxn,

		leds		=> leds(2 downto 0)
	);

	--! Nvme1 storage unit
	nvmeStorageUnit1 : NvmeStorageUnit
	generic map (
		PcieCore	=> 1			--! The Pcie hardblock block to use
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
		nvme_clk	=> nvme1_clk,
		nvme_clk_gt	=> nvme1_clk_gt,
		nvme_reset_n	=> nvme1_reset_n,
		nvme_exp_txp	=> nvme1_exp_txp,
		nvme_exp_txn	=> nvme1_exp_txn,
		nvme_exp_rxp	=> nvme1_exp_rxp,
		nvme_exp_rxn	=> nvme1_exp_rxn,

		leds		=> leds(5 downto 3)
	);
end;
