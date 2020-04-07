################################################################################
#	Makefile to build Dune NvmeStorage documents
#	T.Barnaby,	Beam Ltd,	2020-02-18
################################################################################
#
TOP	= ../../..
include ../Config.mk

.PHONY:	config release

all:	config docs

config: .configured

.configured: ../Config.mk
	sed -i "s/PROJECT_NUMBER.*/PROJECT_NUMBER\t\t= ${VERSION}/g" doxygen.dox
	sed -i "s/\\\version.*/\\\version ${VERSION}/g" overview.dox
	touch .configured

install:
	mkdir -p ${DOCDIR}
	cp -a ../doc/html ${DOCDIR}
	cp -a ../doc/*.pdf ${DOCDIR}

clean:

distclean: clean
	rm -fr ../doc/*
	rm -f .configured
	
release:

docs:
	doxygen doxygen.dox
	soffice --headless --convert-to pdf --outdir ../doc Readme.odt

docspdf: docs
	(cd ../doc/latex; make)
	cp ../doc/latex/refman.pdf ../doc/${PROJECT}.pdf
