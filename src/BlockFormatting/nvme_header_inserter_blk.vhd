----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10.07.2020 15:52:41
-- Design Name: 
-- Module Name: nvme_header_inserter_blk - rtl
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

entity nvme_header_inserter_blk is
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
    m_axis_tlast   : OUT STD_LOGIC
  );
end nvme_header_inserter_blk;

architecture rtl of nvme_header_inserter_blk is

constant count_max   : std_logic_vector(7 downto 0):= conv_std_logic_vector(sub_pkt_pld_size-1,8);
constant count_max_m1: std_logic_vector(7 downto 0):= conv_std_logic_vector(sub_pkt_pld_size-2,8);

signal count  : std_logic_vector(7 downto 0):=(others => '0');
signal tlast  : std_logic:='0';
signal tfirst : std_logic:='1';

signal frame_in_progress: std_logic:='0';

signal header:std_logic_vector(255 downto 0);

signal hdr_flgs    :std_logic_vector(63 downto 0):=(others => '0');
signal hdr_crc     :std_logic_vector(63 downto 0):=(others => '0');
signal hdr_spr_cnt :std_logic_vector(63 downto 0):=(others => '0');
signal hdr_sub_cnt :std_logic_vector(63 downto 0):=(others => '0');

signal s_axis_tvalid_i: std_logic;
signal s_axis_tready_i: std_logic;
signal s_axis_tdata_i : std_logic_vector(255 downto 0);
signal s_axis_tuser_i : std_logic_vector(  8 downto 0);
signal s_axis_tlast_i : std_logic;

signal sup_pkt_count: std_logic_vector(31 downto 0):=(others => '0');
signal sub_pkt_count: std_logic_vector(31 downto 0):=(others => '0');

alias clk: std_logic is s_axis_aclk;
alias rst: std_logic is s_axis_aresetn;
alias trdy: std_logic is m_axis_tready;

begin

hdr_flgs(7 downto 0) <= s_axis_tuser_i(7 downto 0);
hdr_sub_cnt(31 downto 0) <= sub_pkt_count;
hdr_spr_cnt(31 downto 0) <= sup_pkt_count;

header <= hdr_flgs & hdr_crc & hdr_spr_cnt & hdr_sub_cnt;

f0 : nvme_axis_packet_fifo
  PORT MAP (
    s_axis_aresetn => s_axis_aresetn,
    s_axis_aclk    => s_axis_aclk,
    s_axis_tvalid  => s_axis_tvalid,
    s_axis_tready  => s_axis_tready,
    s_axis_tdata   => s_axis_tdata ,
    s_axis_tuser   => s_axis_tuser ,
    s_axis_tlast   => s_axis_tlast ,
    m_axis_aclk    => m_axis_aclk,
    m_axis_tvalid  => s_axis_tvalid_i,
    m_axis_tready  => s_axis_tready_i,
    m_axis_tdata   => s_axis_tdata_i ,
    m_axis_tuser   => s_axis_tuser_i ,
    m_axis_tlast   => s_axis_tlast_i 
  );

--p0: process(clk)

--begin

--   if (clk'event and clk = '1') then
--      if rst = '0' then
--         frame_in_progress <= '0';
--         count <= ( others => '0');
--         tlast <= '0';
--      else
--         if (s_axis_tvalid = '1' and m_axis_tready = '1') then
--             if tfirst = '1' or frame_in_progress = '1' then
--                if s_axis_tlast = '1' then
--                    count <= (others => '0');
--                    frame_in_progress <= '0';
--                    tlast <= '0';
--                else
--                    if count = count_max then
--                       count <= (others => '0');
--                       tlast <= '0';
--                    elsif count = count_max_m1 then
--                       tlast <= '1';
--                       count <= count + 1;
--                    else
--                       count <= count + 1;
--                    end if;
--                    frame_in_progress <= '1';
--                end if;
--            end if;
--         end if;
--      end if;
--   end if;

--end process;

p0: process(clk)

begin
   if (clk'event and clk = '1') then
      if rst = '0' then
         sup_pkt_count <= (others => '0');
      else
         if s_axis_tvalid_i = '1' and m_axis_tready = '1' then
            if s_axis_tuser_i(8) = '1' and s_axis_tlast_i = '1' then
               sup_pkt_count <= sup_pkt_count + 1;
            end if;
         end if;
      end if;
   end if;
end process;

p1: process(clk)

begin
   if (clk'event and clk = '1') then
      if rst = '0' then
         sub_pkt_count <= (others => '0');
      else
         if s_axis_tvalid_i = '1' and m_axis_tready = '1' then
            if s_axis_tlast_i = '1' then
               if s_axis_tuser_i(8) = '1' then
                   sub_pkt_count <= (others => '0');  
               else
                   sub_pkt_count <= sub_pkt_count +1;
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
         if (tfirst = '0' and s_axis_tvalid_i = '1' and m_axis_tready = '1') or (tfirst = '1' and m_axis_tready = '1') then
         --if s_axis_tvalid_i = '1' and m_axis_tready = '1' then
            if s_axis_tlast_i = '1' then
               tfirst <= '1';
            else
               tfirst <= '0';
            end if;
         end if;
      end if;
   end if;
end process;

--pass through s_axis to m_axis
m_axis_tvalid <= s_axis_tvalid_i when tfirst = '0' else '1';

s_axis_tready_i <= m_axis_tready when tfirst = '0' else '0';

m_axis_tlast  <= s_axis_tlast_i;

--multiplex in header on first cycle when tfirst high
m_axis_tdata  <= s_axis_tdata_i when tfirst = '0' else header;

end rtl;
