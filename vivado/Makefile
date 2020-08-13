################################################################################
#	Makefile	Build FPGA bit file from sources
#			T.Barnaby,	BEAM Ltd,	2020-02-18
################################################################################
#
# Targets
#  all:		Build everything to the FPGA bit file
#  project:	Just build the Vivado project file
#  program	Program the FPGA over jtag
#  clean:	Remove output files and project files
#  distclean:	Clean all files
#

# Project and FPGA settings
-include Config.mk
PROJECT 	?= DuneNvme_${BOARD_NAME}_${CARD}
VIVADO_PATH	?= /opt/Xilinx/Vivado/2019.2/bin
VIVADO_TARGET	?= ""

ifeq (${CARD}, Opsero)
	FPGA_TOP	?= DuneNvme${CARD}Top
else
	FPGA_TOP	?= DuneNvmeTop
endif

ifeq (${BOARD_NAME}, KCU105)
	BOARD		?= xilinx.com:kcu105:part0:1.6
	FPGA_PART	?= xcku040-ffva1156-2-e
endif
ifeq (${BOARD_NAME}, K800)
	FPGA_PART	?= xcku115-flva1517-2-e
endif
ifeq (${BOARD_NAME}, VCU118)
	BOARD		?= xilinx.com:vcu118:part0:2.3
	FPGA_PART	?= xcvu9p-flga2104-2l-e
endif

$(info $$PART is [${FPGA_PART}])
$(info $$PROJECT is [${PROJECT}])

# Files for synthesis
SYN_FILES	= ../src/NvmeStoragePkg.vhd ../src/NvmeStorageIntPkg.vhd
SYN_FILES	+= ../src/Ram.vhd ../src/Fifo.vhd ../src/Cdc.vhd
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
SYN_FILES	+= ../src/${BOARD_NAME}/NvmeStorageUnit.vhd
SYN_FILES	+= ../src/NvmeStorage.vhd
SYN_FILES	+= ../src/TestData.vhd
SYN_FILES	+= ../src/${BOARD_NAME}/${FPGA_TOP}.vhd

# IP cores
XCI_FILES	= ../src/ip/${BOARD_NAME}/Clk_core.xci
XCI_FILES	+= ../src/ip/${BOARD_NAME}/Pcie_host.xci
XCI_FILES	+= ../src/ip/${BOARD_NAME}/Axis_clock_converter.xci
# XCI_FILES	+= ../src/ip/${BOARD_NAME}/Pcie_nvme.xci
XCI_FILES	+= ../src/ip/${BOARD_NAME}/Pcie_nvme0.xci
XCI_FILES	+= ../src/ip/${BOARD_NAME}/Pcie_nvme1.xci

# XDC files
XDC_FILES	= ../src/${BOARD_NAME}/${FPGA_TOP}.xdc

include Vivado.mk

all: dirs fpga

all_targets:
	make PROJECT=DuneNvme
	make PROJECT=DuneNvmeOspero

sync_ip:
	mkdir -p ../src/ip/${BOARD_NAME}/
	cp -a ${PROJECT}.srcs/sources_1/ip/${BOARD_NAME}/*/*.xci ../src/ip/${BOARD_NAME}/

start_hw_server:
	${VIVADO_PATH}/hw_server
