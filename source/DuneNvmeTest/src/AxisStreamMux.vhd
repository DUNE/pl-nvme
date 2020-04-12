--------------------------------------------------------------------------------
--	AxisStreamMux.vhd Multiplex two streams with header
--	T.Barnaby, Beam Ltd. 2020-04-08
-------------------------------------------------------------------------------
--!
--! @class	AxisStreamMux
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-08
--! @version	0.0.1
--!
--! @brief
--! This module multiplexes two 128bit Axis streams using a 128bit header
--!
--! @details
--! 
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
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.AxiPkg.all;

entity AxisStreamMux is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn1	: inout AxisStream := AxisInput;	--! Input data stream
	streamIn2	: inout AxisStream := AxisInput;	--! Input data stream

	streamOut	: inout AxisStream := AxisOutput	--! Output data stream
);
end;

architecture Behavioral of AxisStreamMux is

constant TCQ		: time := 1 ns;
type StateType is (STATE_START, STATE_SENDHEAD, STATE_SENDPACKET);

signal state	: StateType := STATE_START;
signal stream	: unsigned(1 downto 0) := (others => '0');

begin
	-- Multiplex streams. Provides 128 bit header word providing source stream number
	streamOut.valid <= '1' when(STATE = STATE_SENDHEAD)
		else streamIn1.valid when((STATE = STATE_SENDPACKET) and (stream = 1))
		else streamIn2.valid when((STATE = STATE_SENDPACKET) and (stream = 2))
		else '0';
	streamOut.last <= streamIn1.last when((STATE = STATE_SENDPACKET) and (stream = 1))
		else streamIn2.last when((STATE = STATE_SENDPACKET) and (stream = 2))
		else '0';
	streamOut.keep <= streamIn1.keep when((STATE = STATE_SENDPACKET) and (stream = 1))
		else streamIn2.keep when((STATE = STATE_SENDPACKET) and (stream = 2))
		else (others => '1');
	streamOut.data <= streamIn1.data when((STATE = STATE_SENDPACKET) and (stream = 1))
		else streamIn2.data when((STATE = STATE_SENDPACKET) and (stream = 2))
		else concat('0', streamOut.data'length - stream'length) & std_logic_vector(stream);
	streamIn1.ready <= streamOut.ready when((STATE = STATE_SENDPACKET) and (stream = 1)) else '0';
	streamIn2.ready <= streamOut.ready when((STATE = STATE_SENDPACKET) and (stream = 2)) else '0';

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				stream <= (others => '0');
				state <= STATE_START;
			else
				case(state) is
				when STATE_START =>
					if((streamIn1.valid = '1') and (streamOut.ready = '1')) then
						stream <= to_unsigned(1, stream'length);
						state <= STATE_SENDHEAD;
					elsif((streamIn2.valid = '1') and (streamOut.ready = '1')) then
						stream <= to_unsigned(2, stream'length);
						state <= STATE_SENDHEAD;
					end if;

				when STATE_SENDHEAD =>
					if((streamOut.valid = '1') and (streamOut.ready = '1')) then
						state <= STATE_SENDPACKET;
					end if;

				when STATE_SENDPACKET =>
					if((streamOut.valid = '1') and (streamOut.ready = '1') and (streamOut.last = '1')) then
						stream <= to_unsigned(0, stream'length);
						state <= STATE_START;
					end if;
				end case;
			end if;
		end if;
	end process;
end;
