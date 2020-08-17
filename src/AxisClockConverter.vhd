--------------------------------------------------------------------------------
-- AxisClockConverter.vhd AXI Stream clock domain crossing
--------------------------------------------------------------------------------
--!
--! @class	AxisClockConverter
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-03-28
--! @version	1.0.0
--!
--! @brief
--! AxisStream clock domain crossing module.
--!
--! @details
--! This module implements a clock crossing for an AXI4 stream encoded using
--! the AxisStream record type. It uses the Xilinx AXI4 stream CDC IP to
--! implement this.
--! The Simulate parameter reduces the functionality to a simple pass through
--! for simple system simulations.
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


entity AxisClockConverter is
generic(
	Simulate	: boolean	:= False
);
port (
	clkRx		: in std_logic;					--! The input stream clock line
	resetRx		: in std_logic;					--! The input stream reset

	streamRx	: inout AxisStreamType := AxisStreamInput;	--! The input stream

	clkTx		: in std_logic;					--! The output stream clock line
	resetTx		: in std_logic;					--! The output stream reset
	streamTx	: inout AxisStreamType := AxisStreamOutput	--! The output stream
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

