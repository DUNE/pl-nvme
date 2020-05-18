--------------------------------------------------------------------------------
-- AxisDataConvertFifo.vhd AXI Stream clock domain crossing
--------------------------------------------------------------------------------
--!
--! @class	AxisDataConvertFifo
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-15
--! @version	0.5.1
--!
--! @brief
--! AXI Stream data Fifo with conversion from 256 to 128 bits.
--!
--! @details
--! This module accepts an AxisDataStreamType AXI4 type data stream with 256 bit width data.
--! It performs a Fifo function outputing the data on a 128 bit wide AxisStreamType AXI4 type stream.
--! The last signal is passed through the Fifo.
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

library work;
use work.NvmeStoragePkg.all;
use work.NvmeStorageIntPkg.all;


entity AxisDataConvertFifo is
generic(
	Simulate	: boolean	:= False;			--! Enable simulation core
	FifoSizeBytes	: integer	:= NvmeStorageBlockSize		--! The Fifo size in bytes
);
port (
	clk		: in std_logic;					--! Module clock
	reset		: in std_logic;					--! Module reset line. Clears Fifo

	streamRx	: in AxisDataStreamType;			--! Input data stream
	streamRx_ready	: out std_logic;				--! Ready signal for input data stream

	streamTx	: inout AxisStreamType := AxisStreamOutput	--! Output data stream
);
end;

architecture Behavioral of AxisDataConvertFifo is

constant TCQ		: time := 1 ns;
constant FifoSize	: integer := (FifoSizeBytes * 8 / AxisDataStreamWidth);
constant AddressWidth	: integer := log2_roundup(FifoSize);
constant DataWidth	: integer := AxisDataStreamWidth + 1;

component Ram is
generic (
	DataWidth	: integer := DataWidth;			--! The data width of the RAM in bits
	Size		: integer := FifoSize;			--! The size in RAM locations
	AddressWidth	: integer := AddressWidth
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
end component;

signal streamRx_readyl	: std_logic;
signal writeEnable	: std_logic;
signal writeData	: std_logic_vector(DataWidth-1 downto 0) := (others => '0');

signal readEnable	: std_logic;
signal readData		: std_logic_vector(DataWidth-1 downto 0) := (others => 'U');

signal writePos		: unsigned(AddressWidth-1 downto 0) := (others => '0');
signal readPos		: unsigned(AddressWidth-1 downto 0) := (others => '0');
signal posLooped	: boolean := False;

signal readDataValid	: std_logic := '0';
signal readDataReady	: std_logic := '0';
signal readDataHigh	: std_logic_vector(127 downto 0) := (others => '0');
signal readHigh		: boolean := False;

begin
	-- Fifo memory
	fifoMem : Ram
	port map (
		clk		=> clk,
		reset		=> reset,

		writeEnable	=> writeEnable,
		writeAddress	=> writePos,
		writeData	=> writeData,

		readEnable	=> '1',
		readAddress	=> readPos,
		readData	=> readData
	);

	-- Fifo input
	streamRx_readyl		<= '1' when(not posLooped or (readPos /= writePos)) else '0';
	streamRx_ready		<= streamRx_readyl;
	writeEnable		<= streamRx.valid and streamRx_readyl when((not posLooped) or (writePos /= readPos)) else '0';
	writeData		<= streamRx.last & streamRx.data;
	
	readEnable		<= readDataReady when((readDataValid = '1') and ((posLooped) or (writePos /= readPos))) else '0';

	-- Data bit width conversion and output
	readDataReady		<= streamTx.ready when(not readHigh) else '0';
	streamTx.valid		<= readDataValid;
	streamTx.last		<= readData(256) when(readHigh) else '0';
	streamTx.data		<= readDataHigh when(readHigh) else readData(127 downto 0);

	fifo: process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				writePos	<= (others => '0');
				readPos		<= (others => '0');
				posLooped	<= False;
				readHigh	<= False;
				readDataValid	<= '0';

			else
				-- Handle Fifo input
				if(writeEnable = '1') then
					if(writePos = FifoSize-1) then
						writePos	<= (others => '0');
						posLooped	<= True;
					else 
						writePos <= writePos + 1;
					end if;
				end if;
				
				-- Handle Fifo output
				if(readEnable = '1') then
					readDataHigh <= readData(255 downto 128);

					if(readPos = FifoSize-1) then
						readPos		<= (others => '0');
						posLooped	<= False;
					else 
						readPos <= readPos + 1;
					end if;
				end if;

				-- Handle Fifo full
				if(readPos = writePos) then
					if(posLooped) then
						readDataValid	<= '1';
					else
						readDataValid	<= '0';
					end if;
				else
					readDataValid	<= '1';
				end if;
				
				-- Handle bit width change
				if((streamTx.valid = '1') and (streamTx.ready = '1')) then
					readHigh <= not readHigh;
				end if;
			end if;
		end if;
	end process;
end;

