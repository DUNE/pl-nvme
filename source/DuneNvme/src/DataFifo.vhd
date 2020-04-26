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
--! This module provides the data input fifo for the NvmeStorage module.
--!
--! @details
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
	DataWriteQueueNum	: integer := 4;			--! The number of DataWrite queue entries
	ChunkSize		: integer := 8192;		--! The chunk size in Bytes.
	FifoSize		: integer := 4 * ChunkSize	--! The Fifo size in Bytes
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	dataInEnable	: in std_logic;				--! Allow data input to particular Fifo
	dataInQueue	: in std_logic_vector(log2(DataWriteQueueNum)-1 downto 0);	--! The ingest Fifo number
	dataIn		: inout AxisStreamType := AxisInput;	--! Input data stream
	
	dataOutQueue	: in std_logic_vector(log2(DataWriteQueueNum)-1 downto 0);	--! The output Fifo number
	dataOut		: inout AxisStreamType := AxisOutput	--! Output data stream
);
end;

architecture Behavioral of DataFifo is

component fifo32k
port(
	s_aclk : in std_logic;
	s_aresetn : in std_logic;
	s_axis_tvalid : in std_logic;
	s_axis_tready : out std_logic;
	s_axis_tdata : in std_logic_vector(127 downto 0);
	s_axis_tlast : in std_logic;
	m_axis_tvalid : out std_logic;
	m_axis_tready : in std_logic;
	m_axis_tdata : out std_logic_vector(127 downto 0);
	m_axis_tlast : out std_logic;
	axis_prog_full : out std_logic
);
end component;

constant TCQ		: time := 1 ns;
signal hasBlock		: std_logic;

begin
	-- Output data stream
	dataOut.valid <= dataIn.valid;
	dataOut.last <= dataIn.last;
	dataIn.ready <= dataOut.ready;
	dataOut.data <= dataIn.data;
	
	fifo32k0 : Fifo32k
	port map (
		s_aclk		=> clk,
		s_aresetn	=> not reset,
		s_axis_tready	=> dataIn.ready,
		s_axis_tvalid	=> dataIn.valid,
		s_axis_tlast	=> dataIn.last,
		s_axis_tdata	=> dataIn.data,
		
		m_axis_tready	=> dataOut.ready,
		m_axis_tvalid	=> dataOut.valid,
		m_axis_tlast	=> dataOut.last,
		m_axis_tdata	=> dataOut.data,
		axis_prog_full	=> hasBlock
	);
end;
