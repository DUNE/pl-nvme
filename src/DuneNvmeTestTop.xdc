###############################################################################
#	DuneNvmeTestTop.xdc	Constraints for DuneNvmeTestTop on a KCU105
#	T.Barnaby,	Beam Ltd.	2020-02-23
###############################################################################
#

# System timings
#create_clock -period 5.000 -name sys_clk_p -waveform {0.000 2.500} [get_ports sys_clk_p]
create_clock -period 10.000 -name pci_clk [get_ports pci_clk_p]
create_clock -period 10.000 -name nvme_clk [get_ports nvme_clk_p]

# CDC crossings
set_false_path -to [get_cells -hier sendCdcReg1*]
set_false_path -to [get_cells -hier recvCdcReg1*]

# Asynchronous resets
set_false_path -from [get_ports sys_reset]
set_false_path -from [get_ports pci_reset_n]
set_false_path -through [get_nets -hier -filter {NAME=~ */nvmeStorageUnit*/reset_local}]
#set_false_path -through [get_nets -hier -filter {NAME=~ */nvmeStorageUnit*/nvme_reset_local_n}]

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

# PCIe Host interface
set_property PACKAGE_PIN K22 [get_ports pci_reset_n]
set_property PULLUP true [get_ports pci_reset_n]
set_property IOSTANDARD LVCMOS18 [get_ports pci_reset_n]
set_property LOC GTHE3_COMMON_X0Y1 [get_cells pci_clk_buf0]

# CPU Reset
set_property PACKAGE_PIN AN8 [get_ports sys_reset]
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
set_property PACKAGE_PIN AP8 [get_ports {leds[0]}]
set_property PACKAGE_PIN H23 [get_ports {leds[1]}]
set_property PACKAGE_PIN P20 [get_ports {leds[2]}]
set_property PACKAGE_PIN P21 [get_ports {leds[3]}]
set_property PACKAGE_PIN N22 [get_ports {leds[4]}]
set_property PACKAGE_PIN M22 [get_ports {leds[5]}]
set_property PACKAGE_PIN R23 [get_ports {leds[6]}]
set_property PACKAGE_PIN P23 [get_ports {leds[7]}]

# PCie Nvme interfaces
set_property PACKAGE_PIN H11 [get_ports nvme_reset_n]
set_property IOSTANDARD LVCMOS18 [get_ports nvme_reset_n]
set_property PACKAGE_PIN K6 [get_ports {nvme_clk_p}]
set_property PACKAGE_PIN K5 [get_ports {nvme_clk_n}]
#set_property LOC GTHE3_COMMON_X0Y1 [get_cells nvme_clk_buf0]

# PCIe Nvme0 interface
set_property LOC GTHE3_CHANNEL_X0Y16 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X0Y17 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X0Y18 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*gen_gthe3_channel_inst[2].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X0Y19 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit0*gen_gthe3_channel_inst[3].GTHE3_CHANNEL_PRIM_INST}]

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
set_property LOC GTHE3_CHANNEL_X0Y12 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X0Y14 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X0Y13 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*gen_gthe3_channel_inst[2].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X0Y15 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*gen_gthe3_channel_inst[3].GTHE3_CHANNEL_PRIM_INST}]

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

#set_property LOC RAMB36_X8Y45 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_rep_inst/bram_rep_8k_inst/RAMB36E2[0].ramb36e2_inst}]
#set_property LOC RAMB36_X8Y46 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_rep_inst/bram_rep_8k_inst/RAMB36E2[1].ramb36e2_inst}]
#set_property LOC RAMB18_X8Y74 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[0].ramb18e2_inst}]
#set_property LOC RAMB18_X8Y75 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[2].ramb18e2_inst}]
#set_property LOC RAMB18_X8Y76 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[1].ramb18e2_inst}]
#set_property LOC RAMB18_X8Y77 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_req_inst/bram_req_8k_inst/RAMB18E2[3].ramb18e2_inst}]
#set_property LOC RAMB18_X8Y80 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[0].ramb18e2_inst}]
#set_property LOC RAMB18_X8Y81 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[2].ramb18e2_inst}]
#set_property LOC RAMB18_X8Y82 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[1].ramb18e2_inst}]
#set_property LOC RAMB18_X8Y83 [get_cells -hierarchical -filter {NAME =~ *nvmeStorageUnit1*pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/bram_inst/bram_cpl_inst/CPL_FIFO_16KB.bram_16k_inst/RAMB18E2[3].ramb18e2_inst}]
