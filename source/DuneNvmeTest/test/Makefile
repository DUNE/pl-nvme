################################################################################
#	Makefile	For Dune Linux tests
#	T.Barnaby,	BEAM Ltd,	2020-02-25
################################################################################
#

PROG		= test_nvme
OBJS		= test_nvme.o NvmeAccess.o BeamLibBasic.o

CXXFLAGS	+= -I.
CXXFLAGS	+= -MMD
LDLIBS		+= -lpthread
LINK.o		= $(LINK.cc)

all:	${PROG}

clean:
	rm -rf *.o *.d $(PROG)

distclean: clean
	make -C bfpga_driver clean

install:

driver:
	make -C bfpga_driver

driver_load:
	make -C bfpga_driver load

${PROG}: ${OBJS}

# Dependancies
-include $(OBJS:.o=.d)