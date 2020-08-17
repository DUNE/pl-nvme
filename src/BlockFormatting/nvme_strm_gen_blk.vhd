----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.07.2020 15:29:59
-- Design Name: 
-- Module Name: nvme_strm_gen_blk - Behavioral
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.nvme_strm_fmt.all;

entity nvme_strm_gen_blk is
Port ( 
    m_axis_aresetn : IN STD_LOGIC;
    m_axis_aclk    : IN STD_LOGIC;
    m_axis_tvalid  : OUT STD_LOGIC;
    dataOutReady   : IN STD_LOGIC;
    m_axis_tdata   : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
    m_axis_tlast   : OUT STD_LOGIC;
    enable         : IN STD_LOGIC
);
end nvme_strm_gen_blk;

architecture Behavioral of nvme_strm_gen_blk is

constant count_max   : std_logic_vector(11 downto 0):= conv_std_logic_vector(sup_pkt_pld_size-1,12);
constant count_max_m1: std_logic_vector(11 downto 0):= conv_std_logic_vector(sup_pkt_pld_size-2,12);

signal count : std_logic_vector(11 downto 0):=(others => '0');
signal tdata : std_logic_vector(255 downto 0):=conv_std_logic_vector(1,256);
signal tlast : std_logic:='0';

alias clk: std_logic is m_axis_aclk;
alias rst: std_logic is m_axis_aresetn;
alias trdy: std_logic is dataOutReady;

begin

p0: process(clk)

begin

   if (clk'event and clk = '1') then
      --m_axis_tvalid <= '0';
      if rst = '0' then
         count <= ( others => '0');
      else
         if trdy = '1' and enable = '1' then
            tdata <= tdata(254 downto 0) & tdata(255);
            --m_axis_tvalid <= '1';
            if count = count_max then
               count <= (others => '0');
               tlast <= '0';
            elsif count = count_max_m1 then
               tlast <= '1';
               count <= count + 1;
            else
               count <= count + 1;
            end if;
         end if;
      end if;
   end if;


end process;

m_axis_tdata <= tdata;
m_axis_tlast <= tlast;
m_axis_tvalid <= '1';

end Behavioral;
