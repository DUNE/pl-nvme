--------------------------------------------------------------------------------
-- NvmeStoragePkg.vhd External interface definitions for NvmeStorage module
--------------------------------------------------------------------------------
--!
--! @class	NvmeStoragePkg
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-12
--! @version	1.0.0
--!
--! @brief
--! This package provides external interface definitions for the NvmeStorage module.
--!
--! @details
--! Includes the record types and parameters for the NvmeStorage modules interface to external logic.
--!
--! @copyright 2020 Beam Ltd, Apache License, Version 2.0
--! Copyright 2020 Beam Ltd
--! Licensed under the Apache License, Version 2.0 (the "License");
--! you may not use this file except in compliance with the License.
--! You may obtain a copy of the License at
--!   http://www.apache.org/licenses/LICENSE-2.0
--! Unless required by applicable law or agreed to in writing, software
--! distributed under the License is distributed on an "AS IS" BASIS,
--! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--! See the License for the specific language governing permissions and
--! limitations under the License.
--!
library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package NvmeStoragePkg is
	--! System constants
	constant NvmeStorageBlockSize	: integer := 4096;	--! Default system block size

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
		Platform	: string	:= "Ultrascale";		--! The underlying target platform
		ClockPeriod	: time		:= 4 ns;			--! Clock period for timers (250 MHz)
		BlockSize	: integer	:= NvmeStorageBlockSize;	--! System block size
		NumBlocksDrop	: integer	:= 2;				--! The number of blocks to drop at a time
		UseConfigure	: boolean	:= False;			--! The module configures the Nvme's on reset
		NvmeBlockSize	: integer	:= 512;				--! The NVMe's formatted block size
		NvmeTotalBlocks	: integer	:= 104857600;			--! The total number of 4k blocks available
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
		nvme1_reset_n	: out std_logic;			--! Nvme0 reset output to reset NVMe device
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
