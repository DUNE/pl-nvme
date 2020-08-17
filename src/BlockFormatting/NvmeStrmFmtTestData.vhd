library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.NvmeStoragePkg.all;
use work.NvmeStorageIntPkg.all;

entity NvmeStrmFmtTestData is 
generic(
	BlockSize	: integer	:= NvmeStorageBlockSize		--! The block size in Bytes.
);
port ( 	
	clk		: in std_logic;
	reset	: in std_logic;
	-- Control and status interface
	enable		: in std_logic;				--! Enable production of data. Clears to reset state when set to 0
	-- AXIS data output
	dataOut		: out AxisDataStreamType;		--! Output data stream
	dataOutReady	: in std_logic;				--! Ready signal for output data stream
	-- Error
	error	: out std_logic
);
end;

architecture Behavioral of NvmeStrmFmtTestData is

component nvme_strm_gen_blk is
port (
	m_axis_aresetn	: in std_logic;
	m_axis_aclk		: in std_logic;
	m_axis_tvalid	: out std_logic;
	dataOutReady	: in std_logic;
	m_axis_tdata	: out std_logic_vector(255 downto 0);
	m_axis_tlast	: out std_logic;
	enable			: in std_logic
);
end component;

component axis_stream_flow_mod_blk is
generic (
	tvalid_mod_pat:std_logic_vector(31 downto 0):= (others => '1');
	tready_mod_pat:std_logic_vector(31 downto 0):= (others => '1');
	terror_mod_pat:std_logic_vector(31 downto 0):= (others => '0')
);
port (
	s_axis_aresetn : IN STD_LOGIC;
	s_axis_aclk    : IN STD_LOGIC;
	s_axis_tvalid  : IN STD_LOGIC;
	s_axis_tready  : OUT STD_LOGIC;
	s_axis_tdata   : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
	s_axis_tlast   : IN STD_LOGIC;
	m_axis_aclk    : IN STD_LOGIC;
	m_axis_tvalid  : OUT STD_LOGIC;
	m_axis_tready  : IN STD_LOGIC;
	m_axis_tdata   : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
	m_axis_tlast   : OUT STD_LOGIC
);
end component;

component nvme_strm_fmt_blk is
port (
    s_axis_aresetn : in  std_logic;
    s_axis_aclk    : in  std_logic;
    s_axis_tvalid  : in  std_logic;
    s_axis_tready  : out std_logic;
    s_axis_tdata   : in  std_logic_vector(255 downto 0);
    s_axis_tlast   : in  std_logic;
    m_axis_aclk    : in  std_logic;
    m_axis_tvalid  : out std_logic;
    m_axis_tready  : in  std_logic;
    m_axis_tdata   : out std_logic_vector(255 downto 0);
    m_axis_tlast   : out std_logic
);
end component;

component axis_stream_check_blk is
generic(
	pattern_type: string:="shift"
);
port (
    s_axis_aresetn : IN STD_LOGIC;
    s_axis_aclk    : IN STD_LOGIC;
    s_axis_tvalid  : IN STD_LOGIC;
    s_axis_tready  : IN STD_LOGIC;
    s_axis_tdata   : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
    s_axis_tlast   : IN STD_LOGIC;
    s_error        : OUT STD_LOGIC
);	
end component;

constant num_m2s    : natural   := 4;

type tdata_array is array (0 to num_m2s-1) of std_logic_vector(255 downto 0);

signal m2s_axis_aclk   : std_logic;
signal m2s_axis_aresetn: std_logic;

signal m2s_axis_tvalid : std_logic_vector(num_m2s-1 downto 0):=(others => '0');
signal m2s_axis_tready : std_logic_vector(num_m2s-1 downto 0):=(others => '0');
signal m2s_axis_tdata  : tdata_array                         :=(others => (others => '0'));
signal m2s_axis_tlast  : std_logic_vector(num_m2s-1 downto 0):=(others => '0'); 

signal s_error: std_logic;

begin

m2s_axis_aclk <= clk;
m2s_axis_aresetn <= reset;

nvme_gen0 : nvme_strm_gen_blk
port map (
			m_axis_aresetn => m2s_axis_aresetn,
			m_axis_aclk    => m2s_axis_aclk,
			m_axis_tvalid  => m2s_axis_tvalid(0),
			dataOutReady   => m2s_axis_tready(0),
			m_axis_tdata   => m2s_axis_tdata(0),
			m_axis_tlast   => m2s_axis_tlast(0),
			enable         => enable
);
  
--front forward/backward pressure & error injection
nvme_fmod_0: axis_stream_flow_mod_blk
generic map(
			tvalid_mod_pat => X"FFFFFFFF",
			tready_mod_pat => X"FFFFFFFF",
			terror_mod_pat => X"00000000"
)
port map(
			s_axis_aresetn => m2s_axis_aresetn,
			s_axis_aclk    => m2s_axis_aclk,
			s_axis_tvalid  => m2s_axis_tvalid(0),
			s_axis_tready  => m2s_axis_tready(0),
			s_axis_tdata   => m2s_axis_tdata(0),
			s_axis_tlast   => m2s_axis_tlast(0),
			m_axis_aclk    => m2s_axis_aclk,
			m_axis_tvalid  => m2s_axis_tvalid(1),
			m_axis_tready  => m2s_axis_tready(1),
			m_axis_tdata   => m2s_axis_tdata(1),
			m_axis_tlast   => m2s_axis_tlast(1)
);

nvme_fmt_0 : nvme_strm_fmt_blk
port map(
			s_axis_aresetn => m2s_axis_aresetn,
			s_axis_aclk    => m2s_axis_aclk,
			s_axis_tvalid  => m2s_axis_tvalid(1),
			s_axis_tready  => m2s_axis_tready(1),
			s_axis_tdata   => m2s_axis_tdata(1),
			s_axis_tlast   => m2s_axis_tlast(1),
			m_axis_aclk    => m2s_axis_aclk,
			m_axis_tvalid  => m2s_axis_tvalid(2),
			m_axis_tready  => m2s_axis_tready(2),
			m_axis_tdata   => m2s_axis_tdata(2),
			m_axis_tlast   => m2s_axis_tlast(2)
);
  
--rear back/forward pressure and error injection
nvme_bmod_0: axis_stream_flow_mod_blk
generic map(
			tvalid_mod_pat => X"FFFFFFFF",
			tready_mod_pat => X"FFFFFFFF",
			terror_mod_pat => X"00000000"
)
port map (
			s_axis_aresetn => m2s_axis_aresetn,
			s_axis_aclk    => m2s_axis_aclk,   
			s_axis_tvalid  => m2s_axis_tvalid(2),
			s_axis_tready  => m2s_axis_tready(2),
			s_axis_tdata   => m2s_axis_tdata(2),
			s_axis_tlast   => m2s_axis_tlast(2),
			m_axis_aclk    => m2s_axis_aclk,   
			m_axis_tvalid  => m2s_axis_tvalid(3),
			m_axis_tready  => m2s_axis_tready(3),
			m_axis_tdata   => m2s_axis_tdata(3),
			m_axis_tlast   => m2s_axis_tlast(3)
);
         
nvme_check_0: axis_stream_check_blk
generic map(
			pattern_type => "shift"
)
port map(
			s_axis_aresetn => m2s_axis_aresetn,
			s_axis_aclk    => m2s_axis_aclk,   
			s_axis_tvalid  => m2s_axis_tvalid(3),
			s_axis_tready  => m2s_axis_tready(3),
			s_axis_tdata   => m2s_axis_tdata(3) ,
			s_axis_tlast   => m2s_axis_tlast(3) ,
			s_error        => s_error
);

error 			<= s_error;
dataOut.valid 	<= m2s_axis_tvalid(3);
dataOut.data 	<= m2s_axis_tdata(3);
dataOut.last	<= m2s_axis_tlast(3);


end;