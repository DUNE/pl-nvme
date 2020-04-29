################################################################################
#	Vivado.mk	General common Makefile targets
#			T.Barnaby,	BEAM Ltd,	2020-02-18
################################################################################
#
# Parameters
#  PROJECT:	The projects name
#  BOARD:	The board type if a specific standard board
#  FPGA_PART:	FPGA device (e.g. xcvu095-ffva2104-2-e)
#  FPGA_TOP:	Top module name
#  SYN_FILES:	Space-separated list of source files
#  INC_FILES:	Space-separated list of include files
#  XDC_FILES:	Space-separated list of timing constraint files
#  XCI_FILES:	Space-separated list of IP XCI files
#
# Targets
#  all:		Build everything
#  clean:	Remove output files and project files
#  distclean:	Clean all files
#

export PATH:=/opt/Xilinx/Vivado/2019.2/bin:${PATH}

.PHONY: clean fpga

# Prevent make from deleting intermediate files and reports
.PRECIOUS: ${PROJECT}.xpr ${PROJECT}.bit ${PROJECT}.mcs ${PROJECT}.prm
.SECONDARY:

all: fpga

fpga: $(PROJECT).bit

clean:
	-rm -rf *.log *.jou *.cache *.hw *.ip_user_files *.runs *.xpr *.html *.xml *.sim *.srcs *.str .Xil defines.v
	-rm -rf create_project.tcl run_synth.tcl run_impl.tcl generate_bit.tcl
	-rm -rf *.bit program.tcl generate_mcs.tcl *.mcs *.prm flash.tcl

distclean: clean
	-rm -rf rev

# Vivado project file
${PROJECT}.xpr: Makefile $(XCI_FILES)
	rm -rf defines.v
	touch defines.v
	for x in $(DEFS); do echo '`define' $$x >> defines.v; done
	echo "create_project -force -part $(FPGA_PART) ${PROJECT}" > create_project.tcl
	if [ "${BOARD}" != "" ]; then echo "set_property board_part ${BOARD} [current_project]" >> create_project.tcl; fi
	echo "set_property target_language VHDL [current_project]" >> create_project.tcl
	echo "add_files -fileset sources_1 defines.v" >> create_project.tcl
	for x in $(SYN_FILES); do echo "add_files -fileset sources_1 $$x" >> create_project.tcl; done
	for x in $(XDC_FILES); do echo "add_files -fileset constrs_1 $$x" >> create_project.tcl; done
	for x in $(XCI_FILES); do echo "import_ip $$x" >> create_project.tcl; done
	echo "exit" >> create_project.tcl
	vivado -nojournal -nolog -mode batch -source create_project.tcl

# Synthesis run
${PROJECT}.runs/synth_1/${PROJECT}.dcp: ${PROJECT}.xpr $(SYN_FILES) $(INC_FILES) $(XDC_FILES)
	rm -f $(PROJECT).bit
	echo "open_project ${PROJECT}.xpr" > run_synth.tcl
	echo "reset_run synth_1" >> run_synth.tcl
	echo "launch_runs synth_1 -jobs 4" >> run_synth.tcl
	echo "wait_on_run synth_1" >> run_synth.tcl
	echo "set runStatus [ get_property STATUS [get_runs synth_1] ]" >> run_synth.tcl
	#echo 'puts stderr "RunStatus: $${runStatus}"' >> run_synth.tcl
	echo 'if { $${runStatus} != "synth_design Complete!"} {' >> run_synth.tcl
	echo "	exit 1" >> run_synth.tcl
	echo "}" >> run_synth.tcl
	echo "exit 0" >> run_synth.tcl
	vivado -nojournal -nolog -mode batch -source run_synth.tcl

# Implementation run
${PROJECT}.runs/impl_1/${PROJECT}_routed.dcp: ${PROJECT}.runs/synth_1/${PROJECT}.dcp
	rm -f $(PROJECT).bit
	echo "open_project ${PROJECT}.xpr" > run_impl.tcl
	echo "reset_run impl_1" >> run_impl.tcl
	echo "launch_runs impl_1 -jobs 4" >> run_impl.tcl
	#echo "launch_runs impl_1 -to_step write_bitstream -jobs 4" >> run_impl.tcl
	echo "wait_on_run impl_1" >> run_impl.tcl
	echo "set runStatus [ get_property STATUS [get_runs impl_1] ]" >> run_impl.tcl
	echo 'puts stderr "RunStatus: $${runStatus}"' >> run_impl.tcl
	echo 'if { $${runStatus} != "route_design Complete!"} {' >> run_impl.tcl
	#echo 'if { $${runStatus} != "write_bitstream Complete!"} {' >> run_impl.tcl
	echo "	exit 1" >> run_impl.tcl
	echo "}" >> run_impl.tcl
	echo "exit 0" >> run_impl.tcl
	vivado -nojournal -nolog -mode batch -source run_impl.tcl

# Bit file
${PROJECT}.bit: ${PROJECT}.runs/impl_1/${PROJECT}_routed.dcp
	rm -f $(PROJECT).bit
	echo "open_project ${PROJECT}.xpr" > generate_bit.tcl
	echo "open_run impl_1" >> generate_bit.tcl
	echo "write_bitstream -force ${PROJECT}.bit" >> generate_bit.tcl
	echo "exit" >> generate_bit.tcl
	time vivado -nojournal -nolog -mode batch -source generate_bit.tcl
	mkdir -p rev
	EXT=bit; COUNT=100; \
	while [ -e rev/${PROJECT}_rev$$COUNT.$$EXT ]; \
	do COUNT=$$((COUNT+1)); done; \
	cp $@ rev/${PROJECT}_rev$$COUNT.$$EXT; \
	echo "Output: rev/${PROJECT}_rev$$COUNT.$$EXT";

# Extras for flash etc
${PROJECT}_primary.mcs ${PROJECT}_secondary.mcs ${PROJECT}_primary.prm ${PROJECT}_secondary.prm: ${PROJECT}.bit
	echo "write_cfgmem -force -format mcs -size 256 -interface SPIx8 -loadbit {up 0x0000000 $*.bit} -checksum -file $*.mcs" > generate_mcs.tcl
	echo "exit" >> generate_mcs.tcl
	vivado -nojournal -nolog -mode batch -source generate_mcs.tcl
	mkdir -p rev
	COUNT=100; \
	while [ -e rev/$*_rev$$COUNT.bit ]; \
	do COUNT=$$((COUNT+1)); done; \
	COUNT=$$((COUNT-1)); \
	for x in _primary.mcs _secondary.mcs _primary.prm _secondary.prm; \
	do cp $*$$x rev/$*_rev$$COUNT$$x; \
	echo "Output: rev/$*_rev$$COUNT$$x"; done;

flash: $(PROJECT)_primary.mcs $(PROJECT)_secondary.mcs $(PROJECT)_primary.prm $(PROJECT)_secondary.prm
	echo "open_hw" > flash.tcl
	echo "connect_hw_server" >> flash.tcl
	echo "open_hw_target" >> flash.tcl
	echo "current_hw_device [lindex [get_hw_devices] 0]" >> flash.tcl
	echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> flash.tcl
	echo "create_hw_cfgmem -hw_device [current_hw_device] [lindex [get_cfgmem_parts {mt25qu01g-spi-x1_x2_x4_x8}] 0]" >> flash.tcl
	echo "current_hw_cfgmem -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM [current_hw_device]]" >> flash.tcl
	echo "set_property PROGRAM.FILES [list \"$(PROJECT)_primary.mcs\" \"$(PROJECT)_secondary.mcs\"] [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.PRM_FILES [list \"$(PROJECT)_primary.prm\" \"$(PROJECT)_secondary.prm\"] [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.ERASE 1 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.CFG_PROGRAM 1 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.VERIFY 1 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.CHECKSUM 0 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.ADDRESS_RANGE {use_file} [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} [current_hw_cfgmem]" >> flash.tcl
	echo "create_hw_bitstream -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM_BITFILE [current_hw_device]]" >> flash.tcl
	echo "program_hw_devices [current_hw_device]" >> flash.tcl
	echo "refresh_hw_device [current_hw_device]" >> flash.tcl
	echo "program_hw_cfgmem -hw_cfgmem [current_hw_cfgmem]" >> flash.tcl
	echo "boot_hw_device [current_hw_device]" >> flash.tcl
	echo "exit" >> flash.tcl
	vivado -nojournal -nolog -mode batch -source flash.tcl
