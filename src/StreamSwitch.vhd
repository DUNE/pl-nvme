--------------------------------------------------------------------------------
-- StreamSwitch.vhd Send PCIe packets between separate streams.
-------------------------------------------------------------------------------
--!
--! @class	StreamSwitch
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-08
--! @version	1.0.0
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
--! A special bit, 29, is set in the reply header to indicate that the packet is a reply type.
--! The switch uses a priority based on the input stream number, with 0 being the highest priority.
--! When the switch sees a valid signal on one of the streams and its desitation stream is ready then
--! the switch will send a complete packet, using the "last" signal to denote the end of packet.
--! Note this simple implementation can only send one packet at a time.
--! This simple switch only allows one packet to be transfered at a time and uses unregistered outputs
--! to reduce latency.
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
	NumStreams	: integer	:= 8			--! The number of streams
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisStreamArrayType(0 to NumStreams-1) := (others => AxisStreamInput);	--! Input streams
	streamOut	: inout AxisStreamArrayType(0 to NumStreams-1) := (others => AxisStreamOutput)	--! Output streams
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
					-- Decide on which stream to send to based on valid and ready signals in stream number priority order (stream 0 highest)
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
