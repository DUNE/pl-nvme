--------------------------------------------------------------------------------
-- NvmeRead.vhd Nvme Write data module
-------------------------------------------------------------------------------
--!
--! @class	NvmeRead
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-14
--! @version	1.0.0
--!
--! @brief
--! This module performs the Nvme read data functionality.
--!
--! @details
--! This is a simple module that provides a set of host accessible registers that can be
--! used to read data from the Nvme device.
--! It requires the NvmeBlockSize and NvmeTotalBlocks parameters to be set for the Nvme device
--! in use.
--! To use the host sets the starting 4k block number to read, the number of blocks to read and
--! then sets the enable bit is set in the control register.
--! the NvmeRead module will then start sending NVme block read requests to the Nvme device.
--! These requests have the Pcie read data address set to 0x01FXXXXX with XXXXX set to the byte
--! address of the block. The Nvme will send Pcie write requests to this address and hence
--! the host will receive a set of Pcie write request packets with the address 0x01FXXXXX.
--! These packets will contain the block data and be sized to the Pcie max payload size.
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

entity NvmeRead is
generic(
	Simulate	: boolean := False;			--! Generate simulation core
	BlockSize	: integer := NvmeStorageBlockSize;	--! System block size
	NvmeBlockSize	: integer := 512;			--! The NVMe's formatted block size
	NvmeTotalBlocks	: integer := 134217728			--! The total number of 4k blocks available
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- To Nvme Request/reply streams
	requestOut	: inout AxisStreamType := AxisStreamOutput;	--! To Nvme request stream (3)
	replyIn		: inout AxisStreamType := AxisStreamInput;	--! from Nvme reply stream

	regWrite	: in std_logic;				--! Enable write to register
	regAddress	: in unsigned(3 downto 0);		--! Register to read/write
	regDataIn	: in std_logic_vector(31 downto 0);	--! Register write data
	regDataOut	: out std_logic_vector(31 downto 0)	--! Register contents
);
end;

architecture Behavioral of NvmeRead is

constant TCQ		: time := 1 ns;
constant NvmeBlocks	: integer := BlockSize / NvmeBlockSize;		--! The number of Nvme blocks per NvmeStorage system block

subtype RegisterType	is unsigned(31 downto 0);

type StateType		is (STATE_IDLE, STATE_INIT, STATE_RUN, STATE_COMPLETE,
				STATE_QUEUE_HEAD, STATE_QUEUE_0, STATE_QUEUE_1, STATE_QUEUE_2, STATE_QUEUE_3,
				STATE_WAIT_REPLY);
type ReplyStateType	is (REPSTATE_IDLE, REPSTATE_INIT, REPSTATE_COMPLETE, REPSTATE_QUEUE_REPLY1, REPSTATE_QUEUE_REPLY2);

signal state		: StateType := STATE_IDLE;
signal replyState	: ReplyStateType := REPSTATE_QUEUE_REPLY1;
signal nvmeReplyHead	: NvmeReplyHeadType;

-- Register information
signal control		: RegisterType := (others => '0');	--! Control register
signal status		: RegisterType := (others => '0');	--! Status register
signal dataStart	: RegisterType := (others => '0');	--! The data chunk start position in blocks
signal dataSize		: RegisterType := (others => '0');	--! The data chunk size in blocks
signal error		: RegisterType := (others => '0');	--! The system errors status

signal enabled		: std_logic := '0';					--! Read is enabled
signal complete		: std_logic := '0';					--! Read is complete
signal numBlocksProc	: unsigned(31 downto 0) := (others => '0');		--! Number of block write requests sent
signal numBlocksDone	: unsigned(31 downto 0) := (others => '0');		--! Number of block write completions received


--! Set the fields in the PCIe TLP header
function setHeader(request: integer; address: integer; count: integer; tag: integer) return std_logic_vector is
begin
	return to_stl(set_PcieRequestHeadType(3, request, address, count, tag));
end function;

function pcieAddress(blocknum: unsigned) return std_logic_vector is
begin
	return x"01F" & to_stl(blocknum(19 - log2(BlockSize) downto 0)) & zeros(log2(BlockSize));
end;

begin
	-- Register access
	regDataOut	<= std_logic_vector(control) when(regAddress = 0)
			else std_logic_vector(status) when(regAddress = 1)
			else std_logic_vector(dataStart) when(regAddress = 2)
			else std_logic_vector(dataSize) when(regAddress = 3)
			else std_logic_vector(error) when(regAddress = 4)
			else ones(32);
	
	enabled			<= control(0);
	status(0)		<= enabled;
	status(1)		<= complete;
	status(31 downto 2)	<= (others => '0');
	
	-- Register process
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				control		<= (others => '0');
				dataStart	<= (others => '0');
				dataSize	<= (others => '0');
			elsif((regWrite = '1') and (regAddress = 0)) then
				control	<= unsigned(regDataIn);
			elsif((regWrite = '1') and (regAddress = 2)) then
				dataStart <= unsigned(regDataIn);
			elsif((regWrite = '1') and (regAddress = 3)) then
				dataSize <= unsigned(regDataIn);
			end if;
		end if;
	end process;


	nvmeReplyHead <= to_NvmeReplyHeadType(replyIn.data);
	
	-- Process data read.
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				requestOut.valid 	<= '0';
				requestOut.last 	<= '0';
				requestOut.keep 	<= (others => '1');
				numBlocksProc		<= (others => '0');
				complete		<= '0';
				state			<= STATE_IDLE;
			else
				case(state) is
				when STATE_IDLE =>
					if(enabled = '1') then
						state <= STATE_INIT;
					end if;
				
				when STATE_INIT =>
					-- Initialise for next run
					numBlocksProc	<= (others => '0');
					state		<= STATE_RUN;
					
				when STATE_RUN =>
					if(enabled = '1') then
						if(numBlocksProc >= dataSize) then
							complete <= '1';
							state <= STATE_COMPLETE;
						
						else
							requestOut.data		<= setHeader(1, 16#02020000#, 16, 0);
							requestOut.valid	<= '1';
							state			<= STATE_QUEUE_HEAD;
						end if;
					else
						complete <= '1';
						state <= STATE_COMPLETE;
					end if;
				
				when STATE_COMPLETE =>
					if(enabled = '0') then
						complete <= '0';
						state <= STATE_IDLE;
					end if;

				when STATE_QUEUE_HEAD =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(64) & x"00000001" & x"06" & to_stl(numBlocksProc(7 downto 0)) & x"0002";	-- Namespace 1, From stream6, opcode 2
						state		<= STATE_QUEUE_0;
					end if;

				when STATE_QUEUE_0 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(32) & pcieAddress(numBlocksProc) & zeros(64);	-- Data source address to host
						state		<= STATE_QUEUE_1;
					end if;

				when STATE_QUEUE_1 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(32-log2(NvmeBlocks)) & std_logic_vector(dataStart + numBlocksProc) & zeros(log2(NvmeBlocks) + 64);
						state		<= STATE_QUEUE_2;
					end if;

				when STATE_QUEUE_2 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.data	<= zeros(96) & to_stl(NvmeBlocks-1, 32);	-- WriteMethod, NumBlocks (0 is 1 block)
						requestOut.last	<= '1';
						numBlocksProc	<= numBlocksProc + 1;
						state		<= STATE_QUEUE_3;
					end if;

				when STATE_QUEUE_3 =>
					if(requestOut.valid = '1' and requestOut.ready = '1') then
						requestOut.last		<= '0';
						requestOut.valid	<= '0';
						
						state <= STATE_WAIT_REPLY;
					end if;

				when STATE_WAIT_REPLY =>
					--! Need to wait here
					if(numBlocksProc > numBlocksDone) then
						state <= STATE_WAIT_REPLY;
					else
						state <= STATE_RUN;
					end if;

				end case;
			end if;
		end if;
	end process;
	
	-- Process replies. This accepts Read request replies from the Nvme storing any errors.
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				replyIn.ready	<= '0';
				error		<= (others => '0');
				numBlocksDone	<= (others => '0');
				replyState 	<= REPSTATE_IDLE;
			else
				case(replyState) is
				when REPSTATE_IDLE =>
					if(enabled = '1') then
						replyState <= REPSTATE_INIT;
					end if;
				
				when REPSTATE_INIT =>
					-- Initialise for next run
					replyIn.ready	<= '1';
					error		<= (others => '0');
					numBlocksDone	<= (others => '0');
					replyState 	<= REPSTATE_QUEUE_REPLY1;
					
				when REPSTATE_COMPLETE =>
					if(enabled = '0') then
						replyIn.ready	<= '0';
						replyState	<= REPSTATE_IDLE;
					end if;
				
				when REPSTATE_QUEUE_REPLY1 =>
					if(enabled = '0') then
						if(replyIn.valid = '0') then
							replyIn.ready	<= '0';
						end if;
						replyState <= REPSTATE_COMPLETE;
					else
						if(numBlocksDone >= dataSize) then
							replyState <= REPSTATE_COMPLETE;
					
						elsif(replyIn.valid = '1' and replyIn.ready = '1') then
							replyState <= REPSTATE_QUEUE_REPLY2;
						end if;
					end if;

				when REPSTATE_QUEUE_REPLY2 =>
					if(enabled = '0') then
						replyIn.ready	<= '0';
						replyState	<= REPSTATE_COMPLETE;

					elsif(replyIn.valid = '1' and replyIn.ready = '1') then
						if(error = 0) then
							error(15 downto 0) <= '0' & nvmeReplyHead.status;
						end if;

						numBlocksDone	<= numBlocksDone + 1;
						replyState	<= REPSTATE_QUEUE_REPLY1;
					end if;
				
				end case;
			end if;
		end if;
	end process;
end;
