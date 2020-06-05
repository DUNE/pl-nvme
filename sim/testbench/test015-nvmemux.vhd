--------------------------------------------------------------------------------
--	Test015-mvmemux.vhd	Simple nvme interface tests
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

component NvmeStreamMux is
port (
	clk		: in std_logic;					--! The interface clock line
	reset		: in std_logic;					--! The active high reset line
	
	hostIn		: inout AxisStreamType := AxisStreamInput;	--! Host multiplexed Input stream
	hostOut		: inout AxisStreamType := AxisStreamOutput;	--! Host multiplexed Ouput stream

	nvme0In		: inout AxisStreamType := AxisStreamInput;	--! Nvme0 Replies input stream
	nvme0Out	: inout AxisStreamType := AxisStreamOutput;	--! Nvme0 Requests output stream

	nvme1In		: inout AxisStreamType := AxisStreamInput;	--! Nvme1 Requests input stream
	nvme1Out	: inout AxisStreamType := AxisStreamOutput	--! Nvme1 replies output stream
);
end component;

constant TCQ		: time := 1 ns;
constant CHUNK_SIZE	: integer := 32;			-- The data write chunk size in DWords due to PCIe packet size limitations

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal hostIn		: AxisStreamType := AxisStreamInput;
signal hostOut		: AxisStreamType := AxisStreamOutput;
signal nvme0In		: AxisStreamType := AxisStreamInput;
signal nvme0Out		: AxisStreamType := AxisStreamOutput;
signal nvme1In		: AxisStreamType := AxisStreamInput;
signal nvme1Out		: AxisStreamType := AxisStreamOutput;

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
	
	-- Host to Nvme stream Mux/DeMux
	nvmeStreamMux0 : NvmeStreamMux
	port map (
		clk		=> clk,
		reset		=> reset,

		hostIn		=> hostOut,
		hostOut		=> hostIn,

		nvme0In		=> nvme0Out,
		nvme0Out	=> nvme0In,

		nvme1In		=> nvme1Out,
		nvme1Out	=> nvme1In
	);

	hostIn.ready <= '1';
	hostOut.valid <= '0';

	nvme0In.ready <= '1';

	nvme0 : process
	begin
		wait until reset = '0';

		--wait for 100 ns;
		
		-- Sets a Pcie request
		pcieRequestWrite(clk, nvme0Out, 0, 1, 4, 16#44#, 16, 16#00000100#);

		pcieRequestWrite(clk, nvme0Out, 0, 1, 4, 16#44#, 16, 16#00000100#);
		
		wait for 100 ns;
		-- Sets a Pcie request
		pcieRequestWrite(clk, nvme0Out, 0, 1, 4, 16#44#, 16, 16#00000100#);
		
		wait;
	end process;

	nvme1In.ready <= '1';

	nvme1 : process
	begin
		wait until reset = '0';
		--wait for 100 ns;
		
		-- Sets a Pcie request
		pcieRequestWrite(clk, nvme1Out, 0, 1, 4, 16#44#, 16, 16#00000100#);

		wait for 300 ns;
		pcieRequestWrite(clk, nvme1Out, 0, 1, 4, 16#44#, 16, 16#00000100#);
		wait until rising_edge(clk);
		
		wait;
	end process;
end;
