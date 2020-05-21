--------------------------------------------------------------------------------
-- NvmeStoragePkg.vhd External interface definitions for NvmeStorage module
--------------------------------------------------------------------------------
--!
--! @class	NvmeStoragePkg
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-12
--! @version	0.5.1
--!
--! @brief
--! This package provides external interface definitions for the NvmeStorage module.
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
library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package NvmeStoragePkg is
	--! System constants
	constant NvmeStorageBlockSize	: integer := 4096;	--! System block size

	--! AXI Lite bus like interface
	constant AxilAddressWidth	: integer := 32;
	constant AxilDataWidth		: integer := 32;

	type AxilToSlaveType is record
		awaddr		: std_logic_vector(AxilAddressWidth-1 downto 0);
		awprot		: std_logic_vector(2 downto 0);
		awvalid		: std_logic;

		wdata		: std_logic_vector(AxilDataWidth-1 downto 0);
		wstrb		: std_logic_vector(3 downto 0);
		wvalid		: std_logic;

		bready		: std_logic;

		araddr		: std_logic_vector(AxilAddressWidth-1 downto 0);
		arprot		: std_logic_vector(2 downto 0);
		arvalid		: std_logic;

		rready		: std_logic;
	end record;

	type AxilToMasterType is record
		awready		: std_logic;

		wready		: std_logic;

		bvalid		: std_logic;
		bresp		: std_logic_vector(1 downto 0);

		arready		: std_logic;

		rdata		: std_logic_vector(AxilDataWidth-1 downto 0);
		rresp		: std_logic_vector(1 downto 0);
		rvalid		: std_logic;
	end record;
	
	type AxilBusType is record
		toSlave		: AxilToSlaveType;
		toMaster	: AxilToMasterType;
	end record;

	function to_AxilAddress(v: integer) return std_logic_vector;
	function to_AxilData(v: integer) return std_logic_vector;


	--! AXI Stream interface
	constant AxisDataWidth	: integer := 128;
	constant AxisKeepWidth	: integer := AxisDataWidth / 8;

	type AxisType is record
		valid		: std_logic;
		last		: std_logic;
		data		: std_logic_vector(AxisDataWidth-1 downto 0);
		keep		: std_logic_vector(AxisKeepWidth-1 downto 0);
	end record;

	constant AxisInit	: AxisType := ('0', '0', (others => '0'), (others => '0'));

	-- Axis data stream
	constant AxisDataStreamWidth : integer := 256;

	type AxisDataStreamType is record
		valid		: std_logic;
		last		: std_logic;
		data		: std_logic_vector(AxisDataStreamWidth-1 downto 0);
	end record;


	--! The NvmeStorage module's interface
	component NvmeStorage is
	generic(
		Simulate	: boolean	:= False;			--! Generate simulation core
		ClockPeriod	: time		:= 8 ns;			--! Clock period for timers (125 MHz)
		BlockSize	: integer	:= NvmeStorageBlockSize;	--! System block size
		NumBlocksDrop	: integer	:= 2;				--! The number of blocks to drop at a time
		UseConfigure	: boolean	:= False			--! The module configures the Nvme's on reset
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
	end component;
	
	--! Simple test data source
	component TestData is
	generic(
		BlockSize	: integer := NvmeStorageBlockSize	--! The block size in Bytes.
	);
	port (
		clk		: in std_logic;				--! The interface clock line
		reset		: in std_logic;				--! The active high reset line

		-- Control and status interface
		enable		: in std_logic;				--! Enable production of data. Clears to reset state when set to 0.

		-- AXIS data output
		dataOut		: out AxisDataStreamType;		--! Output data stream
		dataOutReady	: in std_logic				--! Ready signal for output data stream
	);
	end component;
end package;

package body NvmeStoragePkg is
	function to_AxilAddress(v: integer) return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(v, AxilAddressWidth));
	end function;

	function to_AxilData(v: integer)	return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(v, AxilDataWidth));
	end function;

	function to_AxisData(v: integer) return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(v, AxisDataWidth));
	end function;
end;
