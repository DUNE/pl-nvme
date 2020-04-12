--------------------------------------------------------------------------------
--	AxisStreamDeMux.vhd De-multiplex a streams into two using header
--	T.Barnaby, Beam Ltd. 2020-04-08
-------------------------------------------------------------------------------
--!
--! @class	AxisStreamDeMux
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-08
--! @version	0.0.1
--!
--! @brief
--! This module de-multiplexes a 128bit Axis stream into two streams using the 128bit header
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

entity AxisStreamDeMux is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisStream := AxisInput;	--! Input data stream

	streamOut1	: inout AxisStream := AxisOutput;	--! Output data stream1
	streamOut2	: inout AxisStream := AxisOutput	--! Output data stream2
);
end;

architecture Behavioral of AxisStreamDeMux is

constant TCQ		: time := 1 ns;
type StateType is (STATE_START, STATE_SENDPACKET);

signal state	: StateType := STATE_START;
signal stream	: unsigned(1 downto 0) := (others => '0');

begin
	-- De-multiplex host -> nvme streams. Expects 128 bit header word providing destination stream number
	streamIn.ready <= '1' when(state = STATE_START)
		else streamOut1.ready when(stream = 1)
		else streamOut2.ready when(stream = 2)
		else '0';

	streamOut1.valid <= streamIn.valid when((state = STATE_SENDPACKET) and (stream = 1)) else '0';
	streamOut1.last <= streamIn.last;
	streamOut1.keep <= streamIn.keep;
	streamOut1.data <= streamIn.data;
	
	streamOut2.valid <= streamIn.valid when((state = STATE_SENDPACKET) and (stream = 2)) else '0';
	streamOut2.last <= streamIn.last;
	streamOut2.keep <= streamIn.keep;
	streamOut2.data <= streamIn.data;

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				stream <= (others => '0');
				state <= STATE_START;
			else
				case(state) is
				when STATE_START =>
					if((streamIn.valid = '1') and (streamIn.ready = '1')) then
						stream <= unsigned(streamIn.data(1 downto 0));
						state <= STATE_SENDPACKET;
					end if;

				when STATE_SENDPACKET =>
					if((streamIn.valid = '1') and (streamIn.ready = '1') and (streamIn.last = '1')) then
						state <= STATE_START;
					end if;
				end case;
			end if;
		end if;
	end process;
end;
