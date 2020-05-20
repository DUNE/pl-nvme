--------------------------------------------------------------------------------
--	TestPkg.vhd, Common bits for test harnesses
--	T.Barnaby, Beam Ltd. 2020-03-18
-------------------------------------------------------------------------------
--!
--! @class	TestPkg
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-21
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
use work.NvmeStoragePkg.all;
use work.NvmeStorageIntPkg.all;

package TestPkg is
	procedure pcieRequestWriteHead(signal clk: std_logic; signal stream: inout AxisStreamType; requesterId: in integer; request: in integer; address: in integer; tag: in integer; count: in integer);
	procedure pcieRequestWrite(signal clk: std_logic; signal stream: inout AxisStreamType; requesterId: in integer; request: in integer; address: in integer; tag: in integer; count: in integer; data: in integer);
	procedure pcieRequestRead(signal clk: std_logic; signal stream: inout AxisStreamType; requesterId: in integer; request: in integer; address: in integer; tag: in integer; count: in integer);
	procedure pcieReply(signal clk: std_logic; signal stream: inout AxisStreamType; requesterId: in integer; status: in integer; address: in integer; tag: in integer; count: in integer; data: in integer);
	procedure busWrite(signal clk: std_logic; signal toSlave: out AxilToSlaveType; signal toMaster: in AxilToMasterType; address: in integer; data: in integer);
	procedure busRead(signal clk: std_logic; signal toSlave: out AxilToSlaveType; signal toMaster: in AxilToMasterType; address: in integer);
end;

package body TestPkg is
	procedure pcieRequestWriteHead(signal clk: std_logic; signal stream: inout AxisStreamType; requesterId: in integer; request: in integer; address: in integer; tag: in integer; count: in integer) is
	variable packetHead	: PcieRequestHeadType;
	begin
		packetHead.address := to_unsigned(address, packetHead.address'length);
		packetHead.tag := to_unsigned(tag, packetHead.tag'length);
		packetHead.count := to_unsigned(count, packetHead.count'length);
		packetHead.request := to_unsigned(request, packetHead.request'length);
		packetHead.requesterId := to_unsigned(requesterId, packetHead.requesterId'length);

		-- Send Header
		wait until rising_edge(clk);
		stream.data <= to_stl(packetHead);
		stream.keep <= ones(4);
		stream.valid <= '1';
	end procedure;

	procedure pcieRequestWrite(signal clk: std_logic; signal stream: inout AxisStreamType; requesterId: in integer; request: in integer; address: in integer; tag: in integer; count: in integer; data: in integer) is
	variable packetHead	: PcieRequestHeadType;
	variable c		: integer;
	variable d		: integer;
	begin
		packetHead.address := to_unsigned(address, packetHead.address'length);
		packetHead.tag := to_unsigned(tag, packetHead.tag'length);
		packetHead.count := to_unsigned(count, packetHead.count'length);
		packetHead.request := to_unsigned(request, packetHead.request'length);
		packetHead.requesterId := to_unsigned(requesterId, packetHead.requesterId'length);

		c := count;
		d := data;

		-- Send Header
		wait until rising_edge(clk);
		stream.data <= to_stl(packetHead);
		stream.keep <= ones(4);
		stream.valid <= '1';

		while(c > 0) loop
			wait until rising_edge(clk) and (stream.ready = '1');
			
			-- Note enclodes requester ID for queue write entry
			stream.data <=  to_stl(d + 3, 32) & to_stl(d + 2, 32) & to_stl(d + 1, 32) & to_stl(requesterId, 8) & to_stl(d, 24);

			stream.keep <= keepBits(c);
			stream.valid <= '1';
			d := d + 4;
			c := c - 4;
		end loop;
		stream.last <= '1';

		wait until rising_edge(clk) and (stream.ready = '1');
		stream.valid <= '0';
		stream.last <= '0';
	end procedure;

	procedure pcieRequestRead(signal clk: std_logic; signal stream: inout AxisStreamType; requesterId: in integer; request: in integer; address: in integer; tag: in integer; count: in integer) is
	variable packetHead	: PcieRequestHeadType;
	variable c		: integer;
	variable d		: integer;
	begin
		packetHead.address := to_unsigned(address, packetHead.address'length);
		packetHead.tag := to_unsigned(tag, packetHead.tag'length);
		packetHead.count := to_unsigned(count, packetHead.count'length);
		packetHead.request := to_unsigned(request, packetHead.request'length);
		packetHead.requesterId := to_unsigned(requesterId, packetHead.requesterId'length);

		-- Write address
		wait until rising_edge(clk);
		stream.data <= to_stl(packetHead);
		stream.keep <= ones(4);
		stream.valid <= '1';
		stream.last <= '1';

		wait until rising_edge(clk) and (stream.ready = '1');
		stream.valid <= '0';
		stream.last <= '0';
	end procedure;

	procedure pcieReply(signal clk: std_logic; signal stream: inout AxisStreamType; requesterId: in integer; status: in integer; address: in integer; tag: in integer; count: in integer; data: in integer) is
	variable packetHead	: PcieReplyHeadType;
	variable c		: integer;
	variable d		: integer;
	begin
		packetHead.byteCount := to_unsigned(count * 4, packetHead.byteCount'length);
		packetHead.error := to_unsigned(0, packetHead.error'length);
		packetHead.address := to_unsigned(address, packetHead.address'length);
		packetHead.tag := to_unsigned(tag, packetHead.tag'length);
		packetHead.count := to_unsigned(count, packetHead.count'length);
		packetHead.status := to_unsigned(status, packetHead.status'length);
		packetHead.requesterId := to_unsigned(requesterId, packetHead.requesterId'length);
		c := (count + 3) / 4;
		d := data;

		-- Write address
		wait until rising_edge(clk);
		stream.data <= to_stl(d, 32) &to_stl(packetHead);
		stream.keep <= ones(4);
		stream.valid <= '1';
		d := d + 1;

		while(c > 0) loop
			wait until rising_edge(clk) and (stream.ready = '1');
			stream.data <= to_stl(d + 3, 32) & to_stl(d + 2, 32) & to_stl(d + 1, 32) & to_stl(d, 32);
			stream.valid <= '1';
			d := d + 4;
			c := c - 1;
		end loop;
		stream.last <= '1';
		stream.keep <= "0111";		-- Hard coded for multiple of 4 data words

		wait until rising_edge(clk) and (stream.ready = '1');
		stream.valid <= '0';
		stream.last <= '0';
	end procedure;
	
	procedure busWrite(signal clk: std_logic; signal toSlave: out AxilToSlaveType; signal toMaster: in AxilToMasterType; address: in integer; data: in integer) is
	begin
		-- Write address
		wait until rising_edge(clk);
		toSlave.awaddr <= to_AxilAddress(address);
		toSlave.awvalid <= '1';

		wait until rising_edge(clk) and (toMaster.awready = '1');
		toSlave.awvalid <= '0';

		-- Write data
		toSlave.wvalid <= '1';
		toSlave.wdata <= to_AxilData(data);

		wait until rising_edge(clk) and (toMaster.wready = '1');
		toSlave.wvalid <= '0';
	end procedure;

	procedure busRead(signal clk: std_logic; signal toSlave: out AxilToSlaveType; signal toMaster: in AxilToMasterType; address: in integer) is
	begin
		-- Write address
		wait until rising_edge(clk);
		toSlave.araddr <= to_AxilAddress(address);
		toSlave.arvalid <= '1';

		wait until rising_edge(clk) and (toMaster.arready = '1');
		toSlave.arvalid <= '0';

		-- Read data
		toSlave.rready <= '1';

		wait until rising_edge(clk) and (toMaster.rvalid = '1');
		toSlave.rready <= '0';
	end procedure;
end;
