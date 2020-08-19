###############################################################################
#	DuneNvmeTestTop.xdc	Constraints for DuneNvmeTestTop on a HTG-K800
#	T.Barnaby,	Beam Ltd.	2020-02-23
###############################################################################
#
# @class	DuneNvmeTestOsperoTop
# @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
# @date		2020-06-12
# @version	0.9.0
#
# @brief
# This module implements a complete test design for the NvmeStorage system with
# the HTG-K800 and AB17-M2FMC boards. Editied from KCU105 build by Adam Gillard
# (ag17009@bristol.ac.uk).
#
# @details
# The FPGA bit file produced allows a host computer to access a NVMe storage device
# connected to the FPGA via the hosts PCIe interface. It has a simple test data source
# and allows a host computer program to communicate with the NVMe device for research
# and development test work.
# See the DuneNvmeStorageManual for more details.
# 
#
# @copyright 2020 Beam Ltd, Apache License, Version 2.0
# Copyright 2020 Beam Ltd
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# System timings
create_clock -period 10.000 -name pci_clk [get_ports pci_clk_p]
create_clock -period 10.000 -name nvme_clk [get_ports nvme_clk_p]

# CDC crossings
set_false_path -to [get_cells -hier sendCdcReg1*]
set_false_path -to [get_cells -hier recvCdcReg1*]

# Asynchronous resets
set_false_path -from [get_ports sys_reset]
set_false_path -from [get_ports pci_reset_n]
set_false_path -through [get_nets -hier -filter {NAME=~ */nvmeStorageUnit*/reset_local}]

set_false_path -through [get_nets -hier -filter {NAME=~ */nvmeStorageUnit*/phy_rdy_out}]
set_false_path -through [get_nets -hier -filter {NAME=~ */nvmeStorageUnit*/user_lnk_up}]

# Output pins
set_output_delay -clock [get_clocks nvme_clk] -min 0.0 [get_ports -filter NAME=~nvme_reset_n]
set_output_delay -clock [get_clocks nvme_clk] -max 1000.0 [get_ports -filter NAME=~nvme_reset_n]
set_false_path -to [get_ports -filter NAME=~nvme_reset_n]

set_output_delay -clock [get_clocks nvme_clk] -min 0.0 [get_ports -filter NAME=~leds*]
set_output_delay -clock [get_clocks nvme_clk] -max 1000.0 [get_ports -filter NAME=~leds*]
set_false_path -to [get_ports -filter NAME=~leds*]

# General settings
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# System Clock
set_property PACKAGE_PIN AL12 [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports sys_clk_p]

# PCIe Host interface
set_property PACKAGE_PIN AE15 [get_ports pci_reset_n]
set_property PULLUP true [get_ports pci_reset_n]
set_property IOSTANDARD LVCMOS18 [get_ports pci_reset_n]
set_property LOC GTHE3_COMMON_X1Y1 [get_cells pci_clk_buf0]
set_property PACKAGE_PIN AK9 [get_ports pci_clk_n]
set_property PACKAGE_PIN AK10 [get_ports pci_clk_p]
set_property LOC PCIE_3_1_X0Y0 [get_cells pcie_host0/inst/pcie3_ip_i/U0/pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/PCIE_3_1_inst]

# CPU Reset
set_property PACKAGE_PIN D36 [get_ports sys_reset]
set_property PULLUP false [get_ports sys_reset]
set_property IOSTANDARD LVCMOS18 [get_ports sys_reset]

# LED's
set_property IOSTANDARD LVCMOS18 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[7]}]
set_property DRIVE 12 [get_ports {leds[0]}]
set_property DRIVE 12 [get_ports {leds[1]}]
set_property DRIVE 12 [get_ports {leds[2]}]
set_property DRIVE 12 [get_ports {leds[3]}]
set_property DRIVE 12 [get_ports {leds[4]}]
set_property DRIVE 12 [get_ports {leds[5]}]
set_property DRIVE 12 [get_ports {leds[6]}]
set_property DRIVE 12 [get_ports {leds[7]}]
set_property SLEW SLOW [get_ports {leds[0]}]
set_property SLEW SLOW [get_ports {leds[1]}]
set_property SLEW SLOW [get_ports {leds[2]}]
set_property SLEW SLOW [get_ports {leds[3]}]
set_property SLEW SLOW [get_ports {leds[4]}]
set_property SLEW SLOW [get_ports {leds[5]}]
set_property SLEW SLOW [get_ports {leds[6]}]
set_property SLEW SLOW [get_ports {leds[7]}]
set_property PACKAGE_PIN J31 [get_ports {leds[0]}]
set_property PACKAGE_PIN H31 [get_ports {leds[1]}]
set_property PACKAGE_PIN J29 [get_ports {leds[2]}]
set_property PACKAGE_PIN G31 [get_ports {leds[3]}]
set_property PACKAGE_PIN K30 [get_ports {leds[4]}]
set_property PACKAGE_PIN M26 [get_ports {leds[5]}]
set_property PACKAGE_PIN L28 [get_ports {leds[6]}]
set_property PACKAGE_PIN M32 [get_ports {leds[7]}]

# PCie Nvme interfaces
set_property PACKAGE_PIN J20 [get_ports nvme_reset_n]
set_property IOSTANDARD LVCMOS18 [get_ports nvme_reset_n]
set_property PACKAGE_PIN AC8 [get_ports {nvme_clk_p}]
set_property PACKAGE_PIN AC7 [get_ports {nvme_clk_n}]

# PCIe Nvme0 interface
set_property LOC GTHE3_CHANNEL_X1Y13 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X1Y15 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X1Y14 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*gen_gthe3_channel_inst[2].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X1Y12 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*gen_gthe3_channel_inst[3].GTHE3_CHANNEL_PRIM_INST}]

set_property LOC PCIE_3_1_X0Y2 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/PCIE_3_1_inst}]
set_property LOC RAMB36_X8Y57 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_rep_inst/bram_rep_8k_inst/RAMB36E2[0].ramb36e2_inst}]
set_property LOC RAMB36_X8Y58 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_rep_inst/bram_rep_8k_inst/RAMB36E2[1].ramb36e2_inst}]
set_property LOC RAMB18_X8Y98 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[0].ramb18e2_inst}]
set_property LOC RAMB18_X8Y99 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[1].ramb18e2_inst}]
set_property LOC RAMB18_X8Y100 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[2].ramb18e2_inst}]
set_property LOC RAMB18_X8Y101 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[3].ramb18e2_inst}]
set_property LOC RAMB18_X8Y104 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[0].ramb18e2_inst}]
set_property LOC RAMB18_X8Y105 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[1].ramb18e2_inst}]
set_property LOC RAMB18_X8Y106 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[2].ramb18e2_inst}]
set_property LOC RAMB18_X8Y107 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[3].ramb18e2_inst}]


# PCIe Nvme1 interface
set_property LOC GTHE3_CHANNEL_X1Y10 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X1Y8 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X1Y9 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*gen_gthe3_channel_inst[2].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X1Y11 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*gen_gthe3_channel_inst[3].GTHE3_CHANNEL_PRIM_INST}]

set_property LOC PCIE_3_1_X0Y1 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/PCIE_3_1_inst}]

set_property LOC RAMB36_X8Y45 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_rep_inst/bram_rep_8k_inst/RAMB36E2[0].ramb36e2_inst}]
set_property LOC RAMB36_X8Y46 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_rep_inst/bram_rep_8k_inst/RAMB36E2[1].ramb36e2_inst}]
set_property LOC RAMB18_X8Y74 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[0].ramb18e2_inst}]
set_property LOC RAMB18_X8Y75 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[1].ramb18e2_inst}]
set_property LOC RAMB18_X8Y76 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[2].ramb18e2_inst}]
set_property LOC RAMB18_X8Y77 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[3].ramb18e2_inst}]
set_property LOC RAMB18_X8Y80 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[0].ramb18e2_inst}]
set_property LOC RAMB18_X8Y81 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[1].ramb18e2_inst}]
set_property LOC RAMB18_X8Y82 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[2].ramb18e2_inst}]
set_property LOC RAMB18_X8Y83 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[3].ramb18e2_inst}]