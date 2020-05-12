--------------------------------------------------------------------------------
-- AxilClockConverter.vhd AXI Lite bus clock domain crossing
--------------------------------------------------------------------------------
--!
--! @class	AxilClockConverter
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-02-28
--! @version	0.0.1
--!
--! @brief
--! AXI Lite "bus" clock domain crossing module
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

entity AxilClockConverter is
generic(
	Simulate	: boolean	:= False
);
port (
	clk0		: in std_logic;
	reset0		: in std_logic;

	-- Bus0
	axil0In		: in AxilToSlaveType;
	axil0Out	: out AxilToMasterType;

	clk1		: in std_logic;
	reset1		: in std_logic;

	-- Bus1
	axil1Out	: out AxilToSlaveType;
	axil1In		: in AxilToMasterType
);
end;

architecture Behavioral of AxilClockConverter is

component Axil_clock_converter
	port (
	s_axi_aclk : in std_logic;
	s_axi_aresetn : in std_logic;
	s_axi_awaddr : in std_logic_vector(31 downto 0);
	s_axi_awprot : in std_logic_vector(2 downto 0);
	s_axi_awvalid : in std_logic;
	s_axi_awready : out std_logic;
	s_axi_wdata : in std_logic_vector(31 downto 0);
	s_axi_wstrb : in std_logic_vector(3 downto 0);
	s_axi_wvalid : in std_logic;
	s_axi_wready : out std_logic;
	s_axi_bresp : out std_logic_vector(1 downto 0);
	s_axi_bvalid : out std_logic;
	s_axi_bready : in std_logic;
	s_axi_araddr : in std_logic_vector(31 downto 0);
	s_axi_arprot : in std_logic_vector(2 downto 0);
	s_axi_arvalid : in std_logic;
	s_axi_arready : out std_logic;
	s_axi_rdata : out std_logic_vector(31 downto 0);
	s_axi_rresp : out std_logic_vector(1 downto 0);
	s_axi_rvalid : out std_logic;
	s_axi_rready : in std_logic;
	m_axi_aclk : in std_logic;
	m_axi_aresetn : in std_logic;
	m_axi_awaddr : out std_logic_vector(31 downto 0);
	m_axi_awprot : out std_logic_vector(2 downto 0);
	m_axi_awvalid : out std_logic;
	m_axi_awready : in std_logic;
	m_axi_wdata : out std_logic_vector(31 downto 0);
	m_axi_wstrb : out std_logic_vector(3 downto 0);
	m_axi_wvalid : out std_logic;
	m_axi_wready : in std_logic;
	m_axi_bresp : in std_logic_vector(1 downto 0);
	m_axi_bvalid : in std_logic;
	m_axi_bready : out std_logic;
	m_axi_araddr : out std_logic_vector(31 downto 0);
	m_axi_arprot : out std_logic_vector(2 downto 0);
	m_axi_arvalid : out std_logic;
	m_axi_arready : in std_logic;
	m_axi_rdata : in std_logic_vector(31 downto 0);
	m_axi_rresp : in std_logic_vector(1 downto 0);
	m_axi_rvalid : in std_logic;
	m_axi_rready : out std_logic
	);
end component;

constant TCQ		: time := 1 ns;

signal s_axi_aresetn	: std_logic;
signal m_axi_aresetn	: std_logic;

begin
	sim: if (Simulate = True) generate
		-- Ignore clock domain crossing for simple simulations
		axil0Out	<= axil1In;
		axil1Out	<= axil0In;
	end generate;
	
	synth: if (Simulate = False) generate
		s_axi_aresetn	<= not reset0;
		m_axi_aresetn	<= not reset1;

		axil_clock_converter0 : Axil_clock_converter
		port map (
			s_axi_aclk		=> clk0,
			s_axi_aresetn		=> s_axi_aresetn,
			s_axi_awaddr		=> axil0In.awaddr,
			s_axi_awprot		=> axil0In.awprot,
			s_axi_awvalid		=> axil0In.awvalid,
			s_axi_awready		=> axil0Out.awready,
			s_axi_wdata		=> axil0In.wdata,
			s_axi_wstrb		=> axil0In.wstrb,
			s_axi_wvalid		=> axil0In.wvalid,
			s_axi_wready		=> axil0Out.wready,
			s_axi_bresp		=> axil0Out.bresp,
			s_axi_bvalid		=> axil0Out.bvalid,
			s_axi_bready		=> axil0In.bready,
			s_axi_araddr		=> axil0In.araddr,
			s_axi_arprot		=> axil0In.arprot,
			s_axi_arvalid		=> axil0In.arvalid,
			s_axi_arready		=> axil0Out.arready,
			s_axi_rdata		=> axil0Out.rdata,
			s_axi_rresp		=> axil0Out.rresp,
			s_axi_rvalid		=> axil0Out.rvalid,
			s_axi_rready		=> axil0In.rready,

			m_axi_aclk		=> clk1,
			m_axi_aresetn		=> m_axi_aresetn,
			m_axi_awaddr		=> axil1Out.awaddr,
			m_axi_awprot		=> axil1Out.awprot,
			m_axi_awvalid		=> axil1Out.awvalid,
			m_axi_awready		=> axil1In.awready,
			m_axi_wdata		=> axil1Out.wdata,
			m_axi_wstrb		=> axil1Out.wstrb,
			m_axi_wvalid		=> axil1Out.wvalid,
			m_axi_wready		=> axil1In.wready,
			m_axi_bresp		=> axil1In.bresp,
			m_axi_bvalid		=> axil1In.bvalid,
			m_axi_bready		=> axil1Out.bready,
			m_axi_araddr		=> axil1Out.araddr,
			m_axi_arprot		=> axil1Out.arprot,
			m_axi_arvalid		=> axil1Out.arvalid,
			m_axi_arready		=> axil1In.arready,
			m_axi_rdata		=> axil1In.rdata,
			m_axi_rresp		=> axil1In.rresp,
			m_axi_rvalid		=> axil1In.rvalid,
			m_axi_rready		=> axil1Out.rready
		);
	end generate;
end;

