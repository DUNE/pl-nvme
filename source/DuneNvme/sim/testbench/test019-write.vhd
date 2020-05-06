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

--constant BlockSize	: integer := 512;			--! For simple testing should be 4096
constant BlockSize	: integer := 4096;			--! Proper block size

component NvmeStorageUnit is
generic(
	Simulate	: boolean	:= True;		--! Generate simulation core
	ClockPeriod	: time		:= 10 ms;		--! Clock period for timers (125 MHz)
	BlockSize	: integer	:= Blocksize
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	axilIn		: in AxilToSlaveType;			--! Axil bus input signals
	axilOut		: out AxilToMasterType;			--! Axil bus output signals

	-- From host to NVMe request/reply streams
	hostSend	: inout AxisStreamType := AxisInput;	--! Host request stream
	hostRecv	: inout AxisStreamType := AxisOutput;	--! Host reply stream

	-- AXIS data stream input
	dataEnabledOut	: out std_logic;			--! Indicates that data ingest is enabled
	dataIn		: inout AxisStreamType	:= AxisInput;	--! Raw data to save stream

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
	dataStream	: inout AxisStreamType := AxisOutput	--! Output data stream
);
end component;

component NvmeStreamMux is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	stream1In	: inout AxisStreamType := AxisInput;	--! Single multiplexed Input stream
	stream1Out	: inout AxisStreamType := AxisOutput;	--! Single multiplexed Ouput stream

	stream2In	: inout AxisStreamType := AxisInput;	--! Host Replies input stream
	stream2Out	: inout AxisStreamType := AxisOutput;	--! Host Requests output stream

	stream3In	: inout AxisStreamType := AxisInput;	--! Nvme Requests input stream
	stream3Out	: inout AxisStreamType := AxisOutput	--! Nvme replies output stream
);
end component;

constant TCQ		: time := 1 ns;
constant CHUNK_SIZE	: integer := 32;			-- The data write chunk size in DWords due to PCIe packet size limitations

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal axil		: AxilBusType;
signal hostSend		: AxisStreamType := AxisOutput;
signal hostRecv		: AxisStreamType := AxisInput;

signal leds		: std_logic_vector(3 downto 0);

signal hostReply	: AxisStreamType := AxisInput;
signal hostReq		: AxisStreamType := AxisOutput;
signal nvmeReq		: AxisStreamType := AxisInput;
signal nvmeReply	: AxisStreamType := AxisOutput;
signal dataIn		: AxisStreamType;

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
		
		dataIn		=> dataIn,

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

		-- Test NvmeWrite
		wait for 100 ns;
		sendData <= '1';

		-- Write to NvmeStorage control register to start NvmeWrite processing
		wait for 100 ns;
		busWrite(clk, axil.toSlave, axil.toMaster, 4, 16#00000004#);

		-- Read status registers
		wait for 100 ns;
		busRead(clk, axil.toSlave, axil.toMaster, 32);
		busRead(clk, axil.toSlave, axil.toMaster, 36);

		wait;		
		
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
		pcieRequestWrite(clk, hostReq, 1, 1, 16#02000000#, 16#22#, 16, 16#00000010#);

		-- Write to DataQueue
		pcieRequestWrite(clk, hostReq, 1, 1, 16#02010000#, 16#22#, 16, 16#00000010#);

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

		dataStream	=> dataIn
	);	


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
							if(nvmeCount = 4) then
								nvmeReply.last	<= '0';
								nvmeReply.valid <= '0';
								nvmeState	<= NVME_STATE_IDLE;
							else
								nvmeReply.last	<= '0';
								nvmeReply.valid <= '0';
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

	stop : process
	begin
		--wait for 2000 ns;
		wait for 14000 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
end;
