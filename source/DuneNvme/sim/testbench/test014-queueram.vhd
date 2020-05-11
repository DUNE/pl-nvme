--------------------------------------------------------------------------------
--	Test014-queueram.vhd	Simple nvme interface tests
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
constant CHUNK_SIZE	: integer := 32;			-- The data write chunk size in DWords due to PCIe packet size limitations
constant NumQueueEntries: integer := 4;

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
	
	ready : process(clk)
	begin
		if(rising_edge(clk)) then
			-- This can hold ready high or set ready based on valid for testing
			if(reset = '1') then
				hostReply.ready <= '0';
			else
				--hostReply.ready <= '1';
				--hostReply.ready <= hostReply.valid;
				hostReply.ready <= not hostReply.ready;
			end if;
		end if;
	end process;

	run : process
	begin
		wait until reset = '0';
		
		-- Write queue entries
		pcieRequestWrite(clk, hostReq, 1, 1, 16#02000000#, 16#44#, 16, 16#00000010#);
		pcieRequestWrite(clk, hostReq, 1, 1, 16#02000040#, 16#44#, 16, 16#00000020#);
		
		-- Read queue entry
		pcieRequestRead(clk, hostReq, 1, 0, 16#02000000#, 16#44#, 16);
		pcieRequestRead(clk, hostReq, 1, 0, 16#02000040#, 16#44#, 16);
		
		-- Write reply queue to queue 1 (in bits 16-17)
		pcieRequestWrite(clk, hostReq, 1, 1, 16#02010000#, 16#44#, 4, 16#00000060#);
		wait;

		-- WriteQueue manual queue entries
		pcieRequestWrite(clk, hostReq, 1, 16#D#, 16#02000000#, 16#44#, 16, 16#00000030#);
		pcieRequestWrite(clk, hostReq, 1, 16#D#, 16#02000040#, 16#44#, 16, 16#00000040#);

		wait;
	end process;
	
	stop : process
	begin
		wait for 700 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
end;
