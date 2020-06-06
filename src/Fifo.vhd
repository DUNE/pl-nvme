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
--! in BlockRAM for larger Fifos (>= 32) the Size parameter defining the depth of the Fifo.
--! The data width is defined by the DataWidth parameter.
--! It has a programmable nearFull output that can be enabled by setting the
--! NearFullLevel parameter to the appropriate Fifo level.
--! The module uses the Xilinx xpm_fifo_sync macro for larger Fifo sizes such that the
--! RAM/FIFO hard blocks will be used in this case.
--! The Simulate option disable the use of the Xilinx xpm_fifo_sync macro.
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
	Simulate	: boolean := False;				--! Simulation
	DataWidth	: integer := 128;				--! The data width of the Fifo in bits
	Size		: integer := 2;					--! The size of the fifo
	NearFullLevel	: integer := 0					--! Nearly full level, 0 disables
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

component xpm_fifo_sync
generic (
	DOUT_RESET_VALUE	: string := "0";
	ECC_MODE		: string :=  "no_ecc";
	FIFO_MEMORY_TYPE	: string :=  "auto";
	FIFO_READ_LATENCY	: integer :=  0;
	FIFO_WRITE_DEPTH	: integer :=  Size;
	FULL_RESET_VALUE	: integer :=  0;
	PROG_EMPTY_THRESH	: integer :=  1;
	PROG_FULL_THRESH	: integer :=  NearFullLevel;
	RD_DATA_COUNT_WIDTH	: integer :=  1;
	READ_DATA_WIDTH		: integer :=  DataWidth;
	READ_MODE		: string :=  "fwft";
	SIM_ASSERT_CHK		: integer :=  0;
	USE_ADV_FEATURES	: string :=  "1002";
	WAKEUP_TIME		: integer :=  0;
	WRITE_DATA_WIDTH	: integer :=  DataWidth;
	WR_DATA_COUNT_WIDTH	: integer :=  1
);
port (
	wr_clk		: in std_logic;
	rst		: in std_logic;

	prog_full	: out std_logic;

	full		: out std_logic;
	wr_en		: in std_logic;
	din		: in std_logic_vector(DataWidth-1 downto 0);

	rd_en		: in std_logic;
	data_valid	: out std_logic;
	dout		: out std_logic_vector(DataWidth-1 downto 0);

	sleep		: in std_logic;
	injectdbiterr	: in std_logic;
	injectsbiterr	: in std_logic

	--empty		: out std_logic;
	--almost_full	: out std_logic;
	--almost_empty	: out std_logic;
	--dbiterr	: out std_logic;
	--overflow	: out std_logic;
	--prog_empty	: out std_logic;
	--rd_data_count	: out std_logic;
	--rd_rst_busy	: out std_logic;
	--sbiterr	: out std_logic;
	--underflow	: out std_logic;
	--wr_ack	: out std_logic;
	--wr_data_count : out std_logic;
	--wr_rst_busy	: out std_logic;
);
end component;

type MemoryType		is array(0 to Size-1) of std_logic_vector(DataWidth-1 downto 0);
signal memory		: MemoryType := (others => (others => 'U'));

signal count		: integer range 0 to Size;			--! Count of number of FIFO items.
signal writePos		: integer range 0 to Size-1;			--! The write position pointer
signal readPos		: integer range 0 to Size-1;			--! The read position pointer
signal posLooped	: boolean := False;				--! The write pointer has looped around behind the read pointer
signal writeReady	: std_logic;					--! There is space to write to the FIFO
signal writeEnable	: std_logic;					--! Write data to the FIFO
signal readReady	: std_logic;					--! There is space to write to the FIFO
signal readEnable	: std_logic;					--! Read data from the FIFO

signal full		: std_logic;					--! There is no space to write to the FIFO
signal empty		: std_logic;					--! Yhe FIFO is empty

function features(nearLevel: integer) return string is
begin
	if(nearLevel > 0) then
		return "1002";
	else
		return "1000";
	end if;
end;

begin
	simple: if((Simulate = True) or (Size <= 32)) generate
		writeReady	<= '1' when(not posLooped or (readPos /= writePos)) else '0';
		writeEnable	<= inValid when(writeReady = '1') else '0';
		inReady		<= writeReady;
		nearFull	<= '1' when(count >= NearFullLevel) else '0';

		readReady	<= '1' when((posLooped) or (writePos /= readPos)) else '0';
		readEnable	<= outReady when(readReady = '1') else '0';
		outData		<= memory(readPos);
		outValid	<= '1' when((posLooped) or (writePos /= readPos)) else '0';

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
						if((writeEnable = '1') and (readEnable = '0')) then
							count <= count + 1;
						elsif((writeEnable = '0') and (readEnable = '1')) then
							count <= count - 1;
						end if;
					end if;

				end if;
			end if;
		end process;
	end generate;

	xilinx: if((Simulate = False) and (Size > 32)) generate
	
		inReady <= not full;

		-- xpm_fifo_sync: Synchronous FIFO
		xpm_fifo_sync0 : xpm_fifo_sync
		generic map (
			DOUT_RESET_VALUE	=> "0",
			ECC_MODE		=> "no_ecc",
			FIFO_MEMORY_TYPE	=> "auto",
			FIFO_READ_LATENCY	=> 0,
			FIFO_WRITE_DEPTH	=> Size,
			FULL_RESET_VALUE	=> 0,
			PROG_EMPTY_THRESH	=> 1,
			PROG_FULL_THRESH	=> NearFullLevel,
			RD_DATA_COUNT_WIDTH	=> 1,
			READ_DATA_WIDTH		=> DataWidth,
			READ_MODE		=> "fwft",
			SIM_ASSERT_CHK		=> 0,
			USE_ADV_FEATURES	=> features(NearFullLevel),
			WAKEUP_TIME		=> 0,
			WRITE_DATA_WIDTH	=> DataWidth,
			WR_DATA_COUNT_WIDTH	=> 1
		)
		port map (
			wr_clk		=> clk,
			rst		=> reset,

			prog_full	=> nearFull,

			full		=> full,
			wr_en		=> inValid,
			din		=> inData,
			
			rd_en		=> outReady,
			data_valid	=> outValid,
			dout		=> outData,
			
			sleep		=> '0',
			injectdbiterr	=> '0',
			injectsbiterr	=> '0'

			--empty		=> empty,
			--almost_full	=> nearFull,
			--almost_empty	=> almost_empty,
			--dbiterr	=> dbiterr,
			--overflow	=> overflow,
			--prog_empty	=> prog_empty,
			--rd_data_count	=> rd_data_count,
			--rd_rst_busy	=> rd_rst_busy,
			--sbiterr	=> sbiterr,
			--underflow	=> underflow,
			--wr_ack	=> wr_ack,
			--wr_data_count => wr_data_count,
			--wr_rst_busy	=> wr_rst_busy,
		);
	end generate;
end;
