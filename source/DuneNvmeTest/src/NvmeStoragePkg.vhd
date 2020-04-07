--------------------------------------------------------------------------------
--	NvmeStoragePkg.vhd, NvmeStorage internal data structures and functions
--	T.Barnaby, Beam Ltd. 2020-03-18
-------------------------------------------------------------------------------
--!
--! @class	NvmeStoragePkg
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-03-18
--! @version	0.0.1
--!
--! @brief
--! This package provides definitions for the NvmeStorage system internals.
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

library work;
use work.AxiPkg.all;

package NvmeStoragePkg is
	--! PCIe request packet head
	type PcieRequestHead is record
		nvme		: unsigned(3 downto 0);
		stream		: unsigned(3 downto 0);
		address		: std_logic_vector(23 downto 0);
		tag		: std_logic_vector(7 downto 0);
		request		: unsigned(3 downto 0);
		count		: unsigned(10 downto 0);
	end record;

	function to_stl(v: PcieRequestHead) return std_logic_vector;
	function to_PcieRequestHead(v: std_logic_vector) return PcieRequestHead;

	--! PCIe reply packet head
	type PcieReplyHead is record
		byteCount	: unsigned(12 downto 0);
		error		: std_logic_vector(3 downto 0);
		address		: std_logic_vector(11 downto 0);
		count		: unsigned(10 downto 0);
		status		: std_logic_vector(2 downto 0);
		tag		: std_logic_vector(7 downto 0);
	end record;

	function to_stl(v: PcieReplyHead) return std_logic_vector;
	function to_PcieReplyHead(v: std_logic_vector) return PcieReplyHead;
end package;

package body NvmeStoragePkg is
	function to_stl(v: PcieRequestHead) return std_logic_vector is
	begin
		return to_stl(0, 24) & v.tag & to_stl(0, 17) & std_logic_vector(v.request) & std_logic_vector(v.count) & to_stl(0, 32) & std_logic_vector(v.nvme) & std_logic_vector(v.stream) & v.address;
	end function;

	function to_PcieRequestHead(v: std_logic_vector) return PcieRequestHead is
	variable ret: PcieRequestHead;
	begin
		ret.nvme := unsigned(v(31 downto 28));
		ret.stream := unsigned(v(27 downto 24));
		ret.address := v(23 downto 0);
		ret.request := unsigned(v(78 downto 75));
		ret.count := unsigned(v(74 downto 64));
		ret.tag := v(103 downto 96);
		return ret;
	end function;

	function to_stl(v: PcieReplyHead) return std_logic_vector is
	begin
		return to_stl(0, 32) & to_stl(0, 24) & v.tag & to_stl(0, 18) & v.status & std_logic_vector(v.count) & "010" & std_logic_vector(v.byteCount) & v.error & v.address;
	end function;

	function to_PcieReplyHead(v: std_logic_vector) return PcieReplyHead is
	variable ret: PcieReplyHead;
	begin
		ret.byteCount := unsigned(v(28 downto 16));
		ret.error := v(15 downto 12);
		ret.address := v(11 downto 0);
		ret.status := v(45 downto 43);
		ret.count := unsigned(v(42 downto 32));
		ret.tag := v(71 downto 64);
		return ret;
	end function;
end;
