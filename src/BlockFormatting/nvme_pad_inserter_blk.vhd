----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10.07.2020 15:52:41
-- Design Name: 
-- Module Name: nvme_pad_inserter_blk - rtl
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

entity nvme_pad_inserter_blk is
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
    m_axis_tuser   : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
    m_axis_tlast   : OUT STD_LOGIC
  );
end nvme_pad_inserter_blk;

architecture rtl of nvme_pad_inserter_blk is

constant count_max   : std_logic_vector(7 downto 0):= conv_std_logic_vector(sub_pkt_pld_size-1,8);
constant count_max_m1: std_logic_vector(7 downto 0):= conv_std_logic_vector(sub_pkt_pld_size-2,8);

signal count  : std_logic_vector(7 downto 0):=(others => '0');
signal pcount  : std_logic_vector(7 downto 0):=(others => '0');

signal tlast  : std_logic:='0';
signal tfirst : std_logic:='1';
signal tpad   : std_logic:='0';

signal frame_in_progress: std_logic:='0';

signal s_axis_tready_i : std_logic:='0';

constant padding:std_logic_vector(255 downto 0):=(others => '0');

alias clk: std_logic is s_axis_aclk;
alias rst: std_logic is s_axis_aresetn;
alias trdy: std_logic is m_axis_tready;

begin

p0: process(clk)
begin
   if (clk'event and clk = '1') then
      --m_axis_tuser <= (others => '0');
      if rst = '0' then
         frame_in_progress <= '0';
         count <= ( others => '0');
         tlast <= '0';
      else
         if (tpad = '0' and s_axis_tvalid = '1' and m_axis_tready = '1') or (tpad = '1' and m_axis_tready = '1') then
             if count = count_max then
                count <= (others => '0');
                tlast <= '0';
             elsif count = count_max_m1 then
                if tpad = '1' then
                    tlast <= '1';
                end if;
                count <= count + 1;
             else
                count <= count + 1;
             end if;
             frame_in_progress <= '1';
        end if;
      end if;
   end if;
end process;

--pad flag and count process
p1: process(clk)
begin
   if (clk'event and clk = '1') then
      if rst = '0' then
         tpad <= '0';
         pcount <= ( others => '0');
         m_axis_tuser(7 downto 0) <= count_max+1;
      else
         if (tpad = '0' and s_axis_tvalid = '1' and m_axis_tready = '1') or (tpad = '1' and m_axis_tready = '1') then
            if tpad = '0' and s_axis_tlast = '1' and count /= count_max then
                   tpad  <= '1';
                   m_axis_tuser(7 downto 0) <= count+1;
            elsif tpad = '1' then
               if count = count_max then
                   tpad  <= '0';
                   m_axis_tuser(7 downto 0) <= count+1;
                   pcount <= (others => '0');
               else
                  pcount <= pcount + 1;
               end if;
            end if;
         end if;
      end if;
   end if;
end process;

--tfirst process - tfirst is high during first valid clock cycle of the next frame
p2: process(clk)

begin
   if (clk'event and clk = '1') then
      if rst = '0' then
         tfirst <= '1';
      else
         if (tpad = '0' and s_axis_tvalid = '1' and m_axis_tready = '1') or (tpad = '1' and m_axis_tready = '1')  then 
            if s_axis_tlast = '1' and count = count_max then
               tfirst <= '1';
            else
               tfirst <= '0';
            end if;
         end if;
      end if;
   end if;
end process;

--pass through s_axis to m_axis
m_axis_tvalid <= s_axis_tvalid when tpad = '0' else '1';

s_axis_tready <= m_axis_tready when tpad = '0' else '0';

--m_axis_tlast  <= s_axis_tlast when tpad = '0' else tlast;
m_axis_tlast  <= tlast;

--multiplex in header on first cycle when tfirst high
m_axis_tdata  <= s_axis_tdata when tpad = '0' else padding;

m_axis_tuser(8) <= tlast;

end rtl;
