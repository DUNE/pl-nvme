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

component PcieStreamMux is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	stream1In	: inout AxisStreamType := AxisStreamInput;	--! Single multiplexed Input stream
	stream1Out	: inout AxisStreamType := AxisStreamOutput;	--! Single multiplexed Ouput stream

	stream2In	: inout AxisStreamType := AxisStreamInput;	--! Host Replies input stream
	stream2Out	: inout AxisStreamType := AxisStreamOutput;	--! Host Requests output stream

	stream3In	: inout AxisStreamType := AxisStreamInput;	--! Nvme Requests input stream
	stream3Out	: inout AxisStreamType := AxisStreamOutput	--! Nvme replies output stream
);
end component;

constant TCQ		: time := 1 ns;
constant CHUNK_SIZE	: integer := 32;			-- The data write chunk size in DWords due to PCIe packet size limitations

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal fromHost		: AxisStreamType := AxisStreamOutput;
signal toHost		: AxisStreamType := AxisStreamInput;

signal hostReply	: AxisStreamType := AxisStreamInput;
signal hostReq		: AxisStreamType := AxisStreamOutput;
signal nvmeReq		: AxisStreamType := AxisStreamInput;
signal nvmeReply	: AxisStreamType := AxisStreamOutput;

type NvmeStateType is (NVME_STATE_IDLE, NVME_STATE_WRITEDATA_START, NVME_STATE_WRITEDATA);
signal nvmeState	: NvmeStateType := NVME_STATE_IDLE;
signal nvmeRequestHead	: PcieRequestHeadType;
signal nvmeRequestHead1	: PcieRequestHeadType;
signal nvmeReplyHead	: PcieReplyHeadType;
signal nvmeCount	: unsigned(10 downto 0);			-- DWord data send count
signal nvmeChunkCount	: unsigned(10 downto 0);			-- DWord data send within a chunk count
signal nvmeByteCount	: integer;
signal nvmeData		: std_logic_vector(127 downto 0);

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
	pcieStreamMux0 : PcieStreamMux
	port map (
		clk		=> clk,
		reset		=> reset,

		stream1In	=> fromHost,
		stream1Out	=> toHost,
		
		stream2In	=> nvmeReply,
		stream2Out	=> nvmeReq,

		stream3In	=> hostReq,
		stream3Out	=> hostReply
	);

	demuxSend: process
	begin
		wait until reset = '0';
		
		if(true) then
			-- Send a PCIe write request
			wait until rising_edge(clk);
			pcieRequestWrite(clk, fromHost, 1, 1, 4, 16#44#, 16, 16#0000100#);

			-- Send a PCIe reply
			pcieReply(clk, fromHost, 1, 3, 4, 16#44#, 16, 16#0000100#);

			-- Send a PCIe reply
			pcieReply(clk, fromHost, 1, 3, 4, 16#44#, 1, 16#0000100#);
		end if;

		wait;
	end process;
	
	demuxRecv: process
	begin
		nvmeReq.ready	<= '0';
		
		if(true) then
			if(true) then
				nvmeReq.ready	<= '1';
				wait;
			end if;

			if(false) then
				wait for 50 ns;
				wait until rising_edge(clk);
				nvmeReq.ready <= '1';
				wait;
			end if;

			if(false) then
				wait for 50 ns;
				for i in 0 to 4 loop
					wait until rising_edge(clk);
					nvmeReq.ready <= not nvmeReq.ready;
				end loop;
			end if;

			if(true) then
				wait for 50 ns;
				for i in 0 to 4 loop
					wait until rising_edge(clk);
					wait until rising_edge(clk);
					nvmeReq.ready <= not nvmeReq.ready;
				end loop;
			end if;
		end if;

		wait;
	end process;
	
	muxSend: process
	begin
		hostReq.valid <= '0';
		hostReply.ready <= '1';
		nvmeReply.valid	<= '0';

		wait until reset = '0';
		
		if(true) then
			-- Send a PCIe reply
			--pcieReply(clk, hostReq, 1, 16#AAAA#, 4, 16#44#, 4, 16#0000100#);
			--wait;

			-- Send a PCIe write request
			pcieRequestWrite(clk, hostReq, 1, 1, 4, 16#44#, 16, 16#0000100#);

			-- Send a PCIe reply
			wait until rising_edge(clk);
			pcieReply(clk, hostReq, 1, 3, 4, 16#44#, 16, 16#0000100#);

			-- Send a PCIe reply
			wait until rising_edge(clk);
			pcieReply(clk, hostReq, 1, 3, 4, 16#44#, 4, 16#0000100#);

			-- Send a PCIe reply
			wait until rising_edge(clk);
			pcieReply(clk, hostReq, 1, 3, 4, 16#44#, 1, 16#0000100#);

			-- Send a PCIe write request
			wait until rising_edge(clk);
			pcieRequestWrite(clk, nvmeReply, 1, 1, 4, 16#44#, 16, 16#0000100#);
		end if;

		wait;
	end process;
	
	muxRecv: process
	begin
		toHost.ready <= '0';
		
		if(true) then
			if(true) then
				toHost.ready	<= '1';
				wait;
			end if;

			if(false) then
				wait for 50 ns;
				wait until rising_edge(clk);
				toHost.ready <= '1';
				wait;
			end if;

			if(false) then
				wait for 50 ns;
				for i in 0 to 16 loop
					wait until rising_edge(clk);
					toHost.ready <= not toHost.ready;
				end loop;
			end if;

			if(true) then
				wait for 50 ns;
				for i in 0 to 16 loop
					wait until rising_edge(clk);
					wait until rising_edge(clk);
					toHost.ready <= not toHost.ready;
				end loop;
			end if;
		end if;
		
		wait;
	end process;


end;
