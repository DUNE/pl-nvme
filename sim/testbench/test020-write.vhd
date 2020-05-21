--------------------------------------------------------------------------------
--	Test020-write.vhd	Simple nvme interface tests
--	T.Barnaby,	Beam Ltd.	2020-05-12
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

--constant BlockSize	: integer := 512;			--! For simple testing should really be 4096
constant BlockSize	: integer := 4096;			--! Proper block size

component NvmeStorage is
generic(
	Simulate	: boolean	:= True;		--! Generate simulation core
	--ClockPeriod	: time		:= 10 ms;		--! Clock period for timers (125 MHz)
	ClockPeriod	: time		:= 8 ns;		--! Clock period for timers (125 MHz)
	BlockSize	: integer	:= Blocksize;		--! System block size
	NumBlocksDrop	: integer	:= 2			--! The number of blocks to drop at a time
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	axilIn		: in AxilToSlaveType;			--! Axil bus input signals
	axilOut		: out AxilToMasterType;			--! Axil bus output signals

	-- From host to NVMe request/reply streams
	hostSend	: in AxisType;				--! Host request stream
	hostSend_ready	: out std_logic;			--! Host request stream ready line
	hostRecv	: out AxisType;				--! Host reply stream
	hostRecv_ready	: in std_logic;				--! Host reply stream ready line

	-- AXIS data stream input
	dataDropBlocks	: in std_logic;				--! If set to '1' drop complete input blocks and account for the loss
	dataEnabledOut	: out std_logic;			--! Indicates that data ingest is enabled
	dataIn		: in AxisDataStreamType;		--! Raw data input stream
	dataIn_ready	: out std_logic;			--! Raw data input ready

	-- NVMe interface
	nvme_reset_n	: out std_logic;			--! Nvme reset output to reset NVMe devices

	nvme0_clk	: in std_logic;				--! Nvme0 external clock
	nvme0_clk_gt	: in std_logic;				--! Nvme0 external GT clock
	nvme0_exp_txp	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX plus lanes
	nvme0_exp_txn	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX minus lanes
	nvme0_exp_rxp	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX plus lanes
	nvme0_exp_rxn	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX minus lanes

	nvme1_clk	: in std_logic;				--! Nvme1 external clock
	nvme1_clk_gt	: in std_logic;				--! Nvme1 external GT clock
	nvme1_exp_txp	: out std_logic_vector(3 downto 0);	--! Nvme1 PCIe TX plus lanes
	nvme1_exp_txn	: out std_logic_vector(3 downto 0);	--! Nvme1 PCIe TX minus lanes
	nvme1_exp_rxp	: in std_logic_vector(3 downto 0);	--! Nvme1 PCIe RX plus lanes
	nvme1_exp_rxn	: in std_logic_vector(3 downto 0);	--! Nvme1 PCIe RX minus lanes


	-- Debug
	leds		: out std_logic_vector(5 downto 0)
);
end component;

component TestData is
generic(
	BlockSize	: integer := BlockSize			--! The block size in Bytes.
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	enable		: in std_logic;				--! Enable production of data

	-- AXIS data output
	dataOut		: out AxisDataStreamType;		--! Output data stream
	dataOutReady	: in std_logic
);
end component;

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

signal axil		: AxilBusType;
signal hostSend		: AxisType;
signal hostSend_ready	: std_logic := '0';
signal hostRecv		: AxisType;
signal hostRecv_ready	: std_logic := '0';

signal leds		: std_logic_vector(5 downto 0);

signal hostSend1	: AxisStreamType;
signal hostRecv1	: AxisStreamType;
signal hostReply	: AxisStreamType := AxisStreamInput;
signal hostReq		: AxisStreamType := AxisStreamOutput;
signal nvmeReq		: AxisStreamType := AxisStreamInput;
signal nvmeReply	: AxisStreamType := AxisStreamOutput;

signal dataStream	: AxisDataStreamType;
signal dataStreamReady	: std_logic := '0';

type NvmeStateType is (NVME_STATE_IDLE, NVME_STATE_WRITEDATA, NVME_STATE_READHEAD, NVME_STATE_READDATA);
signal nvmeState	: NvmeStateType := NVME_STATE_IDLE;
signal nvmeRequestHead	: PcieRequestHeadType;
signal nvmeRequestHead1	: PcieRequestHeadType;
signal nvmeReplyHead	: PcieReplyHeadType;
signal nvmeCount	: unsigned(10 downto 0);			-- DWord data send count
signal nvmeChunkCount	: unsigned(10 downto 0);			-- DWord data send within a chunk count
signal nvmeData		: std_logic_vector(127 downto 0);
signal nvmeData1	: std_logic_vector(127 downto 0);

signal sendData		: std_logic := '0';
signal dataDropBlocks	: std_logic := '0';

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
		--wait for 400 ns;
		wait for 14000 ns;
		assert false report "simulation ended ok" severity failure;
	end process;

	dropBlocks : process
	begin
		if(False) then
			-- Drop blocks. Assumes the BlockSize = 512 for testing
			wait for 400 ns;
			dataDropBlocks	<= '1';

			wait for 300 ns;
			dataDropBlocks	<= '0';
			
		end if;

		wait;
	end process;
	
	run : process
	begin
		axil.toSlave <= ((others => '0'), (others => '0'), '0', (others => '0'), (others => '0'), '0', '0', (others => '0'), (others => '0'), '0', '0');
		wait until reset = '0';

		if(False) then
			-- Test Read/Write NvmeStorageUnit's registers
			wait for 100 ns;
			busWrite(clk, axil.toSlave, axil.toMaster, 16#0004#, 16#40000000#);
			busWrite(clk, axil.toSlave, axil.toMaster, 16#0204#, 16#48000000#);
			busRead(clk, axil.toSlave, axil.toMaster, 16#0000#);
			busRead(clk, axil.toSlave, axil.toMaster, 16#0004#);
			busRead(clk, axil.toSlave, axil.toMaster, 16#0204#);

			wait;
		end if;
		
		if(False) then
			-- Test Read/Write NvmeWrite registers
			wait for 100 ns;
			busRead(clk, axil.toSlave, axil.toMaster, 16#0040#);
			busRead(clk, axil.toSlave, axil.toMaster, 16#0044#);
			busWrite(clk, axil.toSlave, axil.toMaster, 16#0040#, 16#00000004#);
			busRead(clk, axil.toSlave, axil.toMaster, 16#0040#);

			wait;
		end if;
		
		if(False) then
			-- Perform local reset
			wait for 100 ns;
			busWrite(clk, axil.toSlave, axil.toMaster, 4, 16#00000001#);
			busRead(clk, axil.toSlave, axil.toMaster, 16#0000#);
			busRead(clk, axil.toSlave, axil.toMaster, 16#0008#);
			busRead(clk, axil.toSlave, axil.toMaster, 16#0008#);
			wait for 200 ns;
			busRead(clk, axil.toSlave, axil.toMaster, 16#0008#);
		end if;
		
		if(True) then
			-- Start off TestData source and start writing data to Nvme
			wait for 100 ns;
			sendData <= '1';

			-- Write to NvmeStorage control register to start NvmeWrite processing
			wait for 100 ns;
			--busWrite(clk, axil.toSlave, axil.toMaster, 16#0044#, 2);		-- Number of blocks
			--busWrite(clk, axil.toSlave, axil.toMaster, 16#0044#, 16);		-- Number of blocks
			busWrite(clk, axil.toSlave, axil.toMaster, 16#0044#, 16386);		-- Number of blocks
			busWrite(clk, axil.toSlave, axil.toMaster, 16#0004#, 16#00000004#);	-- Start

			wait for 11000 ns;
			--busWrite(clk, axil.toSlave, axil.toMaster, 16#0004#, 16#00000000#);	-- Stop
			--busWrite(clk, axil.toSlave, axil.toMaster, 16#0004#, 16#00000004#);	-- Start
			wait;	
		end if;
		
		if(False) then
			-- Start off Reading data from block 8
			wait for 100 ns;

			busWrite(clk, axil.toSlave, axil.toMaster, 16#0188#, 8);		-- Start blocks
			busWrite(clk, axil.toSlave, axil.toMaster, 16#018C#, 2);		-- Number blocks
			busRead(clk, axil.toSlave, axil.toMaster, 16#0188#);

			busWrite(clk, axil.toSlave, axil.toMaster, 16#0180#, 16#00000001#);	-- Start

			wait for 11000 ns;
			--busWrite(clk, axil.toSlave, axil.toMaster, 16#0180#, 16#00000000#);	-- Stop
			wait;	
		end if;
		
		if(False) then
			-- Send command to IO queue to read a block
			wait for 100 ns;

			-- Write to DataQueue
			pcieRequestWriteHead(clk, hostReq, 1, 1, 16#02020000#, 16#22#, 16);

			wait until rising_edge(clk) and (hostReq.ready = '1');
			hostReq.data <= zeros(64) & x"00000001" & x"01000002";	-- Namespace 1, From stream1, opcode 2
			wait until rising_edge(clk) and (hostReq.ready = '1');
			hostReq.data <= zeros(32) & x"01800000" & zeros(64);	-- Data source address to host
			wait until rising_edge(clk) and (hostReq.ready = '1');
			hostReq.data <= zeros(32) & x"00000000" & zeros(64);	-- Block number
			wait until rising_edge(clk) and (hostReq.ready = '1');
			hostReq.data <= zeros(96) & to_stl(0, 32);		-- WriteMethod, NumBlocks (0 is 1 block)
			hostReq.last <= '1';
			wait until rising_edge(clk) and (hostReq.ready = '1');
			hostReq.last <= '0';
			hostReq.valid <= '0';
			
			wait;
		end if;

		--wait for 1000 ns;
		
		-- Perform local reset
		--busWrite(clk, axil.toSlave, axil.toMaster, 4, 16#00000001#);
		--wait for 1000 ns;

		-- Set PCIe configuration command register to 0x06
		--pcieRequestWrite(clk, hostReq, 1, 10, 4, 16#44#, 1, 16#00100006#);
		
		-- Read PCIe configuration command register
		--pcieRequestRead(clk, hostReq, 1, 8, 4, 16#55#, 1);
		
		-- Test Mux with Write to Nvmeregister 0
		--pcieRequestWrite(clk, hostReq, 1, 1, 16#0000#, 16#22#, 1, 16#40#);

		-- Write to AdminQueue doorbell register
		--pcieRequestWrite(clk, hostReq, 1, 1, 16#1000#, 16#22#, 1, 16#40#);

		-- Write to AdminQueue
		--pcieRequestWrite(clk, hostReq, 1, 1, 16#02000000#, 16#22#, 16, 16#00000010#);

		-- Write to DataQueue
		--pcieRequestWrite(clk, hostReq, 1, 1, 16#02010000#, 16#22#, 16, 16#00000010#);

		-- Perform NVMe data write
		-- Write to DataWriteQueue doorbell register
		--pcieRequestWrite(clk, hostReq, 1, 1, 16#1008#, 16#23#, 1, 16#40#);
		wait;
	end process;
	
	-- The test data interface
	testData0 : TestData
	port map (
		clk		=> clk,
		reset		=> reset,

		enable		=> sendData,

		dataOut		=> dataStream,
		dataOutReady	=> dataStreamReady
	);	

	axisConnect(hostSend, hostSend_ready, hostSend1);
	axisConnect(hostRecv1, hostRecv, hostRecv_ready);
	
	hostReply.ready <= '1';
	
	NvmeStorage0 : NvmeStorage
	port map (
		clk		=> clk,
		reset		=> reset,

		axilIn		=> axil.toSlave,
		axilOut		=> axil.toMaster,

		hostSend	=> hostSend,
		hostSend_ready	=> hostSend_ready,
		hostRecv	=> hostRecv,
		hostRecv_ready	=> hostRecv_ready,
		
		dataDropBlocks	=> dataDropBlocks,
		dataIn		=> dataStream,
		dataIn_ready	=> dataStreamReady,

		-- NVMe interface
		nvme0_clk	=> '0',
		nvme0_clk_gt	=> '0',
		--nvme0_exp_txp	: out std_logic_vector(0 downto 0);
		--nvme0_exp_txn	: out std_logic_vector(0 downto 0);
		nvme0_exp_rxp	=> "0000",
		nvme0_exp_rxn	=> "0000",

		nvme1_clk	=> '0',
		nvme1_clk_gt	=> '0',
		--nvme1_exp_txp	: out std_logic_vector(0 downto 0);
		--nvme1_exp_txn	: out std_logic_vector(0 downto 0);
		nvme1_exp_rxp	=> "0000",
		nvme1_exp_rxn	=> "0000",

		leds		=> leds
	);

	-- Host to Nvme stream Mux/DeMux
	pcieStreamMux0 : PcieStreamMux
	port map (
		clk		=> clk,
		reset		=> reset,

		stream1In	=> hostRecv1,
		stream1Out	=> hostSend1,
		
		stream2In	=> nvmeReply,
		stream2Out	=> nvmeReq,

		stream3In	=> hostReq,
		stream3Out	=> hostReply
	);


	nvmeRequestHead	<= to_PcieRequestHeadType(nvmeReq.data);
	nvmeReply.data <= nvmeData(31 downto 0) & to_stl(nvmeReplyHead) when(nvmeState = NVME_STATE_READHEAD)
		else nvmeData(31 downto 0) & nvmeData1(127 downto 32);
	
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
						nvmeRequestHead1	<= nvmeRequestHead;
						nvmeCount		<= nvmeRequestHead.count;

						if(nvmeRequestHead.request = 1) then
							nvmeState <= NVME_STATE_WRITEDATA;
						elsif(nvmeRequestHead.request = 0) then
							nvmeState <= NVME_STATE_READHEAD;
						end if;
					else
						nvmeReq.ready <= '1';
					end if;

				when NVME_STATE_WRITEDATA =>
					if((nvmeReq.ready = '1') and (nvmeReq.valid = '1') and (nvmeReq.last = '1')) then
						nvmeState <= NVME_STATE_IDLE;
					end if;
				
				
				when NVME_STATE_READHEAD =>
					nvmeReq.ready			<= '0';
					nvmeReplyHead.byteCount		<= nvmeCount & "00";
					nvmeReplyHead.address		<= nvmeRequestHead1.address(nvmeReplyHead.address'length - 1 downto 0);
					nvmeReplyHead.error		<= (others => '0');
					nvmeReplyHead.status		<= (others => '0');
					nvmeReplyHead.tag		<= nvmeRequestHead1.tag;
					nvmeReplyHead.requesterId	<= nvmeRequestHead1.requesterId;

					if(nvmeCount > CHUNK_SIZE) then
						nvmeReplyHead.count	<= to_unsigned(PcieMaxPayloadSize, nvmeReplyHead.count'length);
						nvmeChunkCount		<= to_unsigned(PcieMaxPayloadSize, nvmeReplyHead.count'length);
					else
						nvmeReplyHead.count	<= nvmeCount;
						nvmeChunkCount		<= nvmeCount;
					end if;
					
					nvmeData1		<= nvmeData;
					nvmeReply.keep	 	<= (others => '1');
					nvmeReply.valid 	<= '1';

					if(nvmeReply.ready = '1' and nvmeReply.valid = '1') then
						nvmeData 	<= std_logic_vector(unsigned(nvmeData) + 1);
						nvmeState	<= NVME_STATE_READDATA;
					end if;

				when NVME_STATE_READDATA =>
					if(nvmeReply.ready = '1' and nvmeReply.valid = '1') then
						nvmeData1	<= nvmeData;
						nvmeData 	<= std_logic_vector(unsigned(nvmeData) + 1);

						if(nvmeChunkCount = 4) then
							nvmeReply.last	<= '0';
							nvmeReply.valid <= '0';

							if(nvmeCount = 4) then
								nvmeState	<= NVME_STATE_IDLE;
							else
								nvmeState	<= NVME_STATE_READHEAD;
							end if;

						elsif(nvmeChunkCount = 8) then
							nvmeReply.keep <= zeros(4) & ones(12);
							nvmeReply.last <= '1';

						else
							nvmeReply.last <= '0';
						end if;
						
						nvmeChunkCount			<= nvmeChunkCount - 4;
						nvmeCount			<= nvmeCount - 4;
						nvmeRequestHead1.address	<= nvmeRequestHead1.address + 4;
					end if;
				end case;
			end if;
		end if;
	end process;
end;
