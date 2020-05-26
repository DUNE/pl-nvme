--------------------------------------------------------------------------------
-- NvmeWrite.vhd Nvme Write data module
-------------------------------------------------------------------------------
--!
--! @class	NvmeWrite
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-11
--! @version	0.3.1
--!
--! @brief
--! This module performs the Nvme write data functionality.
--!
--! @details
--! This module is the heart of the DuneNvme system. Its purpose is to write
--! the incomming data blocks to the Nvme device.
--! For performance it will concurrently write NvmeWriteNum (8) blocks.
--! It implements a set of NvmeWriteNum x 4k buffers in a single BlockRAM.
--! An input process chooses a free buffer and then writes the data from the input
--! AXIS stream into this buffer. Once complete the input process adds the buffer number
--! to a processing queue.
--! A processing process takes buffer numbers from the processing queue. When available an
--! Nvme write request is sent to the Nvme write queue.
--! On the Nvme reading the queue entry it will perform "bus master" memory reads from the
--! appropriate data buffer.
--! Once the Nvme has completed the write (well taken in the write data) it will send
--! a reply to the reply queue. The NvmeWrite's reply process will process these, storing
--! any error status, and then free the buffer that was used.
--!
--! The module is controlled by the enable line, which enables the processing of input data, and
--!  the dataChunkSize register which specifies how many blocks to capture.
--!  It will continue to capture whist the enable line is high and the number of blocks captured
--!  is less than the number of blocks in the dataChunkSize register.
--!
--! As the system allows up to NvmeWriteNum concurrent writes, it is able to hide ittermitant
--! large write latencies.
--! Notes:
--!   The parameter NvmeWriteNum should be less than NvmeQueueNum.
--!   It assumes the DuneDvme block size is set in NvmeStorageBlockSize and the DataIn stream's
--!     last signal is synchonised with the end of each input block.
--!   At the moment it assumes the Nvme's internal block size is 512 Bytes.
--!   At the moment it stores the first status reply error but continues ignoring the error.
--!   There are no timeouts or any other error handling.
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
	ClockPeriod	: time := 8 ns;				--! The clocks period
	BlockSize	: integer := NvmeStorageBlockSize	--! System block size
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	enable		: in std_logic;				--! Enable the data writing process
	dataIn		: inout AxisStreamType := AxisStreamInput;	--! Raw data to save stream

	-- To Nvme Request/reply streams
	requestOut	: inout AxisStreamType := AxisStreamOutput;	--! To Nvme request stream (3)
	replyIn		: inout AxisStreamType := AxisStreamInput;	--! from Nvme reply stream

	-- From Nvme Request/reply streams
	memReqIn	: inout AxisStreamType := AxisStreamInput;	--! From Nvme request stream (4)
	memReplyOut	: inout AxisStreamType := AxisStreamOutput;	--! To Nvme reply stream
	
	regWrite	: in std_logic;				--! Enable write to register
	regAddress	: in unsigned(3 downto 0);		--! Register to read/write
	regDataIn	: in std_logic_vector(31 downto 0);	--! Register write data
	regDataOut	: out std_logic_vector(31 downto 0)	--! Register contents
);
end;

architecture Behavioral of NvmeWrite is

constant TCQ		: time := 1 ns;
constant SimDelay	: boolean := False;			--! Input data delay after each packet for simulation tests
constant SimWaitReply	: boolean := False;			--! Wait for each write command to return a reply
constant DoWrite	: boolean := True;			--! Perform write blocks
constant DoTrim		: boolean := True;			--! Perform trim/deallocate functionality

constant NvmeBlocks	: integer := BlockSize / NvmeBlockSize;		--! The number of Nvme blocks per NvmeStorage system block
constant RamSize	: integer := (NvmeWriteNum * BlockSize) / 16;	-- One block per write buffer
constant AddressWidth	: integer := log2(RamSize);
constant BlockSizeWidth	: integer := log2(BlockSize);
constant TrimNum	: integer := (32768 / NvmeBlocks);	--! The number of 4k blocks trimmed in one trim instructions

component Ram is
generic(
	DataWidth	: integer := 128;
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
	blockNumber	: unsigned(31 downto 0);		--! The first block number in the buffer
	startTime	: unsigned(31 downto 0);		--! The start time for this buffer transaction
end record;

subtype RegisterType	is unsigned(31 downto 0);
type BufferArrayType	is array (0 to NvmeWriteNum-1) of BufferType;

type InStateType	is (INSTATE_IDLE, INSTATE_INIT, INSTATE_CHOOSE, INSTATE_INPUT_BLOCK, INSTATE_DELAY, INSTATE_COMPLETE);
type StateType		is (STATE_IDLE, STATE_INIT, STATE_RUN, STATE_COMPLETE,
				STATE_WQUEUE_HEAD, STATE_WQUEUE_0, STATE_WQUEUE_1, STATE_WQUEUE_2, STATE_WQUEUE_3,
				STATE_TQUEUE_HEAD, STATE_TQUEUE_0, STATE_TQUEUE_1, STATE_TQUEUE_2, STATE_TQUEUE_3,
				STATE_WAIT_REPLY);
type ReplyStateType	is (REPSTATE_IDLE, REPSTATE_INIT, REPSTATE_COMPLETE, REPSTATE_QUEUE_REPLY1, REPSTATE_QUEUE_REPLY2);

signal inState		: InStateType := INSTATE_IDLE;
signal state		: StateType := STATE_IDLE;
signal replyState	: ReplyStateType := REPSTATE_QUEUE_REPLY1;

signal blockNumberIn	: unsigned(31 downto 0) := (others => '0');		--! Input block number
signal numBlocksProc	: unsigned(31 downto 0) := (others => '0');		--! Number of block write requests sent
signal numBlocksDone	: unsigned(31 downto 0) := (others => '0');		--! Number of block write completions received
signal numBlocksTrimmed	: unsigned(31 downto 0) := (others => '0');		--! Number of blocks trimmed

signal trimQueueProc	: unsigned(3 downto 0) := (others => '0');		--! The number of trim tasks in progress
signal trimQueueDone	: unsigned(3 downto 0) := (others => '0');		--! The number of trim tasks completed

-- Input buffers
signal writeEnable	: std_logic := '0';
signal writeAddress	: unsigned(AddressWidth-1 downto 0) := (others => '0');
signal readEnable	: std_logic := '0';
signal readAddress	: unsigned(AddressWidth-1 downto 0) := (others => '0');
signal readData		: std_logic_vector(127 downto 0) := (others => '0');

signal buffers		: BufferArrayType := (others => ('Z', 'Z', (others => 'Z'), (others => 'Z')));
signal bufferInNum	: integer range 0 to NvmeWriteNum-1 := 0;
signal bufferOutNum	: integer range 0 to NvmeWriteNum-1 := 0;

-- Process queue
type ProcessQueueType	is array(0 to NvmeWriteNum) of integer range 0 to NvmeWriteNum-1;
signal processQueue	: ProcessQueueType := (others => 0);
signal processQueueIn	: integer range 0 to NvmeWriteNum := 0;
signal processQueueOut	: integer range 0 to NvmeWriteNum := 0;

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
signal dataChunkStart	: RegisterType := (others => '0');	-- The data chunk start position in blocks
signal dataChunkSize	: RegisterType := (others => '0');	-- The data chunk size in blocks
signal error		: RegisterType := (others => '0');	-- The system errors status
signal timeUs		: RegisterType := (others => '0');	-- The time in us
signal peakLatency	: RegisterType := (others => '0');	-- The peak latency in us
signal timeCounter	: integer range 0 to (1 us / ClockPeriod) - 1 := 0;

--! Set the fields in the PCIe TLP header
function setHeader(request: integer; address: integer; count: integer; tag: integer) return std_logic_vector is
begin
	return to_stl(set_PcieRequestHeadType(3, request, address, count, tag));
end function;

function incrementPos(v: integer) return integer is
begin
	if(v = NvmeWriteNum-1) then
		return 0;
	else
		return v + 1;
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

function numTrimBlocks(total: unsigned; current: unsigned) return unsigned is
begin
	if((current + TrimNum) > total) then
		return truncate(((total - current) * NvmeBlocks) - 1, 16);
	else
		return to_unsigned(32768-1, 16);
	end if;
end;

begin
	-- Register access
	regDataOut	<= std_logic_vector(dataChunkStart) when(regAddress = 0)
			else std_logic_vector(dataChunkSize) when(regAddress = 1)
			else std_logic_vector(error) when(regAddress = 2)
			else std_logic_vector(numBlocksDone) when(regAddress = 3)
			else std_logic_vector(timeUs) when(regAddress = 4)
			else std_logic_vector(peakLatency) when(regAddress = 5)
			else ones(32);
	
	-- Register process
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				dataChunkStart	<= (others => '0');
				dataChunkSize	<= (others => '0');
			elsif((regWrite = '1') and (regAddress = 0)) then
				dataChunkStart	<= unsigned(regDataIn);
			elsif((regWrite = '1') and (regAddress = 1)) then
				dataChunkSize	<= unsigned(regDataIn);
			end if;
		end if;
	end process;

	-- Input buffers in BlockRAM
	dataBuffer0 : Ram
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

	-- Input data process. Accepts data from input stream and stores it into a free buffer if available.
	dataIn.ready <= writeEnable;

	process(clk)
	variable c: integer;
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				for i in 0 to NvmeWriteNum-1 loop
					buffers(i).inUse1 <= '0';
					buffers(i).blockNumber <= (others => '0');
				end loop;

				blockNumberIn	<= (others => '0');
				processQueueIn	<= 0;
				writeEnable	<= '0';
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
					end loop;

					blockNumberIn	<= (others => '0');
					processQueueIn	<= 0;
					writeEnable	<= '0';
					inState		<= INSTATE_CHOOSE;

				when INSTATE_CHOOSE =>
					if(enable = '1') then
						if(blockNumberIn >= dataChunkSize) then
							inState <= INSTATE_COMPLETE;
						else
							-- Decide on which buffer to use based on inuse state. We should implement a Fifo queue here
							for i in 0 to NvmeWriteNum-1 loop
								if(buffers(i).inUse1 = buffers(i).inUse2) then
									bufferInNum		<= i;
									buffers(i).inUse1	<= not buffers(i).inUse2;
									buffers(i).blockNumber	<= blockNumberIn;
									writeAddress		<= bufferAddress(i);
									writeEnable		<= '1';
									inState			<= INSTATE_INPUT_BLOCK;
									exit;
								end if;
							end loop;
						end if;
					else
						inState <= INSTATE_IDLE;
					end if;

				when INSTATE_INPUT_BLOCK =>
					-- Could check for buffer full status here instead of using last signal
					if((dataIn.valid = '1') and (dataIn.ready = '1')) then
						if(dataIn.last = '1') then
							writeEnable			<= '0';
							blockNumberIn			<= blockNumberIn + 1;
							
							-- Add to process queue
							processQueue(processQueueIn) <= bufferInNum;
							processQueueIn <= incrementPos(processQueueIn);

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
					-- This is for simulation so we can space out input blocks in time
					c := c - 1;
					if(c = 0) then
						inState <= INSTATE_CHOOSE;
					end if;
					
				when INSTATE_COMPLETE =>
					if(enable = '0') then
						inState <= INSTATE_IDLE;
					end if;

				end case;
			end if;
		end if;
	end process;

	-- Process data write. This takes the input buffers and sends a write request to the Nvme for each one that is full and
	-- not already processed
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				requestOut.valid 	<= '0';
				requestOut.last 	<= '0';
				requestOut.keep 	<= (others => '1');
				timeUs			<= (others => '0');
				timeCounter		<= 0;
				bufferOutNum		<= 0;
				numBlocksProc		<= (others => '0');
				processQueueOut		<= 0;
				numBlocksTrimmed	<= (others => '0');
				trimQueueProc		<= (others => '0');
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
					numBlocksProc	<= (others => '0');
					processQueueOut	<= 0;
					numBlocksTrimmed<= (others => '0');
					state		<= STATE_RUN;
					
				when STATE_RUN =>
					if(enable = '1') then
						if(numBlocksProc >= dataChunkSize) then
							state <= STATE_COMPLETE;
						
						elsif(DoTrim and (numBlocksTrimmed < dataChunkSize) and ((trimQueueProc - trimQueueDone) < 4)) then
							requestOut.data		<= setHeader(1, 16#02010000#, 16, 0);
							requestOut.valid	<= '1';
							state			<= STATE_TQUEUE_HEAD;

						elsif(DoWrite and (processQueueOut /= processQueueIn)) then
							bufferOutNum		<= processQueue(processQueueOut);
							processQueueOut		<= incrementPos(processQueueOut);
							buffers(bufferOutNum).startTime	<= timeUs;
							requestOut.data		<= setHeader(1, 16#02010000#, 16, 0);
							requestOut.valid	<= '1';
							state			<= STATE_WQUEUE_HEAD;

						end if;
					else
						state <= STATE_COMPLETE;
					end if;
				
				when STATE_COMPLETE =>
					if(enable = '0') then
						state <= STATE_IDLE;
					end if;

				-- Write blocks request
				when STATE_WQUEUE_HEAD =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(64) & x"00000001" & x"04" & to_stl(bufferOutNum, 8) & x"0001";	-- Namespace 1, From stream4, opcode 1
						state		<= STATE_WQUEUE_0;
					end if;

				when STATE_WQUEUE_0 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(32) & pcieAddress(bufferOutNum) & zeros(64);
						--requestOut.data	<= zeros(32) & x"01800000" & zeros(64);	-- Data source address from host
						state		<= STATE_WQUEUE_1;
					end if;

				when STATE_WQUEUE_1 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(32-log2(NvmeBlocks)) & std_logic_vector(dataChunkStart + buffers(bufferOutNum).blockNumber) & zeros(log2(NvmeBlocks) + 64);
						state		<= STATE_WQUEUE_2;
					end if;

				when STATE_WQUEUE_2 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(96) & to_stl(NvmeBlocks-1, 32);	-- WriteMethod, NumBlocks (0 is 1 block)
						requestOut.last	<= '1';
						numBlocksProc	<= numBlocksProc + 1;
						state		<= STATE_WQUEUE_3;
					end if;

				when STATE_WQUEUE_3 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.last		<= '0';
						requestOut.valid	<= '0';
						
						if(SimWaitReply) then
							state <= STATE_WAIT_REPLY;
						else
							state <= STATE_RUN;
						end if;
					end if;

				-- Trim/deallocate request
				when STATE_TQUEUE_HEAD =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(64) & x"00000001" & x"04F" & to_stl(trimQueueProc(3 downto 0)) & x"0008";	-- Namespace 1, From stream4, opcode 8
						state		<= STATE_TQUEUE_0;
					end if;

				when STATE_TQUEUE_0 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(128);
						state		<= STATE_TQUEUE_1;
					end if;

				when STATE_TQUEUE_1 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(32-log2(NvmeBlocks)) & std_logic_vector(dataChunkStart + numBlocksTrimmed) & zeros(log2(NvmeBlocks) + 64);
						state		<= STATE_TQUEUE_2;
					end if;

				when STATE_TQUEUE_2 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(96) & x"0200" & to_stl(numTrimBlocks(dataChunkSize, numBlocksTrimmed));	-- Deallocate, NumBlocks (0 is 1 block)
						requestOut.last	<= '1';
						state		<= STATE_TQUEUE_3;
					end if;

				when STATE_TQUEUE_3 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.last		<= '0';
						requestOut.valid	<= '0';
						numBlocksTrimmed	<= numBlocksTrimmed + TrimNum;
						trimQueueProc		<= trimQueueProc + 1;
						
						if(SimWaitReply) then
							if(trimQueueDone = trimQueueProc) then
								state <= STATE_RUN;
							end if;
						else
							state <= STATE_RUN;
						end if;
					end if;



				when STATE_WAIT_REPLY =>
					if(numBlocksProc > numBlocksDone) then
						state <= STATE_WAIT_REPLY;
					else
						state <= STATE_RUN;
					end if;

				end case;
				
				-- Microsecond counter for statistics
				if(timeCounter = ((1 us / ClockPeriod) - 1)) then
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
				for i in 0 to NvmeWriteNum-1 loop
					buffers(i).inUse2	<= '0';
				end loop;

				replyIn.ready	<= '0';
				error		<= (others => '0');
				numBlocksDone	<= (others => '0');
				peakLatency	<= (others => '0');
				trimQueueDone	<= (others => '0');
				replyState 	<= REPSTATE_IDLE;
			else
				case(replyState) is
				when REPSTATE_IDLE =>
					if(enable = '1') then
						replyState <= REPSTATE_INIT;
					end if;
				
				when REPSTATE_INIT =>
					-- Initialise for next run
					for i in 0 to NvmeWriteNum-1 loop
						buffers(i).inUse2	<= '0';
					end loop;

					replyIn.ready	<= '1';
					error		<= (others => '0');
					numBlocksDone	<= (others => '0');
					peakLatency	<= (others => '0');
					replyState 	<= REPSTATE_QUEUE_REPLY1;
					
				when REPSTATE_COMPLETE =>
					if(enable = '0') then
						replyIn.ready	<= '0';
						replyState	<= REPSTATE_IDLE;
					end if;
				
				when REPSTATE_QUEUE_REPLY1 =>
					if(enable = '0') then
						if(replyIn.valid = '0') then
							replyIn.ready	<= '0';
						end if;
						replyState <= REPSTATE_COMPLETE;
					else
						if(numBlocksDone >= dataChunkSize) then
							replyState <= REPSTATE_COMPLETE;
					
						elsif(replyIn.valid = '1' and replyIn.ready = '1') then
							nvmeReplyHead	<= to_NvmeReplyHeadType(replyIn.data);
							replyState	<= REPSTATE_QUEUE_REPLY2;
						end if;
					end if;

				when REPSTATE_QUEUE_REPLY2 =>
					if(enable = '0') then
						replyIn.ready	<= '0';
						replyState	<= REPSTATE_COMPLETE;

					elsif(replyIn.valid = '1' and replyIn.ready = '1') then
						if(error = 0) then
							error(15 downto 0) <= '0' & nvmeReplyHead.status;
						end if;
						
						if(nvmeReplyHead.cid(7 downto 4) = x"F") then
							trimQueueDone <= trimQueueDone + 1;
						else
							numBlocksDone		<= numBlocksDone + 1;
							p			:= to_integer(nvmeReplyHead.cid(log2(NvmeWriteNum)-1 downto 0));
							buffers(p).inUse2	<= buffers(p).inUse1;

							if((timeUs - buffers(p).startTime) > peakLatency) then
								peakLatency <= timeUs - buffers(p).startTime;
							end if;
						end if;

						replyState <= REPSTATE_QUEUE_REPLY1;
					end if;
				
				end case;
			end if;
		end if;
	end process;
	
	-- Process Nvme read data requests
	-- This processes the Nvme Pcie memory read requests for the data buffers memory.
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
							memReplyOut.keep <= "0111";
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
