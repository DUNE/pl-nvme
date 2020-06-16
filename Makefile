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
	make -C test/bfpga_driver

all_targets:
	make -C vivado PROJECT=DuneNvmeTest
	make -C vivado PROJECT=DuneNvmeTestOpsero
	make -C test
	make -C test/bfpga_driver

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
	
#release: docs all
release:
	rm -fr /tmp/${PROJECT}-${VERSION}
	mkdir -p /tmp/${PROJECT}-${VERSION} /tmp/${PROJECT}-${VERSION}/vivado
	rsync -a --delete --exclude=*.[od] Config.mk Readme.txt license.txt Makefile sim src tools test doc /tmp/${PROJECT}-${VERSION}
	rsync -a --delete --exclude=*.[od] vivado/Makefile vivado/Config.mk vivado/Config-template.mk vivado/Vivado.mk vivado/*.xpr vivado/bitfiles /tmp/${PROJECT}-${VERSION}/vivado
	tar -czf ../../releases/${PROJECT}-${VERSION}.tar.gz -C /tmp ${PROJECT}-${VERSION}

docs:
	make -C docsrc

installPackages:
	dnf install ${PACKAGES}


################################################################################
#	Git project Management
################################################################################
#
gitPush:
	git push
	git push --tags

gitListReleases:
	git tag

gitCommit:
	git commit -a

gitRelease:
	git tag release-${VERSION}
	git push
	git push --tags

gitDiff:
	git diff

gitId:
	git rev-parse HEAD
