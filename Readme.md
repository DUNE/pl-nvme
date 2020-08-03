This fileset is used to build the BEAM Inc DUNE NVMe firmware to a HiTech Global K800 FPGA Board.

---

This directory contains the source code for the Dune NvmeStorage system together with a simple
NVMe test environment that allows experimentation with the low level PCIe NVMe interfaces as
available on a Xilinx FPGA environment.
The directory contains the FPGA VHDL source code, simulation environment and build environment 
or the Nvme test FPGA firmware as well as the nvme_test host software.

Please see the documentation in the doc directory.

---

## Prerequisites

- Clone/Download of the adapted BEAM Inc DUNE NVMe Firmware found [here](https://github.com/DUNE/pl-nvme/tree/HTG-K800).
    - `git clone --branch HTG-K800 https://github.com/DUNE/pl-nvme/tree/HTG-K800`
- HTG-K800 FPGA Board
    - This documentation refers to FPGA part code *xcku115-flva1517-2-e* with *AB17-M2FMC*
- AB17-M2FMC Daughter Board
- 2x M.2 NVMe SSD installed on daughter board
- Xilinx Vivado 2019.2

---

## Important Notes

- **This build requires the AB17-M2FMC daughter board to be placed in K800 board port J3 (corresponding to FMC A)**

---

## Steps to Build Firmware

1. Clone the HTG-K800 NVMe firmware branch:

    `git clone --branch HTG-K800 https://github.com/DUNE/pl-nvme/tree/HTG-K800`

2. `cd pl-nvme/vivado`  
3. Use a text editor of choice to ensure the `VIVADO_PATH` and `VIVADO_TARGET` fields are correct for your system in *Config.mk*. NOTE: `PROJECT` field must be called *DuneNvmeTest*.
4. `make project` to build the vivado project file *DuneNvmeTest.xpr*
5. Open *DuneNvmeTest.xpr* in Vivado 2019.2 GUI
6. Click *Run Synthesis*
    - Choose your Launch Settings and click *OK*
7. Click *Run Implementation*
    - Choose your Launch Settings and click *OK*
8. Click *Generate Bitstream*
    - Choose your Launch Settings and click *OK*

Done!