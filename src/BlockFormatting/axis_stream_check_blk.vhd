----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.07.2020 14:45:38
-- Design Name: 
-- Module Name: axis_stream_check_blk - rtl
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

entity axis_stream_check_blk is
generic(
        pattern_type: string:="shift"
        );
  PORT (
    s_axis_aresetn : IN STD_LOGIC;
    s_axis_aclk    : IN STD_LOGIC;
    s_axis_tvalid  : IN STD_LOGIC;
    s_axis_tready  : IN STD_LOGIC;
    s_axis_tdata   : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
    s_axis_tlast   : IN STD_LOGIC;
    s_error        : OUT STD_LOGIC
  );
end axis_stream_check_blk;

architecture rtl of axis_stream_check_blk is

constant count_max   : std_logic_vector(7 downto 0):= conv_std_logic_vector(sub_pkt_pld_size-1,8);
constant count_max_m1: std_logic_vector(7 downto 0):= conv_std_logic_vector(sub_pkt_pld_size-2,8);

signal count  : std_logic_vector(7 downto 0):=(others => '0');
signal length : std_logic_vector(7 downto 0):=(others => '0');

signal tfirst : std_logic:='1';

signal error:std_logic:='0';

signal byte_error_2: std_logic_vector(31 downto 0) := (others => '0');
signal byte_error_1: std_logic_vector( 7 downto 0) := (others => '0');
signal byte_error_0: std_logic_vector( 1 downto 0) := (others => '0');

signal data_pattern: std_logic_vector(255 downto 0) := X"0000000000000000000000000000000000000000000000000000000000000001";

alias clk: std_logic is s_axis_aclk;
alias rst: std_logic is s_axis_aresetn;

begin

--pipelined 256 bit compare
p0: process(clk)

begin
   if (clk'event and clk = '1') then
      if rst = '0' then
         error <= '0';
         data_pattern <= X"0000000000000000000000000000000000000000000000000000000000000001";
      else
         if s_axis_tvalid = '1' and s_axis_tready = '1' and not tfirst = '1' and count <= length then
            --shift the test pattern
            data_pattern <= data_pattern(254 downto 0) & data_pattern(255);
            --pipelined 256 bit compare
            for i in 0 to 31 loop
               if s_axis_tdata(i*8+7 downto i*8) = data_pattern(i*8+7 downto i*8) then
                  byte_error_2(i) <= '0';
               else
                  byte_error_2(i) <= '1';
               end if;
            end loop;
         end if;
         for i in 0 to 7 loop
            byte_error_1(i) <= byte_error_2(i*4+3) or byte_error_2(i*4+2) or byte_error_2(i*4+1) or byte_error_2(i*4+0);
         end loop;
         for i in 0 to 1 loop
            byte_error_0(i) <= byte_error_1(i*4+3) or byte_error_1(i*4+2) or byte_error_1(i*4+1) or byte_error_1(i*4+0);
         end loop;
         error <= byte_error_0(1) or byte_error_0(0);
      end if;
   end if;
end process;

--frame cycle count
p1: process(clk)

begin
   if (clk'event and clk = '1') then
      if rst = '0' then
         count <= (others => '0');
      else
         if s_axis_tvalid = '1' and s_axis_tready = '1' then
            if s_axis_tlast = '1' then
              count <= (others => '0');
            else
               count <= count + 1;
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
         if s_axis_tvalid = '1' and s_axis_tready = '1' then
            if s_axis_tlast = '1' then
               tfirst <= '1';
            else
               tfirst <= '0';
            end if;
         end if;
      end if;
   end if;
end process;

--capture payload length from header
p3: process(clk)

begin
   if (clk'event and clk = '1') then
      if rst = '0' then
         length <= (others => '0');
      else
         if s_axis_tvalid = '1' and s_axis_tready = '1' then
            if tfirst = '1' then
              length <= s_axis_tdata(64*3+7 downto 64*3);
            end if;
         end if;
      end if;
   end if;
end process;

s_error <= error;

end rtl;
