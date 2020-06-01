--------------------------------------------------------------------------------
--	NvmeStorageIntPkg.vhd, NvmeStorage internal data structures and functions
--	T.Barnaby, Beam Ltd. 2020-03-18
-------------------------------------------------------------------------------
--!
--! @class	NvmeStorageIntPkg
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-03-18
--! @version	1.0.0
--!
--! @brief
--! This package provides definitions for the NvmeStorage system internals.
--!
--! @details
--! Included are useful functions, core system types and overal system parameters.
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
use work.NvmeStoragePkg.all;

package NvmeStorageIntPkg is
	--! System constants
	constant NvmeQueueNum		: integer := 16;	--! The number of queue entries. Has to be greater than NvmeWriteNum and number of trim requests
	constant NvmeWriteNum		: integer := 8;		--! The number of concurrent data write's.
	constant PcieMaxPayloadSize	: integer := 32;	--! The maximum Pcie packet size in 32bit DWords

	--! Generaly useful functions
	function to_stl(v: integer; b: integer) return std_logic_vector;
	function to_stl(v: unsigned; b: integer) return std_logic_vector;
	function to_stl(v: unsigned) return std_logic_vector;
	function log2(v: integer) return integer;
	function log2_roundup(v: integer) return integer;
	function concat(v: std_logic; n: integer) return std_logic_vector;
	function zeros(n: integer) return std_logic_vector;
	function zeros(n: integer) return unsigned;
	function ones(n: integer) return std_logic_vector;
	function truncate(v: unsigned; n: integer) return unsigned;
	function keepBits(numWords: unsigned) return std_logic_vector;
	function keepBits(numWords: integer) return std_logic_vector;

	--! AXI Stream interface
	--! This implemtation of Axis makes it easy to pass and manipulate streams in VHDL. It's not nice as it uses inout
	--! to acheive this as VHDL is very limited when using records especialy as module in's and out's.
	--! However this scheme simplifies the code syntax a lot at the expense of less in/out validation in the initial compilation stages.
	constant AxisStreamDataWidth	: integer := 128;
	constant AxisStreamKeepWidth	: integer := 4;

	type AxisStreamType is record
		ready		: std_logic;
		valid		: std_logic;
		last		: std_logic;
		data		: std_logic_vector(AxisStreamDataWidth-1 downto 0);
		keep		: std_logic_vector(AxisStreamKeepWidth-1 downto 0);
	end record;

	constant AxisStreamInput	: AxisStreamType := ('0', 'Z', 'Z', (others => 'Z'), (others => 'Z'));
	constant AxisStreamOutput	: AxisStreamType := ('Z', '0', '0', (others => '0'), (others => '0'));
	constant AxisStreamInOut	: AxisStreamType := ('Z', 'Z', 'Z', (others => 'Z'), (others => 'Z'));
	constant AxisStreamSink		: AxisStreamType := ('1', 'Z', 'Z', (others => 'Z'), (others => 'Z'));
	type AxisStreamArrayType is array (natural range <>) of AxisStreamType;

	procedure axisConnect(signal streamOut: inout AxisStreamType; signal streamIn: inout AxisStreamType);
	procedure axisConnect(signal streamOut: out AxisType; signal ready: in std_logic; signal streamIn: inout AxisStreamType);
	procedure axisConnect(signal streamOut: inout AxisStreamType; signal streamIn: in AxisType; signal ready: out std_logic);
	

	--! PCIe request packet head. This uses the Xilinx Pcie Gen3 IP Pcie packet header style.
	type PcieRequestHeadType is record
		reply		: std_logic;			--! This is a reply header
		address		: unsigned(31 downto 0);
		tag		: unsigned(7 downto 0);
		request		: unsigned(3 downto 0);
		count		: unsigned(10 downto 0);
		requesterId	: unsigned(15 downto 0);
	end record;

	function to_stl(v: PcieRequestHeadType) return std_logic_vector;
	function to_PcieRequestHeadType(v: std_logic_vector) return PcieRequestHeadType;
	function set_PcieRequestHeadType(requesterId: integer; request: integer; address: integer; count: integer; tag: integer) return PcieRequestHeadType;

	--! PCIe reply packet head. This uses the Xilinx Pcie Gen3 IP Pcie packet header style.
	type PcieReplyHeadType is record
		reply		: std_logic;			--! This is a reply header
		byteCount	: unsigned(12 downto 0);
		error		: unsigned(3 downto 0);
		address		: unsigned(11 downto 0);
		count		: unsigned(10 downto 0);
		status		: unsigned(2 downto 0);
		requesterId	: unsigned(15 downto 0);
		tag		: unsigned(7 downto 0);
	end record;

	function to_stl(v: PcieReplyHeadType) return std_logic_vector;
	function to_PcieReplyHeadType(v: std_logic_vector) return PcieReplyHeadType;
	function set_PcieReplyHeadType(requesterId: integer; status: integer; address: integer; count: integer; tag: integer) return PcieReplyHeadType;

	--! Nvme request queue entry
	type NvmeRequestHeadType is record
		opcode		: unsigned(15 downto 0);
		cid		: unsigned(15 downto 0);
		namespace	: unsigned(31 downto 0);
		address		: unsigned(31 downto 0);
		cdw10		: unsigned(31 downto 0);
		cdw11		: unsigned(31 downto 0);
		cdw12		: unsigned(31 downto 0);
		cdw13		: unsigned(31 downto 0);
		cdw14		: unsigned(31 downto 0);
		cdw15		: unsigned(31 downto 0);
	end record;

	function to_stl(v: NvmeRequestHeadType; word: integer) return std_logic_vector;

	--! Nvme reply queue entry
	type NvmeReplyHeadType is record
		dw0		: unsigned(31 downto 0);
		sqptr		: unsigned(15 downto 0);
		sqid		: unsigned(15 downto 0);
		cid		: unsigned(15 downto 0);
		status		: unsigned(14 downto 0);
	end record;

	function to_NvmeReplyHeadType(v: std_logic_vector) return NvmeReplyHeadType;

	--! Simple register access
	type RegAccessType is record
		write		: std_logic;
		address		: unsigned(7 downto 0);
		writeData	: std_logic_vector(31 downto 0);
	end record;
	
	subtype RegReturnType is std_logic_vector(31 downto 0);
end;

package body NvmeStorageIntPkg is

	function to_stl(v: integer; b: integer) return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(v, b));
	end function;
	
	function to_stl(v: unsigned; b: integer) return std_logic_vector is
	begin
		return concat('0', b - v'length) & std_logic_vector(v);
	end function;

	function to_stl(v: unsigned) return std_logic_vector is
	begin
		return std_logic_vector(v);
	end function;

	function log2(v: integer) return integer is
	begin
		for i in 1 to 30 loop  -- Works for up to 30 bit integers
			if(2**i > v) then return(i-1); end if;
		end loop;
		return(30);
	end;

	function log2_roundup(v: integer) return integer is
	begin
		for i in 1 to 30 loop  -- Works for up to 32 bit integers
			if(2**i >= v) then return(i); end if;
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
	
	function zeros(n: integer) return std_logic_vector is
	begin
		return concat('0', n);
	end function;

	function zeros(n: integer) return unsigned is
	begin
		return unsigned(concat('0', n));
	end function;

	function ones(n: integer) return std_logic_vector is
	begin
		return concat('1', n);
	end function;

	function truncate(v: unsigned; n: integer) return unsigned is
	begin
		return v(n - 1 downto 0);
	end function;

	--! Set the keep bits based on the number of 32 bit words to be transfered
	function keepBits(numWords: unsigned) return std_logic_vector is
	begin
		if(numWords >= 4) then
			return concat('1', 4);
		elsif(numWords = 3) then
			return concat('0', 1) & concat('1', 3);
		elsif(numWords = 2) then
			return concat('0', 2) & concat('1', 2);
		else
			return concat('0', 3) & concat('1', 1);
		end if;
	end function;

	--! Set the keep bits based on the number of 32 bit words to be transfered
	function keepBits(numWords: integer) return std_logic_vector is
	begin
		if(numWords >= 4) then
			return concat('1', 4);
		elsif(numWords = 3) then
			return concat('0', 1) & concat('1', 3);
		elsif(numWords = 2) then
			return concat('0', 2) & concat('1', 2);
		else
			return concat('0', 3) & concat('1', 1);
		end if;
	end function;

	
	procedure axisConnect(signal streamOut: inout AxisStreamType; signal streamIn: inout AxisStreamType) is
	begin
		streamIn	<= AxisStreamInOut;
		streamOut	<= AxisStreamInOut;
		
		streamIn.ready	<= streamOut.ready;
		streamOut.valid	<= streamIn.valid;
		streamOut.last	<= streamIn.last;
		streamOut.keep	<= streamIn.keep;
		streamOut.data	<= streamIn.data;
	end procedure;

	procedure axisConnect(signal streamOut: out AxisType; signal ready: in std_logic; signal streamIn: inout AxisStreamType) is
	begin
		streamIn	<= AxisStreamInOut;
		
		streamIn.ready	<= ready;
		streamOut.valid	<= streamIn.valid;
		streamOut.last	<= streamIn.last;
		streamOut.keep	<= concat(streamIn.keep(3), 4) & concat(streamIn.keep(2), 4) & concat(streamIn.keep(1), 4) & concat(streamIn.keep(0), 4);
		streamOut.data	<= streamIn.data;
	end procedure;

	procedure axisConnect(signal streamOut: inout AxisStreamType; signal streamIn: in AxisType; signal ready: out std_logic) is
	begin
		streamOut	<= AxisStreamInOut;
		
		ready	<= streamOut.ready;
		streamOut.valid	<= streamIn.valid;
		streamOut.last	<= streamIn.last;
		streamOut.keep	<= streamIn.keep(12) & streamIn.keep(8) & streamIn.keep(4) & streamIn.keep(0);
		streamOut.data	<= streamIn.data;
	end procedure;


	function to_stl(v: PcieRequestHeadType) return std_logic_vector is
	begin
		return zeros(7) & '1' & zeros(16) & std_logic_vector(v.tag) & std_logic_vector(v.requesterId) & to_stl(0, 1) & std_logic_vector(v.request) &
			std_logic_vector(v.count) & to_stl(0, 32) & std_logic_vector(v.address);
	end function;

	function to_PcieRequestHeadType(v: std_logic_vector) return PcieRequestHeadType is
	variable ret: PcieRequestHeadType;
	begin
		ret.reply := v(95);
		ret.address := unsigned(v(31 downto 0));
		ret.request := unsigned(v(78 downto 75));
		ret.count := unsigned(v(74 downto 64));
		ret.requesterId := unsigned(v(95 downto 80));
		ret.tag := unsigned(v(103 downto 96));
		return ret;
	end function;
	
	--! Set the fields in the PCIe TLP header
	function set_PcieRequestHeadType(requesterId: integer; request: integer; address: integer; count: integer; tag: integer) return PcieRequestHeadType is
	variable ret: PcieRequestHeadType;
	begin
		ret.address := to_unsigned(address, ret.address'length);
		ret.request := to_unsigned(request, ret.request'length);
		ret.count := to_unsigned(count, ret.count'length);
		ret.requesterId := to_unsigned(requesterId, ret.requesterId'length);
		ret.tag := to_unsigned(tag, ret.tag'length);
		return ret;
	end function;

	function to_stl(v: PcieReplyHeadType) return std_logic_vector is
	begin
		return '1' & to_stl(0, 23) & std_logic_vector(v.tag) &
			std_logic_vector(v.requesterId) & to_stl(0, 2) & std_logic_vector(v.status) & std_logic_vector(v.count) &
			"010" & std_logic_vector(v.byteCount) &	std_logic_vector(v.error) & std_logic_vector(v.address);
	end function;

	function to_PcieReplyHeadType(v: std_logic_vector) return PcieReplyHeadType is
	variable ret: PcieReplyHeadType;
	begin
		ret.reply := v(95);
		ret.byteCount := unsigned(v(28 downto 16));
		ret.error := unsigned(v(15 downto 12));
		ret.address := unsigned(v(11 downto 0));
		ret.status := unsigned(v(45 downto 43));
		ret.count := unsigned(v(42 downto 32));
		ret.requesterId := unsigned(v(63 downto 48));
		ret.tag := unsigned(v(71 downto 64));
		return ret;
	end function;
	
	--! Set the fields in the PCIe TLP header
	function set_PcieReplyHeadType(requesterId: integer; status: integer; address: integer; count: integer; tag: integer) return PcieReplyHeadType is
	variable ret: PcieReplyHeadType;
	begin
		ret.byteCount := to_unsigned(0, ret.byteCount'length);
		ret.error := to_unsigned(0, ret.error'length);
		ret.address := to_unsigned(address, ret.address'length);
		ret.status := to_unsigned(status, ret.status'length);
		ret.count := to_unsigned(count, ret.count'length);
		ret.requesterId := to_unsigned(requesterId, ret.requesterId'length);
		ret.tag := to_unsigned(tag, ret.tag'length);
		return ret;
	end function;

	function to_stl(v: NvmeRequestHeadType; word: integer) return std_logic_vector is
	begin
		--! *** Needs work ! ****
		return to_stl(0, 128);
	end function;
	
	function to_NvmeReplyHeadType(v: std_logic_vector) return NvmeReplyHeadType is
	variable ret: NvmeReplyHeadType;
	begin
		ret.dw0 := unsigned(v(31 downto 0));
		ret.sqptr := unsigned(v(79 downto 64));
		ret.sqid := unsigned(v(95 downto 80));
		ret.cid := unsigned(v(111 downto 96));
		ret.status := unsigned(v(127 downto 113));
		return ret;
	end;
end;
