----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.07.2020 13:28:03
-- Design Name: 
-- Module Name: nvme_strm_fmt_pkg - Behavioral
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
use IEEE.STD_LOGIC_1164.all;
library work;
use work.NvmeStoragePkg.all;
use work.NvmeStorageIntPkg.all;

package nvme_strm_fmt is

  constant sub_pkt_pld_size : natural := 7;  --clock cycles of 32 Bytes
  constant sup_pkt_pld_size : natural := 29;
  component NvmeStrmFmtTestData
  port (
        clk		       : in std_logic;
        reset	       : in std_logic;
        enable		   : in std_logic;				--! Enable production of data. Clears to reset state when set to 0.
        dataOut		   : out AxisDataStreamType;		--! Output data stream
        dataOutReady   : in std_logic;				--! Ready signal for output data stream
        error	       : out std_logic
       );
  end component;

  component nvme_strm_gen_blk
    port (
      m_axis_aresetn : in  std_logic;
      m_axis_aclk    : in  std_logic;
      m_axis_tvalid  : out std_logic;
      m_axis_tready  : in  std_logic;
      m_axis_tdata   : out std_logic_vector(255 downto 0);
      m_axis_tlast   : out std_logic;
      enable         : in  std_logic
      );
  end component;

  component nvme_strm_fmt_blk
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

  component nvme_pad_inserter_blk
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
      m_axis_tuser   : out std_logic_vector(8 downto 0);
      m_axis_tlast   : out std_logic
      );
  end component;

  component nvme_spkt_splitter_blk
    port (
      s_axis_aresetn : in  std_logic;
      s_axis_aclk    : in  std_logic;
      s_axis_tvalid  : in  std_logic;
      s_axis_tready  : out std_logic;
      s_axis_tdata   : in  std_logic_vector(255 downto 0);
      s_axis_tuser   : in  std_logic_vector(8 downto 0);
      s_axis_tlast   : in  std_logic;
      m_axis_aclk    : in  std_logic;
      m_axis_tvalid  : out std_logic;
      m_axis_tready  : in  std_logic;
      m_axis_tdata   : out std_logic_vector(255 downto 0);
      m_axis_tuser   : out std_logic_vector(8 downto 0);
      m_axis_tlast   : out std_logic
      );
  end component;

  component nvme_header_inserter_blk
    port (
      s_axis_aresetn : in  std_logic;
      s_axis_aclk    : in  std_logic;
      s_axis_tvalid  : in  std_logic;
      s_axis_tready  : out std_logic;
      s_axis_tdata   : in  std_logic_vector(255 downto 0);
      s_axis_tuser   : in  std_logic_vector(8 downto 0);
      s_axis_tlast   : in  std_logic;
      m_axis_aclk    : in  std_logic;
      m_axis_tvalid  : out std_logic;
      m_axis_tready  : in  std_logic;
      m_axis_tdata   : out std_logic_vector(255 downto 0);
      m_axis_tlast   : out std_logic
      );
  end component;



  component axis_strm_stats_blk
    generic(data_width : natural);
    port (
      x_axis_aresetn    : in std_logic;
      x_axis_aclk       : in std_logic;
      x_axis_tvalid     : in std_logic;
      x_axis_tready     : in std_logic;
      x_axis_tdata      : in std_logic_vector(data_width-1 downto 0);
      x_axis_tlast      : in std_logic;
      --stats counters
      frame_length_max  :    std_logic_vector(63 downto 0);
      frame_length_min  :    std_logic_vector(63 downto 0);
      frame_length_last :    std_logic_vector(63 downto 0)
      );
  end component;

  component axis_stream_flow_mod_blk
    generic(
      tvalid_mod_pat : std_logic_vector(31 downto 0) := (others => '1');
      tready_mod_pat : std_logic_vector(31 downto 0) := (others => '1');
      terror_mod_pat : std_logic_vector(31 downto 0) := (others => '0')
      );
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

  component axis_stream_check_blk
    generic(
      pattern_type : string := "shift"
      );
    port (
      s_axis_aresetn : in  std_logic;
      s_axis_aclk    : in  std_logic;
      s_axis_tvalid  : in  std_logic;
      s_axis_tready  : in  std_logic;
      s_axis_tdata   : in  std_logic_vector(255 downto 0);
      s_axis_tlast   : in  std_logic;
      s_error        : out std_logic
      );
  end component;

  component nvme_axis_packet_fifo
    port (
      s_axis_aresetn : in  std_logic;
      s_axis_aclk    : in  std_logic;
      s_axis_tvalid  : in  std_logic;
      s_axis_tready  : out std_logic;
      s_axis_tdata   : in  std_logic_vector(255 downto 0);
      s_axis_tuser   : in  std_logic_vector(8 downto 0);
      s_axis_tlast   : in  std_logic;
      m_axis_aclk    : in  std_logic;
      m_axis_tvalid  : out std_logic;
      m_axis_tready  : in  std_logic;
      m_axis_tdata   : out std_logic_vector(255 downto 0);
      m_axis_tuser   : out std_logic_vector(8 downto 0);
      m_axis_tlast   : out std_logic
      );
  end component;

--IP Integrator blocks

  component axis_data_fifo_ic_512_x_256
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

  component axis_fifo_cc_512_x_8
    port (
      s_aclk        : in  std_logic;
      s_aresetn     : in  std_logic;
      s_axis_tvalid : in  std_logic;
      s_axis_tready : out std_logic;
      s_axis_tdata  : in  std_logic_vector(7 downto 0);
      s_axis_tlast  : in  std_logic;
      m_axis_tvalid : out std_logic;
      m_axis_tready : in  std_logic;
      m_axis_tdata  : out std_logic_vector(7 downto 0);
      m_axis_tlast  : out std_logic
      );
  end component;

  component axis_fifo_cc_512_x_16
    port (
      s_aclk        : in  std_logic;
      s_aresetn     : in  std_logic;
      s_axis_tvalid : in  std_logic;
      s_axis_tready : out std_logic;
      s_axis_tdata  : in  std_logic_vector(15 downto 0);
      s_axis_tlast  : in  std_logic;
      m_axis_tvalid : out std_logic;
      m_axis_tready : in  std_logic;
      m_axis_tdata  : out std_logic_vector(15 downto 0);
      m_axis_tlast  : out std_logic
      );
  end component;

end nvme_strm_fmt;

package body nvme_strm_fmt is

end nvme_strm_fmt;
