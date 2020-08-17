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
// File       : Pcie_nvme0_rx_buffer_per_lane.v
// Version    : 4.4 
//-----------------------------------------------------------------------------

/////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

`define EIEOS_2BYTES_G3   16'hFF00

`define XPREG(clk, reset_n, q,d,rstval)          \
    always @(posedge clk)                        \
    begin                                        \
     if (reset_n == 1'b0)                        \
         q <= #(TCQ) rstval;                     \
     else                                        \
         q <= #(TCQ)  d;                         \
     end


module Pcie_nvme0_rx_buffer_per_lane #(
    parameter           TCQ = 100,
    parameter           LANE = 0,
    parameter           DEPTH = 4,
    parameter           WIDTH = 39,
    parameter           STYLE = "REG",
    parameter           PL_UPSTREAM_FACING = "TRUE",
    parameter           IMPL_TARGET = "SOFT",
    parameter ADDRW = (DEPTH<=2)    ? 1:
                      (DEPTH<=4)    ? 2:
                      (DEPTH<=8)    ? 3:
                      (DEPTH<=16)   ? 4:
                      (DEPTH<=32)   ? 5:
                      (DEPTH<=64)   ? 6:
                      (DEPTH<=128)  ? 7:
                      (DEPTH<=256)  ? 8:
                      (DEPTH<=512)  ? 9:
                      (DEPTH<=1024) ?10:
                      (DEPTH<=2048) ?11:
                      (DEPTH<=4096) ?12:
                      (DEPTH<=8192) ?13:
                      (DEPTH<=16384)?14: -1

    )
    (
    input               clk,
    input               reset_n,
    input [5:0]         cfg_ltssm_state,
    input [1:0]         tx_rate,
    input [31:0]        rx_data_in,
    input               rx_valid_in,
    input [2:0]         rx_status_in,
    input               rx_start_block_in,
    input [1:0]         rx_sync_header_in,
    input               eieos_found_all_in,
    output [31:0]       rx_data_out,
    output              rx_valid_out,
    output [2:0]        rx_status_out,
    output [1:0]        rx_sync_header_out,
    output              rx_start_block_out,
    output              eieos_found
    );

    reg wr_en, check_eie_nxt, check_eie_ff, eie_found_nxt, eie_found_ff, rd_en_ff;
    reg [8:0]   cnt_ff, cnt_nxt;
    wire afull;
    wire cfull; 
    wire cempty; 
    wire aempty;
    wire [38:0] fifo_out; 
    wire rd_en = (eieos_found_all_in & ~cempty) ? 1'b1 : 'b0;
    //wire rd_en = 1'b0;
    wire [ADDRW:0] data_count;
    wire eieos = ((rx_data_in[15:0] ==  `EIEOS_2BYTES_G3) & (rx_start_block_in)) & (rx_sync_header_in == 2'b01) & rx_valid_in;
    wire in_l0 = (cfg_ltssm_state == 6'h10);
    wire in_detect = (cfg_ltssm_state == 6'h00);
    wire in_rec_speed = (cfg_ltssm_state == 6'h0C);
    wire in_rec_lck = (PL_UPSTREAM_FACING == "TRUE") ? ((cfg_ltssm_state == 6'h28) | (cfg_ltssm_state == 6'h0B)) : ((cfg_ltssm_state == 6'h29) | (cfg_ltssm_state == 6'h0B));
    wire in_gen3 = tx_rate[1];
    wire reset_eie = ~tx_rate[1] | (in_rec_lck & in_gen3 & ~check_eie_ff) | (in_detect) | (in_rec_speed);
    wire [38:0] fifo_in;

    always @* begin
        cnt_nxt = cnt_ff;
        check_eie_nxt = check_eie_ff;
        if(in_rec_lck & in_gen3) begin
            if(cnt_ff <= 'd500) begin
                check_eie_nxt = 'b0;
                cnt_nxt = cnt_ff +1;
            end else begin
                check_eie_nxt = 1'b1;
            end
        end else begin
            cnt_nxt = 'b0;
            check_eie_nxt = 'b0;
        end
    end

    always @* begin
        eie_found_nxt = eie_found_ff;
        if(check_eie_ff & ~eie_found_ff) begin
            eie_found_nxt = eieos; // can be used as wr_en
        end
        if(reset_eie) begin
            eie_found_nxt = 'b0;
        end
    end


  Pcie_nvme0_sync_fifo #(
    .TCQ(TCQ),
    .WIDTH(WIDTH),
    .DEPTH(DEPTH),
    .STYLE("REG"),
    .AFASSERT(4),
    .AEASSERT(1),
    .ADDRW(ADDRW)
    ) sync_fifo_inst (
   .clk(clk),
   .rst_n(reset_n),
   .load(reset_eie),
   .din(fifo_in),
   .dout(fifo_out[WIDTH-1:0]),
   .wr_en(eie_found_nxt),
   .rd_en(rd_en),
   .full(cfull),
   .afull(afull),
   .empty(cempty),
   .aempty(aempty),
   .data_count(data_count)
   );    


    assign fifo_in = {rx_valid_in, rx_start_block_in, rx_sync_header_in, rx_status_in, rx_data_in};
    assign rx_data_out = tx_rate[1] ? (eieos_found_all_in ? fifo_out[31:0] : 'b0) : rx_data_in;
    assign rx_valid_out = tx_rate[1] ? (eieos_found_all_in ? fifo_out[38] : 'b0) : rx_valid_in; 
    assign rx_status_out = tx_rate[1] ? (eieos_found_all_in ? fifo_out[34:32] : 'b0) : rx_status_in;
    assign rx_start_block_out = tx_rate[1] ? (eieos_found_all_in ? fifo_out[37] : 'b0) : rx_start_block_in;
    assign rx_sync_header_out = tx_rate[1] ? (eieos_found_all_in ? fifo_out[36:35] : 'b0) : rx_sync_header_in;
    assign eieos_found = eie_found_ff;
    //assign rx_elec_idle_out = (&cfg_rx_pm_state) ? 1'b0 : (rx_l0s_en_ff & rd_en_ff) ? fifo_out[39] : rx_elec_idle_in_eff;
    //

    `XPREG(clk, reset_n, check_eie_ff, check_eie_nxt, 1'b0)
    `XPREG(clk, reset_n, eie_found_ff, eie_found_nxt, 1'b0)
    `XPREG(clk, reset_n, rd_en_ff, rd_en, 1'b0)
    `XPREG(clk, reset_n, cnt_ff, cnt_nxt, 9'b0)

endmodule
    

