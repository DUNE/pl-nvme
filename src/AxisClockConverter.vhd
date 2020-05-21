--------------------------------------------------------------------------------
-- AxisClockConverter.vhd AXI Stream clock domain crossing
--------------------------------------------------------------------------------
--!
--! @class	AxisClockConverter
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-03-28
--! @version	0.0.1
--!
--! @brief
--! AXI Stream clock domain crossing module
--!
--! @details
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


entity AxisClockConverter is
generic(
	Simulate	: boolean	:= False
);
port (
	clkRx		: in std_logic;
	resetRx		: in std_logic;
	streamRx	: inout AxisStreamType := AxisStreamInput;                        

	clkTx		: in std_logic;
	resetTx		: in std_logic;
	streamTx	: inout AxisStreamType := AxisStreamOutput
);
end;

architecture Behavioral of AxisClockConverter is

--! @class	Axis_clock_converter
--! @brief	The Xilinx AXI4 Stream clock doamin crossing IP
--! @details	See the Xilinx documentation for details of this IP block
component axis_clock_converter
	port (
	s_axis_aresetn : in std_logic;
	m_axis_aresetn : in std_logic;
	s_axis_aclk : in std_logic;
	s_axis_tvalid : in std_logic;
	s_axis_tready : out std_logic;
	s_axis_tdata : in std_logic_vector(127 downto 0);
	s_axis_tkeep : in std_logic_vector(15 downto 0);
	s_axis_tlast : in std_logic;
	m_axis_aclk : in std_logic;
	m_axis_tvalid : out std_logic;
	m_axis_tready : in std_logic;
	m_axis_tdata : out std_logic_vector(127 downto 0);
	m_axis_tkeep : out std_logic_vector(15 downto 0);
	m_axis_tlast : out std_logic
	);
end component;

constant TCQ		: time := 1 ns;

signal s_axi_aresetn	: std_logic;
signal m_axi_aresetn	: std_logic;

signal streamRx_keep	: std_logic_vector(15 downto 0);
signal streamTx_keep	: std_logic_vector(15 downto 0);

begin
	sim: if (Simulate = True) generate
		-- Ignore clock domain crossing for simple simulations
		streamTx.valid	<= streamRx.valid;
		streamRx.ready	<= streamTx.ready;
		streamTx.data	<= streamRx.data;
		streamTx.keep	<= streamRx.keep;
		streamTx.last	<= streamRx.last;
	end generate;

	synth: if (Simulate = False) generate
		s_axi_aresetn	<= not resetRx;
		m_axi_aresetn	<= not resetTx;

		streamRx_keep	<= zeros(12) & streamRx.keep;
		streamTx.keep	<= streamTx_keep(3 downto 0);
		
		axis_clock_converter0 : axis_clock_converter
		port map (
			s_axis_aclk		=> clkRx,
			s_axis_aresetn		=> s_axi_aresetn,
			s_axis_tvalid		=> streamRx.valid,
			s_axis_tready		=> streamRx.ready,
			s_axis_tdata		=> streamRx.data,
			s_axis_tkeep		=> streamRx_keep,
			s_axis_tlast		=> streamRx.last,

			m_axis_aclk		=> clkTx,
			m_axis_aresetn		=> m_axi_aresetn,
			m_axis_tvalid		=> streamTx.valid,
			m_axis_tready		=> streamTx.ready,
			m_axis_tdata		=> streamTx.data,
			m_axis_tkeep		=> streamTx_keep,
			m_axis_tlast		=> streamTx.last
		);
	end generate;
end;

