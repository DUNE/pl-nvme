--------------------------------------------------------------------------------
-- Ram.vhd Simple RAM which will be implemented in blockram if large
-------------------------------------------------------------------------------
--!
--! @class	Ram
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-09
--! @version	1.0.0
--!
--! @brief
--! This module provides a simple dual ported RAM module that will be implemented in blockram if large enough.
--!
--! @details
--! This is a simple single clock dual ported RAM element written so that blockram can be easily infered by synthesis tools.
--! The data width and size of the RAM are configurable parameters.
--! Writes to memory happen in 1 clock cycle when the writeEnable signal is high.
--! Reads from memory take two clock cycles. One to latch the read address and one for the readData to become available.
--! There is a RegisterOutputs option on the readData output that will use the block RAM's
--! internal data register for better system timing. This will add an additional 1 cycle latency on
--! memory reads.
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

entity Ram is
generic (
	DataWidth	: integer := 128;			--! The data width of the RAM in bits
	Size		: integer := 4096;			--! The size in RAM locations
	--AddressWidth	: integer := log2(Size);		--! will work with VHDL 08+
	AddressWidth	: integer := 13;
	RegisterOutputs	: boolean := False			--! Register the outputs
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	writeEnable	: in std_logic;
	writeAddress	: in unsigned(AddressWidth-1 downto 0);	
	writeData	: in std_logic_vector(DataWidth-1 downto 0);	

	readEnable	: in std_logic;
	readAddress	: in unsigned(AddressWidth-1 downto 0);	
	readData	: out std_logic_vector(DataWidth-1 downto 0)	
);
end;

architecture Behavioral of Ram is

constant TCQ		: time := 1 ns;

-- Simple RAM buffer, will be implemented in BlockRam by inferance
type MemoryType		is array(0 to Size-1) of std_logic_vector(DataWidth-1 downto 0);
signal memory		: MemoryType := (others => (others => '0'));
signal readDataReg	: std_logic_vector(DataWidth-1 downto 0);

attribute ram_style	: string;
attribute ram_style	of memory : signal is "block";

begin
	-- Read from and write to memory
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(writeEnable = '1') then
				memory(to_integer(writeAddress)) <= writeData;
			end if;

			if(readEnable = '1') then
				if(RegisterOutputs) then
					readData <= readDataReg;
					readDataReg <= memory(to_integer(readAddress));
				else
					readData <= memory(to_integer(readAddress));
				end if;
			end if;
		end if;
	end process;
end;
