--------------------------------------------------------------------------------
-- PcieStreamMux.vhd Multiplex/De-multiplex a streams into two using header
-------------------------------------------------------------------------------
--!
--! @class	PcieStreamMux
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-08
--! @version	0.0.1
--!
--! @brief
--! This module Multiplexes/De-multiplexes a PCIe 128 bit stream into two streams using the 128bit header
--!
--! @details
--! This uses bit 95 in the Pcie header to determine if packets are Pcie requests or replies and then
--! routes the packets appropriately. It is used to handle the quad stream nature of the Xilinx Pcie Gen3 hardblock.
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

entity PcieStreamMux is
generic (
	RegisterOutputs	: boolean := True			--! Register the outputs
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	stream1In	: inout AxisStreamType := AxisStreamInput;	--! Single multiplexed Input stream
	stream1Out	: inout AxisStreamType := AxisStreamOutput;	--! Single multiplexed Ouput stream

	stream2In	: inout AxisStreamType := AxisStreamInput;	--! Host Replies input stream
	stream2Out	: inout AxisStreamType := AxisStreamOutput;	--! Host Requests output stream

	stream3In	: inout AxisStreamType := AxisStreamInput;	--! Nvme Requests input stream
	stream3Out	: inout AxisStreamType := AxisStreamOutput	--! Nvme replies output stream
);
end;

architecture Behavioral of PcieStreamMux is

constant TCQ		: time := 1 ns;

type DemuxStateType	is (DEMUX_STATE_START, DEMUX_STATE_SENDPACKET2, DEMUX_STATE_SENDPACKET3);
signal demuxState	: DemuxStateType := DEMUX_STATE_START;
signal demuxReply	: std_logic;
signal demuxReg		: AxisStreamType;

type MuxStateType	is (MUX_STATE_START, MUX_STATE_SENDPACKET2, MUX_STATE_SENDPACKET3);
signal muxState		: MuxStateType := MUX_STATE_START;
signal muxReply		: std_logic;
signal muxStream2	: std_logic;
signal muxStream2Data	: std_logic_vector(127 downto 0);
signal muxReg		: AxisStreamType;

begin
	noreg: if(not RegisterOutputs) generate
	-- De-multiplex host -> nvme streams. Expects 128 bit header word providing destination stream number
	demuxReply <= stream1In.data(95);

	stream1In.ready <= stream3Out.ready when((demuxState = DEMUX_STATE_START) and (stream1In.valid = '1') and (demuxReply = '1'))
		else stream2Out.ready when((demuxState = DEMUX_STATE_START) and (stream1In.valid = '1') and (demuxReply = '0'))
		else stream2Out.ready when(demuxState = DEMUX_STATE_SENDPACKET2)
		else stream3Out.ready when(demuxState = DEMUX_STATE_SENDPACKET3)
		else stream2Out.ready and stream3Out.ready;
		
	stream2Out.valid <= stream1In.valid when((demuxState = DEMUX_STATE_SENDPACKET2) or ((demuxState = DEMUX_STATE_START) and (demuxReply = '0'))) else '0';
	stream2Out.last <= stream1In.last;
	stream2Out.keep <= stream1In.keep;
	stream2Out.data <= stream1In.data;
	
	stream3Out.valid <= stream1In.valid when((demuxState = DEMUX_STATE_SENDPACKET3) or ((demuxState = DEMUX_STATE_START) and (demuxReply = '1'))) else '0';
	stream3Out.last <= stream1In.last;
	stream3Out.keep <= stream1In.keep;
	stream3Out.data <= stream1In.data;

	-- De-multiplexor
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				demuxState <= DEMUX_STATE_START;
			else
				case(demuxState) is
				when DEMUX_STATE_START =>
					if((stream1In.valid = '1') and (stream1In.ready = '1')) then
						if(stream1In.last = '1') then
							demuxState <= DEMUX_STATE_START;
						elsif(demuxReply = '1') then
							demuxState <= DEMUX_STATE_SENDPACKET3;
						else
							demuxState <= DEMUX_STATE_SENDPACKET2;
						end if;
					end if;

				when DEMUX_STATE_SENDPACKET2 =>
					if((stream1In.valid = '1') and (stream1In.ready = '1') and (stream1In.last = '1')) then
						demuxState <= DEMUX_STATE_START;
					end if;

				when DEMUX_STATE_SENDPACKET3 =>
					if((stream1In.valid = '1') and (stream1In.ready = '1') and (stream1In.last = '1')) then
						demuxState <= DEMUX_STATE_START;
					end if;
				end case;
			end if;
		end if;
	end process;
	
	
	-- Multiplex streams.
	muxStream2 <= '1' when(((muxState = MUX_STATE_START) and (stream2In.valid = '1')) or (muxState = MUX_STATE_SENDPACKET2)) else '0';
	muxStream2Data <= stream2In.data(127 downto 96) & '1' & stream2In.data(94 downto 0) when(muxState = MUX_STATE_START) else stream2In.data;
	
	stream1Out.valid <= stream2In.valid when(muxStream2 = '1') else stream3In.valid;
	stream1Out.last <= stream2In.last when(muxStream2 = '1') else stream3In.last;
	stream1Out.keep <= stream2In.keep when(muxStream2 = '1') else stream3In.keep;
	stream1Out.data <= muxStream2Data when(muxStream2 = '1')  else stream3In.data;

	stream2In.ready <= stream1Out.ready when(muxStream2 = '1') else '0';
	stream3In.ready <= stream1Out.ready when(muxStream2 = '0') else '0';

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				muxState <= MUX_STATE_START;
			else
				case(muxState) is
				when MUX_STATE_START =>
					if((stream2In.valid = '1') and (stream2In.ready = '1')) then
						if(stream2In.last = '1') then
							muxState <= MUX_STATE_START;
						else
							muxState <= MUX_STATE_SENDPACKET2;
						end if;
					elsif((stream3In.valid = '1') and (stream3In.ready = '1')) then
						if(stream3In.last = '1') then
							muxState <= MUX_STATE_START;
						else
							muxState <= MUX_STATE_SENDPACKET3;
						end if;
					end if;

				when MUX_STATE_SENDPACKET2 =>
					if((stream2In.valid = '1') and (stream2In.ready = '1') and (stream2In.last = '1')) then
						muxState <= MUX_STATE_START;
					end if;

				when MUX_STATE_SENDPACKET3 =>
					if((stream3In.valid = '1') and (stream3In.ready = '1') and (stream3In.last = '1')) then
						muxState <= MUX_STATE_START;
					end if;

				end case;
			end if;
		end if;
	end process;
	end generate;


	reg: if(RegisterOutputs) generate
	-- De-multiplex host -> nvme streams. Expects 128 bit header word providing destination stream number
	demuxReply	<= stream1In.data(95);
	stream1In.ready	<= not demuxReg.valid;

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				demuxState <= DEMUX_STATE_START;
				stream2Out.valid <= '0';
				stream2Out.last <= '0';
				stream3Out.valid <= '0';
				stream3Out.last <= '0';
				demuxReg.valid <= '1';
			else
				case(demuxState) is
				when DEMUX_STATE_START =>
					demuxReg.valid <= '0';

					if((stream1In.valid = '1') and (stream1In.ready = '1')) then
						if(demuxReply = '1') then
							stream3Out.valid <= '1';
							stream3Out.last <= stream1In.last;
							stream3Out.keep <= stream1In.keep;
							stream3Out.data <= stream1In.data;
							demuxState <= DEMUX_STATE_SENDPACKET3;
						else
							stream2Out.valid <= '1';
							stream2Out.last <= stream1In.last;
							stream2Out.keep <= stream1In.keep;
							stream2Out.data <= stream1In.data;
							demuxState <= DEMUX_STATE_SENDPACKET2;
						end if;
					end if;

				when DEMUX_STATE_SENDPACKET2 =>
					if((stream1In.valid = '1') and (stream1In.ready = '1') and (stream2Out.valid = '1') and (stream2Out.ready = '0')) then
						demuxReg.valid	<= '1';
						demuxReg.last	<= stream1In.last;
						demuxReg.keep	<= stream1In.keep;
						demuxReg.data	<= stream1In.data;
					elsif(stream2Out.ready = '1') then
						demuxReg.valid <= '0';
					end if;

					if((stream2Out.valid = '0') or (stream2Out.ready = '1')) then
						stream2Out.valid <= stream1In.valid or demuxReg.valid;
						if(demuxReg.valid = '1') then
							stream2Out.last <= demuxReg.last;
							stream2Out.keep <= demuxReg.keep;
							stream2Out.data <= demuxReg.data;
						else
							stream2Out.last <= stream1In.last;
							stream2Out.keep <= stream1In.keep;
							stream2Out.data <= stream1In.data;
						end if;
					end if;
					
					if((stream2Out.valid = '1') and (stream2Out.ready = '1') and (stream2Out.last = '1')) then
						demuxReg.valid	<= '0';
						stream2Out.last	<= '0';
						stream2Out.valid<= '0';
						demuxState	<= DEMUX_STATE_START;
					end if;

				when DEMUX_STATE_SENDPACKET3 =>
					if((stream1In.valid = '1') and (stream1In.ready = '1') and (stream3Out.valid = '1') and (stream3Out.ready = '0')) then
						demuxReg.valid	<= '1';
						demuxReg.last	<= stream1In.last;
						demuxReg.keep	<= stream1In.keep;
						demuxReg.data	<= stream1In.data;
					elsif(stream3Out.ready = '1') then
						demuxReg.valid <= '0';
					end if;

					if((stream3Out.valid = '0') or (stream3Out.ready = '1')) then
						stream3Out.valid <= stream1In.valid or demuxReg.valid;
						if(demuxReg.valid = '1') then
							stream3Out.last <= demuxReg.last;
							stream3Out.keep <= demuxReg.keep;
							stream3Out.data <= demuxReg.data;
						else
							stream3Out.last <= stream1In.last;
							stream3Out.keep <= stream1In.keep;
							stream3Out.data <= stream1In.data;
						end if;
					end if;
					
					if((stream3Out.valid = '1') and (stream3Out.ready = '1') and (stream3Out.last = '1')) then
						demuxReg.valid	<= '0';
						stream3Out.last	<= '0';
						stream3Out.valid<= '0';
						demuxState	<= DEMUX_STATE_START;
					end if;

				end case;
			end if;
		end if;
	end process;
	
	
	-- Multiplex streams.
	muxStream2 <= '1' when(((muxState = MUX_STATE_START) and (stream2In.valid = '1')) or (muxState = MUX_STATE_SENDPACKET2)) else '0';
	muxStream2Data <= stream2In.data(127 downto 96) & '1' & stream2In.data(94 downto 0) when(muxState = MUX_STATE_START) else stream2In.data;

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				muxState <= MUX_STATE_START;
				stream2In.ready	<= '0';
				stream3In.ready	<= '0';
				stream1Out.valid <= '0';
				muxReg.valid	<= '1';
				
			else
				case(muxState) is
				when MUX_STATE_START =>
					stream2In.ready	<= '0';
					stream3In.ready	<= '0';
					stream1Out.valid <= '0';
					stream1Out.last <= '0';
					muxReg.valid	<= '0';

					if((stream2In.valid = '1') and (stream1In.ready = '1')) then
						muxReg.valid	<= '1';
						muxReg.last	<= stream2In.last;
						muxReg.keep	<= stream2In.keep;
						muxReg.data	<= muxStream2Data;
						stream2In.ready	<= '1';
						muxState <= MUX_STATE_SENDPACKET2;

					elsif((stream3In.valid = '1') and (stream1In.ready = '1')) then
						muxReg.valid	<= '1';
						muxReg.last	<= stream3In.last;
						muxReg.keep	<= stream3In.keep;
						muxReg.data	<= stream3In.data;
						stream3In.ready	<= '1';
						muxState <= MUX_STATE_SENDPACKET3;
					end if;

				when MUX_STATE_SENDPACKET2 =>
					if((stream2In.valid = '1') and (stream2In.ready = '1') and (stream1Out.valid = '1') and (stream1Out.ready = '0')) then
						muxReg.valid	<= '1';
						stream2In.ready	<= '0';
						muxReg.last	<= stream2In.last;
						muxReg.keep	<= stream2In.keep;
						muxReg.data	<= stream2In.data;
					elsif(stream1Out.ready = '1') then
						if((muxReg.valid = '1') and (muxReg.last = '1')) then
							stream2In.ready	<= '0';
						elsif((muxReg.valid = '0') and (stream2In.last = '1')) then
							stream2In.ready	<= '0';
						else
							stream2In.ready	<= '1';
						end if;
						muxReg.valid <= '0';
					end if;

					if((stream1Out.valid = '0') or (stream1Out.ready = '1')) then
						stream1Out.valid <= stream2In.valid or muxReg.valid;
						if(muxReg.valid = '1') then
							stream1Out.last <= muxReg.last;
							stream1Out.keep <= muxReg.keep;
							stream1Out.data <= muxReg.data;
						else
							stream1Out.last <= stream2In.last;
							stream1Out.keep <= stream2In.keep;
							stream1Out.data <= stream2In.data;
						end if;
					end if;

					if((stream2In.valid = '1') and (stream2In.ready = '1') and (stream2In.last = '1')) then
						stream2In.ready	<= '0';
					end if;
					
					if((stream1Out.valid = '1') and (stream1Out.ready = '1') and (stream1Out.last = '1')) then
						stream1Out.last <= '0';
						stream1Out.valid <= '0';
						stream2In.ready	<= '0';
						muxState <= MUX_STATE_START;
					end if;


				when MUX_STATE_SENDPACKET3 =>
					if((stream3In.valid = '1') and (stream3In.ready = '1') and (stream1Out.valid = '1') and (stream1Out.ready = '0')) then
						muxReg.valid	<= '1';
						stream3In.ready	<= '0';
						muxReg.last	<= stream3In.last;
						muxReg.keep	<= stream3In.keep;
						muxReg.data	<= stream3In.data;
					elsif(stream1Out.ready = '1') then
						if((muxReg.valid = '1') and (muxReg.last = '1')) then
							stream3In.ready	<= '0';
						elsif((muxReg.valid = '0') and (stream3In.last = '1')) then
							stream3In.ready	<= '0';
						else
							stream3In.ready	<= '1';
						end if;
						muxReg.valid <= '0';
					end if;

					if((stream1Out.valid = '0') or (stream1Out.ready = '1')) then
						stream1Out.valid <= stream3In.valid or muxReg.valid;
						if(muxReg.valid = '1') then
							stream1Out.last <= muxReg.last;
							stream1Out.keep <= muxReg.keep;
							stream1Out.data <= muxReg.data;
						else
							stream1Out.last <= stream3In.last;
							stream1Out.keep <= stream3In.keep;
							stream1Out.data <= stream3In.data;
						end if;
					end if;

					if((stream3In.valid = '1') and (stream3In.ready = '1') and (stream3In.last = '1')) then
						stream3In.ready	<= '0';
					end if;

					if((stream1Out.valid = '1') and (stream1Out.ready = '1') and (stream1Out.last = '1')) then
						stream1Out.last <= '0';
						stream1Out.valid <= '0';
						stream3In.ready	<= '0';
						muxState <= MUX_STATE_START;
					end if;

				end case;
			end if;
		end if;
	end process;
	end generate;
end;
