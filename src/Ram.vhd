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
--! This is a simple RAM element written so that blockram can be easily infered by synthesis tools.
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
