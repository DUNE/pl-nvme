--------------------------------------------------------------------------------
--	Test003-regs.vhd	Simple AXI lite interface tests
--	T.Barnaby,	Beam Ltd.	2020-02-18
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

component NvmeStorage is
generic(
	Simulate	: boolean	:= True
);
port (
	clk		: in std_logic;
	reset		: in std_logic;

	-- Control and status interface
	axilIn		: in AxilToSlave;
	axilOut		: out AxilToMaster;

	-- AXIS Interface to PCIE
	hostReq		: inout AxisStream	:= AxisInput;
	hostReply	: inout AxisStream	:= AxisOutput;                        
	
	-- From Nvme reqeuest and reply stream
	nvmeReq		: inout AxisStream	:= AxisOutput;
	nvmeReply	: inout AxisStream	:= AxisInput;                        
	
	-- AXIS data stream input
	--dataRx	: inout AxisStream	:= AxisInput;
	
	-- NVMe interface
	nvme_clk_p	: in std_logic;
	nvme_clk_n	: in std_logic;
	nvme0_exp_txp	: out std_logic_vector(0 downto 0);
	nvme0_exp_txn	: out std_logic_vector(0 downto 0);
	nvme0_exp_rxp	: in std_logic_vector(0 downto 0);
	nvme0_exp_rxn	: in std_logic_vector(0 downto 0);

	-- Debug
	leds		: out std_logic_vector(3 downto 0)
);
end component;

constant TCQ		: time := 1 ns;

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal axil		: AxilBus;
signal hostReply		: AxisStream;
signal hostReq		: AxisStream;
signal leds		: std_logic_vector(3 downto 0);

procedure busWrite(signal toSlave: out AxilToSlave; signal toMaster: in AxilToMaster; address: in integer; data: in integer) is
begin
	-- Write address
	wait until rising_edge(clk);
	toSlave.awaddr <= toAxilAddress(address) after TCQ;
	toSlave.awvalid <= '1' after TCQ;

	wait until rising_edge(clk) and (axil.toMaster.awready = '1');
	toSlave.awvalid <= '0' after TCQ;

	-- Write data
	toSlave.wvalid <= '1' after TCQ;
	toSlave.wdata <= toAxilData(data) after TCQ;

	wait until rising_edge(clk) and (axil.toMaster.wready = '1');
	toSlave.wvalid <= '0' after TCQ;
end procedure;

procedure busRead(signal toSlave: out AxilToSlave; signal toMaster: in AxilToMaster; address: in integer) is
begin
	-- Read address
	wait until rising_edge(clk);
	toSlave.araddr <= toAxilAddress(address) after TCQ;
	toSlave.arvalid <= '1' after TCQ;

	wait until rising_edge(clk) and (axil.toMaster.arready = '1');
	toSlave.arvalid <= '0' after TCQ;

	-- Read data
	wait until rising_edge(clk) and (axil.toMaster.rvalid = '1');
	toSlave.rready <= '1' after TCQ;

	wait until rising_edge(clk) and (axil.toMaster.rvalid = '1');
	toSlave.rready <= '0' after TCQ;
end procedure;

	
begin
	nvmeStorage0 : NvmeStorage
	port map (
		clk		=> clk,
		reset		=> reset,

		axilIn		=> axil.toSlave,
		axilOut		=> axil.toMaster,

		hostReply		=> hostReply,
		hostReq	=> hostReq,

		-- NVMe interface
		nvme_clk_p	=> '0',
		nvme_clk_n	=> '0',
		--nvme0_exp_txp	: out std_logic_vector(0 downto 0);
		--nvme0_exp_txn	: out std_logic_vector(0 downto 0);
		nvme0_exp_rxp	=> "0",
		nvme0_exp_rxn	=> "0",

		leds		=> leds
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

		axil.toSlave.awvalid <= '0';
		axil.toSlave.wvalid <= '0';
		axil.toSlave.arvalid <= '0';
		axil.toSlave.rready <= '0';
		
		wait until reset = '0';
		busWrite(axil.toSlave, axil.toMaster, 4, 2);
		busRead(axil.toSlave, axil.toMaster, 0);
		busRead(axil.toSlave, axil.toMaster, 4);
		wait;
	end process;

	stop : process
	begin
		wait for 500 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
end;
