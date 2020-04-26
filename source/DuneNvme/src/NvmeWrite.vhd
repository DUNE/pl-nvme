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
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	dataAvailable	: in std_logic;				--! At least 1 x 8k chunk of data is available to write
	dataRx		: inout AxisStreamType := AxisInput;	--! Raw data to save stream

	-- From host to NVMe request/reply streams
	nvmeSend	: inout AxisStreamType := AxisOutput;	--! Nvme request stream
	nvmeRecv	: inout AxisStreamType := AxisInput		--! Nvme reply stream
);
end;

architecture Behavioral of NvmeWrite is

--! Set the fields in the PCIe TLP header
function setHeader(request: integer; address: integer; count: integer; tag: integer) return std_logic_vector is
begin
	return set_PcieRequestHeadType(request, address, count, tag);
end function;

constant TCQ		: time := 1 ns;

type StateType		is (STATE_IDLE, STATE_NEXT_ITEM, STATE_NEXT_DATA, STATE_ITEM_COMPLETE);
signal state		: StateType := STATE_IDLE;

begin
	-- Process register access
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				nvmeSend.valid 		<= '0';
				nvmeSend.last 		<= '0';
				nvmeSend.keep 		<= (others => '1');
				state			<= STATE_IDLE;
			else
				case(state) is
				when STATE_IDLE =>
					if(dataAvailable = '1') then
						state	<= STATE_NEXT_ITEM;
					end if;

				when STATE_NEXT_ITEM =>
					state	<= STATE_NEXT_DATA;
					

				when STATE_NEXT_DATA =>
					if(nvmeSend.valid = '1' and nvmeSend.ready = '1') then
						nvmeSend.data	<= (others => '0');
						state		<= STATE_ITEM_COMPLETE;
					end if;

				when STATE_ITEM_COMPLETE =>
					nvmeSend.valid 	<= '0';
					nvmeSend.last 	<= '0';
					state		<= STATE_IDLE;

				end case;
			end if;
		end if;
	end process;
end;
