----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.07.2020 12:36:24
-- Design Name: 
-- Module Name: axis_stream_flow_mod_blk - rtl
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

entity axis_stream_flow_mod_blk is
generic(
        tvalid_mod_pat:std_logic_vector(31 downto 0):= (others => '1');
        tready_mod_pat:std_logic_vector(31 downto 0):= (others => '1');
        terror_mod_pat:std_logic_vector(31 downto 0):= (others => '0')
        );
  PORT (
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
end axis_stream_flow_mod_blk;

architecture rtl of axis_stream_flow_mod_blk is

signal tv_sr    : std_logic_vector(31 downto 0):= tvalid_mod_pat;
signal tr_sr    : std_logic_vector(31 downto 0):= tready_mod_pat;
signal te_sr    : std_logic_vector(31 downto 0):= terror_mod_pat;

signal tv,tr,te :std_logic:='0';

alias clk: std_logic is s_axis_aclk;
alias rst: std_logic is s_axis_aresetn;

begin

p0: process(clk)

begin
   if (clk'event and clk = '1') then
      if rst = '0' then
         tv_sr <= tvalid_mod_pat;
         tr_sr <= tready_mod_pat;
         te_sr <= terror_mod_pat;
         tv <= '0';
         tr <= '0';
         te <= '0';
      else
         tv_sr <= tv_sr(30 downto 0) & tv_sr(31);
         tr_sr <= tr_sr(30 downto 0) & tr_sr(31);
         te_sr <= te_sr(30 downto 0) & te_sr(31);
         tv <= tv_sr(31);
         tr <= tr_sr(31);
         te <= te_sr(31);
      end if;
   end if;
end process;


 
m_axis_tvalid <= s_axis_tvalid and tv;
s_axis_tready <= m_axis_tready and tr;
m_axis_tdata  <= s_axis_tdata when te = '0' else not s_axis_tdata;
m_axis_tlast  <= s_axis_tlast;

end rtl;
