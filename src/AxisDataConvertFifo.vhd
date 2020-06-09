--------------------------------------------------------------------------------
-- AxisDataConvertFifo.vhd AXI Stream clock domain crossing
--------------------------------------------------------------------------------
--!
--! @class	AxisDataConvertFifo
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-15
--! @version	1.0.0
--!
--! @brief
--! AXI Stream data Fifo with conversion from 256 to 128 bits.
--!
--! @details
--! This module accepts an AxisDataStreamType AXI4 type data stream with 256 bit width data.
--! It performs a Fifo function outputing the data on a 128 bit wide AxisStreamType AXI4 type stream.
--! The last signal is passed through the Fifo.
--! The FIFO depth is configurable with the FifoSizeBytes parameter which is in Bytes. For the NvmeStorage
--! system this is normally set to the block size of 4096 Bytes.
--! The modules uses block RAM to store the data.
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
constant DataWidth	: integer := AxisDataStreamWidth + 1;

component Fifo is
generic (
	Simulate	: boolean := Simulate;				--! Simulation
	DataWidth	: integer := DataWidth;				--! The data width of the Fifo in bits
	Size		: integer := FifoSize;				--! The size of the fifo
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
end component;

signal writeData	: std_logic_vector(DataWidth-1 downto 0) := (others => '0');
signal readData		: std_logic_vector(DataWidth-1 downto 0) := (others => 'U');

signal readDataReady	: std_logic := '0';
signal readDataValid	: std_logic := '0';
signal readDataHigh	: std_logic_vector(127 downto 0) := (others => '0');
signal readLastHigh	: std_logic := '0';
signal readHigh		: std_logic := '0';

begin
	--! Fifo memory
	fifo0 : Fifo
	port map (
		clk		=> clk,
		reset		=> reset,

		inReady		=> streamRx_ready,
		inValid		=> streamRx.valid,
		indata		=> writeData,

		outReady	=> readDataReady,
		outValid	=> readDataValid,
		outdata		=> readData
	);

	--! Fifo input
	writeData		<= streamRx.last & streamRx.data;
	
	--! Data bit width conversion and output
	readDataReady		<= streamTx.ready when(readHigh = '0') else '0';
	streamTx.valid		<= readDataValid or readHigh;
	streamTx.last		<= readLastHigh when(readHigh = '1') else '0';
	streamTx.data		<= readDataHigh when(readHigh) = '1' else readData(127 downto 0);

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				readHigh	<= '0';
				readDataHigh	<= (others => '0');
				readLastHigh	<= '0';

			else
				-- Handle Fifo output
				if((readDataValid = '1') and (readHigh = '0')) then
					readDataHigh	<= readData(255 downto 128);
					readLastHigh	<= readData(256);
				end if;

				-- Handle bit width change
				if((streamTx.valid = '1') and (streamTx.ready = '1')) then
					readHigh <= not readHigh;
				end if;
			end if;
		end if;
	end process;
end;

