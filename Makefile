################################################################################
#	Makefile to build Dune NvmeStorage system
#	T.Barnaby,	Beam Ltd,	2020-02-18
################################################################################
#
include Config.mk

# Fedora RPM packages needed
PACKAGES	= "ghdl gtkwave"
PACKAGES	+= "texlive-scheme-medium texlive-hanging texlive-stackengine texlive-etoc texlive-newunicodechar"

.PHONY:	release

all:
	make -C vivado
	make -C test

install: all

clean:
	make -C vivado clean
	make -C sim clean
	make -C test clean
	make -C docsrc clean

distclean: clean
	make -C vivado distclean
	make -C docsrc distclean
	make -C test distclean
	
release: all
	mkdir -p release
	cp vivado/*.runs/impl_1/*.bit release/${PROJECT}-${VERSION}.bit
	cp test/test-nvme release/test-nvme-${VERSION}

docs:
	make -C docsrc

installPackages:
	dnf install ${PACKAGES}


################################################################################
#	Git project Management
################################################################################
#
gitPush:
	git push master
	git push --tags

gitListReleases:
	git tag

gitCommit:
	git commit -a

gitRelease:
	git tag release-${VERSION}
	git push master
	git push --tags

gitDiff:
	git diff

gitId:
	git rev-parse HEAD
