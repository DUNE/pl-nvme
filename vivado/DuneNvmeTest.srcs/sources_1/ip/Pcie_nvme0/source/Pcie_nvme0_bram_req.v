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
// File       : Pcie_nvme0_bram_req.v
// Version    : 4.4 
//-----------------------------------------------------------------------------

/////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

module Pcie_nvme0_bram_req 
 #(
  parameter TCQ = 100
  ) (
  input  wire         clk_i,
  input  wire         reset_i,
  input  wire   [8:0] waddr0_i,
  input  wire   [8:0] waddr1_i,
  input  wire [127:0] wdata_i,
  input  wire  [15:0] wdip_i,
  input  wire         wen0_i,
  input  wire         wen1_i,
  input  wire         wen2_i,
  input  wire         wen3_i,
  input  wire   [8:0] raddr0_i,
  input  wire   [8:0] raddr1_i,
  output wire [127:0] rdata_o,
  output wire  [15:0] rdop_o,
  input  wire         ren0_i,
  input  wire         ren1_i,
  input  wire         ren2_i,
  input  wire         ren3_i
  );

  Pcie_nvme0_bram_req_8k 
 #(
    .TCQ (TCQ))
  bram_req_8k_inst (
    .clk_i (clk_i),
    .reset_i (reset_i),
    .waddr0_i (waddr0_i[8:0]),
    .waddr1_i (waddr1_i[8:0]),
    .wdata_i (wdata_i[127:0]),
    .wdip_i (wdip_i[15:0]),
    .wen_i ({wen3_i, wen2_i, wen1_i, wen0_i}),
    .raddr0_i (raddr0_i[8:0]),
    .raddr1_i (raddr1_i[8:0]),
    .rdata_o (rdata_o[127:0]),
    .rdop_o (rdop_o[15:0]),
    .ren_i ({ren3_i, ren2_i, ren1_i, ren0_i})
  );

endmodule
