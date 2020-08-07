--------------------------------------------------------------------------------
-- RegAccessClockConvertor.vhd Pass register access signals across a clock domain
-------------------------------------------------------------------------------
--!
--! @class	RegAccessClockConvertor
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-08-06
--! @version	1.0.1
--!
--! @brief
--! This module passes register access signals across a clock domain
--!
--! @details
--! This is a very simple, low utilisation, clock domain crossing unit for the register interface.
--! It is designed to work with asynchronous clocks of the same frequency.
--! It delays the write and read signals by 1 cycle from the address and data transitions to
--! make sure all bits are stable before the actual register write.
--! It also holds the read and write signals for and extra cycle to guarantee they pass through.
--! For reads you need to wait 7 cycles for the read data to be latched and sent across the clock
--! domains.
--! Note this module requires appropriate timing constraints for the CDC applied. This would normally be
--! a set_max_delay or set_false_path constraint on the timing to the sendCdcReg1 and recvCdcReg1 registers.
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
	regRead1	: in std_logic;				--! Enable read from register
	regAddress1	: in unsigned(5 downto 0);		--! Register to read/write
	regDataIn1	: in std_logic_vector(31 downto 0);	--! Register write data
	regDataOut1	: out std_logic_vector(31 downto 0);	--! Register contents

	clk2		: in std_logic;				--! The interface clock line
	reset2		: in std_logic;				--! The active high reset line

	regWrite2	: out std_logic;			--! Enable write to register
	regRead2	: out std_logic;				--! Enable read from register
	regAddress2	: out unsigned(5 downto 0);		--! Register to read/write
	regDataIn2	: out std_logic_vector(31 downto 0);	--! Register write data
	regDataOut2	: in std_logic_vector(31 downto 0)	--! Register contents
);
end;

architecture Behavioral of RegAccessClockConvertor is

constant TCQ		: time := 1 ns;
constant SigSendWidth	: integer := 2 + regAddress1'length + regDataIn1'length;
constant SigRecvWidth	: integer := 32;

subtype SigSendType	is std_logic_vector(SigSendWidth-1 downto 0);
subtype SigRecvType	is std_logic_vector(SigRecvWidth-1 downto 0);

signal regWrite1Delayed	: std_logic := '0';
signal regWrite1Delayed1: std_logic := '0';
signal regRead1Delayed	: std_logic := '0';
signal regRead1Delayed1	: std_logic := '0';

signal sendCdcReg0	: SigSendType := (others => '0');
signal sendCdcReg1	: SigSendType := (others => '0');
signal sendCdcReg2	: SigSendType := (others => '0');

signal recvCdcReg0	: SigRecvType := (others => '0');
signal recvCdcReg1	: SigRecvType := (others => '0');
signal recvCdcReg2	: SigRecvType := (others => '0');

attribute keep		: string;
attribute async_reg	: string;

attribute keep		of sendCdcReg0 : signal is "true";
attribute keep		of sendCdcReg1 : signal is "true";
attribute keep		of sendCdcReg2 : signal is "true";
attribute keep		of recvCdcReg0 : signal is "true";
attribute keep		of recvCdcReg1 : signal is "true";
attribute keep		of recvCdcReg2 : signal is "true";

attribute async_reg	of sendCdcReg1 : signal is "true";
attribute async_reg	of sendCdcReg2 : signal is "true";
attribute async_reg	of recvCdcReg1 : signal is "true";
attribute async_reg	of recvCdcReg2 : signal is "true";

begin
	--! The send process
	regWrite2	<= sendCdcReg2(39);
	regRead2	<= sendCdcReg2(38);
	regAddress2	<= unsigned(sendCdcReg2(37 downto 32));
	regDataIn2	<= sendCdcReg2(31 downto 0);

	process(clk2)
	begin
		if(rising_edge(clk2)) then
			if(reset2 = '1') then
				sendCdcReg1	<= (others => '0');
				sendCdcReg2	<= (others => '0');
				recvCdcReg0	<= (others => '0');
			else
				sendCdcReg2	<= sendCdcReg1;
				sendCdcReg1	<= sendCdcReg0;
				
				recvCdcReg0	<= regDataOut2;
			end if;
		end if;
	end process;

	--! The receive process
	regDataOut1 <= recvCdcReg2;

	process(clk1)
	begin
		if(rising_edge(clk1)) then
			if(reset1 = '1') then
				recvCdcReg1	<= (others => '0');
				recvCdcReg2	<= (others => '0');
			else
				-- Register input address/data and delay control signals and hold for 2 cycles
				sendCdcReg0(39)	<= regWrite1Delayed or regWrite1Delayed1;
				sendCdcReg0(38)	<= regRead1Delayed or regRead1Delayed1;
				if(regWrite1 = '1') then
					sendCdcReg0(37 downto 0) <= to_stl(regAddress1) & regDataIn1;
				elsif(regRead1 = '1') then
					sendCdcReg0(37 downto 32) <= to_stl(regAddress1);
				end if;

				regWrite1Delayed	<= regWrite1;
				regWrite1Delayed1	<= regWrite1Delayed;
				regRead1Delayed		<= regRead1;
				regRead1Delayed1	<= regRead1Delayed;

				recvCdcReg2	<= recvCdcReg1;
				recvCdcReg1	<= recvCdcReg0;
				
			end if;
		end if;
	end process;
end;
