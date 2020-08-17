--------------------------------------------------------------------------------
-- Cdc.vhd Pass signals between clock domains
-------------------------------------------------------------------------------
--!
--! @class	Cdc
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-18
--! @version	1.0.0
--!
--! @brief
--! This is a simple module to pass a set of signals across a clock domain
--!
--! @details
--! This is a very simple, low utilisation clock domain crossing unit for a set of signals.
--! There is no specific structure to the signals and with multiple signals their state can appear across
--! the clock domain crossing on separate clock edges. So if multiple signals are passed some form
--! of handshake system is needed on top of this.
--! A simple method of acheiving this would be to have one of the signals be a valid signal that is
--! activated/deactivated one clock cycle after the rest of the signals have changed state.
--! It uses two clock synchronisation registers.
--! Note it doesn't have an integral input clock domain register and thus it expects the input signals
--! to be stable for at least two input clock cycles prior to a valid signal going high.
--!
--! Note this module requires appropriate timing constraints for the CDC applied. This would normally
--! a set_max_delay or set_false_path constraint on the timing to the sendCdcReg1 and recvCdcReg1 registers.
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

entity Cdc is
generic (
	Width		: integer	:= 1			-- The number of sgnals to pass
);
port (
	clk1		: in std_logic;				--! The interface clock line
	signals1	: in std_logic_vector(Width-1 downto 0); --! The signals to pass

	clk2		: in std_logic;				--! The interface clock line
	reset2		: in std_logic;				--! The active high reset line
	signals2	: out std_logic_vector(Width-1 downto 0) --! The signals passed
);
end;

architecture Behavioral of Cdc is

constant TCQ		: time := 1 ns;
subtype RegisterType	is std_logic_vector(Width-1 downto 0);

signal sendCdcReg1	: RegisterType := (others => '0');
signal sendCdcReg2	: RegisterType := (others => '0');

attribute keep		: string;
attribute async_reg	: string;

attribute keep		of sendCdcReg1 : signal is "true";
attribute keep		of sendCdcReg2 : signal is "true";

attribute async_reg	of sendCdcReg1 : signal is "true";
attribute async_reg	of sendCdcReg2 : signal is "true";

begin
	signals2	<= sendCdcReg2;

	process(clk2)
	begin
		if(rising_edge(clk2)) then
			if(reset2 = '1') then
				sendCdcReg1	<= (others => '0');
				sendCdcReg2	<= (others => '0');
			else
				sendCdcReg2	<= sendCdcReg1;
				sendCdcReg1	<= signals1;
			end if;
		end if;
	end process;
end;



--! @class	CdcSingle
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-18
--! @version	1.0.0
--!
--! @brief
--! This is a simple module to pass a single bit wide signal across a clock domain
--!
--! @details
--! This is a very simple, low utilisation clock domain crossing unit for a single bit wide signal.
--! It uses two clock synchronisation registers.
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

entity CdcSingle is
port (
	clk1		: in std_logic;				--! The interface clock line
	signal1		: in std_logic;				--! The signal to pass

	clk2		: in std_logic;				--! The interface clock line
	reset2		: in std_logic;				--! The active high reset line
	signal2		: out std_logic				--! The signals passed
);
end;

architecture Behavioral of CdcSingle is

constant TCQ		: time := 1 ns;

signal sendCdcReg1	: std_logic := '0';
signal sendCdcReg2	: std_logic := '0';

attribute keep		: string;
attribute async_reg	: string;

attribute keep		of sendCdcReg1 : signal is "true";
attribute keep		of sendCdcReg2 : signal is "true";

attribute async_reg	of sendCdcReg1 : signal is "true";
attribute async_reg	of sendCdcReg2 : signal is "true";

begin
	signal2	<= sendCdcReg2;

	process(clk2)
	begin
		if(rising_edge(clk2)) then
			if(reset2 = '1') then
				sendCdcReg1	<= '0';
				sendCdcReg2	<= '0';
			else
				sendCdcReg2	<= sendCdcReg1;
				sendCdcReg1	<= signal1;
			end if;
		end if;
	end process;
end;
