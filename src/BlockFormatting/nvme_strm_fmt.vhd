----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.07.2020 14:23:03
-- Design Name: 
-- Module Name: nvme_strm_fmt - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library work;
use work.nvme_strm_fmt.all;

entity nvme_strm_fmt_blk is
  port(
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
end nvme_strm_fmt_blk;

architecture rtl of nvme_strm_fmt_blk is

constant num_m2s: natural := 5;

type tdata_array is array (0 to num_m2s-1) of std_logic_vector(255 downto 0);
type tuser_array is array (0 to num_m2s-1) of std_logic_vector(  8 downto 0);

signal m2s_axis_aclk   : std_logic:='0';
signal m2s_axis_aresetn: std_logic:='0';

signal m2s_axis_tvalid : std_logic_vector(num_m2s-1 downto 0):=(others => '0');
signal m2s_axis_tready : std_logic_vector(num_m2s-1 downto 0):=(others => '0');
signal m2s_axis_tdata  : tdata_array                         :=(others => (others => '0'));
signal m2s_axis_tuser  : tuser_array                         :=(others => (others => '0'));
signal m2s_axis_tlast  : std_logic_vector(num_m2s-1 downto 0):=(others => '0'); 

begin

m2s_axis_tvalid(0) <= s_axis_tvalid;
s_axis_tready      <= m2s_axis_tready(0);
m2s_axis_tdata(0)  <= s_axis_tdata;
m2s_axis_tlast(0)  <= s_axis_tlast;


f0 : axis_data_fifo_ic_512_x_256
  PORT MAP (
    s_axis_aresetn => s_axis_aresetn,
    s_axis_aclk    => s_axis_aclk,
    s_axis_tvalid  => m2s_axis_tvalid(0),
    s_axis_tready  => m2s_axis_tready(0),
    s_axis_tdata   => m2s_axis_tdata (0),
    s_axis_tlast   => m2s_axis_tlast (0),
    m_axis_aclk    => m_axis_aclk,
    m_axis_tvalid  => m2s_axis_tvalid(1),
    m_axis_tready  => m2s_axis_tready(1),
    m_axis_tdata   => m2s_axis_tdata (1),
    m_axis_tlast   => m2s_axis_tlast (1)
  );
  
  --packet splitter
  
  p0 : nvme_pad_inserter_blk
  PORT MAP (
    s_axis_aresetn =>  s_axis_aresetn,    
    s_axis_aclk    =>  s_axis_aclk,       
    s_axis_tvalid  =>  m2s_axis_tvalid(1),
    s_axis_tready  =>  m2s_axis_tready(1),
    s_axis_tdata   =>  m2s_axis_tdata (1),
    s_axis_tlast   =>  m2s_axis_tlast (1),
    m_axis_aclk    =>  m_axis_aclk,       
    m_axis_tvalid  =>  m2s_axis_tvalid(2),
    m_axis_tready  =>  m2s_axis_tready(2),
    m_axis_tdata   =>  m2s_axis_tdata (2),
    m_axis_tuser   =>  m2s_axis_tuser (2),
    m_axis_tlast   =>  m2s_axis_tlast (2) 
  );
  

--packet pad inserter

  p1 : nvme_spkt_splitter_blk
  PORT MAP (
    s_axis_aresetn =>  s_axis_aresetn,    
    s_axis_aclk    =>  s_axis_aclk,       
    s_axis_tvalid  =>  m2s_axis_tvalid(2),
    s_axis_tready  =>  m2s_axis_tready(2),
    s_axis_tdata   =>  m2s_axis_tdata (2),
    s_axis_tuser   =>  m2s_axis_tuser (2),
    s_axis_tlast   =>  m2s_axis_tlast (2),
    m_axis_aclk    =>  m_axis_aclk,       
    m_axis_tvalid  =>  m2s_axis_tvalid(3),
    m_axis_tready  =>  m2s_axis_tready(3),
    m_axis_tdata   =>  m2s_axis_tdata (3),
    m_axis_tuser   =>  m2s_axis_tuser (3),
    m_axis_tlast   =>  m2s_axis_tlast (3) 
  );

--packet header inserter

  p2 : nvme_header_inserter_blk
  PORT MAP (
    s_axis_aresetn => s_axis_aresetn,    
    s_axis_aclk    => s_axis_aclk,       
    s_axis_tvalid  => m2s_axis_tvalid(3),
    s_axis_tready  => m2s_axis_tready(3),
    s_axis_tdata   => m2s_axis_tdata (3),
    s_axis_tuser   => m2s_axis_tuser (3),
    s_axis_tlast   => m2s_axis_tlast (3),
    m_axis_aclk    => m_axis_aclk,       
    m_axis_tvalid  => m2s_axis_tvalid(4),
    m_axis_tready  => m2s_axis_tready(4),
    m_axis_tdata   => m2s_axis_tdata (4),
    m_axis_tlast   => m2s_axis_tlast (4) 
  );

--packet crc inserter



--AXI4S monitors as required



--pipeline fifos as required

m_axis_tvalid      <= m2s_axis_tvalid(4);
m2s_axis_tready(4) <= m_axis_tready;
m_axis_tdata       <= m2s_axis_tdata(4);
m_axis_tlast       <= m2s_axis_tlast(4);  

end rtl;
