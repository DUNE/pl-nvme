//-----------------------------------------------------------------------------
//
// (c) Copyright 2012-2012 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
//
// Project    : Ultrascale FPGA Gen3 Integrated Block for PCI Express
// File       : Pcie_nvme0_pipe_misc.v
// Version    : 4.4 
//-----------------------------------------------------------------------------

/////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module Pcie_nvme0_pipe_misc 
 #(
  parameter TCQ = 100,
  parameter PIPE_PIPELINE_STAGES = 0
  ) (
  input  wire         pipe_tx_rcvr_det_i,
  input  wire         pipe_tx_reset_i,
  input  wire   [1:0] pipe_tx_rate_i,
  input  wire         pipe_tx_deemph_i,
  input  wire   [2:0] pipe_tx_margin_i,
  input  wire         pipe_tx_swing_i,
  input  wire   [5:0] pipe_tx_eqfs_i,
  input  wire   [5:0] pipe_tx_eqlf_i,
  output wire         pipe_tx_rcvr_det_o,
  output wire         pipe_tx_reset_o,
  output wire   [1:0] pipe_tx_rate_o,
  output wire         pipe_tx_deemph_o,
  output wire   [2:0] pipe_tx_margin_o,
  output wire         pipe_tx_swing_o,
  output wire   [5:0] pipe_tx_eqfs_o,
  output wire   [5:0] pipe_tx_eqlf_o,
  input  wire         pipe_clk,
  input  wire         rst_n
  );

  reg                 pipe_tx_rcvr_det_q;
  reg                 pipe_tx_reset_q;
  reg           [1:0] pipe_tx_rate_q;
  reg                 pipe_tx_deemph_q;
  reg           [2:0] pipe_tx_margin_q;
  reg                 pipe_tx_swing_q;
  reg           [5:0] pipe_tx_eqfs_q;
  reg           [5:0] pipe_tx_eqlf_q;
  reg                 pipe_tx_rcvr_det_qq;
  reg                 pipe_tx_reset_qq;
  reg           [1:0] pipe_tx_rate_qq;
  reg                 pipe_tx_deemph_qq;
  reg           [2:0] pipe_tx_margin_qq;
  reg                 pipe_tx_swing_qq;
  reg           [5:0] pipe_tx_eqfs_qq;
  reg           [5:0] pipe_tx_eqlf_qq;

  generate
    if (PIPE_PIPELINE_STAGES == 0)
    begin : pipe_stages_0
      assign pipe_tx_rcvr_det_o = pipe_tx_rcvr_det_i;
      assign pipe_tx_reset_o = pipe_tx_reset_i;
      assign pipe_tx_rate_o = pipe_tx_rate_i;
      assign pipe_tx_deemph_o = pipe_tx_deemph_i;
      assign pipe_tx_margin_o = pipe_tx_margin_i;
      assign pipe_tx_swing_o = pipe_tx_swing_i;
      assign pipe_tx_eqfs_o = pipe_tx_eqfs_i;
      assign pipe_tx_eqlf_o = pipe_tx_eqlf_i;
    end
    else if (PIPE_PIPELINE_STAGES == 1)
    begin : pipe_stages_1
      always @(posedge pipe_clk)
      begin
        if (!rst_n)
        begin
          pipe_tx_rcvr_det_q <= #TCQ 1'b0;
          pipe_tx_reset_q <= #TCQ 1'b1;
          pipe_tx_rate_q <= #TCQ 2'b0;
          pipe_tx_deemph_q <= #TCQ 1'b1;
          pipe_tx_margin_q <= #TCQ 3'b0;
          pipe_tx_swing_q <= #TCQ 1'b0;
          pipe_tx_eqfs_q <= #TCQ 5'b0;
          pipe_tx_eqlf_q <= #TCQ 5'b0;
        end
        else
        begin
          pipe_tx_rcvr_det_q <= #TCQ pipe_tx_rcvr_det_i;
          pipe_tx_reset_q <= #TCQ pipe_tx_reset_i;
          pipe_tx_rate_q <= #TCQ pipe_tx_rate_i;
          pipe_tx_deemph_q <= #TCQ pipe_tx_deemph_i;
          pipe_tx_margin_q <= #TCQ pipe_tx_margin_i;
          pipe_tx_swing_q <= #TCQ pipe_tx_swing_i;
          pipe_tx_eqfs_q <= #TCQ pipe_tx_eqfs_i;
          pipe_tx_eqlf_q <= #TCQ pipe_tx_eqlf_i;
        end
      end
      assign pipe_tx_rcvr_det_o = pipe_tx_rcvr_det_q;
      assign pipe_tx_reset_o = pipe_tx_reset_q;
      assign pipe_tx_rate_o = pipe_tx_rate_q;
      assign pipe_tx_deemph_o = pipe_tx_deemph_q;
      assign pipe_tx_margin_o = pipe_tx_margin_q;
      assign pipe_tx_swing_o = pipe_tx_swing_q;
      assign pipe_tx_eqfs_o = pipe_tx_eqfs_q;
      assign pipe_tx_eqlf_o = pipe_tx_eqlf_q;
    end
    else if (PIPE_PIPELINE_STAGES == 2)
    begin : pipe_stages_2
      always @(posedge pipe_clk)
      begin
        if (!rst_n)
        begin
          pipe_tx_rcvr_det_q <= #TCQ 1'b0;
          pipe_tx_reset_q <= #TCQ 1'b1;
          pipe_tx_rate_q <= #TCQ 2'b0;
          pipe_tx_deemph_q <= #TCQ 1'b1;
          pipe_tx_margin_q <= #TCQ 1'b0;
          pipe_tx_swing_q <= #TCQ 1'b0;
          pipe_tx_eqfs_q <= #TCQ 5'b0;
          pipe_tx_eqlf_q <= #TCQ 5'b0;
          pipe_tx_rcvr_det_qq <= #TCQ 1'b0;
          pipe_tx_reset_qq <= #TCQ 1'b1;
          pipe_tx_rate_qq <= #TCQ 2'b0;
          pipe_tx_deemph_qq <= #TCQ 1'b1;
          pipe_tx_margin_qq <= #TCQ 1'b0;
          pipe_tx_swing_qq <= #TCQ 1'b0;
          pipe_tx_eqfs_qq <= #TCQ 5'b0;
          pipe_tx_eqlf_qq <= #TCQ 5'b0;
        end
        else
        begin
          pipe_tx_rcvr_det_q <= #TCQ pipe_tx_rcvr_det_i;
          pipe_tx_reset_q <= #TCQ pipe_tx_reset_i;
          pipe_tx_rate_q <= #TCQ pipe_tx_rate_i;
          pipe_tx_deemph_q <= #TCQ pipe_tx_deemph_i;
          pipe_tx_margin_q <= #TCQ pipe_tx_margin_i;
          pipe_tx_swing_q <= #TCQ pipe_tx_swing_i;
          pipe_tx_eqfs_q <= #TCQ pipe_tx_eqfs_i;
          pipe_tx_eqlf_q <= #TCQ pipe_tx_eqlf_i;
          pipe_tx_rcvr_det_qq <= #TCQ pipe_tx_rcvr_det_q;
          pipe_tx_reset_qq <= #TCQ pipe_tx_reset_q;
          pipe_tx_rate_qq <= #TCQ pipe_tx_rate_q;
          pipe_tx_deemph_qq <= #TCQ pipe_tx_deemph_q;
          pipe_tx_margin_qq <= #TCQ pipe_tx_margin_q;
          pipe_tx_swing_qq <= #TCQ pipe_tx_swing_q;
          pipe_tx_eqfs_qq <= #TCQ pipe_tx_eqfs_q;
          pipe_tx_eqlf_qq <= #TCQ pipe_tx_eqlf_q;
        end
      end
      assign pipe_tx_rcvr_det_o = pipe_tx_rcvr_det_qq;
      assign pipe_tx_reset_o = pipe_tx_reset_qq;
      assign pipe_tx_rate_o = pipe_tx_rate_qq;
      assign pipe_tx_deemph_o = pipe_tx_deemph_qq;
      assign pipe_tx_margin_o = pipe_tx_margin_qq;
      assign pipe_tx_swing_o = pipe_tx_swing_qq;
      assign pipe_tx_eqfs_o = pipe_tx_eqfs_qq;
      assign pipe_tx_eqlf_o = pipe_tx_eqlf_qq;
    end
    else
    begin
      assign pipe_tx_rcvr_det_o = pipe_tx_rcvr_det_i;
      assign pipe_tx_reset_o = pipe_tx_reset_i;
      assign pipe_tx_rate_o = pipe_tx_rate_i;
      assign pipe_tx_deemph_o = pipe_tx_deemph_i;
      assign pipe_tx_margin_o = pipe_tx_margin_i;
      assign pipe_tx_swing_o = pipe_tx_swing_i;
      assign pipe_tx_eqfs_o = pipe_tx_eqfs_i;
      assign pipe_tx_eqlf_o = pipe_tx_eqlf_i;
    end
  endgenerate

endmodule
