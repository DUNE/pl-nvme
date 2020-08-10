This directory cantains the source code for the DUNE NvmeStorage system with a simple test environment. It contains the FPGA VHDL source code, simulation environment and build environment for the Nvme test FPGA firmware and the nvme_test host software.

The directory contains build environments for the following FPGA/NVMe board configurations:

- KCU105 + Design Gateway AB17-M2FMC
- KCU105 + Opsero 047
- HiTech Global K800 + Design Gateway AB17-M2FMC
- VCU118 + Design Gateway AB17-M2FMC
- 

---

## Prerequisites

- Xilinx 2019.2

---

## Important Notes

- For K800 Build: the Design Gateway AB17-M2FMC must be used in connector J3
- Refer to user guide of relevant board for jumper settings:
    - PCIe interface to host is X4 on all builds
- Refer to documentation in doc directory for KCU105-specific details. These details can also be useful for builds on other platforms.

---

## Useage instructions

1. Clone the git repo: 

    `git clone --single-branch -branch allBuilds/master https://github.come/DUNE/pl-nvme.git`

2. Edit the vivado *Config-template.mk* for desired hardware:
    1. `cd vivado`
    2. Daughter board selection is made via *PROJECT:*
        - `DuneNvme` - Design Gateway AB17-M2FMC
        - `DuneNvmeOpsero` - Opsero 047
    3. Board selection is made via *BOARD_NAME* (case sensitive):
        - `KCU105` - Kintex Ultrascale KCU105
        - `K800` - HiTech Global K800
        - `VCU118` - Virtex Ultrascale + VCU118
3. `mv Config-template.mk Config.mk`
4. `make project`
5. The resulting project can be synthesised and implemented in GUI or flow using Vivado 2019.2.