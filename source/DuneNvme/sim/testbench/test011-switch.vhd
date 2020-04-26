--------------------------------------------------------------------------------
--	Test009-packets.vhd	Simple nvme interface tests
--	T.Barnaby,	Beam Ltd.	2020-04-14
--------------------------------------------------------------------------------
--
--
--
library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
--use ieee.std_logic_misc.all;
--use ieee.std_logic_textio.all;
--use std.textio.all; 

library work;
use work.AxiPkg.all;
use work.NvmeStoragePkg.all;

entity Test is
end;

architecture sim of Test is

constant TCQ		: time := 1 ns;
constant CHUNK_SIZE	: integer := 32;			-- The data write chunk size in DWords due to PCIe packet size limitations
constant NumStreams	: integer := 4;

component StreamSwitch is
generic(
	NumStreams	: integer	:= NumStreams		--! The number of stream
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisArrayType(0 to NumStreams-1) := (others => AxisInput);	--! Input stream
	streamOut	: inout AxisArrayType(0 to NumStreams-1) := (others => AxisOutput)	--! Output stream
);
end component;

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal streamSend	: AxisArrayType(0 to NumStreams-1)	:= (others => AxisOutput);
signal streamRecv	: AxisArrayType(0 to NumStreams-1)	:= (others => AxisInput);

procedure pcieWriteRequest(signal stream: inout AxisStream; request: in integer; streamNum: in integer; address: in integer; tag: in integer; count: in integer; data: in integer) is
variable packetHead	: PcieRequestHead;
variable c		: integer;
variable d		: integer;
begin
	packetHead.nvme := to_unsigned(0, packetHead.nvme'length);
	packetHead.stream := to_unsigned(streamNum, packetHead.stream'length);
	packetHead.address := to_unsigned(address, packetHead.address'length);
	packetHead.tag := to_unsigned(tag, packetHead.tag'length);
	packetHead.count := to_unsigned(count, packetHead.count'length);
	packetHead.request := to_unsigned(request, packetHead.request'length);
	packetHead.requesterId := to_unsigned(0, packetHead.requesterId'length);
	c := count / 4;
	d := data;
	
	-- Write address
	wait until rising_edge(clk);
	stream.data <= to_stl(packetHead);
	stream.keep <= concat('1', 16);
	stream.valid <= '1';

	while(c > 0) loop
		wait until rising_edge(clk) and (stream.ready = '1');
		stream.data <= to_stl(0, 96) & to_stl(d, 32);
		stream.valid <= '1';
		d := d + 1;
		c := c - 1;
	end loop;
	stream.last <= '1';
	
	wait until rising_edge(clk) and (stream.ready = '1');
	stream.valid <= '0';
	stream.last <= '0';
end procedure;

procedure pcieReadRequest(signal stream: inout AxisStream; request: in integer; streamNum: in integer; address: in integer; tag: in integer; count: in integer) is
variable packetHead	: PcieRequestHead;
variable c		: integer;
variable d		: integer;
begin
	packetHead.nvme := to_unsigned(0, packetHead.nvme'length);
	packetHead.stream := to_unsigned(streamNum, packetHead.stream'length);
	packetHead.address := to_unsigned(address, packetHead.address'length);
	packetHead.tag := to_unsigned(tag, packetHead.tag'length);
	packetHead.count := to_unsigned(count, packetHead.count'length);
	packetHead.request := to_unsigned(request, packetHead.request'length);
	packetHead.requesterId := to_unsigned(0, packetHead.requesterId'length);

	-- Write address
	wait until rising_edge(clk);
	stream.data <= to_stl(packetHead);
	stream.keep <= concat('1', 16);
	stream.valid <= '1';
	stream.last <= '1';
	
	wait until rising_edge(clk) and (stream.ready = '1');
	stream.valid <= '0';
	stream.last <= '0';
end procedure;

procedure pcieReply(signal stream: inout AxisStream; status: in integer; requesterId: in integer; address: in integer; tag: in integer; count: in integer; data: in integer) is
variable packetHead	: PcieReplyHead;
variable c		: integer;
variable d		: integer;
begin
	packetHead.byteCount := to_unsigned(0, packetHead.byteCount'length);
	packetHead.error := to_unsigned(0, packetHead.error'length);
	packetHead.address := to_unsigned(address, packetHead.address'length);
	packetHead.tag := to_unsigned(tag, packetHead.tag'length);
	packetHead.count := to_unsigned(count, packetHead.count'length);
	packetHead.status := to_unsigned(status, packetHead.status'length);
	packetHead.requesterId := to_unsigned(requesterId, packetHead.requesterId'length);
	c := count / 4;
	d := data;
	
	-- Write address
	wait until rising_edge(clk);
	stream.data <= to_stl(d, 32) &to_stl(packetHead);
	stream.keep <= concat('1', 16);
	stream.valid <= '1';
	d := d + 1;

	while(c > 0) loop
		wait until rising_edge(clk) and (stream.ready = '1');
		stream.data <= to_stl(0, 96) & to_stl(d, 32);
		stream.valid <= '1';
		d := d + 1;
		c := c - 1;
	end loop;
	stream.last <= '1';
	stream.keep <= concat('0', 4) & concat('1', 12);		-- Hard coded for multiple of 4 data words
	
	wait until rising_edge(clk) and (stream.ready = '1');
	stream.valid <= '0';
	stream.last <= '0';
end procedure;

begin
	set: for i in 1 to NumStreams-1 generate
		streamSend(i).valid	<= '0';
		streamRecv(i).ready	<= '1';
	end generate;
	streamRecv(0).ready	<= '1';
	
	streamSwitch0 : StreamSwitch
	port map (
		clk		=> clk,
		reset		=> reset,

		streamIn	=> streamSend,
		streamOut	=> streamRecv
	);

	clock : process
	begin
		wait for 5 ns; clk  <= not clk;
	end process clock;

	init : process
	begin
		reset 	<= '1';
		wait for 20 ns;
		reset	<= '0';
		wait;
	end process;
	
	run : process
	begin
		wait until reset = '0';
		
		-- Write queue entry
		pcieWriteRequest(streamSend(0), 1, 1, 16#00000000#, 16#44#, 16, 16#00100000#);
		pcieWriteRequest(streamSend(0), 1, 2, 16#00000000#, 16#44#, 16, 16#00200000#);
		pcieWriteRequest(streamSend(0), 1, 3, 16#00000000#, 16#44#, 16, 16#00300000#);

		pcieReply(streamSend(0), 0, 2, 16#00000000#, 16#44#, 16, 16#00300000#);

		wait;
	end process;
	
	stop : process
	begin
		wait for 700 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
end;
