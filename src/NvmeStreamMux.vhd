--------------------------------------------------------------------------------
-- NvmeStreamMux.vhd Multiplex/De-multiplex a streams into two based on unit number header
-------------------------------------------------------------------------------
--!
--! @class	NvmeStreamMux
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-08
--! @version	1.0.0
--!
--! @brief
--! This module Multiplexes/De-multiplexes a 128bit Axis stream into two streams based on which Nvme device the packets are for/from.
--!
--! @details
--! When de-multiplexing the packets the module uses bit 80 in request packets and bit 28 in
--! reply packets to determine which Nume device the packet should be sent too.
--! Reply packets are determined by bit 95 being set in the packets header.
--! When multplexing the packets to the host it sets the appropriate Pcie header bits to indicate to the
--! host where the packet is from.
--! It is used to pass requests from the host to the appropriate NvmeStorageUnit engine and get replies.
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

entity NvmeStreamMux is
port (
	clk		: in std_logic;					--! The interface clock line
	reset		: in std_logic;					--! The active high reset line
	
	hostIn		: inout AxisStreamType := AxisStreamInput;	--! Host multiplexed Input stream
	hostOut		: inout AxisStreamType := AxisStreamOutput;	--! Host multiplexed Ouput stream

	nvme0In		: inout AxisStreamType := AxisStreamInput;	--! Nvme0 Replies input stream
	nvme0Out	: inout AxisStreamType := AxisStreamOutput;	--! Nvme0 Requests output stream

	nvme1In		: inout AxisStreamType := AxisStreamInput;	--! Nvme1 Requests input stream
	nvme1Out	: inout AxisStreamType := AxisStreamOutput	--! Nvme1 replies output stream
);
end;

architecture Behavioral of NvmeStreamMux is

constant TCQ		: time := 1 ns;

type DemuxStateType	is (DEMUX_STATE_START, DEMUX_STATE_SENDPACKET0, DEMUX_STATE_SENDPACKET1);
signal demuxState	: DemuxStateType := DEMUX_STATE_START;
signal isReply		: std_logic;
signal nvmeNumber	: std_logic;

type MuxStateType	is (MUX_STATE_START, MUX_STATE_SENDPACKET0, MUX_STATE_SENDPACKET1);
signal muxState		: MuxStateType := MUX_STATE_START;
signal muxReply		: std_logic;
signal nvme1Stream	: std_logic;
signal nvme1StreamData	: std_logic_vector(127 downto 0);

begin
	-- De-multiplex host -> nvme streams. Expects 128 bit header word providing destination stream number
	isReply		<= hostIn.data(95);
	nvmeNumber 	<= hostIn.data(80) when(isReply = '1') else hostIn.data(28);

	hostIn.ready <= nvme1Out.ready when((demuxState = DEMUX_STATE_START) and (hostIn.valid = '1') and (nvmeNumber = '1'))
		else nvme0Out.ready when((demuxState = DEMUX_STATE_START) and (hostIn.valid = '1') and (nvmeNumber = '0'))
		else nvme0Out.ready when(demuxState = DEMUX_STATE_SENDPACKET0)
		else nvme1Out.ready when(demuxState = DEMUX_STATE_SENDPACKET1)
		else nvme0Out.ready and nvme1Out.ready;
		
	nvme0Out.valid <= hostIn.valid when((demuxState = DEMUX_STATE_SENDPACKET0) or ((demuxState = DEMUX_STATE_START) and (nvmeNumber = '0'))) else '0';
	nvme0Out.last <= hostIn.last;
	nvme0Out.keep <= hostIn.keep;
	nvme0Out.data <= hostIn.data;
	
	nvme1Out.valid <= hostIn.valid when((demuxState = DEMUX_STATE_SENDPACKET1) or ((demuxState = DEMUX_STATE_START) and (nvmeNumber = '1'))) else '0';
	nvme1Out.last <= hostIn.last;
	nvme1Out.keep <= hostIn.keep;
	
	-- Mask out Nvme number from packets header
	nvme1Out.data <= hostIn.data(127 downto 32) & x"0" & hostIn.data(27 downto 0) when((demuxState = DEMUX_STATE_START) and (isReply = '0'))
		else hostIn.data(127 downto 81) & '0' & hostIn.data(79 downto 0) when((demuxState = DEMUX_STATE_START) and (isReply = '1'))
		else hostIn.data;

	-- De-multiplexor
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				demuxState <= DEMUX_STATE_START;
			else
				case(demuxState) is
				when DEMUX_STATE_START =>
					if((hostIn.valid = '1') and (hostIn.ready = '1')) then
						if(hostIn.last = '1') then
							demuxState <= DEMUX_STATE_START;
						elsif(nvmeNumber = '1') then
							demuxState <= DEMUX_STATE_SENDPACKET1;
						else
							demuxState <= DEMUX_STATE_SENDPACKET0;
						end if;
					end if;

				when DEMUX_STATE_SENDPACKET0 =>
					if((hostIn.valid = '1') and (hostIn.ready = '1') and (hostIn.last = '1')) then
						demuxState <= DEMUX_STATE_START;
					end if;

				when DEMUX_STATE_SENDPACKET1 =>
					if((hostIn.valid = '1') and (hostIn.ready = '1') and (hostIn.last = '1')) then
						demuxState <= DEMUX_STATE_START;
					end if;
				end case;
			end if;
		end if;
	end process;
	
	
	-- Multiplex streams. Sets the Nvme number to 1 in the Nvme1 reply streams in appropriate location for request and reply packets
	nvme1Stream <= '1' when(((muxState = MUX_STATE_START) and (nvme1In.valid = '1')) or (muxState = MUX_STATE_SENDPACKET1)) else '0';

	nvme1StreamData <= nvme1In.data(127 downto 81) & '1' & nvme1In.data(79 downto 0) when((muxState = MUX_STATE_START) and (nvme1In.data(95) = '1'))
		else nvme1In.data(127 downto 32) & x"1" & nvme1In.data(27 downto 0) when((muxState = MUX_STATE_START) and (nvme1In.data(95) = '0'))
		else nvme1In.data;
	
	hostOut.valid <= nvme0In.valid when(nvme1Stream = '0') else nvme1In.valid;
	hostOut.last <= nvme0In.last when(nvme1Stream = '0') else nvme1In.last;
	hostOut.keep <= nvme0In.keep when(nvme1Stream = '0') else nvme1In.keep;
	hostOut.data <= nvme0In.data when(nvme1Stream = '0')  else nvme1StreamData;

	nvme0In.ready <= hostOut.ready when(nvme1Stream = '0') else '0';
	nvme1In.ready <= hostOut.ready when(nvme1Stream = '1') else '0';

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				muxState <= MUX_STATE_START;
			else
				case(muxState) is
				when MUX_STATE_START =>
					if((nvme0In.valid = '1') and (hostOut.ready = '1')) then
						if(nvme0In.last = '1') then
							muxState <= MUX_STATE_START;
						else
							muxState <= MUX_STATE_SENDPACKET0;
						end if;
					elsif((nvme1In.valid = '1') and (hostOut.ready = '1')) then
						if(nvme1In.last = '1') then
							muxState <= MUX_STATE_START;
						else
							muxState <= MUX_STATE_SENDPACKET1;
						end if;
					end if;

				when MUX_STATE_SENDPACKET0 =>
					if((nvme0In.valid = '1') and (nvme0In.ready = '1') and (nvme0In.last = '1')) then
						muxState <= MUX_STATE_START;
					end if;

				when MUX_STATE_SENDPACKET1 =>
					if((nvme1In.valid = '1') and (nvme1In.ready = '1') and (nvme1In.last = '1')) then
						muxState <= MUX_STATE_START;
					end if;

				end case;
			end if;
		end if;
	end process;
end;
