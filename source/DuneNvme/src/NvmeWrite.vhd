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
	Simulate	: boolean := False			--! Generate simulation core
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
	
	regAddress	: in unsigned(1 downto 0);		--! Status register to read
	regData		: out std_logic_vector(31 downto 0)	--! Status register contents
);
end;

architecture Behavioral of NvmeWrite is

--! Set the fields in the PCIe TLP header
function setHeader(request: integer; address: integer; count: integer; tag: integer) return std_logic_vector is
begin
	return to_stl(set_PcieRequestHeadType(3, request, address, count, tag));
end function;

constant TCQ		: time := 1 ns;
--constant NumBlocksRun	: integer := 2;				--! The total number of blocks in a run
constant NumBlocksRun	: integer := 262144;			--! The total number of blocks in a run
constant NvmeBlocks	: integer := NvmeStorageBlockSize / 512;--! The number of Nvme blocks per NvmeStorage system block

component DataFifo is
generic(
	Simulate	: boolean := Simulate;			--! Generate simulation core
	FifoSize	: integer := NvmeStorageBlockSize/16	--! The Fifo size in 128 bit words
	--FifoSize	: integer := 16				--! The Fifo size for simple simulations
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	full		: out std_logic;			--! The fifo is full (Has Fifo size words)
	empty		: out std_logic;			--! The fifo is empty

	dataIn		: inout AxisStreamType := AxisInput;	--! Input data stream
	dataOut		: inout AxisStreamType := AxisOutput	--! Output data stream
);
end component;

type StateType		is (STATE_IDLE, STATE_RUN, STATE_COMPLETE,
				STATE_QUEUE_HEAD, STATE_QUEUE_0, STATE_QUEUE_1, STATE_QUEUE_2, STATE_QUEUE_3,
				STATE_QUEUE_REPLY1, STATE_QUEUE_REPLY2);

signal state		: StateType := STATE_IDLE;

signal fifo_full	: std_logic := '0';
signal fifo_empty	: std_logic := '0';
signal dataOut		: AxisStreamType;
signal blockNumber	: unsigned(63 downto 0) := (others => '0');

type MemStateType	is (MEMSTATE_IDLE, MEMSTATE_READHEAD, MEMSTATE_READDATA);
signal memState		: MemStateType := MEMSTATE_IDLE;
signal memRequestHead	: PcieRequestHeadType;
signal memRequestHead1	: PcieRequestHeadType;
signal memReplyHead	: PcieReplyHeadType;
signal nvmeReplyHead	: NvmeReplyHeadType;
signal memCount		: unsigned(10 downto 0);			-- DWord data send count
signal memChunkCount	: unsigned(10 downto 0);			-- DWord data send within a chunk count
signal memData		: std_logic_vector(127 downto 0);

-- Status information
signal status		: unsigned(31 downto 0) := (others => '0');	-- The system status
signal numBlocks	: unsigned(31 downto 0) := (others => '0');	-- The number of blocks written
signal timeUs		: unsigned(31 downto 0) := (others => '0');	-- The time in us
signal timeCounter	: integer range 0 to 125 := 0;

begin
	-- Input data FIFO's, one per WriteQueue entry. Just the one for now.
	dataFifo0 : DataFifo
	port map (
		clk		=> clk,
		reset		=> reset,

		full		=> fifo_full,
		empty		=> fifo_empty,

		dataIn		=> dataIn,
		dataOut		=> dataOut
	);
	
	-- Regsiter access
	regData	<= std_logic_vector(status) when(regAddress = 0)
			else std_logic_vector(numBlocks) when(regAddress = 1)
			else std_logic_vector(timeUs);
	
	nvmeReplyHead <= to_NvmeReplyHeadType(replyIn.data);
	
	-- Process data input
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				requestOut.valid 	<= '0';
				requestOut.last 	<= '0';
				requestOut.keep 	<= (others => '1');
				replyIn.ready		<= '1';
				blockNumber		<= (others => '0');
				numBlocks		<= (others => '0');
				timeUs			<= (others => '0');
				status			<= (others => '0');
				timeCounter		<= 0;
				state			<= STATE_IDLE;
			else
				case(state) is
				when STATE_IDLE =>
					if(enable = '1') then
						-- Initialise for next run
						blockNumber	<= (others => '0');
						numBlocks	<= (others => '0');
						timeUs		<= (others => '0');
						status		<= (others => '0');
						timeCounter	<= 0;
						state		<= STATE_RUN;
					end if;
					
				when STATE_RUN =>
					if(enable = '1') then
						if(numBlocks >= NumBlocksRun) then
							state <= STATE_COMPLETE;

						elsif(fifo_full = '1') then
							requestOut.data		<= setHeader(1, 16#02010000#, 16, 0);
							requestOut.valid	<= '1';
							state			<= STATE_QUEUE_HEAD;
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
						requestOut.data	<= zeros(64) & x"00000001" & x"04000001";	-- Namespace 1, From stream4, opcode 1
						state		<= STATE_QUEUE_0;
					end if;

				when STATE_QUEUE_0 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(32) & x"05000000" & zeros(64);	-- Data source address
						--requestOut.data	<= zeros(32) & x"01800000" & zeros(64);	-- Data source address
						state		<= STATE_QUEUE_1;
					end if;

				when STATE_QUEUE_1 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= std_logic_vector(blockNumber) & zeros(64);
						state		<= STATE_QUEUE_2;
					end if;

				when STATE_QUEUE_2 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(96) & to_stl(NvmeBlocks-1, 32);	-- WriteMethod, NumBlocks (0 is 1 block)
						requestOut.last	<= '1';
						state		<= STATE_QUEUE_3;
					end if;

				when STATE_QUEUE_3 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.last		<= '0';
						requestOut.valid	<= '0';
						replyIn.ready		<= '1';
						state			<= STATE_QUEUE_REPLY1;
					end if;

				when STATE_QUEUE_REPLY1 =>
					if(replyIn.valid = '1' and replyIn.ready = '1') then
						state			<= STATE_QUEUE_REPLY2;
					end if;

				when STATE_QUEUE_REPLY2 =>
					if(replyIn.valid = '1' and replyIn.ready = '1') then
						if(status = 0) then
							status(15 downto 0) <= '0' & nvmeReplyHead.status;
						end if;

						status(31 downto 16)	<= status(31 downto 16) + 1;
						blockNumber		<= blockNumber + NvmeBlocks;
						numBlocks		<= numBlocks + 1;
						replyIn.ready		<= '0';
						state			<= STATE_RUN;
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
	
	-- Process Nvme read data requests
	dataOut.ready <= memReplyOut.ready and not memReplyOut.last when((memState = MEMSTATE_READHEAD) or (memState = MEMSTATE_READDATA)) else '0';
	memRequestHead	<= to_PcieRequestHeadType(memReqIn.data);
	memReplyOut.data <= dataOut.data(31 downto 0) & to_stl(memReplyHead) when(memState = MEMSTATE_READHEAD)
		else dataOut.data(31 downto 0) & memData(127 downto 32);

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
							memReqIn.ready	<= '0';
							memState	<= MEMSTATE_READHEAD;
						end if;
					else
						memReqIn.ready <= '1';
					end if;

				when MEMSTATE_READHEAD =>
					if(dataOut.valid = '1') then
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

						memData			<= dataOut.data;
						memReplyOut.keep 	<= (others => '1');
						memReplyOut.valid 	<= '1';

						if(memReplyOut.ready = '1' and memReplyOut.valid = '1') then
							memState	<= MEMSTATE_READDATA;
						end if;
					end if;
				
				when MEMSTATE_READDATA =>
					if(memReplyOut.ready = '1' and memReplyOut.valid = '1') then
						-- Should we also check dataOut.valid ?
						memData		<= dataOut.data;

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
							memReplyOut.last <= '0';
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
