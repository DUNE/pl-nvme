--------------------------------------------------------------------------------
--	Test016-fifo.vhd	Simple nvme interface tests
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
constant BlockSize	: integer := 512;

component AxisDataConvertFifo is
generic(
	Simulate	: boolean	:= True;			--! Enable simulation core
	FifoSizeBytes	: integer	:= BlockSize			--! The Fifo size in bytes
);
port (
	clk		: in std_logic;					--! Module clock
	reset		: in std_logic;					--! Module reset line. Clears Fifo

	streamRx	: in AxisDataStreamType;			--! Input data stream
	streamRx_ready	: out std_logic;				--! Ready signal for input data stream

	streamTx	: inout AxisStreamType := AxisStreamOutput	--! Output data stream
);
end component;

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

-- Fifo test
signal dataStream	: AxisDataStreamType;		--! AXI stream for test data
signal dataStream_ready	: std_logic;
signal streamTx		: AxisStreamType;

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
		wait for 3000 ns;
		assert false report "simulation ended ok" severity failure;
	end process;


	-- Fifo tests
	-- The test data interface
	testData0 : TestData
	generic map (
		BlockSize	=> BlockSize
	)
	port map (
		clk		=> clk,
		reset		=> reset,

		enable		=> '1',

		dataOut		=> dataStream,
		dataOutReady	=> dataStream_ready
	);
	
	fifo: AxisDataConvertFifo
	port map (
		clk		=> clk,
		reset		=> reset,

		streamRx	=> dataStream,
		streamRx_ready	=> dataStream_ready,
		
		streamTx	=> streamTx
	);

	fifoRead : process
	begin
		streamTx.ready <= '0';
		wait until reset = '0';

		--wait;
		
		wait until rising_edge(clk);
		streamTx.ready <= '1';
		
		--wait;
		
		while(true) loop
			streamTx.ready	<= '1';
			wait until rising_edge(clk);
			wait until rising_edge(clk);
			wait until rising_edge(clk);
			streamTx.ready	<= '0';
			--wait until rising_edge(clk);
			wait until rising_edge(clk);
		end loop;
	end process;
end;
