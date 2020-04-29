--------------------------------------------------------------------------------
--	StreamSwitch.vhd Send PCIe packets between separate streams.
--	T.Barnaby, Beam Ltd. 2020-04-08
-------------------------------------------------------------------------------
--!
--! @class	StreamSwitch
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-08
--! @version	0.2
--!
--! @brief
--! This module implements a PCIe packet switch transfering packets between streams.
--!
--! @details
--! This switch sends PCIe packets between streams. There are two AXI streams per logical stream
--! one is for input packets and one for output packets. Streams are numbered 0 to NumStreams-1.
--! It expects Xilinx PCIe Gen3 PCIe packet headers to be used.
--! Packets are switched based on the address fields bits 27 downto 24 in the case of request packets
--! and on the requesterId field in the case of replies.
--! The switch uses a priority based on the input stream number, with 0 being the highest priority.
--! When the switch sees a valid signal on one of the streams and its desitation stream is ready then
--! the switch will send a complete packet, using the "last" signal to denote the end of packet.
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

entity StreamSwitch is
generic(
	NumStreams	: integer	:= 8			--! The number of stream
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisArrayType(0 to NumStreams-1) := (others => AxisInput);	--! Input stream
	streamOut	: inout AxisArrayType(0 to NumStreams-1) := (others => AxisOutput)	--! Output stream
);
end;

architecture Behavioral of streamSwitch is

constant TCQ		: time := 1 ns;

type StateType		is (SWITCH_STATE_IDLE, SWITCH_STATE_TRANSFER);

signal switchState	: StateType := SWITCH_STATE_IDLE;
signal switchIn		: integer range 0 to NumStreams-1 := 0;
signal switchOut	: integer range 0 to NumStreams-1 := 0;

function streamOutNum(header: std_logic_vector) return integer is
variable num: integer;
begin
	if(to_PcieReplyHeadType(header).reply = '1') then
		num := to_integer(to_PcieReplyHeadType(header).requesterId);
	else
		num := to_integer(to_PcieRequestHeadType(header).address(27 downto 24));
	end if;

	return num;
end function;

begin
	switch: for i in 0 to NumStreams-1 generate
		streamIn(i).ready	<= streamOut(switchOut).ready when((switchState = SWITCH_STATE_TRANSFER) and (i = switchIn)) else '0';
		streamOut(i).valid	<= streamIn(switchIn).valid when((switchState = SWITCH_STATE_TRANSFER) and (i = switchOut)) else '0';
		streamOut(i).last	<= streamIn(switchIn).last when((switchState = SWITCH_STATE_TRANSFER) and (i = switchOut)) else '0';
		streamOut(i).keep	<= streamIn(switchIn).keep when((switchState = SWITCH_STATE_TRANSFER) and (i = switchOut)) else (others => '0');
		streamOut(i).data	<= streamIn(switchIn).data when((switchState = SWITCH_STATE_TRANSFER) and (i = switchOut)) else (others => '0');
	end generate;

	-- Process stream
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				switchState <= SWITCH_STATE_IDLE;
			else
				case(switchState) is
				when SWITCH_STATE_IDLE =>
					-- Decide on which swtream to send to based on valid and ready signals in stream number priority order (stream 0 highest)
					for i in 0 to NumStreams-1 loop
						if((streamIn(i).valid = '1') and (streamOut(streamOutNum(streamIn(i).data)).ready = '1')) then
							switchIn	<= i;
							switchOut	<= streamOutNum(streamIn(i).data);
							switchState	<= SWITCH_STATE_TRANSFER;
							exit;
						end if;
					end loop;

				when SWITCH_STATE_TRANSFER =>
					if((streamOut(switchOut).ready = '1') and (streamIn(switchIn).valid = '1') and (streamIn(switchIn).last = '1')) then
						switchState <= SWITCH_STATE_IDLE;
					end if;

				end case;
			end if;
		end if;
	end process;
end;
