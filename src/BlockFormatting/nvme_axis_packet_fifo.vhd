----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 13.07.2020 14:26:04
-- Design Name: 
-- Module Name: nvme_axis_packet_fifo - rtl
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

library work;
use work.nvme_strm_fmt.all;

entity nvme_axis_packet_fifo is
  PORT (
    s_axis_aresetn : IN STD_LOGIC;
    s_axis_aclk    : IN STD_LOGIC;
    s_axis_tvalid  : IN STD_LOGIC;
    s_axis_tready  : OUT STD_LOGIC;
    s_axis_tdata   : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
    s_axis_tuser   : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    s_axis_tlast   : IN STD_LOGIC;
    m_axis_aclk    : IN STD_LOGIC;
    m_axis_tvalid  : OUT STD_LOGIC;
    m_axis_tready  : IN STD_LOGIC;
    m_axis_tdata   : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
    m_axis_tuser   : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
    m_axis_tlast   : OUT STD_LOGIC
  );
end nvme_axis_packet_fifo;

architecture rtl of nvme_axis_packet_fifo is

signal s_axis_tvalid_u : std_logic;
signal s_axis_tready_u : std_logic;
signal s_axis_tuser_u  : std_logic_vector(15 downto 0):=(others => '0');
signal s_axis_tlast_u  : std_logic;

signal m_axis_tvalid_u : std_logic;
signal m_axis_tready_u : std_logic;
signal m_axis_tuser_u  : std_logic_vector(15 downto 0);
signal m_axis_tlast_u  : std_logic;

signal s_axis_tvalid_i : std_logic;
signal s_axis_tready_i : std_logic;
signal s_axis_tdata_i  : std_logic_vector(255 downto 0);
signal s_axis_tlast_i  : std_logic;

signal m_axis_tvalid_i : std_logic;
signal m_axis_tready_i : std_logic;
signal m_axis_tdata_i  : std_logic_vector(255 downto 0);
signal m_axis_tlast_i  : std_logic;


begin

--tdata fifo

s_axis_tvalid_i <= s_axis_tvalid;
s_axis_tready <= s_axis_tready_i;
s_axis_tdata_i  <= s_axis_tdata;
s_axis_tlast_i  <= s_axis_tlast;

f0 : axis_data_fifo_ic_512_x_256
  PORT MAP (
    s_axis_aclk    => s_axis_aclk  ,
    s_axis_aresetn => s_axis_aresetn,
    s_axis_tvalid  => s_axis_tvalid_i,
    s_axis_tready  => s_axis_tready_i,
    s_axis_tdata   => s_axis_tdata_i,
    s_axis_tlast   => s_axis_tlast_i,
    m_axis_aclk    => m_axis_aclk  ,
    m_axis_tvalid  => m_axis_tvalid_i,
    m_axis_tready  => m_axis_tready_i,
    m_axis_tdata   => m_axis_tdata_i,
    m_axis_tlast   => m_axis_tlast_i
  );
  
m_axis_tvalid   <= m_axis_tvalid_i and m_axis_tvalid_u;
m_axis_tready_i <= m_axis_tready;
m_axis_tdata    <= m_axis_tdata_i ;
m_axis_tlast    <= m_axis_tlast_i ;

--tuser fifo
  
  s_axis_tvalid_u <= s_axis_tvalid   and s_axis_tlast;
  --s_axis_tready <= s_axis_tready_u;
  
  s_axis_tuser_u(8 downto 0)  <= s_axis_tuser;
  s_axis_tlast_u              <= s_axis_tlast;
  

  f1 : axis_fifo_cc_512_x_16
  PORT MAP (
    s_aclk        => s_axis_aclk,
    s_aresetn     => s_axis_aresetn,
    
    s_axis_tvalid => s_axis_tvalid_u,
    s_axis_tready => s_axis_tready_u,
    s_axis_tdata  => s_axis_tuser_u,
    s_axis_tlast  => s_axis_tlast_u,
    
    m_axis_tvalid => m_axis_tvalid_u,
    m_axis_tready => m_axis_tready_u,
    m_axis_tdata  => m_axis_tuser_u,
    m_axis_tlast  => m_axis_tlast_u
  );
  
m_axis_tready_u <= m_axis_tvalid_i and m_axis_tready_i and m_axis_tlast_i;
--m_axis_tvalid_u <= m_axis_tvalid_u;

m_axis_tuser    <= m_axis_tuser_u(8 downto 0) ;
--m_axis_tlast_u  <= m_axis_tlast_u ;

end rtl;
