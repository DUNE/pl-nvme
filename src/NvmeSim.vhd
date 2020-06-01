--------------------------------------------------------------------------------
-- NvmeSim.vhd Nvme storage simulation module
-------------------------------------------------------------------------------
--!
--! @class	NvmeSim
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-03-13
--! @version	1.0.0
--!
--! @brief
--! This is a very basic module to simulate an NVMe device connected via PCIe to
--! the Xilinx PCIe Gen3 IP block.
--!
--! @details
--! This is a very basic module to simulate an NVMe device connected via PCIe to the Xilinx PCIe Gen3 IP block.
--! 
--! It has a simple AXI4 Stream interface matching that as used by the Xilinx PCIe Gen3 IP block.
--! It is designed to help with the testing of the NvmeStorage blocks operation during simulation of the VHDL.
--!
--! The core responds to specific configuration space writes and specific NVMe register writes (Queue door bell registers).
--! The module makes PCIe read/write requests to access the request/reply queues and data input/output memory
--! in a similar manner to a real NVMe device.
--!
--! It has a simple interface ignoring actual data values and 32bit dataword positions within 128 bit transfered words.
--!
--! NVMe requests are not pipelined and carried out one at a time, in sequence.
--! Currently does not perform configuration or NVMe register read operations.
--! NvmeSim is still pretty basic.
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
	Simulate	: boolean := True;
	BlockSize	: integer := NvmeStorageBlockSize	--! System block size
);
port (
	clk		: in std_logic;					--! The input clock
	reset		: in std_logic;					--! The reset line

	-- AXIS Interface to PCIE
	hostReq		: inout AxisStreamType := AxisStreamInput;		--! Host request stream
	hostReply	: inout AxisStreamType := AxisStreamOutput;		--! Host reply stream

	-- From Nvme reqeuest and reply stream
	nvmeReq		: inout AxisStreamType := AxisStreamOutput;		--! Nvme request stream (bus master)
	nvmeReply	: inout AxisStreamType := AxisStreamInput		--! Nvme reply stream
);
end;

architecture Behavioral of NvmeSim is

constant TCQ			: time := 1 ns;
constant NumQueue		: integer := 16;			--! Number of queue entries
constant RegWidth		: integer := 32;
constant NumWordsRead		: integer := BlockSize/4;		--! Number of 32bit Dwords in a block

subtype RegDataType		is std_logic_vector(RegWidth-1 downto 0);

-- Host requests
type ReqStateType		is (REQSTATE_IDLE, REQSTATE_WRITE, REQSTATE_READ, REQSTATE_REPLY);
signal reqState			: ReqStateType := REQSTATE_IDLE;
signal hostRequestHead		: PcieRequestHeadType;
signal hostRequestHead1		: PcieRequestHeadType := set_PcieRequestHeadType(0, 0, 0, 0, 0);
signal hostReplyHead		: PcieReplyHeadType := set_PcieReplyHeadType(0, 0, 0, 0, 0);
signal hostReplyHead1		: PcieReplyHeadType := set_PcieReplyHeadType(0, 0, 0, 0, 0);
signal reg_pci_command		: RegDataType := (others => '0');
signal reg_admin_queue		: RegDataType := (others => '0');
signal reg_io1_queue		: RegDataType := (others => '0');
signal reg_io2_queue		: RegDataType := (others => '0');

-- Process queues
signal queueAdminIn		: integer range 0 to NumQueue-1 := 0;
signal queueAdminOut		: integer range 0 to NumQueue-1 := 0;
signal queueWriteIn		: integer range 0 to NumQueue-1 := 0;
signal queueWriteOut		: integer range 0 to NumQueue-1 := 0;
signal queueReadIn		: integer range 0 to NumQueue-1 := 0;
signal queueReadOut		: integer range 0 to NumQueue-1 := 0;

type StateType			is (STATE_IDLE, STATE_READ_QUEUE_START, STATE_READ_QUEUE,
					STATE_QUEUE_REPLY_HEAD, STATE_QUEUE_REPLY_DATA,
					STATE_READ_DATA_START, STATE_READ_DATA_RECV_START, STATE_READ_DATA_RECV,
					STATE_WRITE_DATA_START, STATE_WRITE_DATA_HEAD, STATE_WRITE_DATA,
					STATE_REPLY_QUEUE);
type QueueRequestType		is array(0 to 15) of std_logic_vector(31 downto 0);

signal state			: StateType := STATE_IDLE;
signal queue			: integer range 0 to NumQueue-1 := 0;
signal queue_pos		: integer range 0 to NumQueue-1 := 0;
signal nvmeReply1		: AxisStreamType;			--! Nvme reply stream for valid replies
signal nvmeRequestHead		: PcieRequestHeadType;
signal nvmeReply1Head		: PcieReplyHeadType;
signal regData			: RegDataType := (others => '0');
signal streamNum		: integer := 1;
signal count			: unsigned(10 downto 0);
signal chunkCount		: unsigned(10 downto 0);
signal queueRequest		: QueueRequestType := (others => (others => '0'));
signal queueRequestPos		: integer := 0;
signal waitingForReply		: std_logic := '0';

signal data			: std_logic_vector(127 downto 0);
signal readData			: unsigned(127 downto 0);

function queueNext(pos: integer) return integer is
begin
	if(pos = (NumQueue - 1)) then
		return 0;
	else
		return pos + 1;
	end if;
end;

begin
	--! Host requests including register access
	hostRequestHead		<= to_PcieRequestHeadType(hostReq.data);
	regData			<= reg_pci_command when hostRequestHead1.address = x"4" else x"FFFFFFFF";

	hostReplyHead.byteCount	<= to_unsigned(4, hostReplyHead.byteCount'length);
	hostReplyHead.error	<= to_unsigned(0, hostReplyHead.error'length);
	hostReplyHead.address	<= hostRequestHead1.address(hostReplyHead.address'length-1 downto 0);
	hostReplyHead.status	<= to_unsigned(0, hostReplyHead.status'length);
	hostReplyHead.count	<= to_unsigned(1, hostReplyHead.count'length);
	hostReplyHead.tag	<= hostRequestHead1.tag;
	hostReplyHead.requesterId	<= hostRequestHead1.requesterId;

	data			<= concat('0', 32) & to_stl(hostReplyHead);
	hostReply.data		<= zeros(32) & to_stl(hostReplyHead1) when(reqState = REQSTATE_REPLY)
					else regData & data(95 downto 0);
		


	nvmeReq.data		<= zeros(16)  & queueRequest(0)(31 downto 16) & zeros(96) when(state = STATE_QUEUE_REPLY_DATA)
					else to_stl(readData) when(state = STATE_WRITE_DATA)
					else to_stl(nvmeRequestHead);
	nvmeReply1Head		<= to_PcieReplyHeadType(nvmeReply1.data);

	--! Process host request packets
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				hostReq.ready	<= '0';
				hostReply.valid <= '0';
				hostReply.last	<= '0';
				reg_pci_command	<= (others => '0');
				reg_admin_queue	<= (others => '0');
				reg_io1_queue	<= (others => '0');
				reg_io2_queue	<= (others => '0');
				queueAdminIn	<= 0;
				queueWriteIn	<= 0;
				queueReadIn	<= 0;
				reqState	<= REQSTATE_IDLE;
			else
				case(reqState) is
				when REQSTATE_IDLE =>
					if(hostReq.ready = '1' and hostReq.valid= '1') then
						hostRequestHead1 <= hostRequestHead;

						if((hostRequestHead.request = 10) or (hostRequestHead.request = 1)) then
							reqState <= REQSTATE_WRITE;
						elsif(hostRequestHead.request = 8) then
							reqState <= REQSTATE_READ;
						end if;
					else
						hostReq.ready	<= '1';
					end if;

				when REQSTATE_WRITE =>
					if(hostReq.ready = '1' and hostReq.valid= '1') then
						if(hostRequestHead1.request = 10) then
							if(hostRequestHead1.address = x"0004") then
								reg_pci_command <= hostReq.data(31 downto 0);
							end if;
							reqState <= REQSTATE_REPLY;
						else 
							if(hostRequestHead1.address = x"1000") then
								reg_admin_queue <= hostReq.data(31 downto 0);
								queueAdminIn	<= to_integer(unsigned(hostReq.data(3 downto 0)));
							elsif(hostRequestHead1.address = x"1008") then
								reg_io1_queue	<= hostReq.data(31 downto 0);
								queueWriteIn	<= to_integer(unsigned(hostReq.data(3 downto 0)));
							elsif(hostRequestHead1.address = x"1010") then
								reg_io2_queue	<= hostReq.data(31 downto 0);
								queueReadIn	<= to_integer(unsigned(hostReq.data(3 downto 0)));
							end if;

							reqState <= REQSTATE_IDLE;
						end if;

						hostReq.ready <= '0';
					end if;

				when REQSTATE_REPLY =>
					hostReplyHead1.byteCount	<= to_unsigned(0, hostReplyHead1.byteCount'length);
					hostReplyHead1.address		<= to_unsigned(0, hostReplyHead1.address'length);
					hostReplyHead1.error		<= to_unsigned(0, hostReplyHead1.error'length);
					hostReplyHead1.status		<= to_unsigned(0, hostReplyHead1.status'length);
					hostReplyHead1.tag		<= hostRequestHead1.tag;
					hostReplyHead1.requesterId	<= hostRequestHead1.requesterId;

					if(hostReply.ready = '1' and hostReply.valid= '1') then
						hostReply.valid	<= '0';
						hostReply.last	<= '0';
						reqState	<= REQSTATE_IDLE;
					else
						hostReply.valid	<= '1';
						hostReply.last	<= '1';
						hostReply.keep	<= "0111";
					end if;
					

				when REQSTATE_READ =>
					if(hostReply.ready = '1' and hostReply.valid= '1') then
						hostReply.valid	<= '0';
						hostReply.last	<= '0';
						reqState	<= REQSTATE_IDLE;
					else
						hostReply.valid	<= '1';
						hostReply.last	<= '1';
						hostReply.keep	<= ones(hostReply.keep'length);
					end if;
				end case;
			end if;
		end if;
	end process;


	--! Process queued requests
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				queueWriteOut	<= 0;
				queueReadOut	<= 0;
				queue		<= 0;
				queue_pos	<= 0;
				nvmeReq.valid	<= '0';
				nvmeReq.last	<= '0';
				nvmeReply1.ready <= '0';
				nvmeRequestHead	<= to_PcieRequestHeadType(concat('0', 128));
				state		<= STATE_IDLE;
			else
				case(state) is
				when STATE_IDLE =>
					if(queueAdminIn /= queueAdminOut) then
						queue		<= 0;
						queue_pos	<= queueAdminOut;
						queueAdminOut	<= queueNext(queueAdminOut);
						state		<= STATE_READ_QUEUE_START;
					elsif(queueWriteIn /= queueWriteOut) then
						queue		<= 1;
						queue_pos	<= queueWriteOut;
						queueWriteOut	<= queueNext(queueWriteOut);
						state		<= STATE_READ_QUEUE_START;
					elsif(queueReadIn /= queueReadOut) then
						queue		<= 2;
						queue_pos	<= queueReadOut;
						queueReadOut	<= queueNext(queueReadOut);
						state		<= STATE_READ_QUEUE_START;
					end if;

				when STATE_READ_QUEUE_START =>
					-- Perform bus master read request for queue data
					nvmeRequestHead.address	<= x"020" & to_unsigned(queue, 4) & zeros(6) & to_unsigned(queue_pos, 4) & zeros(6);
					nvmeRequestHead.tag	<= x"44";
					nvmeRequestHead.requesterId	<= to_unsigned(0, nvmeRequestHead.requesterId'length);
					nvmeRequestHead.request	<= "0000";
					nvmeRequestHead.count	<= to_unsigned(16#0010#, nvmeRequestHead.count'length);
					nvmeReq.keep 		<= ones(nvmeReq.keep'length);
					nvmeReq.valid 		<= '1';
					nvmeReq.last 		<= '1';
					
					if(nvmeReq.valid = '1' and nvmeReq.ready = '1') then
						count		<= nvmeRequestHead.count;
						queueRequestPos	<= 0;
						nvmeReq.valid 	<= '0';
						nvmeReq.last 	<= '0';
						nvmeReply1.ready <= '1';
						waitingForReply	<= '1';
						state		<= STATE_READ_QUEUE;
					end if;

				when STATE_READ_QUEUE =>
					-- Read in queue data, generally ignoring it
					if(nvmeReply1.valid = '1' and nvmeReply1.ready = '1') then
						if(count = 16) then
							queueRequest(queueRequestPos)	<= nvmeReply1.data(127 downto 96);
							queueRequestPos			<= queueRequestPos + 1;
						elsif(count = 0) then
							queueRequest(queueRequestPos)	<= nvmeReply1.data(31 downto 0);
							queueRequest(queueRequestPos+1)	<= nvmeReply1.data(63 downto 32);
							queueRequest(queueRequestPos+2)	<= nvmeReply1.data(95 downto 64);
							queueRequestPos			<= queueRequestPos + 3;
						else
							queueRequest(queueRequestPos)	<= nvmeReply1.data(31 downto 0);
							queueRequest(queueRequestPos+1)	<= nvmeReply1.data(63 downto 32);
							queueRequest(queueRequestPos+2)	<= nvmeReply1.data(95 downto 64);
							queueRequest(queueRequestPos+3)	<= nvmeReply1.data(127 downto 96);
							queueRequestPos			<= queueRequestPos + 4;
						end if;

						count <= count - 4;
						if(count = 0) then
							nvmeReply1.ready	<= '0';
							waitingForReply		<= '0';

							if(queue = 0) then
								-- Writes an entry into the Admin reply queue. Simply uses info in that last queued request. So only one request at a time.
								-- Note data sent to queue is just the header reapeated so junk data ATM.
								-- Perform bus master read request for data to write to NVMe
								nvmeRequestHead.address	<= to_unsigned(16#02100000#, nvmeRequestHead.address'length);
								nvmeRequestHead.tag	<= x"44";
								nvmeRequestHead.request	<= "0001";
								nvmeRequestHead.count	<= to_unsigned(16#0004#, nvmeRequestHead.count'length);	-- 16 Byte queue entry
								count			<= to_unsigned(16#0004#, count'length);	-- 16 Byte queue entry
								nvmeReq.keep 		<= ones(nvmeReq.keep'length);
								nvmeReq.valid 		<= '1';
								state			<= STATE_QUEUE_REPLY_HEAD;
							else
								if(unsigned(queueRequest(0)(7 downto 0)) = 1) then
									state <= STATE_READ_DATA_START;
								elsif(unsigned(queueRequest(0)(7 downto 0)) = 2) then
									state <= STATE_WRITE_DATA_START;
								else
									state <= STATE_REPLY_QUEUE;
								end if;
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
						state		<= STATE_IDLE;
					end if;

				when STATE_READ_DATA_START =>
					-- Perform bus master read request for data to write to NVMe
					nvmeRequestHead.address	<= unsigned(queueRequest(6));
					--nvmeRequestHead.address	<= to_unsigned(16#05000000#, nvmeRequestHead.address'length);
					nvmeRequestHead.tag	<= x"44";
					nvmeRequestHead.request	<= "0000";
					nvmeRequestHead.count	<= to_unsigned(NumWordsRead, nvmeRequestHead.count'length);				-- Test size of 32 DWords

					if(nvmeReq.valid = '1' and nvmeReq.ready = '1') then
						count		<= nvmeRequestHead.count;	-- Note ignoring 1 DWord in first 128 bits
						nvmeReq.last 	<= '0';
						nvmeReq.valid 	<= '0';
						nvmeReply1.ready <= '1';
						waitingForReply	<= '1';
						state		<= STATE_READ_DATA_RECV_START;
					else
						nvmeReq.keep 	<= ones(nvmeReq.keep'length);
						nvmeReq.last 	<= '1';
						nvmeReq.valid 	<= '1';
					end if;

				when STATE_READ_DATA_RECV_START =>
					-- Read in write data ignoring it
					if(nvmeReply1.valid = '1' and nvmeReply1.ready = '1') then
						chunkCount 	<= nvmeReply1Head.count;
						state		<= STATE_READ_DATA_RECV;
					end if;

				when STATE_READ_DATA_RECV =>
					-- Read in write data ignoring it
					if(nvmeReply1.valid = '1' and nvmeReply1.ready = '1') then
						if(chunkCount = 4) then
							if(count = 4) then
								nvmeReply1.ready<= '0';
								waitingForReply	<= '0';
								state		<= STATE_REPLY_QUEUE;
							else
								state		<= STATE_READ_DATA_RECV_START;
							end if;
						end if;

						count		<= count - 4;
						chunkCount	<= chunkCount - 4;
					end if;


				when STATE_WRITE_DATA_START =>
					-- Perform bus master write request for data to write to NVMe
					-- Initialise the header
					nvmeRequestHead.address	<= unsigned(queueRequest(6));
					nvmeRequestHead.tag	<= x"44";
					nvmeRequestHead.request	<= "0001";

					count		<= to_unsigned(NumWordsRead, count'length);	-- Note hard coded length of 1 block
					readData	<= (others => '0');
					waitingForReply	<= '0';
					state		<= STATE_WRITE_DATA_HEAD;

				when STATE_WRITE_DATA_HEAD =>
					-- Send the updated header

					if(count > PcieMaxPayloadSize) then
						nvmeRequestHead.count	<= to_unsigned(PcieMaxPayloadSize, nvmeRequestHead.count'length);
						chunkCount		<= to_unsigned(PcieMaxPayloadSize, chunkCount'length);
					else
						nvmeRequestHead.count	<= count;
						chunkCount		<= count;
					end if;
					
					if(nvmeReq.valid = '1' and nvmeReq.ready = '1') then
						nvmeReq.last 	<= '0';
						state		<= STATE_WRITE_DATA;
					else
						nvmeReq.keep 	<= ones(nvmeReq.keep'length);
						nvmeReq.last 	<= '0';
						nvmeReq.valid 	<= '1';
					end if;

				when STATE_WRITE_DATA =>
					-- Read in write data ignoring it
					if(nvmeReq.valid = '1' and nvmeReq.ready = '1') then
						if(chunkCount = 4) then
							nvmeReq.last 	<= '0';
							nvmeReq.valid 	<= '0';

							if(count = 4) then
								nvmeReply1.ready<= '0';
								state		<= STATE_REPLY_QUEUE;
							else
								nvmeRequestHead.address <= nvmeRequestHead.address + (nvmeRequestHead.count * 4);
								state		<= STATE_WRITE_DATA_HEAD;
							end if;
						elsif(chunkCount = 8) then
							nvmeReq.last 	<= '1';
						end if;
						readData	<= readData + 1;
						count		<= count - 4;
						chunkCount	<= chunkCount - 4;
					end if;




				when STATE_REPLY_QUEUE =>
					-- Send reply queue header
					-- Writes an entry into the DataWRite reply queue. Simply uses info in that last queued request. So only one request at a time.
					-- Note data sent to queue is just the header reapeated so junk data ATM.
					nvmeRequestHead.address	<= x"021" & to_unsigned(queue, 4) & zeros(16);
					nvmeRequestHead.tag	<= x"44";
					nvmeRequestHead.request	<= "0001";
					nvmeRequestHead.count	<= to_unsigned(16#0004#, nvmeRequestHead.count'length);	-- 16 Byte queue entry
					count			<= to_unsigned(16#0004#, count'length);	-- 16 Byte queue entry
					nvmeReq.keep 		<= ones(nvmeReq.keep'length);
					nvmeReq.valid 		<= '1';
					state			<= STATE_QUEUE_REPLY_HEAD;

				end case;
			end if;
		end if;
	end process; 

	-- Process nvme replies. This keeps the nvmeReply stream open for business to allow the stream multiplexor to work
	-- with the StreamSwitch.
	nvmeReply1.valid	<= nvmeReply.valid;
	nvmeReply1.last		<= nvmeReply.last;
	nvmeReply1.keep		<= nvmeReply.keep;
	nvmeReply1.data		<= nvmeReply.data;
	nvmeReply.ready		<= nvmeReply1.ready when(waitingForReply = '1') else '1';

	process(clk)
	begin
		if(rising_edge(clk)) then
			if((nvmeReply.valid = '1') and (waitingForReply = '0')) then
				assert false report "NvmeSim had unexpected nvmeReply" severity failure;
			end if;
		end if;
	end process;

end;
