--------------------------------------------------------------------------------
--	TestData.vhd Simple AXIS test data source
--	T.Barnaby, Beam Ltd. 2020-04-07
-------------------------------------------------------------------------------
--!
--! @class	TestData
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-07
--! @version	0.0.1
--!
--! @brief
--! This module provides a simple test data source for testing the NvmeStorage system.
--!
--! @details
--! This module provides a sequence of 32bit incrementing values over a 128 bit wide AXI stream.
--! It sets the Axi streams last signal in the last word transfer of a configurable BlockSize block of data.
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

entity TestData is
generic(
	BlockSize	: integer := 4096			--! The block size in Bytes.
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	enable		: in std_logic;				--! Enable production of data

	-- AXIS data output
	dataStream	: inout AxisStreamType := AxisOutput	--! Output data stream
);
end;

architecture Behavioral of TestData is

constant TCQ		: time := 1 ns;
constant BytesPerWord	: integer := 16;	-- Number of bytes per Axis data word

signal data		: unsigned(31 downto 0) := (others => '0');
signal countBlock	: unsigned(log2(BlockSize/BytesPerWord)-1 downto 0) := (others => '0');

begin
	-- Output incrementing data stream
	dataStream.data <= std_logic_vector((data + 3) & (data + 2) & (data + 1) & data);
		
	-- Generate data stream
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				data			<= (others => '0');
				dataStream.valid	<= '0';
				dataStream.last		<= '0';
			else
				if(enable = '1') then
					dataStream.valid <= '1';
				else
					dataStream.valid <= '0';
				end if;
				
				if((enable = '1') and (dataStream.valid = '1') and (dataStream.ready = '1')) then
					data <= data + 4;
					countBlock <= countBlock + 1;
				end if;
				
				if(countBlock = (BlockSize/BytesPerWord) - 2) then
					dataStream.last <= '1';
				else
					dataStream.last <= '0';
				end if;
			end if;
		end if;
	end process; 
end;
