--------------------------------------------------------------------------------
-- Fifo.vhd Simple FWFT Fifo
-------------------------------------------------------------------------------
--!
--! @class	Fifo
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-06-03
--! @version	1.0.0
--!
--! @brief
--! This module provides a simple, single clocked FWFT FIFO.
--!
--! @details
--! This is a simple single clock first word fall through FIFO.
--! Its data storage memory will be implemented in registers for small Fifo's and
--! in BlockRAM for larger Fifos the FifoSize parameter defining the depth of the Fifo.
--! The data width is defined by the DataWidth parameter.
--! It has a programmable fifoNearFull output that can be enabled by setting the
--! NearFull parameter to the appropriate Fifo level.
--! The RegisterOutputs parameter provides registered output of the data for better system timing
--! at the expense of one cycle of latency.
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

entity Fifo is
generic (
	DataWidth	: integer := 128;				--! The data width of the Fifo in bits
	FifoSize	: integer := 2;					--! The size of the fifo
	NearFull	: integer := 0;					--! Nearly full level, 0 disables
	RegisterOutputs	: boolean := False				--! Register the outputs
);
port (
	clk		: in std_logic;					--! The interface clock line
	reset		: in std_logic;					--! The active high reset line
	
	fifoNearFull	: out std_logic;				--! Fifo is nearly full

	fifoInReady	: out std_logic;				--! Fifo is ready for input
	fifoInValid	: in std_logic;					--! Data input is valid
	fifoIn		: in std_logic_vector(DataWidth-1 downto 0);	--! The input data


	fifoOutReady	: in std_logic;					--! The external logic is ready for output
	fifoOutValid	: out std_logic;				--! The data output is available
	fifoOut		: out std_logic_vector(DataWidth-1 downto 0)	--! The output data
);
end;

architecture Behavioral of Fifo is

constant TCQ		: time := 1 ns;

type MemoryType		is array(0 to FifoSize-1) of std_logic_vector(DataWidth-1 downto 0);
signal memory		: MemoryType := (others => (others => 'U'));

signal count		: integer range 0 to FifoSize;			--! Count of number of FIFO items.
signal writePos		: integer range 0 to FifoSize-1;		--! The write position pointer
signal readPos		: integer range 0 to FifoSize-1;		--! The read position pointer
signal posLooped	: boolean := False;				--! The write pointer has looped around behind the read pointer
signal writeReady	: std_logic;					--! There is space to write to the FIFO
signal writeEnable	: std_logic;					--! Write data to the FIFO
signal readEnable	: std_logic;					--! Read data from the FIFO

begin
	writeReady	<= '1' when(not posLooped or (readPos /= writePos)) else '0';
	writeEnable	<= fifoInValid when(writeReady = '1') else '0';
	fifoInReady	<= writeReady;
	fifoNearFull	<= '1' when(count >= NearFull) else '0';

	readEnable	<= fifoOutReady when((posLooped) or (writePos /= readPos)) else '0';
	fifoOutValid	<= '1' when((posLooped) or (writePos /= readPos)) else '0';
	
	-- Handle data output
	noreg: if(RegisterOutputs = False) generate
		fifoOut <= memory(readPos);
	end generate;

	reg: if(RegisterOutputs = True) generate
	process(clk)
	begin
		if(rising_edge(clk)) then
			-- Handle Fifo output
			if(readEnable = '1') then
				fifoOut <= memory(readPos);
			end if;
		end if;
	end process;
	end generate;


	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				writePos	<= 0;
				readPos		<= 0;
				posLooped	<= False;
				count		<= 0;
				
			else
				-- Handle Fifo input
				if(writeEnable = '1') then
					memory(writePos) <= fifoIn;

					if(writePos = FifoSize-1) then
						writePos	<= 0;
						posLooped	<= True;
					else 
						writePos <= writePos + 1;
					end if;
				end if;
				
				-- Handle Fifo output
				if(readEnable = '1') then
					if(readPos = FifoSize-1) then
						readPos		<= 0;
						posLooped	<= False;
					else 
						readPos <= readPos + 1;
					end if;
				end if;

				-- Contents counter logic
				if(NearFull > 0) then
					if((writeEnable = '1') and (readEnable = '0')) then
						count <= count + 1;
					elsif((writeEnable = '0') and (readEnable = '1')) then
						count <= count - 1;
					end if;
				end if;
				
			end if;
		end if;
	end process;
end;
