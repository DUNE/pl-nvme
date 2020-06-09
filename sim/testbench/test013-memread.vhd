--------------------------------------------------------------------------------
--	Test013-memread.vhd	Test of NvmeWrite's memory read functionality
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

constant TCQ		: time := 2 ns;

component Fifo is
generic (
	Simulate	: boolean := True;			--! Simulation
	DataWidth	: integer := 128;			--! The data width of the Fifo in bits
	Size		: integer := 8;				--! The size of the fifo
	NearFullLevel	: integer := 6				--! Nearly full level, 0 disables
);
port (
	clk		: in std_logic;					--! The interface clock line
	reset		: in std_logic;					--! The active high reset line
	
	nearFull	: out std_logic;				--! Fifo is nearly full

	inReady		: out std_logic;				--! Fifo is ready for input
	inValid		: in std_logic;					--! Data input is valid
	inData		: in std_logic_vector(DataWidth-1 downto 0);	--! The input data


	outReady	: in std_logic;					--! The external logic is ready for output
	outValid	: out std_logic;				--! The data output is available
	outData		: out std_logic_vector(DataWidth-1 downto 0)	--! The output data
);
end component;


signal clk		: std_logic := '0';
signal reset		: std_logic := '0';

signal memReqIn		: AxisStreamType := AxisStreamOutput;
signal memReplyOut	: AxisStreamType := AxisStreamOutput;

-- RAM simulation
constant AddressWidth	: integer := 16;
constant DataWidth	: integer := 128;

signal readEnable	: std_logic := '1';
signal readAddress	: unsigned(AddressWidth-1 downto 0) := (others => 'U');
signal readValid	: std_logic;
signal readData		: std_logic_vector(127 downto 0) := (others => 'U');

-- Produce the next DataWidth item
function dataValue(v: unsigned) return std_logic_vector is
variable ret: std_logic_vector(DataWidth-1 downto 0);
begin
	for i in 0 to (DataWidth/32)-1 loop
		ret((i*32)+31 downto (i*32)) := to_stl(truncate(v * 4 + i, 32));
	end loop;
	
	return ret;
end;

-- Buffer read
type MemStateType	is (MEMSTATE_IDLE, MEMSTATE_READSTART, MEMSTATE_READHEAD, MEMSTATE_READDATA);
signal memState		: MemStateType := MEMSTATE_IDLE;
signal memRequestHead	: PcieRequestHeadType;
signal memRequestHead1	: PcieRequestHeadType;
signal memReplyHead	: PcieReplyHeadType;
signal nvmeReplyHead	: NvmeReplyHeadType;
signal memCount		: unsigned(10 downto 0);		-- DWord data send count
signal memChunkCount	: unsigned(10 downto 0);		-- DWord data send within a chunk count

signal readValid0	: std_logic;
signal readValid1	: std_logic;

signal fifoReset	: std_logic;
signal fifoNearFull	: std_logic;
signal fifoInReady	: std_logic;
signal fifoInValid	: std_logic;
signal fifoOutValid	: std_logic;
signal fifoOutReady	: std_logic;
signal fifoData0	: std_logic_vector(127 downto 0);
signal fifoData1	: std_logic_vector(127 downto 0);

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
		wait for 4000 ns;
		assert false report "simulation ended ok" severity failure;
	end process;
	
	run : process
	begin
		wait until reset = '0';
		wait for 100 ns;

		-- Read PCIe data
		pcieRequestRead(clk, memReqIn, 5, 0, 0, 16#55#, 512/4);

		wait;
	end process;
	
	-- Provide RAM delays
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				readData	<= (others => 'U');
			else
				readData <= dataValue(zeros(16) & readAddress) after TCQ;
			end if;
		end if;
	end process;
	
	-- Ready processing
	process
	begin
		memReplyOut.ready <= '0';
		wait until reset = '0';

		memReplyOut.ready <= '1';
		wait;

		wait until rising_edge(clk) and memReplyOut.valid = '1';
		wait until rising_edge(clk);
		memReplyOut.ready <= '1';
		
		wait;
		
		wait for 400 ns;
		wait until rising_edge(clk);
		memReplyOut.ready <= '0';
		
		wait for 200 ns;
		wait until rising_edge(clk);
		memReplyOut.ready <= '1';

		wait;
		
		while(true) loop
			wait until rising_edge(clk);
			memReplyOut.ready <= not memReplyOut.ready;
		end loop;
		
		wait;
	end process;



	-- Process Nvme read data requests
	-- This processes the Nvme Pcie memory read requests for the data buffers memory.
	memRequestHead	<= to_PcieRequestHeadType(memReqIn.data);
	memReplyOut.data <=
		fifoData0(31 downto 0) & to_stl(memReplyHead) when(memState = MEMSTATE_READHEAD)
		else fifoData0(31 downto 0) & fifoData1(127 downto 32);

	fifoReset <= not readEnable;
	fifoOutReady <= memReplyOut.ready and not memReplyOut.last;
	memReplyOut.valid <= fifoOutValid;

	fifo0 : Fifo
	port map (
		clk		=> clk,
		reset		=> fifoReset,

		nearFull	=> fifoNearFull,
		inReady		=> fifoInReady,
		inValid		=> readValid1,
		indata		=> readData,

		outReady	=> fifoOutReady,
		outValid	=> fifoOutValid,
		outdata		=> fifoData0
	);
	
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				memReqIn.ready		<= '0';
				readEnable		<= '0';
				readValid0		<= '0';
				readValid1		<= '0';
				memState		<= MEMSTATE_IDLE;
			else
				-- Fill fifo from buffer RAM. There are two cycles latency when reading from the RAM
				if(readEnable = '1') then
					readValid1 <= readValid0;

					if(fifoNearFull = '1') then
						readValid0 <= '0';
					else
						readAddress <= readAddress + 1;
						readValid0 <= '1';
					end if;

					-- Output from Fifo
					if((fifoOutValid = '1') and (fifoOutReady = '1')) then
						fifoData1 <= fifoData0;
					end if;
				end if;
			
			
				case(memState) is
				when MEMSTATE_IDLE =>
					if((memReqIn.ready = '1') and (memReqIn.valid = '1')) then
						memRequestHead1	<= memRequestHead;
						memCount	<= memRequestHead.count;

						if(memRequestHead.request = 0) then
							readAddress	<= memRequestHead.address(AddressWidth+3 downto 4);
							readEnable	<= '1';
							readValid0	<= '1';
							readValid1	<= '0';
							memReqIn.ready	<= '0';
							memState	<= MEMSTATE_READSTART;
						end if;
					else
						readEnable	<= '0';
						readValid0	<= '0';
						readValid1	<= '0';
						memReqIn.ready	<= '1';
					end if;

				when MEMSTATE_READSTART =>
					memState  <= MEMSTATE_READHEAD;

				when MEMSTATE_READHEAD =>
					memReplyHead.byteCount		<= memCount & "00";
					memReplyHead.address		<= memRequestHead1.address(memReplyHead.address'length - 1 downto 0);
					memReplyHead.error		<= (others => '0');
					memReplyHead.status		<= (others => '0');
					memReplyHead.tag		<= memRequestHead1.tag;
					memReplyHead.requesterId	<= memRequestHead1.requesterId;

					if(memCount > PcieMaxPayloadSize) then
						memReplyHead.count	<= to_unsigned(PcieMaxPayloadSize, memReplyHead.count'length);
						memChunkCount		<= to_unsigned(PcieMaxPayloadSize, memChunkCount'length);
					else
						memReplyHead.count	<= memCount;
						memChunkCount		<= memCount;
					end if;

					memReplyOut.keep <= (others => '1');

					if((memReplyOut.ready = '1') and (memReplyOut.valid = '1')) then
						memState <= MEMSTATE_READDATA;
					end if;
				
				when MEMSTATE_READDATA =>
					if((memReplyOut.ready = '1') and (memReplyOut.valid = '1')) then
						if(memChunkCount = 4) then
							memReplyOut.last	<= '0';
							if(memCount = 4) then
								readEnable	<= '0';
								memState	<= MEMSTATE_IDLE;
							else
								memState	<= MEMSTATE_READHEAD;
							end if;

						elsif(memChunkCount = 8) then
							memReplyOut.keep <= "0111";
							memReplyOut.last <= '1';

						else
							memReplyOut.last <= '0';
						end if;

						memChunkCount		<= memChunkCount - 4;
						memCount		<= memCount - 4;
						memRequestHead1.address	<= memRequestHead1.address + 16;
					end if;

				end case;
			end if;
		end if;
	end process;
end;
