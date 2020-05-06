--------------------------------------------------------------------------------
--	Test018-buffer.vhd	Simple testbench scipt
--	T.Barnaby,	Beam Ltd.	2020-05-05
--------------------------------------------------------------------------------
--
--
--
library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.NvmeStoragePkg.all;
use work.NvmeStorageIntPkg.all;
use work.TestPkg.all;

entity Test is
end;

architecture sim of Test is
constant DataWidth	: integer := 128;
constant RamSize	: integer := 16;			--! For simple testing
constant AddressWidth	: integer := log2(RamSize);

constant TCQ		: time := 1 ns;

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';
signal run		: std_logic := '0';

signal writeEnable	: std_logic := '0';
signal writeAddress	: unsigned(AddressWidth-1 downto 0) := (others => '0');
signal writeData	: unsigned(DataWidth-1 downto 0) := (others => '0');

signal readEnable	: std_logic := '0';
signal readAddress	: unsigned(AddressWidth-1 downto 0) := (others => '0');
signal readData		: std_logic_vector(DataWidth-1 downto 0) := (others => '0');

component DataBuffer is
generic(
	Simulate	: boolean := True;			--! Generate simulation core
	Size		: integer := RamSize			--! The Buffer size in 128 bit words
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	writeEnable	: in std_logic;
	writeAddress	: in unsigned(AddressWidth-1 downto 0);	
	writeData	: in std_logic_vector(127 downto 0);	

	readEnable	: in std_logic;
	readAddress	: in unsigned(AddressWidth-1 downto 0);	
	readData	: out std_logic_vector(127 downto 0)	
);
end component;

begin
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
	
	stop : process
	begin
		--wait for 2000 ns;
		wait for 10000 ns;
		assert false report "simulation ended ok" severity failure;
	end process;


	dataBuffer0 : DataBuffer
	port map (
		clk		=> clk,
		reset		=> reset,

		writeEnable	=> writeEnable,
		writeAddress	=> writeAddress,
		writeData	=> std_logic_vector(writeData),

		readEnable	=> readEnable,
		readAddress	=> readAddress,
		readData	=> readData
	);

	runWrite : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				writeAddress	<= (others => '0');
				writeData	<= (others => '0');
			else
				writeEnable	<= '1';
				writeAddress	<= writeAddress + 1;
				writeData	<= writeData + 1;
			end if;
		end if;
	end process;
	
	start : process
	begin
		wait until reset = '0';
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		run <= '1';
		
		wait;
	end process;
	
	runRead : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				readAddress	<= (others => '0');
			else
				if(run = '1') then
					readEnable	<= '1';
					readAddress	<= readAddress + 1;
				end if;
			end if;
		end if;
	end process;
	
end;
