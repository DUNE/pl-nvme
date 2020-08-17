--------------------------------------------------------------------------------
-- Fifo.vhd Simple FWFT Fifo
-------------------------------------------------------------------------------
--!
--! @class	Fifo
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-08-11
--! @version	1.0.1
--!
--! @brief
--! This module provides a simple, single clocked FWFT FIFO.
--!
--! @details
--! This is a simple single clock first word fall through FIFO.
--! Its data storage memory will be implemented in registers for small Fifo's and
--! in BlockRAM for larger Fifos the Size parameter defining the depth of the Fifo.
--! The data width is defined by the DataWidth parameter.
--! It has a programmable nearFull output that can be enabled by setting the
--! NearFullLevel parameter to the appropriate Fifo level.
--! The RegisterOutputs parameter provides registered output of the data for better system timing
--! at the expense of one cycle of latency.
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

entity Fifo is
generic (
	Simulate	: boolean := False;				--! Simulation
	DataWidth	: integer := 128;				--! The data width of the Fifo in bits
	Size		: integer := 2;					--! The size of the fifo
	NearFullLevel	: integer := 0;					--! Nearly full level, 0 disables
	RegisterOutputs	: boolean := False				--! Register the outputs
);
port (
	clk		: in std_logic;					--! The interface clock line
	reset		: in std_logic;					--! The active high reset line
	
	nearFull	: out std_logic;				--! Fifo is nearly full

	inReady		: out std_logic;				--! Fifo is ready for input
	inValid		: in std_logic;					--! Data input is valid
	inData		: in std_logic_vector(DataWidth-1 downto 0);	--! The input data


	outReady	: in std_logic;					--! The external logic is ready for output
	outValid	: out std_logic;				--! The data output is available
	outData		: out std_logic_vector(DataWidth-1 downto 0)	--! The output data
);
end;

architecture Behavioral of Fifo is

constant TCQ		: time := 1 ns;

type MemoryType		is array(0 to Size-1) of std_logic_vector(DataWidth-1 downto 0);
signal memory		: MemoryType := (others => (others => 'U'));

signal count		: integer range 0 to Size+1;			--! Count of number of FIFO items.
signal writePos		: integer range 0 to Size-1;			--! The write position pointer
signal readPos		: integer range 0 to Size-1;			--! The read position pointer
signal posLooped	: boolean := False;				--! The write pointer has looped around behind the read pointer
signal writeReady	: std_logic;					--! There is space to write to the FIFO
signal writeEnable	: std_logic;					--! Write data to the FIFO
signal readReady	: std_logic;					--! There is space to write to the FIFO
signal readEnable	: std_logic;					--! Read data from the RAM
signal readOutput	: std_logic;					--! Read data from the FIFO
signal outValidl	: std_logic;					--! Local outValid

begin
	-- Handle data input
	writeReady	<= '1' when((reset = '0') and (not posLooped or (readPos /= writePos))) else '0';
	writeEnable	<= inValid when(writeReady = '1') else '0';
	inReady		<= writeReady;
	nearFull	<= '1' when(count >= NearFullLevel) else '0';
	outValid	<= outValidl;

	noreg: if(RegisterOutputs = False) generate
		readReady	<= '1' when((reset = '0') and ((posLooped) or (writePos /= readPos))) else '0';
		readEnable	<= outReady when(readReady = '1') else '0';
		readOutput	<= outValidl and outReady;
		outData		<= memory(readPos);
		outValidl	<= readReady;

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
						memory(writePos) <= inData;

						if(writePos = Size-1) then
							writePos	<= 0;
							posLooped	<= True;
						else 
							writePos <= writePos + 1;
						end if;
					end if;

					-- Handle Fifo output
					if(readEnable = '1') then
						if(readPos = Size-1) then
							readPos		<= 0;
							posLooped	<= False;
						else 
							readPos <= readPos + 1;
						end if;
					end if;

					-- Contents counter logic
					if(NearFullLevel > 0) then
						if((writeEnable = '1') and (readOutput = '0')) then
							count <= count + 1;
						elsif((writeEnable = '0') and (readOutput = '1')) then
							count <= count - 1;
						end if;
					end if;

				end if;
			end if;
		end process;
	end generate;

	reg: if(RegisterOutputs = True) generate
		readReady	<= '1' when((reset = '0') and ((posLooped) or (writePos /= readPos))) else '0';
		readEnable	<= readReady when((outValidl = '0') or (outReady = '1')) else '0';
		readOutput	<= outValidl and outReady;

		process(clk)
		begin
			if(rising_edge(clk)) then
				if(reset = '1') then
					writePos	<= 0;
					readPos		<= 0;
					posLooped	<= False;
					count		<= 0;
					outData  	<= (others => 'U');
					outValidl	<= '0';
				else
					-- Handle Fifo input
					if(writeEnable = '1') then
						memory(writePos) <= inData;

						if(writePos = Size-1) then
							writePos	<= 0;
							posLooped	<= True;
						else 
							writePos <= writePos + 1;
						end if;
					end if;

					-- Handle Fifo output
					if(readEnable = '1') then
						outData		<= memory(readPos);
						outValidl	<= '1';

						if(readPos = Size-1) then
							readPos		<= 0;
							posLooped	<= False;
						else 
							readPos <= readPos + 1;
						end if;

					elsif((readReady = '0') and (outReady = '1')) then
						outValidl	<= '0';
					end if;
					
					-- Contents counter logic
					if(NearFullLevel > 0) then
						if((writeEnable = '1') and (readOutput = '0')) then
							count <= count + 1;
						elsif((writeEnable = '0') and (readOutput = '1')) then
							count <= count - 1;
						end if;
					end if;
					
				end if;
			end if;
		end process;
	end generate;
end;
