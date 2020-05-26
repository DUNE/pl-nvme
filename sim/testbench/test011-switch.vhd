--------------------------------------------------------------------------------
--	Test009-packets.vhd	Simple nvme interface tests
--	T.Barnaby,	Beam Ltd.	2020-04-14
--------------------------------------------------------------------------------
--
--
--
library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.NvmeStoragePkg.all;
use work.NvmeStorageIntPkg.all;
use work.TestPkg.all;

entity Test is
end;

architecture sim of Test is

constant TCQ		: time := 1 ns;
constant NumStreams	: integer := 4;

component StreamSwitch is
generic(
	NumStreams	: integer	:= NumStreams		--! The number of stream
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisStreamArrayType(0 to NumStreams-1) := (others => AxisStreamInput);	--! Input stream
	streamOut	: inout AxisStreamArrayType(0 to NumStreams-1) := (others => AxisStreamOutput)	--! Output stream
);
end component;

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal streamSend	: AxisStreamArrayType(0 to NumStreams-1) := (others => AxisStreamOutput);
signal streamRecv	: AxisStreamArrayType(0 to NumStreams-1) := (others => AxisStreamInput);

begin
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

	stop : process
	begin
		wait for 700 ns;
		assert false report "simulation ended ok" severity failure;
	end process;


	streamSwitch0 : StreamSwitch
	port map (
		clk		=> clk,
		reset		=> reset,

		streamIn	=> streamSend,
		streamOut	=> streamRecv
	);

	run1 : process
	begin
		streamSend(0).valid	<= '0';
		streamRecv(0).ready	<= '1';
		streamSend(1).valid	<= '0';
		streamRecv(1).ready	<= '1';
	
		wait until reset = '0';
		
		-- Write queue entry
		pcieRequestWrite(clk, streamSend(0), 0, 1, 16#01000000#, 16#44#, 16, 16#01000000#);
		pcieRequestWrite(clk, streamSend(1), 1, 1, 16#02000000#, 16#44#, 16, 16#02000000#);

		pcieReply(clk, streamSend(0), 2, 16#1234#, 16#00000000#, 16#44#, 16, 16#03000000#);

		-- Test ready signal block
		streamRecv(1).ready <= '0';
		wait for 120 ns;
		wait until rising_edge(clk);
		streamRecv(1).ready <= '1';
		wait until rising_edge(clk);
		streamRecv(1).ready <= '0';
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		streamRecv(1).ready <= '1';
		
		--pcieRequestWrite(clk, streamSend(0), 0, 1, 16#01000000#, 16#44#, 16, 16#04000000#);

		wait;
	end process;
	
	run2 : process
	begin
		streamSend(2).valid	<= '0';
		streamRecv(2).ready	<= '1';
		streamSend(3).valid	<= '0';
		streamRecv(3).ready	<= '1';
	
		wait until reset = '0';
		wait for 300 ns;
		pcieRequestWrite(clk, streamSend(2), 0, 1, 16#01000000#, 16#44#, 16, 16#04000000#);
		
		-- Write queue entry
		pcieRequestWrite(clk, streamSend(2), 0, 1, 16#00000000#, 16#44#, 16, 16#05000000#);

		wait;
	end process;
end;
