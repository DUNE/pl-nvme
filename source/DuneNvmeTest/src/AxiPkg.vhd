--------------------------------------------------------------------------------
--	AxiPkg.vhd Axil and Axis definitions for NvmeStorage module
--	T.Barnaby, Beam Ltd. 2020-02-28
--------------------------------------------------------------------------------
--!
--! @class	AxiPkg
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

package AxiPkg is
	--! General functions
	function to_stl(v: integer; b: integer) return std_logic_vector;
	function log2(v: integer) return integer;
	function concat(v: std_logic; n: integer) return std_logic_vector;

	--! AXI Lite bus like interface
	constant AxilAddressWidth	: integer := 32;
	constant AxilDataWidth		: integer := 32;

	type AxilToSlave is record
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

	type AxilToMaster is record
		awready		: std_logic;

		wready		: std_logic;

		bvalid		: std_logic;
		bresp		: std_logic_vector(1 downto 0);

		arready		: std_logic;

		rdata		: std_logic_vector(AxilDataWidth-1 downto 0);
		rresp		: std_logic_vector(1 downto 0);
		rvalid		: std_logic;
	end record;
	
	type AxilBus is record
		toSlave		: AxilToSlave;
		toMaster	: AxilToMaster;
	end record;

	function to_AxilAddress(v: integer) return std_logic_vector;
	function to_AxilData(v: integer) return std_logic_vector;


	--! AXI Stream interface
	constant AxisDataWidth	: integer := 128;
	constant AxisKeepWidth	: integer := 16;

	type AxisStream is record
		ready		: std_logic;
		valid		: std_logic;
		last		: std_logic;
		data		: std_logic_vector(AxisDataWidth-1 downto 0);
		keep		: std_logic_vector(AxisKeepWidth-1 downto 0);
	end record;

	constant AxisInput	: AxisStream	:= ('0', 'Z', 'Z', (others => 'Z'), (others => 'Z'));
	constant AxisOutput	: AxisStream	:= ('Z', '0', '0', (others => '0'), (others => '0'));

	function to_AxisData(v: integer) return std_logic_vector;	
end package;

package body AxiPkg is
	function to_stl(v: integer; b: integer) return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(v, b));
	end function;
	
	function log2(v: integer) return integer is
	begin
		for i in 1 to 30 loop  -- Works for up to 30 bit integers
			if(2**i > v) then return(i-1); end if;
		end loop;
		return(30);
	end;
	
	function concat(v: std_logic; n: integer) return std_logic_vector is
	variable ret: std_logic_vector(n-1 downto 0);
	begin
		for i in 0 to n-1 loop
			ret(i) := v;
		end loop;
		return ret;
	end function;

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
