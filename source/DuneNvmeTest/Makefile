################################################################################
#	Makefile to build Dune NvmeStorage system
#	T.Barnaby,	Beam Ltd,	2020-02-18
################################################################################
#
TOP	= ../..
include Config.mk

.PHONY:	release

all:
	

install:

clean:
	make -C vivado clean
	make -C sim clean
	make -C test clean
	make -C docsrc clean

distclean: clean
	make -C vivado distclean
	make -C docsrc distclean
	
release:
	mkdir -p release
	cp vivado/*.runs/impl_1/*.bit release/${PROJECT}-${VERSION}.bit

docs:
	make -C docsrc

packages:
	dnf install texlive-scheme-medium texlive-hanging texlive-stackengine texlive-etoc texlive-newunicodechar
