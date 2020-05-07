--------------------------------------------------------------------------------
--	NvmeQueues.vhd Nvme request/reply queues in RAM
--	T.Barnaby, Beam Ltd. 2020-04-18
-------------------------------------------------------------------------------
--!
--! @class	NvmeQueues
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-08
--! @version	0.0.1
--!
--! @brief
--! This module implements the Nvme request/reply queues in RAM
--!
--! @details
--! 
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

entity NvmeQueues is
generic(
	NumQueueEntries	: integer	:= 8;			--! The number of entries per queue
	Simulate	: boolean	:= True
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisStreamType := AxisInput;	--! Request queue entries
	streamOut	: inout AxisStreamType := AxisOutput	--! replies and requests
);
end;

architecture Behavioral of NvmeQueues is

constant TCQ		: time		:= 1 ns;
constant NUM_QUEUES	: integer	:= 4;
constant RAM_SIZE	: integer	:= (NUM_QUEUES * NumQueueEntries * 4);	-- Note uses same size for reply queues which is wasteful

subtype QueueNumRange	is integer range 17 downto 16;
subtype QueuePosType	is unsigned(log2(NumQueueEntries)-1 downto 0);
type QueuePosArrayType	is array(0 to NUM_QUEUES-1) of QueuePosType;
type StateType		is (STATE_IDLE, STATE_WRITE, STATE_READHEAD, STATE_READDATA,
				STATE_WRITE_QUEUE, STATE_SEND_DOORBELL_HEAD, STATE_SEND_DOORBELL_POS,
				STATE_REPLY_RDATA, STATE_REPLY_SHEAD, STATE_REPLY_SDATA, STATE_SEND_RDOORBELL_HEAD);
type RamType		is array(0 to RAM_SIZE - 1) of std_logic_vector(127 downto 0);

signal ram		: RamType := (others => zeros(128));

signal state		: StateType := STATE_IDLE;
signal ramAddress	: integer range 0 to RAM_SIZE - 1 := 0;

signal queueIn		: integer range 0 to NUM_QUEUES - 1;
signal queueInArrayPos	: QueuePosArrayType := (others => (others => '0'));
signal queueOutArrayPos	: QueuePosArrayType := (others => (others => '0'));

signal requestHead	: PcieRequestHeadType;
signal requestHead1	: PcieRequestHeadType;
signal replyHead	: PcieReplyHeadType;
signal doorbellReqHead	: PcieRequestHeadType;
signal data1		: std_logic_vector(127 downto 0);
signal data2		: std_logic_vector(127 downto 0);

--! Sets the RAM access address from last queue position and updates queue position
procedure queueAddressStart(signal queueArray: inout QueuePosArrayType; queueNum: unsigned; signal address: out integer) is
begin
	address <= to_integer(queueNum & queueArray(to_integer(queueNum)) & "00");
	queueArray(to_integer(queueNum)) <= queueArray(to_integer(queueNum)) + 1;
end;

procedure queueOutIncrement(signal queueArray: inout QueuePosArrayType; queueNum: unsigned) is
begin
	queueArray(to_integer(queueNum)) <= queueArray(to_integer(queueNum)) + 1;
end;

begin
	requestHead		<= to_PcieRequestHeadType(streamIn.data);
	streamOut.data		<= data1(31 downto 0) & to_stl(replyHead) when(state = STATE_READHEAD)
					else data1(31 downto 0) & data2(127 downto 32) when(state = STATE_READDATA)
					else to_stl(doorbellReqHead) when(state = STATE_SEND_DOORBELL_HEAD)
					else data1 when(state = STATE_SEND_DOORBELL_POS)
					else to_stl(requestHead1) when(state = STATE_REPLY_SHEAD)
					else data1 when(state = STATE_REPLY_SDATA)
					else to_stl(doorbellReqHead) when(state = STATE_SEND_RDOORBELL_HEAD)
					else zeros(128);

	--! Process requests
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				streamIn.ready	<= '0';
				streamOut.valid	<= '0';
				streamOut.last	<= '0'; 
				streamOut.keep	<= (others => '1'); 

				for i in 0 to NUM_QUEUES-1 loop
					queueInArrayPos(i) <= (others => '0');
					queueOutArrayPos(i) <= (others => '0');
				end loop;

				state 		<= STATE_IDLE;

			else
				case(state) is
				when STATE_IDLE =>
					streamIn.ready	<= '1';
					streamOut.valid	<= '0';
					streamOut.last	<= '0';
					streamOut.keep	<= (others => '1'); 

					if((streamIn.ready = '1') and (streamIn.valid = '1')) then
						if(requestHead.request = 12) then
							-- Special message handling performs normal write to addressed memory
							ramAddress	<= to_integer(requestHead.address(log2(RAM_SIZE * 16)-1 downto 0)) / 16;
							state		<= STATE_WRITE;

						elsif(requestHead.request = 0) then
							ramAddress <= (to_integer(requestHead.address(17 downto 16)) * NumQueueEntries * 4) + to_integer(requestHead.address(log2(RAM_SIZE * 16)-1 downto 0)) / 16;
							replyHead.error <= to_unsigned(0, replyHead.error'length);
							replyHead.status <= to_unsigned(0, replyHead.status'length);
							replyHead.byteCount <= truncate(requestHead.count * 4, replyHead.byteCount'length);
							replyHead.count <= requestHead.count;
							replyHead.requesterId <= requestHead.requesterId;
							replyHead.tag <= requestHead.tag;
							replyHead.address <= requestHead.address(11 downto 0);
							streamIn.ready <= '0';
							state <= STATE_READHEAD;

						elsif(requestHead.request = 1) then
							-- Performs special queue operation
							queueIn <= to_integer(requestHead.address(QueueNumRange));
							if(requestHead.address(20) = '1') then
								requestHead1	<= requestHead;
								queueOutIncrement(queueOutArrayPos, requestHead.address(QueueNumRange));
								state		<= STATE_REPLY_RDATA;
							else
								queueAddressStart(queueInArrayPos, requestHead.address(QueueNumRange), ramAddress);
								state <= STATE_WRITE_QUEUE;
							end if;
						end if;
					end if;
					
				when STATE_WRITE =>
					if((streamIn.ready = '1') and (streamIn.valid = '1')) then
						ram(ramAddress) <= streamIn.data;
						ramAddress <= ramAddress + 1;
						if(streamIn.last = '1') then
							state <= STATE_IDLE;
						end if;
					end if;
				
				when STATE_READHEAD =>
					data1		<= ram(ramAddress);
					streamOut.valid	<= '1';

					if((streamOut.ready = '1') and (streamOut.valid = '1')) then
						data2		<= data1;
						data1		<= ram(ramAddress+1);
						replyHead.count	<= replyHead.count - 5;
						ramAddress 	<= ramAddress + 1;
						state		<= STATE_READDATA;
					end if;

				when STATE_READDATA =>
					if((streamOut.ready = '1') and (streamOut.valid = '1')) then
						data2		<= data1;
						data1		<= ram(ramAddress+1);
						replyHead.count	<= replyHead.count - 4;
						ramAddress 	<= ramAddress + 1;

						if(streamOut.last = '1') then
							streamOut.valid	<= '0';
							streamOut.last	<= '0';
							state		<= STATE_IDLE;
						elsif(replyHead.count <= 4) then
							streamOut.last	<= '1';
							streamOut.keep	<= concat('0', 4) & concat('1', 12);
						end if;
					end if;

				when STATE_WRITE_QUEUE =>
					if((streamIn.ready = '1') and (streamIn.valid = '1')) then
						ram(ramAddress) <= streamIn.data;
						ramAddress <= ramAddress + 1;
						if(streamIn.last = '1') then
							-- Perform bus master write request to doorbell register on Nvme (0x1000, 0x1008, 0x1010 ...)
							doorbellReqHead.address	<= to_unsigned(16#000010#, doorbellReqHead.address'length - 8) & to_unsigned(queueIn * 8, 8);
							doorbellReqHead.tag	<= x"44";
							doorbellReqHead.requesterId	<= to_unsigned(2, doorbellReqHead.requesterId'length);
							doorbellReqHead.request	<= "0001";
							doorbellReqHead.count	<= to_unsigned(16#0001#, doorbellReqHead.count'length);

							streamIn.ready		<= '0';
							streamOut.keep 		<= ones(16);
							streamOut.valid 	<= '1';
							streamOut.last 		<= '0';
							state			<= STATE_SEND_DOORBELL_HEAD;
						end if;
					end if;
					
				when STATE_SEND_DOORBELL_HEAD =>
					if(streamOut.valid = '1' and streamOut.ready = '1') then
						data1		<= zeros(128 - log2(NumQueueEntries)) & std_logic_vector(queueInArrayPos(queueIn));
						streamOut.keep 	<= zeros(12) & ones(4);
						streamOut.last 	<= '1';
						state		<= STATE_SEND_DOORBELL_POS;
					end if;

				when STATE_SEND_DOORBELL_POS =>
					if(streamOut.valid = '1' and streamOut.ready = '1') then
						streamOut.valid <= '0';
						streamOut.last 	<= '0';
						state		<= STATE_IDLE;
					end if;

				when STATE_REPLY_RDATA =>
					if((streamIn.ready = '1') and (streamIn.valid = '1')) then
						data1					<= streamIn.data;
						requestHead1.address(31 downto 24)	<= unsigned(streamIn.data(111 downto 104));
						requestHead1.requesterId		<= to_unsigned(2, requestHead1.requesterId'length);

						streamIn.ready				<= '0';
						streamOut.keep 				<= ones(16);
						streamOut.last 				<= '0';
						streamOut.valid 			<= '1';
						state					<= STATE_REPLY_SHEAD;
					end if;
					
				when STATE_REPLY_SHEAD =>
					if(streamOut.valid = '1' and streamOut.ready = '1') then
						streamOut.last	<= '1';
						state		<= STATE_REPLY_SDATA;
					end if;

				when STATE_REPLY_SDATA =>
					if(streamOut.valid = '1' and streamOut.ready = '1') then
						streamOut.last	<= '0';

						-- Perform bus master write request to doorbell register on Nvme (0x1000, 0x1008, 0x1010 ...)
						doorbellReqHead.address	<= to_unsigned(16#000010#, doorbellReqHead.address'length - 8) & to_unsigned(queueIn * 8 + 4, 8);
						doorbellReqHead.tag	<= x"44";
						doorbellReqHead.requesterId	<= requestHead1.requesterId;
						doorbellReqHead.request	<= "0001";
						doorbellReqHead.count	<= to_unsigned(16#0001#, doorbellReqHead.count'length);

						state	<= STATE_SEND_RDOORBELL_HEAD;
					end if;

				when STATE_SEND_RDOORBELL_HEAD =>
					if(streamOut.valid = '1' and streamOut.ready = '1') then
						data1		<= zeros(128 - log2(NumQueueEntries)) & std_logic_vector(queueOutArrayPos(queueIn));
						streamOut.keep 	<= zeros(12) & ones(4);
						streamOut.last	<= '1';
						state		<= STATE_SEND_DOORBELL_POS;
					end if;

				end case;
			end if;
		end if;
	end process;
end;
