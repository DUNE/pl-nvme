################################################################################
#	Makefile	Build FPGA bit file from sources
#			T.Barnaby,	BEAM Ltd,	2020-02-18
################################################################################
#
# Targets
#  all:		Build everything to the FPGA bit file
#  program	Program the FPGA over jtag
#  clean:	Remove output files and project files
#  distclean:	Clean all files
#
# Project and FPGA settings
PROJECT 	= nvme-test
BOARD		= xilinx.com:kcu105:part0:1.6
FPGA_PART	= xcku040-ffva1156-2-e
FPGA_TOP	= DuneNvmeTestTop

# Files for synthesis
SYN_FILES	= ../src/AxiPkg.vhd ../src/NvmeStoragePkg.vhd
SYN_FILES	+= ../src/AxilClockConverter.vhd
SYN_FILES	+= ../src/AxisClockConverter.vhd
SYN_FILES	+= ../src/AxisStreamMux.vhd
SYN_FILES	+= ../src/AxisStreamDeMux.vhd
SYN_FILES	+= ../src/NvmeStorage.vhd
SYN_FILES	+= ../src/DuneNvmeTestTop.vhd

# IP cores
XCI_FILES	= ../src/ip/Clk_core.xci
XCI_FILES	+= ../src/ip/Pcie_host.xci
XCI_FILES	+= ../src/ip/Axil_clock_converter.xci
XCI_FILES	+= ../src/ip/Axis_clock_converter.xci
XCI_FILES	+= ../src/ip/Pcie_nvme0.xci
XCI_FILES	+= ../src/ip/blk_mem_gen_0.xci

# XDC files
XDC_FILES	= ../src/DuneNvmeTestTop.xdc

include vivado.mk

#program: $(PROJECT).bit
program:
	echo "open_hw" > program.tcl
	echo "connect_hw_server" >> program.tcl
	echo "open_hw_target" >> program.tcl
	echo "current_hw_device [lindex [get_hw_devices] 0]" >> program.tcl
	echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> program.tcl
	echo "set_property PROGRAM.FILE {$(PROJECT).bit} [current_hw_device]" >> program.tcl
	echo "program_hw_devices [current_hw_device]" >> program.tcl
	echo "exit" >> program.tcl
	vivado -nojournal -nolog -mode batch -source program.tcl

sync_ip:
	mkdir -p ../src/ip
	cp -a ${PROJECT}.srcs/sources_1/ip/*/*.xci ../src/ip

start_hw_server:
	/opt/Xilinx/Vivado/2019.2/bin/hw_server
