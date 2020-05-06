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
--use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
--use ieee.std_logic_misc.all;
--use ieee.std_logic_textio.all;
--use std.textio.all; 

library work;
use work.NvmeStoragePkg.all;
use work.NvmeStorageIntPkg.all;
use work.TestPkg.all;

entity Test is
end;

architecture sim of Test is

constant TCQ		: time := 1 ns;
constant CHUNK_SIZE	: integer := 32;			-- The data write chunk size in DWords due to PCIe packet size limitations
constant NumQueueEntries: integer := 2;

component NvmeQueues is
generic(
	NumQueueEntries	: integer	:= NumQueueEntries;	--! The number of entries per queue
	Simulate	: boolean	:= True
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisStreamType := AxisInput;	--! Request queue entries
	streamOut	: inout AxisStreamType := AxisOutput	--! replies and requests
);
end component;

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal hostReq		: AxisStreamType := AxisOutput;
signal hostReply	: AxisStreamType := AxisInput;

begin
	hostReply.ready <= '1';
	
	NvmeQueues0 : NvmeQueues
	port map (
		clk		=> clk,
		reset		=> reset,

		streamIn	=> hostReq,
		streamOut	=> hostReply
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
		
		-- WriteRam queue entries
		pcieRequestWrite(clk, hostReq, 1, 1, 16#05000000#, 16#44#, 16, 16#00000010#);
		pcieRequestWrite(clk, hostReq, 1, 1, 16#05000040#, 16#44#, 16, 16#00000020#);
		
		-- ReadRam queue entry
		pcieRequestRead(clk, hostReq, 1, 0, 16#05000040#, 16#44#, 16);

		-- WriteQueue queue entries
		pcieRequestWrite(clk, hostReq, 1, 16#F#, 16#05000000#, 16#44#, 16, 16#00000030#);
		pcieRequestWrite(clk, hostReq, 1, 16#F#, 16#05000000#, 16#44#, 16, 16#00000040#);
		pcieRequestWrite(clk, hostReq, 1, 16#F#, 16#05000000#, 16#44#, 16, 16#00000050#);

		-- WriteQueue to queue 1 (in bits 16-17)
		pcieRequestWrite(clk, hostReq, 1, 16#F#, 16#05010000#, 16#44#, 16, 16#00000060#);
		wait;
	end process;
	
	stop : process
	begin
		wait for 700 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
end;
