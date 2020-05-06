--------------------------------------------------------------------------------
--	DataBuffer.vhd NvmeStorage data input fifo
--	T.Barnaby, Beam Ltd. 2020-04-07
-------------------------------------------------------------------------------
--!
--! @class	DataBuffer
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-07
--! @version	0.0.1
--!
--! @brief
--! This module provides a data input fifo for the NvmeWrite module.
--!
--! @details
--! This FIFO will store a complete DataWiteChunk's worth of data, 32 kBytes.
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

entity DataBuffer is
generic (
	Simulate	: boolean := False;			--! Generate simulation core
	Size		: integer := 4096;			--! The Buffer size in 128 bit words
	--AddressWidth	: integer := log2(Size)
	AddressWidth	: integer := 13
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	writeEnable	: in std_logic;
	writeAddress	: in unsigned(AddressWidth-1 downto 0);	
	writeData	: in std_logic_vector(127 downto 0);	

	readEnable	: in std_logic;
	readAddress	: in unsigned(AddressWidth-1 downto 0);	
	readData	: out std_logic_vector(127 downto 0)	
);
end;

architecture Behavioral of DataBuffer is

constant TCQ		: time := 1 ns;

-- Simple RAM buffer, will be implemented in BlockRam by inferance
type RamType		is array(0 to Size-1) of std_logic_vector(127 downto 0);
signal ram		: RamType := (others => zeros(128));

attribute ram_style	: string;
attribute ram_style	of ram : signal is "block";

begin
	-- Write to memory
	write: process(clk)
	begin
		if(rising_edge(clk)) then
			if(writeEnable = '1') then
				ram(to_integer(writeAddress)) <= writeData;
			end if;
			if(readEnable = '1') then
				readData <= ram(to_integer(readAddress));
			end if;
		end if;
	end process;
end;
