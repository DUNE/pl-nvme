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

library work;
use work.NvmeStoragePkg.all;
use work.NvmeStorageIntPkg.all;
use work.TestPkg.all;

entity Test is
end;

architecture sim of Test is

component DataFifo is
generic(
	Simulate	: boolean := True;			--! Generate simulation core
	FifoSize	: integer := 16				--! The Fifo size
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	full		: out std_logic;			--! The fifo is full (Has Fifo size words)
	empty		: out std_logic;			--! The fifo is empty

	dataIn		: inout AxisStreamType := AxisInput;	--! Input data stream
	dataOut		: inout AxisStreamType := AxisOutput	--! Output data stream
);
end component;

component Fifo4k
port (
	clk : in std_logic;
	srst : in std_logic;
	din : in std_logic_vector(127 downto 0);
	wr_en : in std_logic;
	rd_en : in std_logic;
	dout : out std_logic_vector(127 downto 0);
	almost_full : out std_logic;
	full : out std_logic;
	empty : out std_logic;
	valid : out std_logic;
	wr_rst_busy : out std_logic;
	rd_rst_busy : out std_logic;
	data_count : out std_logic_vector(8 downto 0)
);
end component;

constant TCQ		: time := 1 ns;
constant CHUNK_SIZE	: integer := 32;			-- The data write chunk size in DWords due to PCIe packet size limitations

signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

-- Raw Fifo test
signal fifo_wr_en	: std_logic := '0';
signal fifo_wr_rst_busy	: std_logic := '0';
signal fifo_rd_en	: std_logic := '0';
signal fifo_full	: std_logic := '0';
signal fifo_full1	: std_logic := '0';
signal fifo_almost_full	: std_logic := '0';
signal fifo_data_count	: std_logic_vector(8 downto 0);
signal fifo_empty	: std_logic := '0';
signal fifo_valid	: std_logic := '0';
signal fifo_dataIn	: unsigned(127 downto 0) := (others => '0');
signal fifo_dataOut	: std_logic_vector(127 downto 0) := (others => '0');
signal fifo_start_read	: std_logic := '0';
signal fifo_start_write	: std_logic := '0';

-- DataFifo test
signal dataIn		: AxisStreamType;
signal dataOut		: AxisStreamType;
signal fifo1_full	: std_logic := '0';
signal fifo1_empty	: std_logic := '0';
signal fifo1_dataIn	: unsigned(127 downto 0) := (others => '0');

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

	raw: if false generate
		fifo_full1 <= '1' when(unsigned(fifo_data_count) >= 256) else '0';

		fifo0: Fifo4k
		port map (
			clk		=> clk,
			srst		=> reset,
			din		=> std_logic_vector(fifo_dataIn),
			wr_en		=> fifo_wr_en,
			rd_en		=> fifo_rd_en,
			dout		=> fifo_dataOut,
			almost_full	=> fifo_almost_full,
			full		=> fifo_full,
			empty		=> fifo_empty,
			valid		=> fifo_valid,
			wr_rst_busy	=> fifo_wr_rst_busy,
			--rd_rst_busy	=>
			data_count	=> fifo_data_count
		);

		runFifo : process(clk)
		begin
			if(rising_edge(clk)) then
				if(reset = '1') then
					fifo_wr_en		<= '0';
					--fifo_rd_en		<= '0';
					fifo_dataIn		<= (others => '0');
					fifo_start_write	<= '1';
					fifo_start_read		<= '0';
				else
					if(fifo_wr_en = '1') then
						if(fifo_full = '1') then
							fifo_wr_en	<= '0';
							fifo_start_read	<= '1';
						else
							fifo_dataIn <= fifo_dataIn + 1;
						end if;
					end if;

					if(fifo_start_write = '1') then
						if(fifo_wr_en = '0') then
							fifo_wr_en	<= '1';
						else
							--fifo_wr_en	<= '0';
						end if;
					end if;

					--if(fifo_start_read = '1') then
					--	fifo_rd_en	<= '1';
					--	fifo_start_read	<= '0';
					--end if;
				end if;
			end if;
		end process;

		runFifoRead : process
		begin
			fifo_rd_en		<= '0';
			wait until fifo_start_read = '1';
			wait until rising_edge(clk);
			wait until rising_edge(clk);

			while true loop
				fifo_rd_en	<= '1';
				wait until rising_edge(clk) and fifo_valid = '1';
				wait until rising_edge(clk) and fifo_valid = '1';
				fifo_rd_en	<= '0';
				wait until rising_edge(clk);
				wait until rising_edge(clk);
				wait until rising_edge(clk);
			end loop;
		end process;
	end generate;	

	-- DataFifo tests
	fifo1: DataFifo
	port map (
		clk		=> clk,
		reset		=> reset,

		full		=> fifo1_full,
		empty		=> fifo1_empty,
		
		dataIn		=> dataIn,
		dataOut		=> dataOut
	);

	dataIn.data <= std_logic_vector(fifo1_dataIn);

	runFifo1Write : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				dataIn.valid	<= '0';
				fifo1_dataIn	<= (others => '0');
			else
				dataIn.valid	<= '1';
				
				if((dataIn.valid = '1') and (dataIn.ready = '1')) then
					fifo1_dataIn <= fifo1_dataIn + 1;
				end if;
			end if;
		end if;
	end process;

	runFifo1Read : process
	begin
		dataOut.ready <= '0';

		wait until reset = '0';
		wait until fifo1_full = '1';
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		
		while true loop
			dataOut.ready	<= '1';
			wait until rising_edge(clk) and dataOut.valid = '1';
			wait until rising_edge(clk) and dataOut.valid = '1';
			dataOut.ready	<= '0';
			wait until rising_edge(clk);
			wait until rising_edge(clk);
			wait until rising_edge(clk);
		end loop;
	end process;
	
	stop : process
	begin
		wait for 1000 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
end;
