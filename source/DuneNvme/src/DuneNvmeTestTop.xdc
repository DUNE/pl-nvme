###############################################################################
#	DuneNvmeTestTop.xdc	Constraints for DuneNvmeTestTop on a KCU105
#	T.Barnaby,	Beam Ltd.	2020-02-23
###############################################################################
#

# System timings
create_clock -period 5.000 -name sys_clk_p -waveform {0.000 2.500} [get_ports sys_clk_p]
create_clock -period 10.000 -name pci_clk [get_ports pci_clk_p]
create_clock -period 10.000 -name nvme_clk [get_ports nvme_clk_p]

# Asyncronous resets
set_false_path -from [get_ports sys_reset]
set_false_path -from [get_ports pci_reset_n]
set_false_path -through [get_nets boot_reset]
set_false_path -through [get_nets sys_reset_buf_n]

# PCIe Host
#set_false_path -through [get_pins pcie_host0/inst/pcie3_ip_i/inst/pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/PCIE_3_1_inst/CFGMAX*]
set_false_path -through [get_pins pcie_host0/inst/pcie3_ip_i/U0/pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/PCIE_3_1_inst/CFGMAX*]
set_false_path -through [get_nets pcie_host0/inst/cfg_max*]
set_false_path -to [get_pins -hier *sync_reg[0]/D]

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

# PCIe Nvme0 interface
set_property PACKAGE_PIN H11 [get_ports nvme_reset_n]
set_property PULLUP true [get_ports nvme_reset_n]
set_property IOSTANDARD LVCMOS18 [get_ports nvme_reset_n]
#set_property LOC GTHE3_COMMON_X0Y1 [get_cells nvme_clk_buf0]

set_property PACKAGE_PIN K6 [get_ports {nvme_clk_p}]
set_property PACKAGE_PIN K5 [get_ports {nvme_clk_n}]
