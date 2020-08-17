#!/bin/sh

# 
# Vivado(TM)
# runme.sh: a Vivado-generated Runs Script for UNIX
# Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
# 

if [ -z "$PATH" ]; then
  PATH=/software/CAD/Xilinx/2019.2/Vitis/2019.2/bin:/software/CAD/Xilinx/2019.2/Vivado/2019.2/ids_lite/ISE/bin/lin64:/software/CAD/Xilinx/2019.2/Vivado/2019.2/bin
else
  PATH=/software/CAD/Xilinx/2019.2/Vitis/2019.2/bin:/software/CAD/Xilinx/2019.2/Vivado/2019.2/ids_lite/ISE/bin/lin64:/software/CAD/Xilinx/2019.2/Vivado/2019.2/bin:$PATH
fi
export PATH

if [ -z "$LD_LIBRARY_PATH" ]; then
  LD_LIBRARY_PATH=
else
  LD_LIBRARY_PATH=:$LD_LIBRARY_PATH
fi
export LD_LIBRARY_PATH

HD_PWD='/usersc/ag17009/NVMe/BlockFormatting/Test/pl-nvme/vivado/DuneNvmeTest.runs/axis_fifo_cc_512_x_16_synth_1'
cd "$HD_PWD"

HD_LOG=runme.log
/bin/touch $HD_LOG

ISEStep="./ISEWrap.sh"
EAStep()
{
     $ISEStep $HD_LOG "$@" >> $HD_LOG 2>&1
     if [ $? -ne 0 ]
     then
         exit
     fi
}

EAStep vivado -log axis_fifo_cc_512_x_16.vds -m64 -product Vivado -mode batch -messageDb vivado.pb -notrace -source axis_fifo_cc_512_x_16.tcl
