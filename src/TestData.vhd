--------------------------------------------------------------------------------
-- TestData.vhd Simple AXIS test data source
-------------------------------------------------------------------------------
--!
--! @class	TestData
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-12
--! @version	1.0.0
--!
--! @brief
--! This module provides a simple test data source for testing the NvmeStorage system.
--!
--! @details
--! This module provides a sequence of 32bit incrementing values over a <n> bit wide AXI4 stream (multiple of 32 bits).
--! It sets the AXI4 streams last signal in the last word transfer of a configurable BlockSize block of data.
--! the enable signal enables its operation and when set to 0 clears its state back to intial reset state.
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
	BlockSize	: integer := NvmeStorageBlockSize	--! The block size in Bytes.
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	enable		: in std_logic;				--! Enable production of data. Clears to reset state when set to 0.

	-- AXIS data output
	dataOut		: out AxisDataStreamType;		--! Output data stream
	dataOutReady	: in std_logic				--! Ready signal for output data stream
);
end;

architecture Behavioral of TestData is

constant TCQ		: time := 1 ns;
constant DataWidth	: integer := dataOut.data'length;	-- The bit width of the data stream
constant BytesPerWord	: integer := (DataWidth / 8);		-- Number of bytes per Axis data word

signal dataValid	: std_logic := '0';
signal data		: unsigned(31 downto 0) := (others => '0');
signal countBlock	: unsigned(log2(BlockSize/BytesPerWord)-1 downto 0) := (others => '0');

-- Produce the next DataWidth item
function dataValue(v: unsigned) return std_logic_vector is
variable ret: std_logic_vector(DataWidth-1 downto 0);
begin
	for i in 0 to (DataWidth/32)-1 loop
		ret((i*32)+31 downto (i*32)) := std_logic_vector(v + i);
	end loop;
	
	return ret;
end;

begin
	-- Output incrementing data stream
	dataOut.valid	<= dataValid;
	dataOut.data	<= dataValue(data);
	dataOut.last	<= '1' when(countBlock = (BlockSize/BytesPerWord) - 1) else '0';
		
	-- Generate data stream
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				data		<= (others => '0');
				countBlock	<= (others => '0');
				dataValid	<= '0';
			else
				if(enable = '1') then
					dataValid <= '1';
					if((dataValid = '1') and (dataOutReady = '1')) then
						data		<= data + (DataWidth / 32);
						countBlock	<= countBlock + 1;
					end if;
				else
					data		<= (others => '0');
					countBlock	<= (others => '0');
					dataValid	<= '0';
				end if;
			end if;
		end if;
	end process; 
end;
