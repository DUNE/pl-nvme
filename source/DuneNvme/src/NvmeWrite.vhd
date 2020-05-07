--------------------------------------------------------------------------------
--	NvmeWrite.vhd Nvme Write data module
--	T.Barnaby, Beam Ltd. 2020-02-28
-------------------------------------------------------------------------------
--!
--! @class	NvmeWrite
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-14
--! @version	0.0.1
--!
--! @brief
--! This module performs the Nvme write data functionality.
--!
--! @details
--! TBD.
--!
--! @copyright GNU GPL License
--! Copyright (c) Beam Ltd, All rights reserved. <br>
--! This code is free software: you can redistribute it and/or modify
--! it under the terms of the GNU General Public License as published by
--! the Free Software Foundation, either version 3 of the License, or
--! (at your option) any later version.
--! This program is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--! GNU General Public License for more details. <br>
--! You should have received a copy of the GNU General Public License
--! along with this code. If not, see <https://www.gnu.org/licenses/>.
--!
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.NvmeStoragePkg.all;
use work.NvmeStorageIntPkg.all;

entity NvmeWrite is
generic(
	Simulate	: boolean := False;			--! Generate simulation core
	BlockSize	: integer := NvmeStorageBlockSize	--! System block size
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	enable		: in std_logic;				--! Enable the data writing process
	dataIn		: inout AxisStreamType := AxisInput;	--! Raw data to save stream

	-- To Nvme Request/reply streams
	requestOut	: inout AxisStreamType := AxisOutput;	--! To Nvme request stream (3)
	replyIn		: inout AxisStreamType := AxisInput;	--! from Nvme reply stream

	-- From Nvme Request/reply streams
	memReqIn	: inout AxisStreamType := AxisInput;	--! From Nvme request stream (4)
	memReplyOut	: inout AxisStreamType := AxisOutput;	--! To Nvme reply stream
	
	regWrite	: in std_logic;				--! Enable write to register
	regAddress	: in unsigned(5 downto 0);		--! Register to read/write
	regDataIn	: in std_logic_vector(31 downto 0);	--! Register write data
	regDataOut	: out std_logic_vector(31 downto 0)	--! Register contents
);
end;

architecture Behavioral of NvmeWrite is

--! Set the fields in the PCIe TLP header
function setHeader(request: integer; address: integer; count: integer; tag: integer) return std_logic_vector is
begin
	return to_stl(set_PcieRequestHeadType(3, request, address, count, tag));
end function;

constant TCQ		: time := 1 ns;
constant SimDelay	: boolean := False;			--! Input data delay after each packet for simulation tests
--constant NumBlocksRun	: integer := 2;				--! The total number of blocks in a run
constant NumBlocksRun	: integer := 262144;			--! The total number of blocks in a run

constant NvmeBlocks	: integer := BlockSize / 512;		--! The number of Nvme blocks per NvmeStorage system block
constant RamSize	: integer := (NvmeWriteNum * BlockSize) / 16;	-- One block per write buffer
constant AddressWidth	: integer := log2(RamSize);
constant BlockSizeWidth	: integer := log2(BlockSize);

component DataBuffer is
generic(
	Simulate	: boolean := Simulate;			--! Generate simulation core
	Size		: integer := RamSize;			--! The Buffer size in 128 bit words
	AddressWidth	: integer := AddressWidth
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	writeEnable	: in std_logic;
	writeAddress	: in unsigned(AddressWidth-1 downto 0);	
	writeData	: in std_logic_vector(127 downto 0);	

	readEnable	: in std_logic;
	readAddress	: in unsigned(AddressWidth-1 downto 0);	
	readData	: out std_logic_vector(127 downto 0)	
);
end component;

--! Input buffer status
type BufferType is record
	inUse1		: std_logic;				--! inUse1 and inUse2 are used to indicate buffer is in use when different
	inUse2		: std_logic;
	full		: std_logic;				--! The buffer is full
	process1	: std_logic;				--! process1 and process2 are used to indicate buffer is being sent to Nvme
	process2	: std_logic;
	blockNumber	: unsigned(31 downto 0);		--! The first block number in the buffer
end record;

subtype RegisterType	is unsigned(31 downto 0);
type BufferArrayType	is array (0 to NvmeWriteNum-1) of BufferType;

type InStateType	is (INSTATE_IDLE, INSTATE_INIT, INSTATE_CHOOSE, INSTATE_INPUT_BLOCK, INSTATE_DELAY, INSTATE_COMPLETE);
type StateType		is (STATE_IDLE, STATE_INIT, STATE_RUN, STATE_COMPLETE,
				STATE_QUEUE_HEAD, STATE_QUEUE_0, STATE_QUEUE_1, STATE_QUEUE_2, STATE_QUEUE_3,
				STATE_WAIT_REPLY);
type ReplyStateType	is (REPLY_STATE_QUEUE_REPLY1, REPLY_STATE_QUEUE_REPLY2);

signal inState		: InStateType := INSTATE_IDLE;
signal state		: StateType := STATE_IDLE;
signal replyState	: ReplyStateType := REPLY_STATE_QUEUE_REPLY1;

signal blockNumber	: unsigned(31 downto 0) := (others => '0');
signal numIn		: integer := 0;
signal num		: integer := 0;
signal numReply		: integer := 0;


-- Input buffers
signal writeEnable	: std_logic := '0';
signal writeAddress	: unsigned(AddressWidth-1 downto 0) := (others => '0');
signal readEnable	: std_logic := '0';
signal readAddress	: unsigned(AddressWidth-1 downto 0) := (others => '0');
signal readData		: std_logic_vector(127 downto 0) := (others => '0');

signal buffers		: BufferArrayType := (others => ('Z', 'Z', 'Z', 'Z', 'Z', (others => 'Z')));
signal bufferInNum	: integer range 0 to NvmeWriteNum-1 := 0;
signal bufferInNumNext	: integer range 0 to NvmeWriteNum-1 := 0;
signal bufferOutNum	: integer range 0 to NvmeWriteNum-1 := 0;
signal bufferOutNumNext	: integer range 0 to NvmeWriteNum-1 := 0;


-- Buffer read
type MemStateType	is (MEMSTATE_IDLE, MEMSTATE_READHEAD, MEMSTATE_READDATA);
signal memState		: MemStateType := MEMSTATE_IDLE;
signal memRequestHead	: PcieRequestHeadType;
signal memRequestHead1	: PcieRequestHeadType;
signal memReplyHead	: PcieReplyHeadType;
signal nvmeReplyHead	: NvmeReplyHeadType;
signal memCount		: unsigned(10 downto 0);			-- DWord data send count
signal memChunkCount	: unsigned(10 downto 0);			-- DWord data send within a chunk count
signal memData		: std_logic_vector(127 downto 0);

-- Register information
signal dataChunkSize	: RegisterType := (others => '0');	-- The data chunk size in blocks
signal error		: RegisterType := (others => '0');	-- The system errors status
signal numBlocks	: RegisterType := (others => '0');	-- The number of blocks written
signal timeUs		: RegisterType := (others => '0');	-- The time in us
signal timeCounter	: integer range 0 to 125 := 0;

function addPos(v: integer; a: integer) return integer is
begin
	if(v + a > NvmeWriteNum-1) then
		return v + a - NvmeWriteNum;
	else
		return v + a;
	end if;
end;

function bufferAddress(bufferNum: integer) return unsigned is
begin
	return to_unsigned(bufferNum, log2(NvmeWriteNum)) & to_unsigned(0, AddressWidth-log2(NvmeWriteNum));
end;

function pcieAddress(bufferNum: integer) return std_logic_vector is
begin
	return x"05" & zeros(32-8-log2(NvmeWriteNum)-(BlockSizeWidth)) & to_stl(bufferNum, log2(NvmeWriteNum)) & zeros(BlockSizeWidth);
end;

begin
	-- Register access
	regDataOut	<= std_logic_vector(dataChunkSize) when(regAddress = 0)
			else std_logic_vector(error) when(regAddress = 1)
			else std_logic_vector(numBlocks) when(regAddress = 2)
			else std_logic_vector(timeUs);
	
	-- Register process
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				dataChunkSize	<= (others => '0');
			elsif((regWrite = '1') and (regAddress = "00")) then
				dataChunkSize	<= unsigned(regDataIn);
			end if;
		end if;
	end process;

	-- Input buffers in BlockRAM
	dataBuffer0 : DataBuffer
	port map (
		clk		=> clk,
		reset		=> reset,

		writeEnable	=> writeEnable,
		writeAddress	=> writeAddress,
		writeData	=> dataIn.data,

		readEnable	=> readEnable,
		readAddress	=> readAddress,
		readData	=> readData
	);

	-- Input data process. Accepts data from input stream and stores it into NvmeWriteNum buffers
	dataIn.ready <= writeEnable;

	process(clk)
	variable p: integer range 0 to NvmeWriteNum-1;
	variable c: integer;
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				for i in 0 to NvmeWriteNum-1 loop
					buffers(i).inUse1 <= '0';
					buffers(i).full <= '0';
					buffers(i).blockNumber <= (others => '0');
				end loop;

				blockNumber	<= (others => '0');
				writeEnable	<= '0';
				numIn		<= 0;
				inState		<= INSTATE_IDLE;
			else
				case(inState) is
				when INSTATE_IDLE =>
					if(enable = '1') then
						inState <= INSTATE_INIT;
					end if;

				when INSTATE_INIT =>
					-- Initialise for next run
					for i in 0 to NvmeWriteNum-1 loop
						buffers(i).inUse1 <= '0';
						buffers(i).full <= '0';
					end loop;

					blockNumber	<= (others => '0');
					writeEnable	<= '0';
					numIn		<= 0;
					inState		<= INSTATE_CHOOSE;

				when INSTATE_CHOOSE =>
					if(enable = '1') then
						if(blockNumber >= dataChunkSize) then
							inState <= INSTATE_COMPLETE;
						end if;
						
						-- Decide on which buffer to use based on inuse state.
						for i in 0 to NvmeWriteNum-1 loop
							p := addPos(bufferInNumNext, i);
							if(buffers(p).inUse1 = buffers(p).inUse2) then
								bufferInNum		<= p;
								bufferInNumNext		<= addPos(p, 1);
								buffers(p).blockNumber	<= blockNumber;
								buffers(p).full		<= '0';
								buffers(p).inUse1	<= not buffers(p).inUse2;
								writeAddress		<= bufferAddress(p);
								writeEnable		<= '1';
								numIn			<= numIn + 1;
								inState			<= INSTATE_INPUT_BLOCK;
								exit;
							end if;
						end loop;
					else
						inState <= INSTATE_IDLE;
					end if;

				when INSTATE_INPUT_BLOCK =>
					-- Could check for buffer full status here ...
					if((dataIn.valid = '1') and (dataIn.ready = '1')) then
						if(dataIn.last = '1') then
							writeEnable			<= '0';
							buffers(bufferInNum).full	<= '1';
							blockNumber			<= blockNumber + 1;
							if(SimDelay) then
								c	:= 400;
								inState	<= INSTATE_DELAY;
							else
								inState	<= INSTATE_CHOOSE;
							end if;
						else
							writeAddress <= writeAddress + 1;
						end if;
					end if;

				when INSTATE_DELAY =>
					c := c - 1;
					if(numIn = numReply) then
					--if(c = 0) then
						inState				<= INSTATE_CHOOSE;
					end if;
					
				when INSTATE_COMPLETE =>
					if(enable = '0') then
						inState <= INSTATE_IDLE;
					end if;

				end case;
			end if;
		end if;
	end process;

	nvmeReplyHead <= to_NvmeReplyHeadType(replyIn.data);
	
	-- Process data write. This takes the input buffers and sends a write request to the Nvme for each one that is full.
	-- It waits for replices if there are more than NvmeWriteNum-1 writes in progress.
	process(clk)
	variable p: integer range 0 to NvmeWriteNum-1;
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				requestOut.valid 	<= '0';
				requestOut.last 	<= '0';
				requestOut.keep 	<= (others => '1');
				timeUs			<= (others => '0');
				timeCounter		<= 0;
				bufferOutNum		<= 0;
				num			<= 0;
				for i in 0 to NvmeWriteNum-1 loop
					buffers(i).process1 <= '0';
				end loop;
				state			<= STATE_IDLE;
			else
				case(state) is
				when STATE_IDLE =>
					if(enable = '1') then
						state <= STATE_INIT;
					end if;
				
				when STATE_INIT =>
					-- Initialise for next run
					timeUs		<= (others => '0');
					timeCounter	<= 0;
					num		<= 0;
					for i in 0 to NvmeWriteNum-1 loop
						buffers(i).process1 <= '0';
					end loop;
					state		<= STATE_RUN;
					
				when STATE_RUN =>
					if(enable = '1') then
						if(num >= dataChunkSize) then
							state <= STATE_COMPLETE;
						
						else
							-- Decide on which buffer to output
							for i in 0 to NvmeWriteNum-1 loop
								p := addPos(bufferOutNumNext, i);
								if((buffers(p).full = '1') and (buffers(p).inUse1 /= buffers(p).inUse2) and (buffers(p).process1 = buffers(p).process2)) then
									buffers(p).process1	<= not buffers(p).process2;
									bufferOutNum		<= p;
									bufferOutNumNext	<= addPos(p, 1);
									requestOut.data		<= setHeader(1, 16#02010000#, 16, 0);
									requestOut.valid	<= '1';
									state			<= STATE_QUEUE_HEAD;
									exit;
								end if;
							end loop;
						end if;
					else
						state <= STATE_COMPLETE;
					end if;
				
				when STATE_COMPLETE =>
					if(enable = '0') then
						state <= STATE_IDLE;
					end if;

				when STATE_QUEUE_HEAD =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(64) & x"00000001" & x"04" & to_stl(bufferOutNum, 8) & x"0001";	-- Namespace 1, From stream4, opcode 1
						state		<= STATE_QUEUE_0;
					end if;

				when STATE_QUEUE_0 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(32) & pcieAddress(bufferOutNum) & zeros(64);
						--requestOut.data	<= zeros(32) & x"05000000" & zeros(64);	-- Data source address
						--requestOut.data	<= zeros(32) & x"01800000" & zeros(64);	-- Data source address
						state		<= STATE_QUEUE_1;
					end if;

				when STATE_QUEUE_1 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(29) & std_logic_vector(buffers(bufferOutNum).blockNumber) & zeros(3 + 64);
						state		<= STATE_QUEUE_2;
					end if;

				when STATE_QUEUE_2 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(96) & to_stl(NvmeBlocks-1, 32);	-- WriteMethod, NumBlocks (0 is 1 block)
						requestOut.last	<= '1';
						num		<= num + 1;
						state		<= STATE_QUEUE_3;
					end if;

				when STATE_QUEUE_3 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.last		<= '0';
						requestOut.valid	<= '0';
						
						state <= STATE_RUN;
						
						--if(num > (numReply + 4)) then
						--	state <= STATE_WAIT_REPLY;
						--else
						--	state <= STATE_RUN;
						--end if;
					end if;

				when STATE_WAIT_REPLY =>
					if(num > (numReply + 4)) then
						state <= STATE_WAIT_REPLY;
					else
						state <= STATE_RUN;
					end if;

				end case;
				
				if(timeCounter = 125) then
					if(state /= STATE_COMPLETE) then
						timeUs <= timeUs + 1;
					end if;
					timeCounter <= 0;
				else
					timeCounter <= timeCounter + 1;
				end if;
			end if;
		end if;
	end process;
	
	-- Process replies. This accepts Write request replies from the Nvme storing any errors and marking the buffer as free.
	process(clk)
	variable p: integer range 0 to NvmeWriteNum-1;
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				replyIn.ready		<= '1';
				numBlocks		<= (others => '0');
				error			<= (others => '0');
				numReply		<= 0;
				for i in 0 to NvmeWriteNum-1 loop
					buffers(i).inUse2	<= '0';
					buffers(i).process2	<= '0';
				end loop;
				replyState		<= REPLY_STATE_QUEUE_REPLY1;
			else
				case(replyState) is
				when REPLY_STATE_QUEUE_REPLY1 =>
					if(state = STATE_INIT) then
						numBlocks	<= (others => '0');
						error		<= (others => '0');
						numReply	<= 0;
					end if;
					
					if(replyIn.valid = '1' and replyIn.ready = '1') then
						replyState <= REPLY_STATE_QUEUE_REPLY2;
					end if;

				when REPLY_STATE_QUEUE_REPLY2 =>
					if(replyIn.valid = '1' and replyIn.ready = '1') then
						if(error = 0) then
							error(15 downto 0) <= '0' & nvmeReplyHead.status;
						end if;

						numBlocks		<= numBlocks + 1;
						numReply		<= numReply + 1;
						p			:= to_integer(nvmeReplyHead.cid(2 downto 0));
						buffers(p).inUse2	<= buffers(p).inUse1;
						buffers(p).process2	<= buffers(p).process1;

						replyState		<= REPLY_STATE_QUEUE_REPLY1;
					end if;
				
				end case;
			end if;
		end if;
	end process;
	
	-- Process Nvme read data requests
	-- The processes Nvme Pcie memory read requests for the data buffers memory.
	readEnable <= '1';
	-- readEnable <= memReplyOut.ready and not memReplyOut.last when((memState = MEMSTATE_READHEAD) or (memState = MEMSTATE_READDATA)) else '0';
	memRequestHead	<= to_PcieRequestHeadType(memReqIn.data);
	memReplyOut.data <= memData(31 downto 0) & to_stl(memReplyHead) when(memState = MEMSTATE_READHEAD)
		else readData(31 downto 0) & memData(127 downto 32);

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				memReqIn.ready	<= '0';
				memState	<= MEMSTATE_IDLE;
			else
				case(MEMSTATE) is
				when MEMSTATE_IDLE =>
					if((memReqIn.ready = '1') and (memReqIn.valid = '1')) then
						memRequestHead1	<= memRequestHead;
						memCount	<= memRequestHead.count;

						if(memRequestHead.request = 0) then
							readAddress	<= memRequestHead.address(AddressWidth+3 downto 4);
							memReqIn.ready	<= '0';
							memState	<= MEMSTATE_READHEAD;
						end if;
					else
						memReqIn.ready <= '1';
					end if;

				when MEMSTATE_READHEAD =>
					if(memReplyOut.valid = '0') then
						memReplyHead.byteCount		<= memCount & "00";
						memReplyHead.address		<= memRequestHead1.address(memReplyHead.address'length - 1 downto 0);
						memReplyHead.error		<= (others => '0');
						memReplyHead.status		<= (others => '0');
						memReplyHead.tag		<= memRequestHead1.tag;
						memReplyHead.requesterId	<= memRequestHead1.requesterId;

						if(memCount > PcieMaxPayloadSize) then
							memReplyHead.count	<= to_unsigned(PcieMaxPayloadSize, memReplyHead.count'length);
							memChunkCount		<= to_unsigned(PcieMaxPayloadSize, memReplyHead.count'length);
						else
							memReplyHead.count	<= memCount;
							memChunkCount		<= memCount;
						end if;

						memReplyOut.valid 	<= '1';
						memData			<= readData;
						readAddress		<= readAddress + 1;
					else
						memReplyOut.keep 	<= (others => '1');

						if(memReplyOut.ready = '1' and memReplyOut.valid = '1') then
							readAddress	<= readAddress + 1;
							memState	<= MEMSTATE_READDATA;
						end if;
					end if;
				
				when MEMSTATE_READDATA =>
					if(memReplyOut.ready = '1' and memReplyOut.valid = '1') then
						memData		<= readData;

						if(memChunkCount = 4) then
							if(memCount = 4) then
								memReplyOut.last	<= '0';
								memReplyOut.valid	<= '0';
								memState		<= MEMSTATE_IDLE;
							else
								memReplyOut.last	<= '0';
								memReplyOut.valid	<= '0';
								memState		<= MEMSTATE_READHEAD;
							end if;

						elsif(memChunkCount = 8) then
							memReplyOut.keep <= zeros(4) & ones(12);
							memReplyOut.last <= '1';

						else
							readAddress		<= readAddress + 1;
							memReplyOut.last	<= '0';
						end if;

						memChunkCount		<= memChunkCount - 4;
						memCount		<= memCount - 4;
						memRequestHead1.address	<= memRequestHead1.address + 16;
					end if;

				end case;
			end if;
		end if;
	end process;
end;
