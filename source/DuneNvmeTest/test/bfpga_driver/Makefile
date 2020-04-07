################################################################################
#	Makefile	For BFpga Linux Device Driver
#			T.Barnaby,	BEAM Ltd,	2020-03-05
################################################################################
#
TOP	= ..

#include ../Makefile.config

obj-m	:= bfpga.o

TARGET			= 
KERNELVERSION		= $(shell uname -r)
#KERNELVERSION		= 5.5.7-200.fc31.x86_64

ifeq ("$(TARGET)", "")
DEST_DIR 		=
KERNELDIR		?= /lib/modules/${KERNELVERSION}/build
KERNELINSTALLDIR	= ${DEST_DIR}/lib/modules/$${KERNELVERSION}/extra
PWD			:= $(shell pwd)
endif

LDLIBS	+= -lpthread

all:
	$(MAKE) -C $(KERNELDIR) M=$(PWD)

test:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) KBUILD_CFLAGS_MODULE="-DMODULE -Wno-unused-function"

clean:
	rm -rf *.o *~ core .depend .*.cmd *.ko *.mod *.mod.c built-in.a .tmp_versions Module.symvers Module.markers  modules.order dtest1 dtest2

install:
	-mkdir -p ${DEST_DIR}/usr/include
	cp bfpga.h ${DEST_DIR}/usr/include/bfpga.h
	-mkdir -p ${KERNELINSTALLDIR}
	cp bfpga.ko ${KERNELINSTALLDIR}/bfpga.ko
	-mkdir -p ${DEST_DIR}/etc/udev/rules.d
	cp bfpga.rules ${DEST_DIR}/etc/udev/rules.d/bfpga.rules
	echo "Need to run as root: chroot ${DEST_DIR} depmod"

# Debug
installRules:
	cp bfpga.rules ${DESTDIR}/etc/udev/rules.d/bfpga.rules 

load:
	-rmmod bfpga
	#echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove
	echo 1 > /sys/bus/pci/rescan
	echo 1 > /sys/bus/pci/devices/0000:01:00.0/reset
	insmod bfpga.ko
	
