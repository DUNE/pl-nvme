--------------------------------------------------------------------------------
--	Test004-nvme.vhd	Simple AXI lite interface tests
--	T.Barnaby,	Beam Ltd.	2020-03-13
--------------------------------------------------------------------------------
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
use work.Axi.all;

entity Test is
end;

architecture sim of Test is

component NvmeSim is
generic(
	Simulate	: boolean	:= True
);
port (
	clk		: in std_logic;
	reset		: in std_logic;

	-- AXIS Interface to PCIE
	hostReq		: inout AxisStream	:= AxisStreamInput;
	hostReply	: inout AxisStream	:= AxisStreamOutput;                        
	
	-- From Nvme reqeuest and reply stream
	nvmeReq		: inout AxisStream	:= AxisStreamOutput;
	nvmeReply	: inout AxisStream	:= AxisStreamInput
);
end component;

constant TCQ		: time := 1 ns;

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal hostReply	: AxisStream	:= AxisStreamInput;
signal hostReq		: AxisStream	:= AxisStreamOutput;
signal nvmeReq		: AxisStream	:= AxisStreamOutput;
signal nvmeReply	: AxisStream	:= AxisStreamInput;

function toStdLogicVector(v: integer; b: integer) return std_logic_vector is
begin
	return std_logic_vector(to_unsigned(v, b));
end function;

procedure streamWrite(signal toSlave: inout AxisStream; address: in integer; tag: in integer; data: in integer) is
variable packet	: NvmePacket;
begin
	packet.reply := '0';
	packet.nvme := toStdLogicVector(0, packet.nvme'length);
	packet.stream := toStdLogicVector(0, packet.stream'length);
	packet.address := toStdLogicVector(address, packet.address'length);
	packet.tag := toStdLogicVector(tag, packet.tag'length);
	packet.request := toStdLogicVector(1, packet.request'length);
	packet.spare0 := toStdLogicVector(0, packet.spare0'length);
	packet.count := toStdLogicVector(1, packet.count'length);
	packet.data0 := toStdLogicVector(data, packet.data0'length);
	packet.data1 := toStdLogicVector(0, packet.data1'length);
	
	-- Write address
	wait until rising_edge(clk);
	toSlave.data <= toStdLogicVector(packet);
	--toSlave.data <= x"000000" & toStdLogicVector(tag, 8) & x"00000000" & toStdLogicVector(address, 64) after TCQ;
	toSlave.valid <= '1' after TCQ;

	wait until rising_edge(clk) and (toSlave.ready = '1');
	toSlave.data <= x"00000000" & x"00000000" & x"00000000" & toStdLogicVector(data, 32) after TCQ;
	
	wait until rising_edge(clk) and (toSlave.ready = '1');
	toSlave.valid <= '0' after TCQ;
end procedure;

begin
	nvmeSim0 : NvmeSim
	port map (
		clk		=> clk,
		reset		=> reset,

		hostReply	=> hostReply,
		hostReq		=> hostReq,

		nvmeReq		=> nvmeReq,
		nvmeReply	=>nvmeReply
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
		streamWrite(hostReq, 4, 1, 6);
		streamWrite(hostReq, 4, 2, 6);
		wait;
	end process;

	stop : process
	begin
		wait for 500 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
end;
