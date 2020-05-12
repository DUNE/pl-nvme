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
--! At the moment, during development, it just passes the datra through to a single NvmeStorageUnit module.
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
	dataInReady	: out std_logic;			--! Raw data input ready

	-- NVMe interface
	nvme_clk_p	: in std_logic;				--! Nvme external clock +ve
	nvme_clk_n	: in std_logic;				--! Nvme external clock -ve
	nvme_reset_n	: out std_logic;			--! Nvme reset output to reset NVMe devices
	nvme0_exp_txp	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX plus lanes
	nvme0_exp_txn	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX minus lanes
	nvme0_exp_rxp	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX plus lanes
	nvme0_exp_rxn	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX minus lanes

	-- Debug
	leds		: out std_logic_vector(3 downto 0)
);
end;

architecture Behavioral of NvmeStorage is

component NvmeStorageUnit is
generic(
	Simulate	: boolean	:= Simulate;		--! Generate simulation core
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
	hostSend	: inout AxisStreamType := AxisStreamInput;	--! Host request stream
	hostRecv	: inout AxisStreamType := AxisStreamOutput;	--! Host reply stream

	-- AXIS data stream input
	dataEnabledOut	: out std_logic;			--! Indicates that data ingest is enabled
	dataIn		: inout AxisStreamType := AxisStreamInput;	--! Raw data to save stream

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
end component;

constant TCQ		: time := 1 ns;

signal dataIn1		: AxisStreamType := AxisStreamOutput;
signal hostSend1	: AxisStreamType;
signal hostRecv1	: AxisStreamType;

begin
	-- Connect to local Axis stream style
	dataInReady	<= dataIn1.ready;
	dataIn1.valid	<= dataIn.valid;
	dataIn1.last	<= dataIn.last;
	dataIn1.data	<= dataIn.data;
	
	axisConnect(hostSend1, hostSend, hostSendReady);
	axisConnect(hostRecv, hostRecvReady, hostRecv1);
	
	NvmeStorageUnit0 : NvmeStorageUnit
	port map (
		clk		=> clk,
		reset		=> reset,

		axilIn		=> axilIn,
		axilOut		=> axilOut,

		hostSend	=> hostSend1,
		hostRecv	=> hostRecv1,
		
		dataEnabledOut	=> dataEnabledOut,
		dataIn		=> dataIn1,

		-- NVMe interface
		nvme_clk_p	=> nvme_clk_p,
		nvme_clk_n	=> nvme_clk_n,
		nvme_exp_txp	=> nvme0_exp_txp,
		nvme_exp_txn	=> nvme0_exp_txn,
		nvme_exp_rxp	=> nvme0_exp_rxp,
		nvme_exp_rxn	=> nvme0_exp_rxn,

		leds		=> leds
	);
end;
