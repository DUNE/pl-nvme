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

constant TCQ		: time := 2 ns;

component Fifo is
generic (
	DataWidth	: integer := 128;			--! The data width of the Fifo in bits
	FifoSize	: integer := 8				--! The size of the fifo
);
port (
	clk		: in std_logic;					--! The interface clock line
	reset		: in std_logic;					--! The active high reset line
	
	fifoInNearFull	: out std_logic;
	fifoInReady	: out std_logic;
	fifoInValid	: in std_logic;
	fifoIn		: in std_logic_vector(127 downto 0);


	fifoOutReady	: in std_logic;
	fifoOutValid	: out std_logic;
	fifoOut		: out std_logic_vector(127 downto 0)
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

signal fifoInNearFull	: std_logic;
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
		pcieRequestRead(clk, memReqIn, 5, 0, 0, 16#55#, 512);

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

		--memReplyOut.ready <= '1';
		--wait;

		wait until rising_edge(clk) and memReplyOut.valid = '1';
		wait until rising_edge(clk);
		memReplyOut.ready <= '1';
		
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
	readEnable <= '1';
	memRequestHead	<= to_PcieRequestHeadType(memReqIn.data);
	memReplyOut.data <=
		fifoData0(31 downto 0) & to_stl(memReplyHead) when(memState = MEMSTATE_READHEAD)
		else fifoData0(31 downto 0) & fifoData1(127 downto 32);

	fifoOutReady <= memReplyOut.ready when((memReplyOut.valid = '1') and (memReplyOut.last = '0')) else '0';

	fif0 : Fifo
	port map (
		clk		=> clk,
		reset		=> reset,

		fifoInNearFull	=> fifoInNearFull,
		fifoInReady	=> fifoInReady,
		fifoInValid	=> fifoInValid,
		fifoIn		=> readData,

		fifoOutReady	=> fifoOutReady,
		fifoOutValid	=> fifoOutValid,
		fifoOut		=> fifoData0
	);

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				memReqIn.ready		<= '0';
				readValid		<= '0';
				fifoInValid		<= '0';
				memReplyOut.valid	<= '0';
				memState		<= MEMSTATE_IDLE;
			else
				if(memState /= MEMSTATE_IDLE) then
					-- Fill fifo
					if(readValid = '1') then
						fifoInValid <= '1';
						readValid <= '0';
					end if;
					
					if(fifoInNearFull = '1') then
						fifoInValid <= '0';
					else
						readAddress <= readAddress + 1;
						fifoInValid <= '1';
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
							fifoInValid	<= '0';
							readValid	<= '1';
							memReqIn.ready	<= '0';
							memState	<= MEMSTATE_READSTART;
						end if;
					else
						memReqIn.ready <= '1';
					end if;

				when MEMSTATE_READSTART =>
					memState  <= MEMSTATE_READHEAD;

				when MEMSTATE_READHEAD =>
					if(memReplyOut.valid = '0') then
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
						memReplyOut.valid <= '1';
					else

						if((memReplyOut.ready = '1') and (memReplyOut.valid = '1')) then
							memState <= MEMSTATE_READDATA;
						end if;
					end if;
				
				when MEMSTATE_READDATA =>
					if((memReplyOut.ready = '1') and (memReplyOut.valid = '1')) then
						if(memChunkCount = 4) then
							memReplyOut.last	<= '0';
							memReplyOut.valid	<= '0';
							if(memCount = 4) then
								memState <= MEMSTATE_IDLE;
							else
								memState <= MEMSTATE_READHEAD;
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
