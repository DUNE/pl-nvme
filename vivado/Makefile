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
PROJECT 	?= DuneNvmeTest
FPGA_PART	?= xcku115-flva1517-2-e
FPGA_TOP	?= ${PROJECT}Top
VIVADO_PATH	?= /software/CAD/Xilinx/2019.2/Vivado/2019.2/bin
VIVADO_TARGET	?= "vivado"
INCLUDE_BLKFMT	?= True

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
SYN_FILES	+= ../src/NvmeStorageUnit.vhd
SYN_FILES	+= ../src/NvmeStorage.vhd
ifeq (${INCLUDE_BLKFMT}, True)
	SYN_FILES	+= ../src/BlockFormatting/axis_stream_check_blk.vhd
	SYN_FILES	+= ../src/BlockFormatting/axis_stream_flow_mod_blk.vhd
	SYN_FILES	+= ../src/BlockFormatting/nvme_axis_packet_fifo.vhd
	SYN_FILES	+= ../src/BlockFormatting/nvme_header_inserter_blk.vhd
	SYN_FILES	+= ../src/BlockFormatting/nvme_pad_inserter_blk.vhd
	SYN_FILES	+= ../src/BlockFormatting/nvme_spkt_splitter_blk.vhd
	SYN_FILES	+= ../src/BlockFormatting/nvme_strm_fmt.vhd
	SYN_FILES	+= ../src/BlockFormatting/nvme_strm_fmt_pkg.vhd
	SYN_FILES	+= ../src/BlockFormatting/nvme_strm_gen_blk.vhd
	SYN_FILES	+= ../src/BlockFormatting/NvmeStrmFmtTestData.vhd
else
SYN_FILES	+= ../src/TestData.vhd
endif
SYN_FILES	+= ../src/${FPGA_TOP}.vhd



# IP cores
XCI_FILES	= ../src/ip/Clk_core.xci
XCI_FILES	+= ../src/ip/Pcie_host.xci
XCI_FILES	+= ../src/ip/Axis_clock_converter.xci
#XCI_FILES	+= ../src/ip/Pcie_nvme.xci
XCI_FILES	+= ../src/ip/Pcie_nvme0.xci
XCI_FILES	+= ../src/ip/Pcie_nvme1.xci
ifeq (${INCLUDE_BLKFMT}, True)
	XCI_FILES	+= ../src/ip/BlockFormatting/axis_data_fifo_ic_512_x_256.xci
	XCI_FILES 	+= ../src/ip/BlockFormatting/axis_fifo_cc_512_x_16.xci
endif

# XDC files
XDC_FILES	= ../src/${FPGA_TOP}.xdc

include Vivado.mk

all: dirs fpga

all_targets:
	make PROJECT=DuneNvmeTest
	make PROJECT=DuneNvmeTestOspero

start_hw_server:
	${VIVADO_PATH}/hw_server
