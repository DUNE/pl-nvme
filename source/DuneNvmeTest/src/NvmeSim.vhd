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
--use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.AxiPkg.all;
use work.NvmeStoragePkg.all;

entity NvmeSim is
generic(
	Simulate	: boolean	:= True
);
port (
	clk		: in std_logic;					--! The input clock
	reset		: in std_logic;					--! The reset line

	-- AXIS Interface to PCIE
	hostReq		: inout AxisStream	:= AxisInput;		--! Host request stream
	hostReply	: inout AxisStream	:= AxisOutput;		--! Host reply stream

	-- From Nvme reqeuest and reply stream
	nvmeReq		: inout AxisStream	:= AxisOutput;		--! Nvme request stream (bus master)
	nvmeReply	: inout AxisStream	:= AxisInput		--! Nvme reply stream
);
end;

architecture Behavioral of NvmeSim is

constant TCQ			: time := 1 ns;
constant RegWidth		: integer := 32;

subtype RegDataType		is std_logic_vector(RegWidth-1 downto 0);
type StateType			is (STATE_IDLE, STATE_WRITE, STATE_READ_QUEUE_START, STATE_READ_QUEUE,
					STATE_READ_DATA_START, STATE_READ_DATA_RECV_START, STATE_READ_DATA_RECV);

signal state			: StateType := STATE_IDLE;
signal hostRequest		: PcieRequestHead;
signal nvmeRequest		: PcieRequestHead;
signal nvmeReplyHead		: PcieReplyHead;
signal config			: std_logic;
signal address			: std_logic_vector(15 downto 0);
signal tag			: std_logic_vector(7 downto 0);
signal reg_pci_command		: RegDataType := (others => '0');
signal reg_admin_queue		: RegDataType := (others => '0');
signal reg_io1_queue		: RegDataType := (others => '0');
signal reg_io2_queue		: RegDataType := (others => '0');
signal queue			: integer;
signal count			: unsigned(10 downto 0);
signal chunkCount		: unsigned(10 downto 0);

begin
	-- Register access
	hostReply.data(63 downto 32) <=	(others => '0');
	hostReply.data(31 downto 0) <=	reg_pci_command when address = "0000" else x"FFFFFFFF";
		
	hostRequest <= to_PcieRequestHead(hostReq.data);
	nvmeReq.data <= to_stl(nvmeRequest);
	nvmeReplyHead <= to_PcieReplyHead(nvmeReply.data);
	
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
				nvmeReq.valid	<= '0';
				nvmeReply.ready <= '0';
				state		<= STATE_IDLE;
			else
				case(state) is
				when STATE_IDLE =>
					if(hostReq.ready = '1' and hostReq.valid= '1') then
						address <= hostRequest.address(15 downto 0);

						if(hostRequest.request = 10) then
							config	<= '1';
							state	<= STATE_WRITE;
						elsif(hostRequest.request = 1) then
							config	<= '0';
							state	<= STATE_WRITE;
						end if;
					else
						hostReq.ready	<= '1';
					end if;

				when STATE_WRITE =>
					if(hostReq.ready = '1' and hostReq.valid= '1') then
						if(config = '1') then
							if(address = x"0004") then
								reg_pci_command <= hostReq.data(31 downto 0);
							end if;
							state <= STATE_IDLE;
						else 
							if(address = x"1000") then
								reg_admin_queue <= hostReq.data(31 downto 0);
								queue		<= 1;
								state		<= STATE_READ_QUEUE_START;
							elsif(address = x"1008") then
								reg_io1_queue	<= hostReq.data(31 downto 0);
								queue		<= 2;
								state		<= STATE_READ_QUEUE_START;
							elsif(address = x"1010") then
								reg_io2_queue	<= hostReq.data(31 downto 0);
								queue		<= 3;
								state		<= STATE_READ_QUEUE_START;
							else
								state <= STATE_IDLE;
							end if;
						end if;

						hostReq.ready	<= '0';
					end if;

				when STATE_READ_QUEUE_START =>
					-- Perform bus master read request for queue data
					nvmeRequest.nvme	<= to_unsigned(0, nvmeRequest.nvme'length);
					nvmeRequest.stream	<= to_unsigned(queue, nvmeRequest.stream'length);
					nvmeRequest.address	<= to_stl(0, nvmeRequest.address'length);
					nvmeRequest.tag		<= x"44";
					nvmeRequest.request	<= "0000";
					nvmeRequest.count	<= to_unsigned(16#000F#, nvmeRequest.count'length);
					nvmeReq.valid 		<= '1';
					
					if(nvmeReq.valid = '1' and nvmeReq.ready = '1') then
						count		<= nvmeRequest.count + 1;	-- Note ignoring 1 DWord in first 128 bits
						nvmeReq.valid 	<= '0';
						nvmeReply.ready <= '1';
						state		<= STATE_READ_QUEUE;
					end if;

				when STATE_READ_QUEUE =>
					-- Read in queue data ignoring it
					if(nvmeReply.valid = '1' and nvmeReply.ready = '1') then
						count <= count - 4;
						if(count = 0) then
							nvmeReply.ready	<= '0';
							--state		<= STATE_IDLE;
							state		<= STATE_READ_DATA_START;
						end if;
					end if;

				when STATE_READ_DATA_START =>
					-- Perform bus master read request for data to write to NVMe
					nvmeRequest.nvme	<= to_unsigned(0, nvmeRequest.nvme'length);
					nvmeRequest.stream	<= to_unsigned(4, nvmeRequest.stream'length);
					nvmeRequest.address	<= to_stl(0, nvmeRequest.address'length);
					nvmeRequest.tag		<= x"44";
					nvmeRequest.request	<= "0000";
					--nvmeRequest.count	<= to_unsigned(16#03FF#, nvmeRequest.count'length);	-- 4096 Byte block
					nvmeRequest.count	<= to_unsigned(16#003F#, nvmeRequest.count'length);	-- Test size of 32 DWords
					
					if(nvmeReq.valid = '1' and nvmeReq.ready = '1') then
						count		<= nvmeRequest.count + 1;	-- Note ignoring 1 DWord in first 128 bits
						nvmeReq.valid 	<= '0';
						nvmeReply.ready <= '1';
						state		<= STATE_READ_DATA_RECV_START;
					else
						nvmeReq.valid 	<= '1';
					end if;

				when STATE_READ_DATA_RECV_START =>
					-- Read in write data ignoring it
					if(nvmeReply.valid = '1' and nvmeReply.ready = '1') then
						chunkCount 	<= nvmeReplyHead.count + 1;
						state		<= STATE_READ_DATA_RECV;
					end if;

				when STATE_READ_DATA_RECV =>
					-- Read in write data ignoring it
					if(nvmeReply.valid = '1' and nvmeReply.ready = '1') then
						if(chunkCount = 4) then
							if(count = 4) then
								nvmeReply.ready	<= '0';
								state		<= STATE_IDLE;
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
