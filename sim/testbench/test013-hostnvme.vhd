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

component NvmeStorageUnit is
generic(
	Simulate	: boolean	:= True
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	axilIn		: in AxilToSlaveType;			--! Axil bus input signals
	axilOut		: out AxilToMasterType;			--! Axil bus output signals

	-- From host to NVMe request/reply streams
	hostSend	: inout AxisStreamType := AxisStreamInput;	--! Host request stream
	hostRecv	: inout AxisStreamType := AxisStreamOutput;	--! Host reply stream

	-- AXIS data stream input
	--dataRx	: inout AxisStreamType	:= AxisStreamInput;	--! Raw data to save stream

	-- NVMe interface
	nvme_clk_p	: in std_logic;				--! Nvme external clock +ve
	nvme_clk_n	: in std_logic;				--! Nvme external clock -ve
	nvme_reset_n	: out std_logic;			--! Nvme reset output to reset NVMe devices
	nvme_exp_txp	: out std_logic_vector(3 downto 0);	--! Nvme PCIe TX plus lanes
	nvme_exp_txn	: out std_logic_vector(3 downto 0);	--! Nvme PCIe TX minus lanes
	nvme_exp_rxp	: in std_logic_vector(3 downto 0);	--! Nvme PCIe RX plus lanes
	nvme_exp_rxn	: in std_logic_vector(3 downto 0);	--! Nvme PCIe RX minus lanes

	-- Debug
	leds		: out std_logic_vector(3 downto 0)
);
end component;

component NvmeStreamMux is
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

signal axil		: AxilBusType;
signal hostSend		: AxisStreamType	:= AxisStreamOutput;
signal hostRecv		: AxisStreamType	:= AxisStreamInput;

signal leds		: std_logic_vector(3 downto 0);

signal hostReply	: AxisStreamType	:= AxisStreamInput;
signal hostReq		: AxisStreamType	:= AxisStreamOutput;
signal nvmeReq		: AxisStreamType	:= AxisStreamInput;
signal nvmeReply	: AxisStreamType	:= AxisStreamOutput;

type NvmeStateType is (NVME_STATE_IDLE, NVME_STATE_WRITEDATA_START, NVME_STATE_WRITEDATA);
signal nvmeState	: NvmeStateType := NVME_STATE_IDLE;
signal nvmeRequestHeadType	: PcieRequestHeadType;
signal nvmeRequestHeadType1	: PcieRequestHeadType;
signal nvmeReplyHeadType	: PcieReplyHeadType;
signal nvmeCount	: unsigned(10 downto 0);			-- DWord data send count
signal nvmeChunkCount	: unsigned(10 downto 0);			-- DWord data send within a chunk count
signal nvmeByteCount	: integer;
signal nvmeData		: std_logic_vector(127 downto 0);

signal sendData		: std_logic := '0';

begin
	hostReply.ready <= '1';
	
	NvmeStorageUnit0 : NvmeStorageUnit
	port map (
		clk		=> clk,
		reset		=> reset,

		axilIn		=> axil.toSlave,
		axilOut		=> axil.toMaster,

		hostSend	=> hostSend,
		hostRecv	=> hostRecv,

		-- NVMe interface
		nvme_clk_p	=> '0',
		nvme_clk_n	=> '0',
		--nvme_exp_txp	: out std_logic_vector(0 downto 0);
		--nvme_exp_txn	: out std_logic_vector(0 downto 0);
		nvme_exp_rxp	=> "0000",
		nvme_exp_rxn	=> "0000",

		leds		=> leds
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
		wait for 1000 ns;

		-- Set PCIe configuration command register to 0x06
		pcieRequestWrite(clk, hostReq, 5, 10, 4, 16#44#, 1, 16#00100006#);
		
		-- Read PCIe configuration command register
		pcieRequestRead(clk, hostReq, 5, 8, 4, 16#55#, 1);
		
		-- Test Mux with Write to Nvmeregister 0
		pcieRequestWrite(clk, hostReq, 5, 1, 16#0000#, 16#22#, 1, 16#40#);
		--wait until rising_edge(clk);
		--pcieSendReply(clk, nvmeReply, 5, 0, 16#1000#, 16#22#, 0, 0);

		-- Write to AdminQueue doorbell register
		pcieRequestWrite(clk, hostReq, 5, 1, 16#1000#, 16#22#, 1, 16#40#);

		-- Perform NVMe data write
		-- Write to DataWriteQueue doorbell register
		--pcieRequestWrite(clk, hostReq, 5, 1, 16#1008#, 16#23#, 1, 16#40#);
		wait;
	end process;
	
	-- Host to Nvme stream Mux/DeMux
	nvmeStreamMux0 : NvmeStreamMux
	port map (
		clk		=> clk,
		reset		=> reset,

		stream1In	=> hostRecv,
		stream1Out	=> hostSend,
		
		stream2In	=> nvmeReply,
		stream2Out	=> nvmeReq,

		stream3In	=> hostReq,
		stream3Out	=> hostReply
	);


	nvmeRequestHeadType	<= to_PcieRequestHeadType(nvmeReq.data);
	nvmeReply.data <= nvmeData when(nvmeState = NVME_STATE_WRITEDATA) else concat('0', 32) & to_stl(nvmeReplyHeadType);
	
	requests : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				nvmeReq.ready	<= '0';
				nvmeReply.valid <= '0';
				nvmeReply.last	<= '0';
				nvmeReply.keep	<= (others => '1');
				nvmeData	<= (others => '0');
				nvmeState	<= NVME_STATE_IDLE;
			else
				case (nvmeState) is
				when NVME_STATE_IDLE =>
					if(nvmeReq.ready = '1' and nvmeReq.valid = '1') then
						nvmeRequestHeadType1	<= nvmeRequestHeadType;
						nvmeCount		<= nvmeRequestHeadType.count + 1;
						nvmeState		<= NVME_STATE_WRITEDATA_START;
						nvmeReq.ready		<= '0';
					else
						nvmeReq.ready		<= '1';
					end if;

				when NVME_STATE_WRITEDATA_START =>
					nvmeReplyHeadType.byteCount	<= nvmeRequestHeadType1.count & "00";
					nvmeReplyHeadType.address	<= nvmeRequestHeadType1.address(nvmeReplyHeadType.address'length - 1 downto 0);
					nvmeReplyHeadType.error	<= (others => '0');
					nvmeReplyHeadType.status	<= (others => '0');
					nvmeReplyHeadType.tag	<= nvmeRequestHeadType1.tag;
					nvmeReplyHeadType.requesterId	<= nvmeRequestHeadType1.requesterId;

					if(nvmeCount > CHUNK_SIZE) then
						nvmeReplyHeadType.count	<= to_unsigned(CHUNK_SIZE-1, nvmeReplyHeadType.count'length);
						nvmeChunkCount		<= to_unsigned(CHUNK_SIZE, nvmeReplyHeadType.count'length);
					else
						nvmeReplyHeadType.count	<= nvmeCount - 1;
						nvmeChunkCount		<= nvmeCount;
					end if;

					nvmeByteCount		<= (to_integer(nvmeRequestHeadType1.count) + 1) * 4;
					nvmeReply.valid 	<= '1';

					if(nvmeReply.ready = '1' and nvmeReply.valid = '1') then
						nvmeData 	<= std_logic_vector(unsigned(nvmeData) + 1);
						nvmeState	<= NVME_STATE_WRITEDATA;
					end if;

				when NVME_STATE_WRITEDATA =>
					if(nvmeReply.ready = '1' and nvmeReply.valid = '1') then
						nvmeData 	<= std_logic_vector(unsigned(nvmeData) + 1);
						if(nvmeChunkCount = 4) then
							if(nvmeCount = 4) then
								nvmeReply.valid <= '0';
								nvmeReply.last	<= '0';
								nvmeState	<= NVME_STATE_IDLE;
							else
								nvmeReply.last	<= '0';
								nvmeState	<= NVME_STATE_WRITEDATA_START;
							end if;
						elsif(nvmeChunkCount = 8) then
							nvmeReply.last <= '1';
						else
							nvmeReply.last <= '0';
						end if;
						nvmeChunkCount	<= nvmeChunkCount - 4;
						nvmeCount	<= nvmeCount - 4;
					end if;
				end case;
			end if;
		end if;
	end process;

	stop : process
	begin
		wait for 700 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
end;
