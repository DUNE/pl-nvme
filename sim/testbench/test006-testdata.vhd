--------------------------------------------------------------------------------
--	Test006-testdata.vhd	Test of TestData module
--	T.Barnaby,	Beam Ltd.	2020-04-07
--------------------------------------------------------------------------------
--
library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
--use ieee.std_logic_misc.all;
--use ieee.std_logic_textio.all;
--use std.textio.all; 

library work;
use work.AxiPkg.all;
use work.NvmeStoragePkg.all;

entity Test is
end;

architecture sim of Test is

component TestData is
generic(
	BlockSize	: integer := 64				--! The block size in Bytes.
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	enable		: in std_logic;				--! Enable production of data

	-- AXIS data output
	dataStream	: inout AxisStream := AxisStreamOutput	--! Output data stream
);
end component;

constant TCQ		: time := 1 ns;

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal enable		: std_logic := '0';
signal dataStream	: AxisStream	:= AxisStreamInput;

begin
	testData0 : TestData
	port map (
		clk		=> clk,
		reset		=> reset,

		enable		=> enable,

		dataStream	=> dataStream
	);

	clock : process
	begin
		wait for 5 ns; clk  <= not clk;
	end process clock;

	init : process
	begin
		reset 	<= '1';
		wait for 20 ns;
		reset	<= '0';
		wait;
	end process;
	
	run : process
	begin
		wait until reset = '0';
		wait until rising_edge(clk);
		enable <= '1';
		dataStream.ready <= '1';
		
		-- Watch data comming in
		wait for 100 ns;
		
		-- Pause data
		wait until rising_edge(clk);
		dataStream.ready <= '0';
		wait until rising_edge(clk);
		dataStream.ready <= '1';

		-- Disable
		wait for 200 ns;
		enable <= '0';
		wait;
	end process;

	stop : process
	begin
		wait for 500 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
end;
