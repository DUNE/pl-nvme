--------------------------------------------------------------------------------
-- NvmeConfig.vhd Nvme configuration module
-------------------------------------------------------------------------------
--!
--! @class	NvmeConfig
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-06-06
--! @version	1.0.0
--!
--! @brief
--! This module configures a Nvme device for operation.
--!
--! @details
--! This has a set of PCIe requests hard coded in a ROM that are sent out on the
--! streamOut stream when the configStart signal is set high for one clock period.
--! The module ignores all replies and assumes all requests complete with no errors.
--! The configComplete signal is set high on completion.
--! The ROM's contents have a list of 128 bit words. There will be a set of a requests
--! consisting of a PCIe TLP header followed by its data words.
--! The TLP headers count field specifies how many 32 bit words of data follow the header.
--! A 128 bit entry of all 0's terminates the list of Pcie requests.
--! The module will wait 100ms before starting configuration to allow its use directly after a device reset.
--! This time allows the Nvme device to complete its internal initialisation.
--! The ClockPeriod parameter should be set to the clocks period to achieve the correct delay timing.
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

entity NvmeConfig is
generic(
	ClockPeriod	: time := 8 ns				--! Clock period for timers (250 MHz)
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	configStart	: in std_logic;				--! Start the initialisation (1 clk cycle only)
	configComplete	: out std_logic;			--! Initialisation is complete

	-- From host to NVMe request/reply streams
	streamOut	: inout AxisStreamType := AxisStreamOutput;	--! Nvme request stream
	streamIn	: inout AxisStreamType := AxisStreamInput	--! Nvme reply stream
);
end;

architecture Behavioral of NvmeConfig is

--! Set the fields in the PCIe TLP header
function setHeader(request: integer; address: integer; count: integer; tag: integer) return std_logic_vector is
begin
	return to_stl(set_PcieRequestHeadType(3, request, address, count, tag));
end function;


constant TCQ		: time := 1 ns;

type StateType		is (STATE_IDLE, STATE_DELAY, STATE_NEXT_ITEM, STATE_NEXT_DATA, STATE_ITEM_COMPLETE);
signal state		: StateType := STATE_IDLE;

--! The Configuration requests				
type RomType	is array(integer range <>) of std_logic_vector(127 downto 0);

constant rom	: RomType(0 to 34) := (
	-- Set PCIe configuration command word
	setHeader(10, 16#00004#, 1, 0),	to_stl(16#00010006#, 128),
	
	-- Stop controller
	setHeader(1, 16#0014#, 1, 0), to_stl(x"00460000", 128),

	-- Disable interrupts
	setHeader(1, 16#000C#, 1, 0), to_stl(x"FFFFFFFF", 128),

	-- Admin queue lengths to NvmeQueueNum entries each
	setHeader(1, 16#0024#, 1, 0), zeros(96) & to_stl(NvmeQueueNum-1, 16) & to_stl(NvmeQueueNum-1, 16),

	-- Admin request queue base address
	setHeader(1, 16#0028#, 1, 0), to_stl(x"02000000", 128),

	-- Admin reply queue base address
	setHeader(1, 16#0030#, 1, 0), to_stl(x"02100000", 128),

	-- Start controller
	setHeader(1, 16#0014#, 1, 0), to_stl(x"00460001", 128),
	
	-- We should wait for CSTS.RDY. For simplicity we delay for 1ms between each command

	-- Create DataWrite reply queue (16 entries)  by sending 64byte request to Admin queue
	setHeader(1, 16#02000000#, 16, 0),
		zeros(96) & x"03000005",					-- Dwords 3, 2, 1, 0
		zeros(32) & x"02110000" & zeros(64), 				-- DWords 7, 6, 5, 4
		x"00000001" & to_stl(NvmeQueueNum-1, 16) & x"0001" & zeros(64),	-- DWords 11, 10, 9, 8
		zeros(128),							-- DWords 15, 14, 13, 12

	-- Could Wait for reply in queue

	-- Create DataWrite request queue by sending 64byte request to Admin queue
	setHeader(1, 16#02000000#, 16, 0),
		zeros(96) & x"03010001",					-- Dwords 3, 2, 1, 0
		zeros(32) & x"02010000" & zeros(64), 				-- DWords 7, 6, 5, 4
		x"00010001" & to_stl(NvmeQueueNum-1, 16) & x"0001" & zeros(64),	-- DWords 11, 10, 9, 8
		zeros(128),							-- DWords 15, 14, 13, 12

	-- Could Wait for reply in queue
	
	-- Create DataRead reply queue (16 entries)  by sending 64byte request to Admin queue
	setHeader(1, 16#02000000#, 16, 0),
		zeros(96) & x"03020005",					-- Dwords 3, 2, 1, 0
		zeros(32) & x"02120000" & zeros(64), 				-- DWords 7, 6, 5, 4
		x"00000001" & to_stl(NvmeQueueNum-1, 16) & x"0002" & zeros(64),	-- DWords 11, 10, 9, 8
		zeros(128),							-- DWords 15, 14, 13, 12

	-- Could Wait for reply in queue

	-- Create DataRead request queue by sending 64byte request to Admin queue
	setHeader(1, 16#02000000#, 16, 0),
		zeros(96) & x"03030001",					-- Dwords 3, 2, 1, 0
		zeros(32) & x"02020000" & zeros(64), 				-- DWords 7, 6, 5, 4
		x"00020001" & to_stl(NvmeQueueNum-1, 16) & x"0002" & zeros(64),	-- DWords 11, 10, 9, 8
		zeros(128),							-- DWords 15, 14, 13, 12

	-- Could Wait for reply in queue

	(others => '0')
);

signal requestHead	: PcieRequestHeadType;			--! The PCIe TLP request header fields
signal tag		: unsigned(7 downto 0);
signal count		: integer range 0 to rom'length;	--! The ROM position pointer
signal numWords		: unsigned(10 downto 0);		--! The number of 32 bit data words left to transfer
signal delay		: integer;				--! Delay counter in clock periods

begin
	streamIn.ready	<= '1';					--! Ignore any replies
	requestHead	<= to_PcieRequestHeadType(rom(count));

	-- Process register access
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				streamOut.valid 	<= '0';
				streamOut.last 		<= '0';
				streamOut.keep 		<= (others => '1');
				configComplete		<= '0';
				count			<= 0;
				tag			<= (others => '0');
				state			<= STATE_IDLE;
			else
				case(state) is
				when STATE_IDLE =>
					if(configStart = '1') then
						count		<= 0;
						configComplete	<= '0';
						delay		<= 100 ms / ClockPeriod;	--! Started from reset, delay for 100ms
						state		<= STATE_DELAY;
					end if;

				when STATE_DELAY =>						--! Delay for clock cycles given in delay
					if(delay = 0) then
						state <= STATE_NEXT_ITEM;
					else
						delay <= delay - 1;
					end if;

				when STATE_NEXT_ITEM =>						--! Process next config item
					if(unsigned(rom(count)) = 0) then
						configComplete	<= '1';
						state		<= STATE_IDLE;
					else
						numWords	<= requestHead.count;
						streamOut.data	<= rom(count);
						streamOut.valid <= '1';
						streamOut.last 	<= '0';
						streamOut.keep 	<= (others => '1');
						state		<= STATE_NEXT_DATA;
					end if;
					

				when STATE_NEXT_DATA =>						--! Send items data
					if(streamOut.valid = '1' and streamOut.ready = '1') then
						streamOut.data	<= rom(count + 1);
						count		<= count + 1;

						if(numWords <= 4) then
							streamOut.last 	<= '1';
							streamOut.keep 	<= keepBits(numWords);
							state		<= STATE_ITEM_COMPLETE;
						else
							numWords	<= numWords - 4;
						end if;
					end if;

				when STATE_ITEM_COMPLETE =>					--! Item has been processed
					count		<= count + 1;
					streamOut.valid <= '0';
					streamOut.last 	<= '0';
					delay		<= 1 ms / ClockPeriod;
					state		<= STATE_DELAY;

				end case;
			end if;
		end if;
	end process;
end;
