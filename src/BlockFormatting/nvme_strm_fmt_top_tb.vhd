-------------------------------------------------------------------------------
-- Title      : Testbench for design "nvme_strm_fmt_top"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : nvme_strm_fmt_top_tb.vhd
-- Author     : 
-- Company    : 
-- Created    : 2020-07-07
-- Last update: 2020-07-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2020 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author       Description
-- 2020-07-07  1.0                   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library nvme_strm_fmt;
use nvme_strm_fmt.nvme_strm_fmt.all;

-------------------------------------------------------------------------------

entity nvme_strm_fmt_top_tb is

end entity nvme_strm_fmt_top_tb;

-------------------------------------------------------------------------------

architecture behavioural of nvme_strm_fmt_top_tb is

  -- component ports
  signal rst_s : STD_LOGIC:='0';
  signal clk   : STD_LOGIC:='1';
  signal start : STD_LOGIC:='1';
  signal error : STD_LOGIC;


begin

  -- component instantiation
  DUT: nvme_strm_fmt_top
    port map (
      rst_s => rst_s,
      clk   => clk,
      start => start,
      error => error
      );

  -- clock generation
  clk <= not Clk after 10 ns;

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here
    wait until clk'event and clk = '1';
    rst_s <='1';
    wait;
  end process WaveGen_Proc;

end architecture behavioural;

-------------------------------------------------------------------------------

configuration nvme_strm_fmt_top_tb_behavioural_cfg of nvme_strm_fmt_top_tb is
  for behavioural
  end for;
end nvme_strm_fmt_top_tb_behavioural_cfg;

-------------------------------------------------------------------------------
