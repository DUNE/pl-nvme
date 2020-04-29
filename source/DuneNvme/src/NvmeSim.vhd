--------------------------------------------------------------------------------
--	NvmeSim.vhd Nvme storage simulation module
--	T.Barnaby, Beam Ltd. 2020-03-13
-------------------------------------------------------------------------------
--!
--! @class	NvmeSim
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-03-13
--! @version	0.0.1
--!
--! @brief
--! This is a very basic module to simulate an NVMe device connected via PCIe to
--!  the Xilinx PCIe Gen3 IP block.
--!
--! @details
--! This is a very basic module to simulate an NVMe device connected via PCIe to the Xilinx PCIe Gen3 IP block.
--! 
--! It has a simple AXI4 Stream interface matching that as used by the Xilinx PCIe Gen3 IP block.
--! It is designed to help with the testing of the NvmeStorage blocks operation during simulation of the VHDL.
--!
--! The core responds to specific configuration space writes and specific NVMe register writes (Queue door bell registers).
--! The module makes PCIe read/write requests to access the request/reply queues and data input/output memory
--!  in a similar manner to a real NVMe device.
--!
--! Simple interface ignoring actual data values and 32bit dataword positions with 128 bit transfered words.
--!
--! NVMe requests not pipelined and carried out one at a time, in sequence.
--! Currently does not perform configuration or NVMe register read operations.
--! Currently does not handle NVMe read data requests.
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

entity NvmeSim is
generic(
	Simulate	: boolean	:= True
);
port (
	clk		: in std_logic;					--! The input clock
	reset		: in std_logic;					--! The reset line

	-- AXIS Interface to PCIE
	hostReq		: inout AxisStreamType := AxisInput;		--! Host request stream
	hostReply	: inout AxisStreamType := AxisOutput;		--! Host reply stream

	-- From Nvme reqeuest and reply stream
	nvmeReq		: inout AxisStreamType := AxisOutput;		--! Nvme request stream (bus master)
	nvmeReply	: inout AxisStreamType := AxisInput		--! Nvme reply stream
);
end;

architecture Behavioral of NvmeSim is

constant TCQ			: time := 1 ns;
constant RegWidth		: integer := 32;

subtype RegDataType		is std_logic_vector(RegWidth-1 downto 0);
type StateType			is (STATE_IDLE, STATE_WRITE, STATE_REPLY, STATE_READ, STATE_READ_QUEUE_START, STATE_READ_QUEUE,
					STATE_QUEUE_REPLY_HEAD, STATE_QUEUE_REPLY_DATA,
					STATE_READ_DATA_START, STATE_READ_DATA_RECV_START, STATE_READ_DATA_RECV);
type QueueRequestType		is array(0 to 15) of std_logic_vector(31 downto 0);

signal state			: StateType := STATE_IDLE;
signal hostRequestHead		: PcieRequestHeadType;
signal hostRequestHead1		: PcieRequestHeadType := set_PcieRequestHeadType(0, 0, 0, 0, 0);
signal hostReplyHead		: PcieReplyHeadType := set_PcieReplyHeadType(0, 0, 0, 0, 0);
signal hostReplyHead1		: PcieReplyHeadType := set_PcieReplyHeadType(0, 0, 0, 0, 0);
signal nvmeRequestHead		: PcieRequestHeadType;
signal nvmeReplyHead		: PcieReplyHeadType;
signal reg_pci_command		: RegDataType := (others => '0');
signal reg_admin_queue		: RegDataType := (others => '0');
signal reg_io1_queue		: RegDataType := (others => '0');
signal reg_io2_queue		: RegDataType := (others => '0');
signal regData			: RegDataType := (others => '0');
signal streamNum		: integer := 1;
signal queue			: integer;
signal count			: unsigned(10 downto 0);
signal chunkCount		: unsigned(10 downto 0);
signal queueRequest		: QueueRequestType := (others => (others => '0'));
signal queueRequestPos		: integer := 0;

signal data			: std_logic_vector(127 downto 0);

begin
	-- Register access
	regData			<= reg_pci_command when hostRequestHead1.address = x"4" else x"FFFFFFFF";

	hostReplyHead.byteCount	<= to_unsigned(4, hostReplyHead.byteCount'length);
	hostReplyHead.error	<= to_unsigned(0, hostReplyHead.error'length);
	hostReplyHead.address	<= hostRequestHead1.address(hostReplyHead.address'length-1 downto 0);
	hostReplyHead.status	<= to_unsigned(0, hostReplyHead.status'length);
	hostReplyHead.count	<= to_unsigned(1, hostReplyHead.count'length);
	hostReplyHead.tag	<= hostRequestHead1.tag;
	hostReplyHead.requesterId	<= hostRequestHead1.requesterId;
	data			<= concat('0', 32) & to_stl(hostReplyHead);
	hostReply.data		<= zeros(32) & to_stl(hostReplyHead1) when(state = STATE_REPLY)
					else regData & data(95 downto 0);
		
	hostRequestHead		<= to_PcieRequestHeadType(hostReq.data);
	nvmeReq.data		<= zeros(16)  & queueRequest(0)(31 downto 16) & zeros(96) when(state = STATE_QUEUE_REPLY_DATA)
					else to_stl(nvmeRequestHead);
	nvmeReplyHead		<= to_PcieReplyHeadType(nvmeReply.data);
	
	-- Process host requests
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				reg_pci_command	<= (others => '0');
				reg_admin_queue	<= (others => '0');
				reg_io1_queue	<= (others => '0');
				reg_io2_queue	<= (others => '0');
				hostReq.ready	<= '0';
				hostReply.valid <= '0';
				hostReply.last	<= '0';
				nvmeReq.valid	<= '0';
				nvmeReq.last	<= '0';
				nvmeReply.ready <= '0';
				nvmeRequestHead	<= to_PcieRequestHeadType(concat('0', 128));
				state		<= STATE_IDLE;
			else
				case(state) is
				when STATE_IDLE =>
					if(hostReq.ready = '1' and hostReq.valid= '1') then
						hostRequestHead1 <= hostRequestHead;

						if((hostRequestHead.request = 10) or (hostRequestHead.request = 1)) then
							state	<= STATE_WRITE;
						elsif(hostRequestHead.request = 8) then
							state	<= STATE_READ;
						end if;
					else
						hostReq.ready	<= '1';
					end if;

				when STATE_WRITE =>
					if(hostReq.ready = '1' and hostReq.valid= '1') then
						if(hostRequestHead1.request = 10) then
							if(hostRequestHead1.address = x"0004") then
								reg_pci_command <= hostReq.data(31 downto 0);
							end if;
							state <= STATE_REPLY;
						else 
							if(hostRequestHead1.address = x"1000") then
								reg_admin_queue <= hostReq.data(31 downto 0);
								queue		<= 0;
								state		<= STATE_READ_QUEUE_START;
							elsif(hostRequestHead1.address = x"1008") then
								reg_io1_queue	<= hostReq.data(31 downto 0);
								queue		<= 1;
								state		<= STATE_READ_QUEUE_START;
							elsif(hostRequestHead1.address = x"1010") then
								reg_io2_queue	<= hostReq.data(31 downto 0);
								queue		<= 2;
								state		<= STATE_READ_QUEUE_START;
							else
								state <= STATE_IDLE;
							end if;
						end if;

						hostReq.ready	<= '0';
					end if;

				when STATE_REPLY =>
					hostReplyHead1.byteCount	<= to_unsigned(0, hostReplyHead1.byteCount'length);
					hostReplyHead1.address		<= to_unsigned(0, hostReplyHead1.address'length);
					hostReplyHead1.error		<= to_unsigned(0, hostReplyHead1.error'length);
					hostReplyHead1.status		<= to_unsigned(0, hostReplyHead1.status'length);
					hostReplyHead1.tag		<= hostRequestHead1.tag;
					hostReplyHead1.requesterId	<= hostRequestHead1.requesterId;

					if(hostReply.ready = '1' and hostReply.valid= '1') then
						hostReply.valid	<= '0';
						hostReply.last	<= '0';
						state		<= STATE_IDLE;
					else
						hostReply.valid	<= '1';
						hostReply.last	<= '1';
						hostReply.keep	<= zeros(4) & ones(12);
					end if;
					

				when STATE_READ =>
					if(hostReply.ready = '1' and hostReply.valid= '1') then
						hostReply.valid	<= '0';
						hostReply.last	<= '0';
						state		<= STATE_IDLE;
					else
						hostReply.valid	<= '1';
						hostReply.last	<= '1';
						hostReply.keep	<= ones(16);
					end if;

				when STATE_READ_QUEUE_START =>
					-- Perform bus master read request for queue data
					nvmeRequestHead.address	<= x"020" & to_unsigned(queue, 4) & x"0000";
					nvmeRequestHead.tag	<= x"44";
					nvmeRequestHead.requesterId	<= to_unsigned(0, nvmeRequestHead.requesterId'length);
					nvmeRequestHead.request	<= "0000";
					nvmeRequestHead.count	<= to_unsigned(16#0010#, nvmeRequestHead.count'length);
					nvmeReq.keep 		<= ones(16);
					nvmeReq.valid 		<= '1';
					nvmeReq.last 		<= '1';
					
					if(nvmeReq.valid = '1' and nvmeReq.ready = '1') then
						count		<= nvmeRequestHead.count;
						queueRequestPos	<= 0;
						nvmeReq.valid 	<= '0';
						nvmeReq.last 	<= '0';
						nvmeReply.ready <= '1';
						state		<= STATE_READ_QUEUE;
					end if;

				when STATE_READ_QUEUE =>
					-- Read in queue data ignoring it
					if(nvmeReply.valid = '1' and nvmeReply.ready = '1') then
						if(count = 16) then
							queueRequest(queueRequestPos)	<= nvmeReply.data(127 downto 96);
							queueRequestPos			<= queueRequestPos + 1;
						elsif(count = 0) then
							queueRequest(queueRequestPos)	<= nvmeReply.data(31 downto 0);
							queueRequest(queueRequestPos+1)	<= nvmeReply.data(63 downto 32);
							queueRequest(queueRequestPos+2)	<= nvmeReply.data(95 downto 64);
							queueRequestPos			<= queueRequestPos + 3;
						else
							queueRequest(queueRequestPos)	<= nvmeReply.data(31 downto 0);
							queueRequest(queueRequestPos+1)	<= nvmeReply.data(63 downto 32);
							queueRequest(queueRequestPos+2)	<= nvmeReply.data(95 downto 64);
							queueRequest(queueRequestPos+3)	<= nvmeReply.data(127 downto 96);
							queueRequestPos			<= queueRequestPos + 4;
						end if;

						count <= count - 4;
						if(count = 0) then
							nvmeReply.ready	<= '0';
							if(queue = 1) then
								state		<= STATE_READ_DATA_START;
							elsif(queue = 2) then
								state		<= STATE_READ_DATA_START;
							else
								-- Writes an entry into the Admin reply queue. Simply uses info in that last queued request. So only one request at a time.
								-- Note data sent to queue is just the header reapeated so junk data ATM.
								-- Perform bus master read request for data to write to NVMe
								nvmeRequestHead.address	<= to_unsigned(16#02100000#, nvmeRequestHead.address'length);
								nvmeRequestHead.tag	<= x"44";
								nvmeRequestHead.request	<= "0001";
								nvmeRequestHead.count	<= to_unsigned(16#0004#, nvmeRequestHead.count'length);	-- 16 Byte queue entry
								count			<= to_unsigned(16#0004#, count'length);	-- 16 Byte queue entry
								nvmeReq.keep 		<= ones(16);
								nvmeReq.valid 		<= '1';
								state			<= STATE_QUEUE_REPLY_HEAD;
							end if;
						end if;
					end if;

				when STATE_QUEUE_REPLY_HEAD =>
					if(nvmeReq.valid = '1' and nvmeReq.ready = '1') then
						nvmeReq.last 	<= '1';
						state 		<= STATE_QUEUE_REPLY_DATA;
					end if;

				when STATE_QUEUE_REPLY_DATA =>
					if(nvmeReq.valid = '1' and nvmeReq.ready = '1') then
						nvmeReq.last 	<= '0';
						nvmeReq.valid 	<= '0';
						nvmeReply.ready <= '1';
						state		<= STATE_IDLE;
					end if;

				when STATE_READ_DATA_START =>
					-- Perform bus master read request for data to write to NVMe
					-- Hardcoded to address 0x04000000
					nvmeRequestHead.address	<= to_unsigned(16#04000000#, nvmeRequestHead.address'length);
					nvmeRequestHead.tag	<= x"44";
					nvmeRequestHead.request	<= "0000";
					nvmeRequestHead.count	<= to_unsigned(16#0040#, nvmeRequestHead.count'length);	-- Test size of 64 DWords
					
					if(nvmeReq.valid = '1' and nvmeReq.ready = '1') then
						count		<= nvmeRequestHead.count;	-- Note ignoring 1 DWord in first 128 bits
						nvmeReq.last 	<= '0';
						nvmeReq.valid 	<= '0';
						nvmeReply.ready <= '1';
						state		<= STATE_READ_DATA_RECV_START;
					else
						nvmeReq.keep 	<= ones(16);
						nvmeReq.last 	<= '1';
						nvmeReq.valid 	<= '1';
					end if;

				when STATE_READ_DATA_RECV_START =>
					-- Read in write data ignoring it
					if(nvmeReply.valid = '1' and nvmeReply.ready = '1') then
						chunkCount 	<= nvmeReplyHead.count;
						state		<= STATE_READ_DATA_RECV;
					end if;

				when STATE_READ_DATA_RECV =>
					-- Read in write data ignoring it
					if(nvmeReply.valid = '1' and nvmeReply.ready = '1') then
						if(chunkCount = 4) then
							if(count = 4) then
								nvmeReply.ready	<= '0';
								state		<= STATE_IDLE;
								--state		<= STATE_READ_DATA_START;
							else
								state		<= STATE_READ_DATA_RECV_START;
							end if;
						end if;
						count <= count - 4;
						chunkCount <= chunkCount - 4;
					end if;

				end case;
			end if;
		end if;
	end process; 
end;
