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
// File       : Pcie_nvme1_sync_fifo.v
// Version    : 4.4 
//-----------------------------------------------------------------------------

/////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

`define XLREG_EDGE(clkedge,clk,rstedge,rst) \
    always @(clkedge clk)


module Pcie_nvme1_sync_fifo 
  #(
    parameter TCQ      = 100,
    parameter WIDTH    = 32,
    parameter DEPTH    = 16,
    parameter STYLE    = "REG",  //Choices: SRL, REG
    parameter AFASSERT = DEPTH-1,
    parameter AEASSERT = 1,
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
   input  wire             clk,
   input  wire             rst_n,
   input  wire             load,
   input  wire [WIDTH-1:0] din,
   output wire [WIDTH-1:0] dout,
   input  wire             wr_en,
   input  wire             rd_en,
   output reg              full,
   output reg              afull,
   output wire             empty,
   output wire             aempty,
   output wire [ADDRW:0]   data_count
   );


   reg    [WIDTH-1:0] regBank         [DEPTH-1:0];
   wire   [WIDTH-1:0] dout_int;
   reg    [ADDRW:0]   data_count_int;
   reg    [ADDRW-1:0] data_count_m1;
   reg                empty_int;
   reg                aempty_int;
   wire               rd_en_int;
   (* keep = "true", max_fanout = 500 *)  wire               wr_en_int;
   integer            i;

//{{{ Choose external IO drivers based on mode
// Read Enable must be qualified with Empty; for FWFT, internal logic drives
assign rd_en_int = (rd_en && !empty_int);
// Write Enable must be qualified with Full
assign wr_en_int = wr_en && !full;
// Dout is the output register stage in FWFT mode
assign dout   = dout_int;
//Empty indicates that the output stage is not valid in FWFT mode
assign empty  = empty_int;
//Aempty may be assert 1 cycle soon for FWFT
assign aempty = aempty_int;
assign data_count = data_count_int;
//}}}


//{{{ Infer Memory 
//{{{ SRL 16 should be inferred
generate if (STYLE=="SRL")  begin: srl_style_fifo

   // synthesis translate_off
   initial
   begin
      for (i=0; i < (WIDTH-1); i=i+1)
         regBank[i] = 0;
   end
   always @(posedge clk) begin
    if(load) begin
        $display("SRL sync fifo and Load is not supported");
        $finish;
    end
   end
   // synthesis translate_on

   //Write to SRL inputs, and shift SRL
   always @(posedge clk) begin
      if (wr_en_int) begin
         for (i=(DEPTH-1); i>0; i=i-1)
            regBank[i] <= #TCQ regBank[i-1];
         regBank[0]    <= #TCQ din;
      end
   end
 
   wire [ADDRW-1:0] data_count_int_trunc = data_count_int[ADDRW-1:0];
   assign dout_int                       = regBank[data_count_int_trunc];
//}}}

//{{{ REGISTERs should be inferred
end else begin: reg_style_fifo //STYLE==REG
   reg    [WIDTH-1:0] dout_reg;

   //Write to register bank input, and shift other entries
`XLREG_EDGE(posedge,clk,negedge,rst_n)
    begin
      if (!rst_n)
         for (i=(DEPTH-1); i>=0; i=i-1) regBank[i] <= #TCQ 'b0;
      else if (load)
         for (i=(DEPTH-1); i>=0; i=i-1) regBank[i] <= #TCQ 'b0;
      else if (wr_en_int) begin
         for (i=(DEPTH-1); i>0; i=i-1)  regBank[i] <= #TCQ regBank[i-1];
         regBank[0]    <= #TCQ din;
      end
   end

   //Capture muxed output based or read counter
`XLREG_EDGE(posedge,clk,negedge,rst_n)
  begin
      if (!rst_n)
        dout_reg <= #TCQ 'b0;
      else if (load)
        dout_reg <= #TCQ 'b0;
      else if (rd_en_int)
        dout_reg <= #TCQ regBank[data_count_m1];
  end

  assign dout_int = dout_reg;
end
endgenerate
//}}} //}}}

//{{{ SRL/Reg Address Logic; SRL/Reg/BRAM flag logic
`XLREG_EDGE(posedge,clk,negedge,rst_n)
 begin
    if (!rst_n) begin
       data_count_int  <= #TCQ {(ADDRW+1){1'h0}};
       data_count_m1   <= #TCQ {(ADDRW){1'b1}};
       full            <= #TCQ 1'b0;
       afull           <= #TCQ 1'b0;
    // read from non-empty FIFO, not writing to FIFO
    end else if (load) begin
       data_count_int  <= #TCQ {(ADDRW+1){1'h0}};
       data_count_m1   <= #TCQ {(ADDRW){1'b1}};
       full            <= #TCQ 1'b0;
       afull           <= #TCQ 1'b0;
    // read from non-empty FIFO, not writing to FIFO
    end else if (rd_en_int && !wr_en_int) begin
       data_count_int  <= #TCQ data_count_int - 1;
       data_count_m1   <= #TCQ data_count_m1  - 1;
       full            <= #TCQ 1'b0;
       if (data_count_int == AFASSERT[ADDRW:0])
         afull           <= #TCQ 1'b0;
    // write into non-full FIFO, not reading from FIFO
    end else if (!rd_en_int && wr_en_int) begin
       data_count_int  <= #TCQ data_count_int + 1;
       data_count_m1   <= #TCQ data_count_m1  + 1;
       if (data_count_int == (DEPTH-1))
         full            <= #TCQ 1'b1;
       if (data_count_int == (AFASSERT-1))
         afull           <= #TCQ 1'b1;
    end
 end
//}}}

//Calculate empty/almost-empty values
`XLREG_EDGE(posedge,clk,negedge,rst_n)
   begin
       if (!rst_n) begin
          empty_int       <= #TCQ 1'b1;
          aempty_int      <= #TCQ 1'b1;
       // read from non-empty FIFO, not writing to FIFO
       end else if (load) begin
          empty_int       <= #TCQ 1'b1;
          aempty_int      <= #TCQ 1'b1;
       // read from non-empty FIFO, not writing to FIFO
       end else if (rd_en_int && !wr_en_int) begin
          if (data_count_int == 1)
            empty_int       <= #TCQ 1'b1;
          if (data_count_int == (AEASSERT+1))
            aempty_int      <= #TCQ 1'b1;
       // write into non-full FIFO, not reading from FIFO
       end else if (!rd_en_int && wr_en_int) begin
          empty_int       <= #TCQ 1'b0;
          if (data_count_int == AEASSERT)
            aempty_int      <= #TCQ 1'b0;
       end
   end
endmodule
