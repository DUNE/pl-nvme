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
use work.AxiPkg.all;
use work.NvmeStoragePkg.all;
use work.TestPkg.all;

entity Test is
end;

architecture sim of Test is

constant TCQ		: time := 1 ns;
constant CHUNK_SIZE	: integer := 32;			-- The data write chunk size in DWords due to PCIe packet size limitations
constant NumQueueEntries: integer	:= 2;

component NvmeQueues is
generic(
	NumQueueEntries	: integer	:= NumQueueEntries;	--! The number of entries per queue
	Simulate	: boolean	:= True
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	hostRequestIn	: inout AxisStream := AxisInput;	--! Request queue entries
	hostRequestPos	: out unsigned(log2(NumQueueEntries)-1 downto 0);		--! Current queue position for last request queue entry

	hostReplyOut	: inout AxisStream := AxisOutput;	--! Replies
	hostReplyPos	: out unsigned(log2(NumQueueEntries)-1 downto 0);		--! Current queue position for last reply queue entry
	
	-- Nvme read/write data interface
	nvmeRequestIn	: inout AxisStream := AxisInput;	--! Nvme Request queue entries
	nvmeReplyOut	: inout AxisStream := AxisOutput	--! Nvme Replies
);
end component;

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal hostReq		: AxisStream	:= AxisOutput;
signal hostReply	: AxisStream	:= AxisInput;
signal nvmeReq		: AxisStream	:= AxisOutput;
signal nvmeReply	: AxisStream	:= AxisInput;

signal hostReqPos	: unsigned(log2(NumQueueEntries)-1 downto 0);
signal hostReplyPos	: unsigned(log2(NumQueueEntries)-1 downto 0);

type NvmeStateType is (NVME_STATE_IDLE, NVME_STATE_WRITEDATA_START, NVME_STATE_WRITEDATA);
signal nvmeState	: NvmeStateType := NVME_STATE_IDLE;
signal nvmeRequestHead	: PcieRequestHead;
signal nvmeRequestHead1	: PcieRequestHead;
signal nvmeReplyHead	: PcieReplyHead;
signal nvmeCount	: unsigned(10 downto 0);			-- DWord data send count
signal nvmeChunkCount	: unsigned(10 downto 0);			-- DWord data send within a chunk count
signal nvmeByteCount	: integer;
signal nvmeData		: std_logic_vector(127 downto 0);


begin
	hostReply.ready <= '1';
	nvmeReply.ready <= '1';
	
	NvmeQueues0 : NvmeQueues
	port map (
		clk		=> clk,
		reset		=> reset,

		hostRequestIn	=> hostReq,
		hostRequestPos	=> hostReqPos,

		hostReplyOut	=> hostReply,
		hostReplyPos	=> hostReplyPos,

		-- NVMe interface
		nvmeRequestIn	=> nvmeReq,
		nvmeReplyOut	=> nvmeReply
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
		
		-- Write queue entry
		pcieWriteRequest(clk, hostReq, 1, 1, 0, 16#44#, 16, 16#00100000#);
		pcieWriteRequest(clk, hostReq, 1, 1, 0, 16#44#, 16, 16#00200000#);
		pcieWriteRequest(clk, hostReq, 1, 1, 0, 16#44#, 16, 16#00300000#);
		
		--pcieWriteRequest(clk, nvmeReq, 1, 1, 0, 16#44#, 1, 16#00400000#);
		--pcieWriteRequest(clk, nvmeReq, 1, 1, 0, 16#44#, 1, 16#00500000#);
		pcieReadRequest(clk, nvmeReq, 0, 1, 0, 16#44#, 16);

		wait;
	end process;
	
	stop : process
	begin
		wait for 700 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
end;
