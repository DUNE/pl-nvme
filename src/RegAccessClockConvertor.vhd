--------------------------------------------------------------------------------
-- RegAccessClockConvertor.vhd Pass register access signals across a clock domain
-------------------------------------------------------------------------------
--!
--! @class	RegAccessClockConvertor
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-18
--! @version	0.0.1
--!
--! @brief
--! This module passes register access signals acrossd a clock domain
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

entity RegAccessClockConvertor is
port (
	clk1		: in std_logic;				--! The interface clock line
	reset1		: in std_logic;				--! The active high reset line
	
	regWrite1	: in std_logic;				--! Enable write to register
	regAddress1	: in unsigned(5 downto 0);		--! Register to read/write
	regDataIn1	: in std_logic_vector(31 downto 0);	--! Register write data
	regDataOut1	: out std_logic_vector(31 downto 0);	--! Register contents

	clk2		: in std_logic;				--! The interface clock line
	reset2		: in std_logic;				--! The active high reset line

	regWrite2	: out std_logic;				--! Enable write to register
	regAddress2	: out unsigned(5 downto 0);		--! Register to read/write
	regDataIn2	: out std_logic_vector(31 downto 0);	--! Register write data
	regDataOut2	: in std_logic_vector(31 downto 0)	--! Register contents
);
end;

architecture Behavioral of RegAccessClockConvertor is

constant TCQ		: time := 1 ns;
constant SigSendWidth	: integer := 1 + regAddress1'length + regDataIn1'length;
constant SigRecvWidth	: integer := 32;

subtype SigSendType	is std_logic_vector(SigSendWidth-1 downto 0);
subtype SigRecvType	is std_logic_vector(SigRecvWidth-1 downto 0);

signal sigSendFifo1	: SigSendType := (others => '0');
signal sigSendFifo2	: SigSendType := (others => '0');
signal sigRecvFifo1	: SigRecvType := (others => '0');
signal sigRecvFifo2	: SigRecvType := (others => '0');

attribute rtl_keep	: string;
attribute async_reg	: string;

attribute rtl_keep	of sigSendFifo1 : signal is "true";
attribute rtl_keep	of sigSendFifo2 : signal is "true";
attribute rtl_keep	of sigRecvFifo1 : signal is "true";
attribute rtl_keep	of sigRecvFifo2 : signal is "true";

attribute async_reg	of sigSendFifo1 : signal is "true";
attribute async_reg	of sigSendFifo2 : signal is "true";
attribute async_reg	of sigRecvFifo1 : signal is "true";
attribute async_reg	of sigRecvFifo2 : signal is "true";

begin
	regWrite2	<= sigSendFifo2(38);
	regAddress2	<= unsigned(sigSendFifo2(37 downto 32));
	regDataIn2	<= sigSendFifo2(31 downto 0);

	process(clk2)
	begin
		if(rising_edge(clk2)) then
			if(reset2 = '1') then
				sigSendFifo1	<= (others => '0');
				sigSendFifo2	<= (others => '0');
			else
				sigSendFifo2	<= sigSendFifo1;
				sigSendFifo1	<= regWrite1 & to_stl(regAddress1) & regDataIn1;
			end if;
		end if;
	end process;

	regDataOut1 <= sigRecvFifo2;

	process(clk1)
	begin
		if(rising_edge(clk1)) then
			if(reset1 = '1') then
				sigRecvFifo1	<= (others => '0');
				sigRecvFifo2	<= (others => '0');
			else
				sigRecvFifo2	<= sigRecvFifo1;
				sigRecvFifo1	<= regDataOut2;
			end if;
		end if;
	end process;
end;
