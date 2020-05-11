--------------------------------------------------------------------------------
--	Test002-axil.vhd	Simple AXI lite interface tests
--	T.Barnaby,	Beam Ltd.	2020-02-18
--------------------------------------------------------------------------------
--
library ieee ;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
--use ieee.std_logic_arith.all;
--use ieee.std_logic_misc.all;
--use ieee.std_logic_textio.all;
--use std.textio.all; 

library work;
use work.Axil.all;

entity Test is
end;

architecture sim of Test is

component AxilToCfg is
generic(
	Simulate	: boolean	:= False
);
port (
	clk				: in std_logic;
	reset				: in std_logic;

	axilIn				: in AxilToSlave;
	axilOut				: out AxilToMaster;
	
	cfg_mgmt_addr			: out std_logic_vector(18 downto 0);
	cfg_mgmt_write			: out std_logic;
	cfg_mgmt_write_data		: out std_logic_vector(31 downto 0);
	cfg_mgmt_byte_enable		: out std_logic_vector(3 downto 0);
	cfg_mgmt_read			: out std_logic;
	cfg_mgmt_read_data		: in std_logic_vector(31 downto 0);
	cfg_mgmt_read_write_done	: in std_logic;
	cfg_mgmt_type1_cfg_reg_access	: out std_logic
);
end component;

constant TCQ		: time := 1 ns;

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';
signal axil		: AxilInterface;

signal cfg_mgmt_addr			: std_logic_vector(18 downto 0);
signal cfg_mgmt_write			: std_logic;
signal cfg_mgmt_write_data		: std_logic_vector(31 downto 0);
signal cfg_mgmt_byte_enable		: std_logic_vector(3 downto 0);
signal cfg_mgmt_read			: std_logic;
signal cfg_mgmt_read_data		: std_logic_vector(31 downto 0);
signal cfg_mgmt_read_write_done		: std_logic;
signal cfg_mgmt_type1_cfg_reg_access	: std_logic;

function toAxilAddress(v: integer)	return std_logic_vector is
begin
	return std_logic_vector(to_unsigned(v, AxilAddressWidth));
end function;

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
	toSlave.wdata <= toAxilAddress(data) after TCQ;

	wait until rising_edge(clk) and (axil.toMaster.wready = '1');
	toSlave.wvalid <= '0' after TCQ;
		
end procedure;

	
begin
	axilToCfg0 : AxilToCfg port map (
		clk				=> clk,
		reset				=> reset,

		axilIn				=> axil.toSlave,
		axilOut				=> axil.toMaster,

		cfg_mgmt_addr			=> cfg_mgmt_addr,
		cfg_mgmt_write			=> cfg_mgmt_write,
		cfg_mgmt_write_data		=> cfg_mgmt_write_data,
		cfg_mgmt_byte_enable		=> cfg_mgmt_byte_enable,
		cfg_mgmt_read			=> cfg_mgmt_read,
		cfg_mgmt_read_data		=> cfg_mgmt_read_data,
		cfg_mgmt_read_write_done	=> cfg_mgmt_read_write_done,
		cfg_mgmt_type1_cfg_reg_access	=> cfg_mgmt_type1_cfg_reg_access
	);

	clock : process
	begin
		wait for 5 ns; clk  <= not clk;
	end process clock;

	init : process
	begin
		reset 	<= '1';
		wait for 50 ns;
		reset	<= '0';
		wait;
	end process;
	
	run : process
	begin

		axil.toSlave.awvalid <= '0';
		axil.toSlave.wvalid <= '0';
		axil.toSlave.arvalid <= '0';
		
		wait until reset = '0';
		busWrite(axil.toSlave, axil.toMaster, 1, 2);
		wait;
	end process;

	stop : process
	begin
		wait for 500 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
end;
