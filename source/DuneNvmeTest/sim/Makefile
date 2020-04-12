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
TEST	= test007-hostnvme

# VHDL source files
FILES_BASE	+= ../src/AxiPkg.vhd ../src/NvmeStoragePkg.vhd ../src/AxilClockConverter.vhd ../src/AxisClockConverter.vhd ../src/AxisStreamMux.vhd ../src/AxisStreamDeMux.vhd

# Test files
FILES_test001-leds += testbench/${TEST}.vhd ${FILES_BASE} ../src/LedCount.vhd
FILES_test002-axil += testbench/${TEST}.vhd ${FILES_BASE} ../src/AxilToCfg.vhd
FILES_test003-regs += testbench/${TEST}.vhd ${FILES_BASE} ../src/NvmeStorage.vhd
FILES_test004-nvme += testbench/${TEST}.vhd ${FILES_BASE} ../src/NvmeSim.vhd
FILES_test005-nvme += testbench/${TEST}.vhd ${FILES_BASE} ../src/NvmeSim.vhd
FILES_test006-testdata += testbench/${TEST}.vhd ${FILES_BASE} ../src/TestData.vhd
FILES_test007-hostnvme += testbench/${TEST}.vhd ${FILES_BASE}  ../src/NvmeStorage.vhd ../src/NvmeSim.vhd

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

#GFLAGS	+= --std=08

.PHONY: isim

all:	compile run

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
	ghdl -i $(GFLAGS) --workdir=simu --work=unisim /opt/Xilinx/Vivado/2019.2/data/vhdl/src/unisims/primitive/*.vhd
	#ghdl -i $(GFLAGS) --workdir=simu --work=xilinxcorelib /opt/Xilinx/13.4/ISE_DS/ISE/vhdl/src/XilinxCoreLib/*.vhd

setup:
	mkdir -p bin simu src testbench work unisim

isim:
	rm -f ${TEST}.prj
	(for f in $(SFILES) ${FILES}; do echo vhdl work "$$f" >> ${TEST}.prj; done)
	fuse -prj ${TEST}.prj work.test -o ${TEST} && ./${TEST} -gui
