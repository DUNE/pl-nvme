--------------------------------------------------------------------------------
--	Test001.vhd	Simple Leds
--			T.Barnaby,	Beam Ltd.	2020-02-18
--------------------------------------------------------------------------------
--
library ieee ;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_textio.all;
use std.textio.all; 

--library work;
--use work.PacketLink.all;

entity Test is
end;

architecture sim of Test is

component LedCount is
generic (
	Simulate	: boolean	:= True;
	Divider		: integer	:= 4
);
port (
	clk_p	: in std_logic;
	clk_n	: in std_logic;
	reset	: in std_logic;
	leds	: out std_logic_vector(7 downto 0)
);
end component;

constant TCQ		: time := 1 ns;

signal clk_p		: std_logic := '1';
signal clk_n		: std_logic := '0';
signal reset		: std_logic := '0';
signal leds		: std_logic_vector(7 downto 0);

begin
	ledCount0 : LedCount port map (
		clk_p		=> clk_p,
		clk_n		=> clk_n,
		reset		=> reset,
		leds		=> leds
	);

	clock : process
	begin
		wait for 5 ns; clk_p  <= not clk_p;
	end process clock;

	clk_n <= not clk_p;

	init : process
	begin
		reset 	<= '1';
		wait for 50 ns;
		reset	<= '0';
		wait;
	end process;
	
	run : process
	begin
		wait;
	end process;

	stop : process
	begin
		wait for 500 ns;
		--assert false report "simulation ended" severity failure;
	end process;
end;
