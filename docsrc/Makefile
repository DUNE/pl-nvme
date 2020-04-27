################################################################################
#	Makefile to build Dune NvmeStorage documents
#	T.Barnaby,	Beam Ltd,	2020-02-18
################################################################################
#
TOP	= ..

all:	docs

install:

clean:

distclean: clean
	
docs:
	soffice --headless --convert-to pdf --outdir ../doc DuneNvmeStorageManual.odt
	soffice --headless --convert-to pdf --outdir ../doc DuneNvmeStorageProject.odt
