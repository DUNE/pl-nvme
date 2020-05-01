--------------------------------------------------------------------------------
--	DataFifo.vhd NvmeStorage data input fifo
--	T.Barnaby, Beam Ltd. 2020-04-07
-------------------------------------------------------------------------------
--!
--! @class	DataFifo
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

entity DataFifo is
generic(
	Simulate	: boolean := False;			--! Generate simulation core
	FifoSize	: integer := 2048			--! The Fifo size
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	full		: out std_logic;			--! The fifo is full (Has Fifo size words)
	empty		: out std_logic;			--! The fifo is empty

	dataIn		: inout AxisStreamType := AxisInput;	--! Input data stream
	dataOut		: inout AxisStreamType := AxisOutput	--! Output data stream
);
end;

architecture Behavioral of DataFifo is

component Fifo32k
port (
	clk : in std_logic;
	srst : in std_logic;
	din : in std_logic_vector(127 downto 0);
	wr_en : in std_logic;
	rd_en : in std_logic;
	dout : out std_logic_vector(127 downto 0);
	full : out std_logic;
	empty : out std_logic;
	valid : out std_logic;
	wr_rst_busy : out std_logic;
	rd_rst_busy : out std_logic;
	data_count : out std_logic_vector(11 downto 0)
);
end component;

constant TCQ		: time := 1 ns;
signal fifo_full	: std_logic:= '0';
signal fifo_empty	: std_logic:= '0';
signal fifo_count	: std_logic_vector(11 downto 0) := (others => '0');

-- Simulation signals
type RamType		is array(0 to FifoSize) of std_logic_vector(127 downto 0);
signal ram		: RamType := (others => zeros(128));
signal fifoInPos	: integer range 0 to FifoSize := 0;
signal fifoOutPos	: integer range 0 to FifoSize := 0;

function nextPos(pos: integer) return integer is
begin
	if((pos + 1) > FifoSize) then
		return 0;
	else
		return pos + 1;
	end if;
end;

begin
	synth: if Simulate = false generate
		-- Stream signals
		dataIn.ready	<= not fifo_full when(reset = '0') else '0';
		full		<= '1' when((reset = '0') and (unsigned(fifo_count) >=  FifoSize)) else '0';
		empty		<= fifo_empty;
		dataOut.valid	<= not fifo_empty;
		dataOut.last	<= '0';

		fifo0: Fifo32k
		port map (
			clk		=> clk,
			srst		=> reset,
			din		=> dataIn.data,
			wr_en		=> dataIn.valid,
			rd_en		=> dataOut.ready,
			dout		=> dataOut.data,
			full		=> fifo_full,
			empty		=> fifo_empty,
			--valid		=> dataOut.valid,
			--wr_rst_busy	=>
			--rd_rst_busy	=>
			data_count	=> fifo_count
		);
	end generate;

	sim: if Simulate = true generate
		-- Fifo input
		dataIn.ready	<= '1' when(nextPos(fifoInPos) /= fifoOutPos) else '0';
		full		<= not dataIn.ready;

		fifoPos: process(clk)
		begin
		end process;

		fifoIn: process(clk)
		begin
			if(rising_edge(clk)) then
				if(reset = '1') then
					fifoInPos	<= 0;
				else
					if((dataIn.valid = '1') and (dataIn.ready = '1')) then
						ram(fifoInPos)	<= dataIn.data;
						fifoInPos <= nextPos(fifoInPos);
					end if;
				end if;
			end if;
		end process;

		-- Fifo output
		dataOut.valid	<= '1' when(fifoOutPos /= fifoInPos) else '0';
		empty		<= not dataOut.valid;

		fifoOut: process(clk)
		begin
			if(rising_edge(clk)) then
				if(reset = '1') then
					fifoOutPos	<= 0;
				else
					if((dataOut.valid = '1') and (dataOut.ready = '1')) then
						dataOut.data <= ram(fifoOutPos);
						fifoOutPos <= nextPos(fifoOutPos);
					end if;
				end if;
			end if;
		end process;
	end generate;
end;
