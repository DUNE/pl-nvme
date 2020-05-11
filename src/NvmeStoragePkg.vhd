--------------------------------------------------------------------------------
--	NvmeStoragePkg.vhd Axil and Axis definitions for NvmeStorage module
--	T.Barnaby, Beam Ltd. 2020-02-28
--------------------------------------------------------------------------------
--!
--! @class	NvmeStoragePkg
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-02-28
--! @version	0.0.1
--!
--! @brief
--! This package provides definitions to the AXI4 lite and AXI4 stream interfaces to the NvmeStorage module.
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
	constant AxisKeepWidth	: integer := 16;

	type AxisType is record
		valid		: std_logic;
		last		: std_logic;
		data		: std_logic_vector(AxisDataWidth-1 downto 0);
		keep		: std_logic_vector(AxisKeepWidth-1 downto 0);
	end record;

	constant AxisInit	: AxisType := ('0', '0', (others => '0'), (others => '0'));

	--! This implemtation makes it easy to pass and manipulate streams in VHDL. It's not not nice as it uses inout
	--! to acheive this as VHDL is very limited when using records especialy as module in's and out's.
	--! However this scheme simplifies the code syntax a lot at the expense of less in/out validation in initial compilation stages.
	type AxisStreamType is record
		ready		: std_logic;
		valid		: std_logic;
		last		: std_logic;
		data		: std_logic_vector(AxisDataWidth-1 downto 0);
		keep		: std_logic_vector(AxisKeepWidth-1 downto 0);
	end record;

	constant AxisInput	: AxisStreamType := ('0', 'Z', 'Z', (others => 'Z'), (others => 'Z'));
	constant AxisOutput	: AxisStreamType := ('Z', '0', '0', (others => '0'), (others => '0'));
	constant AxisInOut	: AxisStreamType := ('Z', 'Z', 'Z', (others => 'Z'), (others => 'Z'));
	constant AxisSink	: AxisStreamType := ('1', 'Z', 'Z', (others => 'Z'), (others => 'Z'));
	type AxisArrayType is array (natural range <>) of AxisStreamType;

	function to_AxisData(v: integer) return std_logic_vector;

	procedure axisConnect(signal streamOut: inout AxisStreamType; signal streamIn: inout AxisStreamType);



	--! The NvmeStorage module's interface
	component NvmeStorage is
	generic(
		Simulate	: boolean	:= False
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
		nvme0_exp_txp	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX plus lanes
		nvme0_exp_txn	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX minus lanes
		nvme0_exp_rxp	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX plus lanes
		nvme0_exp_rxn	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX minus lanes

		-- Debug
		leds		: out std_logic_vector(3 downto 0)
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
	
	procedure axisConnect(signal streamOut: inout AxisStreamType; signal streamIn: inout AxisStreamType) is
	begin
		streamIn	<= AxisInOut;
		streamOut	<= AxisInOut;
		
		streamIn.ready	<= streamOut.ready;
		streamOut.valid	<= streamIn.valid;
		streamOut.last	<= streamIn.last;
		streamOut.keep	<= streamIn.keep;
		streamOut.data	<= streamIn.data;
	end procedure;
end;
