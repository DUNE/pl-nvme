################################################################################
#	Makefile to build Dune NvmeStorage documents
#	T.Barnaby,	Beam Ltd,	2020-02-18
################################################################################
#
include ../Config.mk

DateNow = $(shell date -I)

.PHONY:	config release

all:	config docs

config: .configured

.configured: ../Config.mk
	sed -i "s/PROJECT_NUMBER.*/PROJECT_NUMBER\t\t= ${VERSION}/g" fpga_doxygen.dox
	sed -i "s/PROJECT_NUMBER.*/PROJECT_NUMBER\t\t= ${VERSION}/g" host_doxygen.dox
	sed -i "s/\\\version.*/\\\version ${VERSION}/g" fpga_overview.dox
	sed -i "s/\\\date.*/\\\date ${DateNow}/g" fpga_overview.dox
	sed -i "s/\\\version.*/\\\version ${VERSION}/g" host_overview.dox
	sed -i "s/\\\date.*/\\\date ${DateNow}/g" host_overview.dox
	touch .configured

install:
	@if [ "${DOCDIR}" != "" ]; then \
		mkdir -p ${DOCDIR}/host ${DOCDIR}/fpga; \
		cp -a ../doc/host/html ${DOCDIR}/host; \
		cp -a ../doc/fpga/html ${DOCDIR}/fpga; \
		cp -a ../doc/*.pdf ${DOCDIR}; \
		cp -a ../doc/*.html ${DOCDIR}; \
	fi;

clean:

distclean: clean
	rm -fr ../doc/host ../doc/fpga
	rm -f .configured
	
release:

docs:
	doxygen host_doxygen.dox
	doxygen fpga_doxygen.dox
	soffice --headless --convert-to pdf --outdir ../doc Readme.odt
	soffice --headless --convert-to pdf --outdir ../doc DuneNvmeStorageManual.odt
	soffice --headless --convert-to pdf --outdir ../doc DuneNvmeStorageDesign.odt
	soffice --headless --convert-to pdf --outdir ../doc DuneNvmeStorageProject.odt
	soffice --headless --convert-to pdf --outdir ../doc DuneNvmeStorageTestSoftware.odt

docspdf: docs
	(cd ../doc/host/latex; make)
	cp ../doc/host/latex/refman.pdf ../doc/${PROJECT}_host.pdf
	(cd ../doc/fpga/latex; make)
	cp ../doc/fpga/latex/refman.pdf ../doc/${PROJECT}_fpga.pdf
