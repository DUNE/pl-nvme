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
VIVADO_PATH	?= /opt/Xilinx/Vivado/2019.2/bin
VIVADO_TARGET	?= "-url study.kingnet:3121 -allow_non_jtag"

# Files for synthesis
SYN_FILES	= ../src/NvmeStoragePkg.vhd ../src/NvmeStorageIntPkg.vhd
SYN_FILES	+= ../src/Ram.vhd
SYN_FILES	+= ../src/RegAccessClockConvertor.vhd
SYN_FILES	+= ../src/AxisClockConverter.vhd
SYN_FILES	+= ../src/AxisDataConvertFifo.vhd
SYN_FILES	+= ../src/NvmeStreamMux.vhd
SYN_FILES	+= ../src/PcieStreamMux.vhd
SYN_FILES	+= ../src/StreamSwitch.vhd
SYN_FILES	+= ../src/NvmeSim.vhd
SYN_FILES	+= ../src/NvmeQueues.vhd
SYN_FILES	+= ../src/NvmeConfig.vhd
SYN_FILES	+= ../src/NvmeWrite.vhd
SYN_FILES	+= ../src/NvmeRead.vhd
SYN_FILES	+= ../src/NvmeStorageUnit.vhd
SYN_FILES	+= ../src/NvmeStorage.vhd
SYN_FILES	+= ../src/TestData.vhd
SYN_FILES	+= ../src/DuneNvmeTestTop.vhd

# IP cores
XCI_FILES	= ../src/ip/Clk_core.xci
XCI_FILES	+= ../src/ip/Pcie_host.xci
XCI_FILES	+= ../src/ip/Axis_clock_converter.xci
#XCI_FILES	+= ../src/ip/Pcie_nvme.xci
XCI_FILES	+= ../src/ip/Pcie_nvme0.xci
XCI_FILES	+= ../src/ip/Pcie_nvme1.xci

# XDC files
XDC_FILES	= ../src/DuneNvmeTestTop.xdc

include Vivado.mk

sync_ip:
	mkdir -p ../src/ip
	cp -a ${PROJECT}.srcs/sources_1/ip/*/*.xci ../src/ip

start_hw_server:
	${VIVADO_PATH}/hw_server
