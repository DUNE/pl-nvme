################################################################################
#	Makefile	VHDL simulation
#			T. Barnaby,	Beam Ltd,	2011-07-17
################################################################################
#

# The Test
#TEST	= test001-leds
#TEST	= test002-axil
#TEST	= test003-regs
#TEST	= test004-nvme
#TEST	= test005-nvme
#TEST	= test006-testdata
#TEST	= test007-hostnvme
#TEST	= test008-nvmeconfig
#TEST	= test009-packets

#TEST	= test010-queueram
#TEST	= test011-switch
#TEST	= test012-hostnvme
#TEST	= test013-hostnvme
#TEST	= test014-queueram
#TEST	= test015-hostnvme
#TEST	= test016-fifo
#TEST	= test017-write
#TEST	= test018-buffer
#TEST	= test019-write
TEST	= test020-write

# VHDL source files
FILES_BASE	+= testbench/TestPkg.vhd ../src/NvmeStoragePkg.vhd ../src/NvmeStorageIntPkg.vhd ../src/AxilClockConverter.vhd ../src/AxisClockConverter.vhd 
FILES_BASE	+= ../src/PcieStreamMux.vhd ../src/Ram.vhd
FILES_BASE	+= ../src/NvmeStreamMux.vhd ../src/AxisDataConvertFifo.vhd ../src/RegAccessClockConvertor.vhd

#FILES_BASE	+= ../vivado/nvme-test.srcs/sources_1/ip/Fifo4k/Fifo4k_sim_netlist.vhdl
#FILES_BASE	+= ../vivado/nvme-test.srcs/sources_1/ip/Fifo32k/Fifo32k_sim_netlist.vhdl

FILES_SYSTEM	= ../src/NvmeStorageUnit.vhd ../src/NvmeSim.vhd ../src/NvmeConfig.vhd ../src/StreamSwitch.vhd ../src/NvmeQueues.vhd
FILES_SYSTEM	+= ../src/TestDataStream.vhd ../src/TestData.vhd ../src/NvmeWrite.vhd

# Test files
FILES_test001-leds += testbench/${TEST}.vhd ${FILES_BASE} ../src/LedCount.vhd
FILES_test002-axil += testbench/${TEST}.vhd ${FILES_BASE} ../src/AxilToCfg.vhd
FILES_test003-regs += testbench/${TEST}.vhd ${FILES_BASE} ../src/NvmeStorage.vhd
FILES_test004-nvme += testbench/${TEST}.vhd ${FILES_BASE} ../src/NvmeSim.vhd
FILES_test005-nvme += testbench/${TEST}.vhd ${FILES_BASE} ../src/NvmeSim.vhd
FILES_test006-testdata += testbench/${TEST}.vhd ${FILES_BASE} ../src/TestData.vhd
FILES_test007-hostnvme += testbench/${TEST}.vhd ${FILES_BASE}  ../src/NvmeStorage.vhd ../src/NvmeSim.vhd
FILES_test008-nvmeconfig += testbench/${TEST}.vhd ${FILES_BASE}  ../src/NvmeStorage.vhd ../src/NvmeSim.vhd ../src/NvmeConfig.vhd
FILES_test009-packets += testbench/${TEST}.vhd ${FILES_BASE}  ../src/NvmeStorageUnit.vhd ../src/NvmeSim.vhd ../src/NvmeConfig.vhd
FILES_test010-queueram += testbench/${TEST}.vhd ${FILES_BASE}  ../src/NvmeQueues.vhd ../src/NvmeConfig.vhd
FILES_test011-switch += testbench/${TEST}.vhd ${FILES_BASE} ../src/StreamSwitch.vhd
FILES_test012-hostnvme += testbench/${TEST}.vhd ${FILES_BASE} ${FILES_SYSTEM}
FILES_test013-hostnvme += testbench/${TEST}.vhd ${FILES_BASE} ${FILES_SYSTEM}
FILES_test014-queueram += testbench/${TEST}.vhd ${FILES_BASE}  ../src/NvmeQueues.vhd
FILES_test015-hostnvme += testbench/${TEST}.vhd ${FILES_BASE} ${FILES_SYSTEM}
FILES_test016-fifo += testbench/${TEST}.vhd ${FILES_BASE} ${FILES_SYSTEM}
FILES_test017-write += testbench/${TEST}.vhd ${FILES_BASE} ${FILES_SYSTEM}
FILES_test018-buffer += testbench/${TEST}.vhd ${FILES_BASE} ${FILES_SYSTEM}
FILES_test019-write += testbench/${TEST}.vhd ${FILES_BASE} ${FILES_SYSTEM}
FILES_test020-write += testbench/${TEST}.vhd ${FILES_BASE} ${FILES_SYSTEM} ../src/NvmeStorage.vhd

# VHDL testbench files
STOP	= test
SVIEW	= testbench/${TEST}.sav

FILES	= ${FILES_${TEST}}

# Options
#GFLAGS	= --ieee=synopsys --warn-no-vital-generic
GFLAGS	= --ieee=synopsys --warn-no-unused
GFLAGS	+= -fexplicit
GFLAGS	+= -Psimu
SFLAGS	= --assert-level=error
#SFLAGS += --stop-time=300ns
SFLAGS += --stop-time=30us

#GFLAGS	+= --std=93
#GFLAGS	+= --std=02
#GFLAGS	+= --std=08

.PHONY: isim

all:	dirs compile run

dirs:
	-mkdir -p simu

compile: unisim
	ghdl -i $(GFLAGS) --workdir=simu --work=work $(FILES)
	ghdl -m $(GFLAGS) --workdir=simu --work=work $(STOP)
	@mv $(STOP) simu/$(STOP)

run:
	#@simu/$(STOP) $(SFLAGS) --vcd=simu/$(STOP).vcd
	@simu/$(STOP) $(SFLAGS) --wave=simu/$(STOP).ghw

view:
	#gtkwave --vcd -f simu/$(STOP).vcd -a ${SVIEW}
	#gtkwave simu/$(STOP).vcd -a ${SVIEW}
	gtkwave -f simu/$(STOP).ghw -a ${SVIEW}

clean:
	rm -f simu/* e~test.o

unisim: simu/unisim-obj93.cf

simu/unisim-obj93.cf:
	ghdl -i $(GFLAGS) --workdir=simu --work=unisim /opt/Xilinx/Vivado/2019.2/data/vhdl/src/unisims/*.vhd
	#ghdl -i $(GFLAGS) --workdir=simu --work=unisim /opt/Xilinx/Vivado/2019.2/data/vhdl/src/unisims/primitive/*.vhd
	#ghdl -i $(GFLAGS) --workdir=simu --work=xilinxcorelib /opt/Xilinx/13.4/ISE_DS/ISE/vhdl/src/XilinxCoreLib/*.vhd

setup:
	mkdir -p bin simu src testbench work unisim

isim:
	rm -f ${TEST}.prj
	(for f in $(SFILES) ${FILES}; do echo vhdl work "$$f" >> ${TEST}.prj; done)
	fuse -prj ${TEST}.prj work.test -o ${TEST} && ./${TEST} -gui
