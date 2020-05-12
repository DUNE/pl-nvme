--------------------------------------------------------------------------------
-- NvmeQueues.vhd Nvme request/reply queues in RAM
-------------------------------------------------------------------------------
--!
--! @class	NvmeQueues
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-08
--! @version	0.2.0
--!
--! @brief
--! This module implements the Nvme request/reply queues in RAM
--!
--! @details
--! This module provides the ability to write a request to one of the 4 Nvme request queues
--! and receive the queued replies. This engine handles the queue location and informs
--! the Nvme of the new queue entry by writing to the appropriate doorbell register.
--! It supports queue memory reads from the Nvme device.
--! When the Nvme writes to a reply queue, the queue reply messages is directly sent to
--! the originator of the request as given in the CID field.
--! The process sending a requests simply uses a PcieWrite request to the appropriate queue memory location.
--! The NvmeQueue engine handles wrting this to the next available queue entry slot.
--! The queue replies are sent to the originator as a PcieWrite request with the address set to the reply
--! queues address (0x0201XXXXX).
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
	
	streamIn	: inout AxisStreamType := AxisStreamInput;	--! Request queue entries
	streamOut	: inout AxisStreamType := AxisStreamOutput	--! replies and requests
);
end;

architecture Behavioral of NvmeQueues is

constant TCQ		: time		:= 1 ns;
constant NUM_QUEUES	: integer	:= 4;
constant RAM_SIZE	: integer	:= NUM_QUEUES * NumQueueEntries * 4;		--! Only write to request queues are stored
constant ADDRESS_WIDTH	: integer	:= log2(RAM_SIZE); 

component Ram is
generic (
	DataWidth	: integer := 128;			--! The data width of the RAM in bits
	Size		: integer := RAM_SIZE;			--! The size in RAM locations
	AddressWidth	: integer := log2(RAM_SIZE)
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	writeEnable	: in std_logic;
	writeAddress	: in unsigned(AddressWidth-1 downto 0);	
	writeData	: in std_logic_vector(DataWidth-1 downto 0);	

	readEnable	: in std_logic;
	readAddress	: in unsigned(AddressWidth-1 downto 0);	
	readData	: out std_logic_vector(DataWidth-1 downto 0)	
);
end component;

subtype QueueNumRange	is integer range 17 downto 16;
subtype QueuePosType	is unsigned(log2(NumQueueEntries)-1 downto 0);
type QueuePosArrayType	is array(0 to NUM_QUEUES-1) of QueuePosType;
type StateType		is (STATE_IDLE, STATE_WRITE, STATE_READHEAD1, STATE_READHEAD2, STATE_READDATA,
				STATE_WRITE_QUEUE, STATE_SEND_DOORBELL_HEAD, STATE_SEND_DOORBELL_POS,
				STATE_REPLY_RDATA, STATE_REPLY_SHEAD, STATE_REPLY_SDATA, STATE_SEND_RDOORBELL_HEAD);

signal state		: StateType := STATE_IDLE;
signal ramWriteEnable	: std_logic := '0';
signal ramReadEnable	: std_logic := '0';
signal ramAddressWrite	: unsigned(ADDRESS_WIDTH-1 downto 0) := (others => '0');
signal ramAddressRead	: unsigned(ADDRESS_WIDTH-1 downto 0) := (others => '0');
signal ramReadData	: std_logic_vector(127 downto 0) := (others => '0');
signal data1		: std_logic_vector(127 downto 0) := (others => '0');

signal queueIn		: integer range 0 to NUM_QUEUES - 1 := 0;
signal queueInArrayPos	: QueuePosArrayType := (others => (others => '0'));
signal queueOutArrayPos	: QueuePosArrayType := (others => (others => '0'));

signal requestHead	: PcieRequestHeadType;
signal requestHead1	: PcieRequestHeadType;
signal replyHead	: PcieReplyHeadType;
signal doorbellReqHead	: PcieRequestHeadType;

--! Given Pcie address calculate RAM address
procedure queueAddress(address: unsigned; signal ramAddress: out unsigned) is
begin
	ramAddress <= address(QueueNumRange) & address(log2(NumQueueEntries)+4+2-1 downto 4);
end;

--! Sets the RAM access address from last queue position and updates queue position
procedure queueAddressStart(signal queueArray: inout QueuePosArrayType; queueNum: unsigned; signal address: out unsigned) is
begin
	address <= queueNum & queueArray(to_integer(queueNum)) & "00";
	queueArray(to_integer(queueNum)) <= queueArray(to_integer(queueNum)) + 1;
end;

procedure queueOutIncrement(signal queueArray: inout QueuePosArrayType; queueNum: unsigned) is
begin
	queueArray(to_integer(queueNum)) <= queueArray(to_integer(queueNum)) + 1;
end;

begin
	-- Queue memory
	queueMem0 : Ram
	port map (
		clk		=> clk,
		reset		=> reset,

		writeEnable	=> ramWriteEnable,
		writeAddress	=> ramAddressWrite,
		writeData	=> streamIn.data,

		readEnable	=> ramReadEnable,
		readAddress	=> ramAddressRead,
		readData	=> ramReadData
	);
	
	ramWriteEnable		<= '1' when(((state = STATE_WRITE) or (state = STATE_WRITE_QUEUE)) and (streamIn.valid = '1')) else '0';
	ramReadEnable		<= '1' when((state = STATE_IDLE) or (state = STATE_READHEAD1)) else streamOut.ready;
	
	requestHead		<= to_PcieRequestHeadType(streamIn.data);
	streamOut.data		<= ramReadData(31 downto 0) & to_stl(replyHead) when((state = STATE_READHEAD1) or (state = STATE_READHEAD2))
					else ramReadData(31 downto 0) & data1(127 downto 32) when(state = STATE_READDATA)
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
							ramAddressWrite	<= requestHead.address(ADDRESS_WIDTH+4-1 downto 4);
							state		<= STATE_WRITE;

						elsif(requestHead.request = 0) then
							-- Reads from one of the queue
							queueAddress(requestHead.address, ramAddressRead);
							replyHead.error <= to_unsigned(0, replyHead.error'length);
							replyHead.status <= to_unsigned(0, replyHead.status'length);
							replyHead.byteCount <= truncate(requestHead.count * 4, replyHead.byteCount'length);
							replyHead.count <= requestHead.count;
							replyHead.requesterId <= requestHead.requesterId;
							replyHead.tag <= requestHead.tag;
							replyHead.address <= requestHead.address(11 downto 0);
							streamIn.ready <= '0';
							state <= STATE_READHEAD1;

						elsif(requestHead.request = 1) then
							-- Writes to the queue
							queueIn <= to_integer(requestHead.address(QueueNumRange));
							if(requestHead.address(20) = '1') then
								requestHead1	<= requestHead;
								queueOutIncrement(queueOutArrayPos, requestHead.address(QueueNumRange));
								state		<= STATE_REPLY_RDATA;
							else
								queueAddressStart(queueInArrayPos, requestHead.address(QueueNumRange), ramAddressWrite);
								state <= STATE_WRITE_QUEUE;
							end if;
						end if;
					end if;
					
				when STATE_WRITE =>
					if((streamIn.ready = '1') and (streamIn.valid = '1')) then
						ramAddressWrite <= ramAddressWrite + 1;
						if(streamIn.last = '1') then
							state <= STATE_IDLE;
						end if;
					end if;
				
				when STATE_READHEAD1 =>
					data1		<= ramReadData;
					ramAddressRead 	<= ramAddressRead + 1;
					streamOut.valid	<= '1';
					state		<= STATE_READHEAD2;

				when STATE_READHEAD2 =>
					if(streamOut.ready = '1') then
						data1		<= ramReadData;
						ramAddressRead 	<= ramAddressRead + 1;
						replyHead.count	<= replyHead.count - 5;
						state		<= STATE_READDATA;
					end if;

				when STATE_READDATA =>
					if((streamOut.ready = '1') and (streamOut.valid = '1')) then
						data1		<= ramReadData;
						ramAddressRead 	<= ramAddressRead + 1;
						replyHead.count	<= replyHead.count - 4;

						if(streamOut.last = '1') then
							streamOut.valid	<= '0';
							streamOut.last	<= '0';
							state		<= STATE_IDLE;
						elsif(replyHead.count <= 4) then
							streamOut.last	<= '1';
							streamOut.keep	<= "0111";
						end if;
					end if;

				when STATE_WRITE_QUEUE =>
					if((streamIn.ready = '1') and (streamIn.valid = '1')) then
						ramAddressWrite <= ramAddressWrite + 1;
						if(streamIn.last = '1') then
							-- Perform bus master write request to doorbell register on Nvme (0x1000, 0x1008, 0x1010 ...)
							doorbellReqHead.address	<= to_unsigned(16#000010#, doorbellReqHead.address'length - 8) & to_unsigned(queueIn * 8, 8);
							doorbellReqHead.tag	<= x"44";
							doorbellReqHead.requesterId	<= to_unsigned(2, doorbellReqHead.requesterId'length);
							doorbellReqHead.request	<= "0001";
							doorbellReqHead.count	<= to_unsigned(16#0001#, doorbellReqHead.count'length);

							streamIn.ready		<= '0';
							streamOut.keep 		<= ones(streamOut.keep'length);
							streamOut.valid 	<= '1';
							streamOut.last 		<= '0';
							state			<= STATE_SEND_DOORBELL_HEAD;
						end if;
					end if;
					
				when STATE_SEND_DOORBELL_HEAD =>
					if(streamOut.valid = '1' and streamOut.ready = '1') then
						data1		<= zeros(128 - log2(NumQueueEntries)) & std_logic_vector(queueInArrayPos(queueIn));
						streamOut.keep 	<= "0001";
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
						streamOut.keep 				<= ones(streamOut.keep'length);
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
						streamOut.keep 	<= "0001";
						streamOut.last	<= '1';
						state		<= STATE_SEND_DOORBELL_POS;
					end if;

				end case;
			end if;
		end if;
	end process;
end;
