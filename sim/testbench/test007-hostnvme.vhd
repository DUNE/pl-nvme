--------------------------------------------------------------------------------
--	Test007-hostnvme.vhd	Simple host-nvme interface tests
--	T.Barnaby,	Beam Ltd.	2020-03-13
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

entity Test is
end;

architecture sim of Test is

component NvmeStorage is
generic(
	Simulate	: boolean	:= True;
	Divider		: integer	:= 5000000
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	axilIn		: in AxilToSlave;			--! Axil bus input signals
	axilOut		: out AxilToMaster;			--! Axil bus output signals

	-- From host to NVMe request/reply streams
	hostSend	: inout AxisStream := AxisStreamInput;	--! Host request stream
	hostRecv	: inout AxisStream := AxisStreamOutput;	--! Host reply stream

	-- AXIS data stream input
	--dataRx	: inout AxisStream	:= AxisStreamInput;	--! Raw data to save stream

	-- NVMe interface
	nvme_clk_p	: in std_logic;				--! Nvme external clock +ve
	nvme_clk_n	: in std_logic;				--! Nvme external clock -ve
	nvme_reset_n	: out std_logic;			--! Nvme reset output to reset NVMe devices
	nvme0_exp_txp	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX plus lanes
	nvme0_exp_txn	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX minus lanes
	nvme0_exp_rxp	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX plus lanes
	nvme0_exp_rxn	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX minus lanes

	-- Debug
	leds		: out std_logic_vector(3 downto 0)
);
end component;

component AxisStreamMux is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn1	: inout AxisStream := AxisStreamInput;	--! Input data stream
	streamIn2	: inout AxisStream := AxisStreamInput;	--! Input data stream

	streamOut	: inout AxisStream := AxisStreamOutput	--! Output data stream
);
end component;

component AxisStreamDeMux is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisStream := AxisStreamInput;	--! Input data stream

	streamOut1	: inout AxisStream := AxisStreamOutput;	--! Output data stream1
	streamOut2	: inout AxisStream := AxisStreamOutput	--! Output data stream2
);
end component;

constant TCQ		: time := 1 ns;
constant CHUNK_SIZE	: integer := 32;			-- The data write chunk size in DWords due to PCIe packet size limitations

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal axil		: AxilBus;
signal hostSend		: AxisStream	:= AxisStreamOutput;
signal hostRecv		: AxisStream	:= AxisStreamInput;

signal leds		: std_logic_vector(3 downto 0);

signal hostReply	: AxisStream	:= AxisStreamInput;
signal hostReq		: AxisStream	:= AxisStreamOutput;
signal nvmeReq		: AxisStream	:= AxisStreamOutput;
signal nvmeReply	: AxisStream	:= AxisStreamInput;

type NvmeStateType is (NVME_STATE_IDLE, NVME_STATE_WRITEDATA_START, NVME_STATE_WRITEDATA);
signal nvmeState	: NvmeStateType := NVME_STATE_IDLE;
signal nvmeRequestHead	: PcieRequestHead;
signal nvmeRequestHead1	: PcieRequestHead;
signal nvmeReplyHead	: PcieReplyHead;
signal nvmeCount	: unsigned(10 downto 0);			-- DWord data send count
signal nvmeChunkCount	: unsigned(10 downto 0);			-- DWord data send within a chunk count
signal nvmeByteCount	: integer;
signal nvmeData		: std_logic_vector(127 downto 0);

signal sendData		: std_logic := '0';

procedure pcieWrite(signal toSlave: inout AxisStream; config: in integer; address: in integer; tag: in integer; data: in integer) is
variable packetHead	: PcieRequestHead;
begin
	packetHead.nvme := to_unsigned(0, packetHead.nvme'length);
	packetHead.stream := to_unsigned(0, packetHead.stream'length);
	packetHead.address := to_stl(address, packetHead.address'length);
	packetHead.tag := to_stl(tag, packetHead.tag'length);
	packetHead.count := to_unsigned(0, packetHead.count'length);
	
	if(config = 1) then
		packetHead.request := to_unsigned(10, packetHead.request'length);
	else
		packetHead.request := to_unsigned(1, packetHead.request'length);
	end if;

	-- Write address
	wait until rising_edge(clk);
	toSlave.data <= to_stl(packetHead);
	toSlave.valid <= '1';

	wait until rising_edge(clk) and (toSlave.ready = '1');
	toSlave.data <= to_stl(0, 96) & to_stl(data, 32);
	toSlave.valid <= '1';
	toSlave.last <= '1';
	
	wait until rising_edge(clk) and (toSlave.ready = '1');
	toSlave.valid <= '0';
	toSlave.last <= '0';
end procedure;

begin
	nvmeStorage0 : NvmeStorage
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
		--nvme0_exp_txp	: out std_logic_vector(0 downto 0);
		--nvme0_exp_txn	: out std_logic_vector(0 downto 0);
		nvme0_exp_rxp	=> "0000",
		nvme0_exp_rxn	=> "0000",

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
		
		-- Set PCIe configuration command register to 0x06
		--pcieWrite(hostReq, 1, 4, 1, 6);
		
		-- Write to AdminQueue doorbell register
		pcieWrite(hostReq, 0, 16#1000#, 16#22#, 16#40#);

		-- Perfoem NVMe wdata write
		-- Write to DataWriteQueue doorbell register
		--pcieWrite(hostReq, 0, 16#1008#, 16#23#, 16#40#);
		wait;
	end process;
	
	-- Host to Nvme stream Mux
	axisMux0 : AxisStreamMux
	port map (
		clk		=> clk,
		reset		=> reset,

		streamIn1	=> hostReq,
		streamIn2	=> nvmeReply,

		streamOut	=> hostSend
	);

	-- Nvme to Host stream DeMux
	axisDeMux0 : AxisStreamDeMux
	port map (
		clk		=> clk,
		reset		=> reset,

		streamIn	=> hostRecv,

		streamOut1	=> hostReply,
		streamOut2	=> nvmeReq
	);
	
	nvmeRequestHead	<= to_PcieRequestHead(nvmeReq.data);
	nvmeReply.data <= nvmeData when(nvmeState = NVME_STATE_WRITEDATA) else to_stl(nvmeReplyHead);
	
	requests : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				nvmeReq.ready	<= '0';
				nvmeReply.valid <= '0';
				nvmeReply.last	<= '0';
				nvmeData	<= (others => '0');
				nvmeState	<= NVME_STATE_IDLE;
			else
				case (nvmeState) is
				when NVME_STATE_IDLE =>
					if(nvmeReq.ready = '1' and nvmeReq.valid = '1') then
						nvmeRequestHead1	<= nvmeRequestHead;
						nvmeCount		<= nvmeRequestHead.count + 1;
						nvmeState		<= NVME_STATE_WRITEDATA_START;
						nvmeReq.ready		<= '0';
					else
						nvmeReq.ready		<= '1';
					end if;

				when NVME_STATE_WRITEDATA_START =>
					nvmeReplyHead.byteCount	<= (nvmeRequestHead1.count + 1) & "00";
					nvmeReplyHead.address	<= nvmeRequestHead1.address(nvmeReplyHead.address'length - 1 downto 0);
					nvmeReplyHead.error	<= (others => '0');
					nvmeReplyHead.status	<= (others => '0');
					nvmeReplyHead.tag	<= nvmeRequestHead1.tag;

					if(nvmeCount > CHUNK_SIZE) then
						nvmeReplyHead.count	<= to_unsigned(CHUNK_SIZE-1, nvmeReplyHead.count'length);
						nvmeChunkCount		<= to_unsigned(CHUNK_SIZE, nvmeReplyHead.count'length);
					else
						nvmeReplyHead.count	<= nvmeCount - 1;
						nvmeChunkCount		<= nvmeCount;
					end if;

					nvmeByteCount		<= (to_integer(nvmeRequestHead1.count) + 1) * 4;
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
