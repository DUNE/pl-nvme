--------------------------------------------------------------------------------
-- TestDataStream.vhd Simple AXIS test data source
-------------------------------------------------------------------------------
--!
--! @class	TestDataStream
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-07
--! @version	1.0.0
--!
--! @brief
--! This module provides a simple test data source for testing the NvmeStorage system.
--!
--! @details
--! This module provides a sequence of 32bit incrementing values over a 128 bit wide AXI stream.
--! It sets the Axi streams last signal in the last word transfer of a configurable BlockSize block of data.
--! the enable signal enables it's operation and when set to 0 clears its state back to intial reset state.
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

entity TestDataStream is
generic(
	BlockSize	: integer := NvmeStorageBlockSize	--! The block size in Bytes.
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	enable		: in std_logic;				--! Enable production of data. Clears to reset state when set to 0.

	-- AXIS data output
	dataOut		: inout AxisStreamType := AxisStreamOutput	--! Output data stream
);
end;

architecture Behavioral of TestDataStream is

constant TCQ		: time := 1 ns;
constant BytesPerWord	: integer := 16;	-- Number of bytes per Axis data word

signal data		: unsigned(31 downto 0) := (others => '0');
signal countBlock	: unsigned(log2(BlockSize/BytesPerWord)-1 downto 0) := (others => '0');

begin
	-- Output incrementing data stream
	dataOut.data <= std_logic_vector((data + 3) & (data + 2) & (data + 1) & data);
	dataOut.keep <= ones(dataOut.keep'length);
	dataOut.last <= '1' when(countBlock = (BlockSize/BytesPerWord) - 1) else '0';
		
	-- Generate data stream
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				data		<= (others => '0');
				countBlock	<= (others => '0');
				dataOut.valid	<= '0';
			else
				if(enable = '1') then
					dataOut.valid <= '1';
					if((dataOut.valid = '1') and (dataOut.ready = '1')) then
						data		<= data + 4;
						countBlock	<= countBlock + 1;
					end if;
				else
					data		<= (others => '0');
					countBlock	<= (others => '0');
					dataOut.valid	<= '0';
				end if;
			end if;
		end if;
	end process; 
end;
