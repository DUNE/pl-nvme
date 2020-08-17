--------------------------------------------------------------------------------
-- PcieStreamMux.vhd Multiplex/De-multiplex a streams into two using header
-------------------------------------------------------------------------------
--!
--! @class	PcieStreamMux
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-04-08
--! @version	1.0.0
--!
--! @brief
--! This module Multiplexes/De-multiplexes a PCIe 128 bit stream into two streams using the 128bit header
--!
--! @details
--! This module will multiplex two bi-directional AxisStream's into a single bi-directional stream and de-multiplex
--! a single bi-directional stream into two such streams.
--! It is used to handle the quad stream nature of the Xilinx Pcie Gen3 hardblock merging the two streams into one for
--! easy processing. The Xilinx Pcie Gen3 IP uses a pair of streams for host requests to the Pcie device (stream2) and
--! a pair of streams for Pcie device requests to the host (stream3).
--! Because of the 4 streams and their usage each will solely transport request or reply packets. This module
--! sets and uses the state of bit 95 in the Pcie request and reply headers when multiplexing/de-muliplexing packets
--! to/from the single stream (stream1).
--! When muliplexing the packets bit 95 is set in the header on any reply packets and when de-multiplexing it looks
--! at bit 95 in the header to determine which stream to send the packet on.
--! The RegisterOutputs parameter allows the output data streams to be latched for better system timing
--! at the expence of a 1 clock cycle latency.
--! the module prioritises packet replies from the Pcie device when multiplexing.
--! The multiplex and de-multiplex processes are separate and function independantly.
--!
--! @copyright 2020 Beam Ltd, Apache License, Version 2.0
--! Copyright 2020 Beam Ltd
--! Licensed under the Apache License, Version 2.0 (the "License");
--! you may not use this file except in compliance with the License.
--! You may obtain a copy of the License at
--!   http://www.apache.org/licenses/LICENSE-2.0
--! Unless required by applicable law or agreed to in writing, software
--! distributed under the License is distributed on an "AS IS" BASIS,
--! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--! See the License for the specific language governing permissions and
--! limitations under the License.
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
	RegisterOutputs	: boolean := True				--! Register the outputs
);
port (
	clk		: in std_logic;					--! The interface clock line
	reset		: in std_logic;					--! The active high reset line
	
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

component PcieStreamMuxFifo is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisStreamType := AxisStreamInput;	--! Single multiplexed Input stream
	streamOut	: inout AxisStreamType := AxisStreamOutput	--! Single multiplexed Ouput stream
);
end component;

type DemuxStateType	is (DEMUX_STATE_HEAD, DEMUX_STATE_SENDPACKET2, DEMUX_STATE_SENDPACKET3);
signal demuxState	: DemuxStateType := DEMUX_STATE_HEAD;
signal demuxReply	: std_logic;
signal stream2OutFeed	: AxisStreamType;
signal stream3OutFeed	: AxisStreamType;

type MuxStateType	is (MUX_STATE_HEAD, MUX_STATE_SENDPACKET2, MUX_STATE_SENDPACKET3);
signal muxState		: MuxStateType := MUX_STATE_HEAD;
signal muxStream2	: std_logic;
signal muxStream2Data	: std_logic_vector(127 downto 0);
signal stream1OutFeed	: AxisStreamType;


begin
	noreg: if(not RegisterOutputs) generate

	-- De-multiplex host -> nvme streams. Expects 128 bit header word providing destination stream number and bit 95 to indicate replies.
	demuxReply <= stream1In.data(95);

	stream1In.ready <= stream3Out.ready when((demuxState = DEMUX_STATE_HEAD) and (stream1In.valid = '1') and (demuxReply = '1'))
		else stream2Out.ready when((demuxState = DEMUX_STATE_HEAD) and (stream1In.valid = '1') and (demuxReply = '0'))
		else stream2Out.ready when(demuxState = DEMUX_STATE_SENDPACKET2)
		else stream3Out.ready when(demuxState = DEMUX_STATE_SENDPACKET3)
		else stream2Out.ready and stream3Out.ready;
		
	stream2Out.valid <= stream1In.valid when((demuxState = DEMUX_STATE_SENDPACKET2) or ((demuxState = DEMUX_STATE_HEAD) and (demuxReply = '0'))) else '0';
	stream2Out.last <= stream1In.last;
	stream2Out.keep <= stream1In.keep;
	stream2Out.data <= stream1In.data;
	
	stream3Out.valid <= stream1In.valid when((demuxState = DEMUX_STATE_SENDPACKET3) or ((demuxState = DEMUX_STATE_HEAD) and (demuxReply = '1'))) else '0';
	stream3Out.last <= stream1In.last;
	stream3Out.keep <= stream1In.keep;
	stream3Out.data <= stream1In.data;

	-- De-multiplexor
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				demuxState <= DEMUX_STATE_HEAD;
			else
				case(demuxState) is
				when DEMUX_STATE_HEAD =>
					if((stream1In.valid = '1') and (stream1In.ready = '1')) then
						if(stream1In.last = '1') then
							demuxState <= DEMUX_STATE_HEAD;
						elsif(demuxReply = '1') then
							demuxState <= DEMUX_STATE_SENDPACKET3;
						else
							demuxState <= DEMUX_STATE_SENDPACKET2;
						end if;
					end if;

				when DEMUX_STATE_SENDPACKET2 =>
					if((stream1In.valid = '1') and (stream1In.ready = '1') and (stream1In.last = '1')) then
						demuxState <= DEMUX_STATE_HEAD;
					end if;

				when DEMUX_STATE_SENDPACKET3 =>
					if((stream1In.valid = '1') and (stream1In.ready = '1') and (stream1In.last = '1')) then
						demuxState <= DEMUX_STATE_HEAD;
					end if;
				end case;
			end if;
		end if;
	end process;
	
	
	-- Multiplex streams, setting bit 95 to indicate replies.
	muxStream2 <= '1' when(((muxState = MUX_STATE_HEAD) and (stream2In.valid = '1')) or (muxState = MUX_STATE_SENDPACKET2)) else '0';
	muxStream2Data <= stream2In.data(127 downto 96) & '1' & stream2In.data(94 downto 0) when(muxState = MUX_STATE_HEAD) else stream2In.data;
	
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
				muxState <= MUX_STATE_HEAD;
			else
				case(muxState) is
				when MUX_STATE_HEAD =>
					if((stream2In.valid = '1') and (stream2In.ready = '1')) then
						if(stream2In.last = '1') then
							muxState <= MUX_STATE_HEAD;
						else
							muxState <= MUX_STATE_SENDPACKET2;
						end if;
					elsif((stream3In.valid = '1') and (stream3In.ready = '1')) then
						if(stream3In.last = '1') then
							muxState <= MUX_STATE_HEAD;
						else
							muxState <= MUX_STATE_SENDPACKET3;
						end if;
					end if;

				when MUX_STATE_SENDPACKET2 =>
					if((stream2In.valid = '1') and (stream2In.ready = '1') and (stream2In.last = '1')) then
						muxState <= MUX_STATE_HEAD;
					end if;

				when MUX_STATE_SENDPACKET3 =>
					if((stream3In.valid = '1') and (stream3In.ready = '1') and (stream3In.last = '1')) then
						muxState <= MUX_STATE_HEAD;
					end if;

				end case;
			end if;
		end if;
	end process;
	end generate;


	reg: if(RegisterOutputs) generate

	-- De-multiplex host -> nvme streams. Expects 128 bit header word providing destination stream number and bit 95 to indicate replies.
	demuxReply		<= stream1In.data(95);

	stream1In.ready		<= stream2OutFeed.ready and stream3OutFeed.ready;

	stream2OutFeed.valid	<= stream1In.valid when(((demuxState = DEMUX_STATE_HEAD) and (demuxReply = '0')) or (demuxState = DEMUX_STATE_SENDPACKET2)) else '0';
	stream2OutFeed.keep	<= stream1In.keep;
	stream2OutFeed.last	<= stream1In.last;
	stream2OutFeed.data	<= stream1In.data;
	
	axisFifo2 : PcieStreamMuxFifo port map (
		clk		=> clk,
		reset		=> reset,

		streamIn	=> stream2OutFeed,
		streamOut	=> stream2Out
	);

	stream3OutFeed.valid	<= stream1In.valid when(((demuxState = DEMUX_STATE_HEAD) and (demuxReply = '1')) or (demuxState = DEMUX_STATE_SENDPACKET3)) else '0';
	stream3OutFeed.keep	<= stream1In.keep;
	stream3OutFeed.last	<= stream1In.last;
	stream3OutFeed.data	<= stream1In.data;
	
	axisFifo3 : PcieStreamMuxFifo port map (
		clk		=> clk,
		reset		=> reset,

		streamIn	=> stream3OutFeed,
		streamOut	=> stream3Out
	);

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				demuxState <= DEMUX_STATE_HEAD;
			else
				case(demuxState) is
				when DEMUX_STATE_HEAD =>
					if((stream1In.valid = '1') and (stream1In.ready = '1') and (stream1In.last = '0')) then
						if(demuxReply = '1') then
							demuxState <= DEMUX_STATE_SENDPACKET3;
						else
							demuxState <= DEMUX_STATE_SENDPACKET2;
						end if;
					end if;

				when DEMUX_STATE_SENDPACKET2 =>
					if((stream1In.valid = '1') and (stream1In.ready = '1') and (stream1In.last = '1')) then
						demuxState	<= DEMUX_STATE_HEAD;
					end if;

				when DEMUX_STATE_SENDPACKET3 =>
					if((stream1In.valid = '1') and (stream1In.ready = '1') and (stream1In.last = '1')) then
						demuxState	<= DEMUX_STATE_HEAD;
					end if;

				end case;
			end if;
		end if;
	end process;
	
	
	-- Multiplex streams, setting bit 95 to indicate replies.
	muxStream2 <= '1' when(((muxState = MUX_STATE_HEAD) and (stream2In.valid = '1')) or (muxState = MUX_STATE_SENDPACKET2)) else '0';
	muxStream2Data <= stream2In.data(127 downto 96) & '1' & stream2In.data(94 downto 0) when(muxState = MUX_STATE_HEAD) else stream2In.data;

	stream2In.ready		<= stream1OutFeed.ready when(muxStream2 = '1') else '0';
	stream3In.ready		<= stream1OutFeed.ready when(muxStream2 = '0') else '0';

	stream1OutFeed.valid	<= stream2In.valid when(muxStream2 = '1') else stream3In.valid;
	stream1OutFeed.last	<= stream2In.last when(muxStream2 = '1') else stream3In.last;
	stream1OutFeed.keep	<= stream2In.keep when(muxStream2 = '1') else stream3In.keep;
	stream1OutFeed.data	<= muxStream2Data when(muxStream2 = '1') else stream3In.data;

	axisFifo1 : PcieStreamMuxFifo port map (
		clk		=> clk,
		reset		=> reset,

		streamIn	=> stream1OutFeed,
		streamOut	=> stream1Out
	);

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				muxState <= MUX_STATE_HEAD;
				
			else
				case(muxState) is
				when MUX_STATE_HEAD =>
					if((stream2In.valid = '1') and (stream2In.ready = '1') and (stream2In.last = '0')) then
						muxState <= MUX_STATE_SENDPACKET2;

					elsif((stream3In.valid = '1') and (stream3In.ready = '1') and (stream3In.last = '0')) then
						muxState <= MUX_STATE_SENDPACKET3;
					end if;

				when MUX_STATE_SENDPACKET2 =>
					if((stream2In.valid = '1') and (stream2In.ready = '1') and (stream2In.last = '1')) then
						muxState <= MUX_STATE_HEAD;
					end if;

				when MUX_STATE_SENDPACKET3 =>
					if((stream3In.valid = '1') and (stream3In.ready = '1') and (stream3In.last = '1')) then
						muxState <= MUX_STATE_HEAD;
					end if;

				end case;
			end if;
		end if;
	end process;
	end generate;
end;


--------------------------------------------------------------------------------
-- PcieStreamMuxFifo.vhd Simple 1/2 stage Fifo
-------------------------------------------------------------------------------
--!
--! @class	PcieStreamMuxFifo
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-05-31
--! @version	1.0.0
--!
--! @brief
--! This module implements a simple 1/2 stage Fifo for the PcieStreamMux module
--!
--! @details
--! This is a simple 1/2 register FIFO of AxisStream's.
--!
--! @copyright 2020 Beam Ltd, Apache License, Version 2.0
--! Copyright 2020 Beam Ltd
--! Licensed under the Apache License, Version 2.0 (the "License");
--! you may not use this file except in compliance with the License.
--! You may obtain a copy of the License at
--!   http://www.apache.org/licenses/LICENSE-2.0
--! Unless required by applicable law or agreed to in writing, software
--! distributed under the License is distributed on an "AS IS" BASIS,
--! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--! See the License for the specific language governing permissions and
--! limitations under the License.
--!
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.NvmeStoragePkg.all;
use work.NvmeStorageIntPkg.all;

entity PcieStreamMuxFifo is
port (
	clk		: in std_logic;					--! The interface clock line
	reset		: in std_logic;					--! The active high reset line
	
	streamIn	: inout AxisStreamType := AxisStreamInput;	--! Single multiplexed Input stream
	streamOut	: inout AxisStreamType := AxisStreamOutput	--! Single multiplexed Ouput stream
);
end;

architecture Behavioral of PcieStreamMuxFifo is

constant TCQ		: time := 1 ns;
signal reg0		: AxisStreamType;

begin
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				streamIn.ready	<= '1';
				streamOut.valid <= '0';
				reg0.valid	<= '0';
				
			else
				if((streamIn.valid = '1') and (streamIn.ready = '1') and (streamOut.valid = '1') and (streamOut.ready = '0')) then
					streamIn.ready	<= '0';
					reg0.valid	<= '1';
					reg0.last	<= streamIn.last;
					reg0.keep	<= streamIn.keep;
					reg0.data	<= streamIn.data;
				elsif(streamOut.ready = '1') then
					streamIn.ready	<= '1';
					reg0.valid	<= '0';
				end if;

				if((streamOut.valid = '0') or (streamOut.ready = '1')) then
					streamOut.valid <= streamIn.valid or reg0.valid;
					if(reg0.valid = '1') then
						streamOut.last <= reg0.last;
						streamOut.keep <= reg0.keep;
						streamOut.data <= reg0.data;
					else
						streamOut.last <= streamIn.last;
						streamOut.keep <= streamIn.keep;
						streamOut.data <= streamIn.data;
					end if;
				end if;
			end if;
		end if;
	end process;
end;
