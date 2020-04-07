################################################################################
#	Makefile	For Dune Linux tests
#	T.Barnaby,	BEAM Ltd,	2020-02-25
################################################################################
#

PROGS	= test_nvme
LDLIBS	+= -lpthread

all:	${PROGS}

clean:
	rm -rf *.o $(PROGS)
	make -C bfpga_driver clean

install:
