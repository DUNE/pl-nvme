Dune NVMe Storage System
===========================

This directory contains the source code for the Dune NvmeStorage system together with a simple
NVMe test environment. It contains the FPGA VHDL source code, simulation environment and build
environment for the Nvme test FPGA firmware and the nvme_test host software.

Please see the documentation in the doc directory.

The directory contains build environments for the following FPGA/NVMe board configurations:

- KCU105 + Design Gateway AB17-M2FMC
- KCU105 + Opsero 047
- HiTech Global K800 + Design Gateway AB17-M2FMC
- VCU118 + Design Gateway AB17-M2FMC

---
## Prerequisites
- Xilinx 2019.2

---
## Important Notes
- For K800 Build: the Design Gateway AB17-M2FMC must be used in connector J3
- Refer to user guide of relevant board for jumper settings
- PCIe interface to host is X4 on all builds
- Refer to documentation in doc directory for KCU105-specific details. These details can also be useful for builds on other platforms.

---
## Usage instructions
1. Clone the git repo: 
    `git clone --single-branch -branch allBuilds/master <GIT URL>`

2. Change to the vivado directory: `cd vivado`

3. Copy the template config: `mv Config-template.mk Config.mk`

4. Edit the vivado *Config.mk* for desired hardware:

    Daughter board selection is made via *CARD*:
        - `DesignGateway` - Design Gateway AB17-M2FMC
        - `Opsero` - Opsero 047

    Board selection is made via *BOARD_NAME* (case sensitive):
        - `KCU105` - Kintex Ultrascale KCU105
        - `K800` - HiTech Global K800
        - `VCU118` - Virtex Ultrascale + VCU118

5. Create the Vivado project file: `make project`

6. The resulting project can be synthesised and implemented in GUI or flow using Vivado 2019.2.
