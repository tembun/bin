#
# make			Build everything.
# make bin/brio		Build a particular binary.
# make clean		Clean everything.
# make clean/bin/brio	Clean a particular installed binary.
#
# All final scripts should be located in bin/.
# A script (apart from having a single top-level .sh file) can have a separate
# directory, where a .sh file can be along with a number of other files (needed
# for this script to work/be installed properly) in a custom file hierarchy.
# This makefile automatically handles this kind of files for nested directories:
#     Makefile -	it can be used in order to define additional variables
#               	for installing custom files.
#     *.1 -		man(1) page for a script.  Installed automatically, no
#          		configuration needed.
# As said, a nested makefile is used for setting variables that will help to
# automatically install custom files that are not .sh or .1 files.
# As for now, the only option is to install such files in $PREFIX/share (and
# optionally, in nested directory there).  For this there are variables:
#     SHARE_SRCS -	files that should be installed in $PREFIX/share.
#     SHARE_SUBDIR -	(optionally) a subdirectory inside $PREFIX/share, where
#                   	SHARE_SRCS will be installed.
# Note: if a nested makefile wants to use a path, relative to its own location
# (i.e. a nested directory itself), it should set and further use a variable:
#     PARSEDIR= ${.PARSEDIR:tA}
#

SRCS_DIR= bin
SRCS:sh= find ${SRCS_DIR} -mindepth 1 -maxdepth 1
PREFIX= /usr/local
BINDIR= bin
BIN_MODE= 0755
MANDIR= share/man/man1
MAN_MODE= 0644
MANCOMPRESS= gzip -cn
SHAREDIR= share
SHARE_MODE= 0444
INSTALL= install
INSTALL_LINK_OPT= -l h
INSTALL_MODE_OPT= -m

LINKS_ren= normalize
LINKS_src= dsrc ksrc lsrc

all_handles=${SRCS:C/\.[^.]*$//}
all: ${all_handles}

.for src in ${SRCS}
src_file=${src}
is_dir:sh= test -d ${src} && echo "1" || echo "0"
.if ${is_dir} == "1"
src_file:sh= find ${src} -type f -name "*.sh" |head -n 1
.endif
src_handle=${src:C/\.[^.]*$//}
src_base:sh= basename ${src_handle}
main_target=${PREFIX}/${BINDIR}/${src_base}
${main_target}: ${src_file}
	@mkdir -p ${.TARGET:H}
	${INSTALL} ${INSTALL_MODE_OPT} ${BIN_MODE} ${.ALLSRC} ${.TARGET}
clean_main_target=clean/${main_target}
${clean_main_target}:
	rm -f ${.TARGET:C/^clean\///}
	@rmdir -p ${.TARGET:H:C/^clean\///} 2>/dev/null || true

link_targets=
clean_link_targets=
.if defined(LINKS_${src_base})
link_targets=${LINKS_${src_base}:C/^/${PREFIX}\/${BINDIR}\//}
clean_link_targets=${link_targets:C/^/clean\//}
.for link_target in ${link_targets}
${link_target}: ${main_target}
	@mkdir -p ${.TARGET:H}
	${INSTALL} ${INSTALL_LINK_OPT} ${INSTALL_MODE_OPT} ${BIN_MODE}\
	    ${.ALLSRC} ${.TARGET}
clean_link_target=clean/${link_target}
${clean_link_target}:
	rm -f ${.TARGET:C/^clean\///}
	@rmdir -p ${.TARGET:H:C/^clean\///} 2>/dev/null || true
.endfor
.endif

src_man=${src}/${src_base}.1
man_gz_target=
clean_man_gz_target=
.OPTIONAL: ${man_gz_target} ${clean_man_gz_target}
.if ${is_dir} == "1" && exists(${src_man})
${man_gz_target}: ${src_man}
	man_gz_target=${PREFIX}/${MANDIR}/${src_base}.1.gz
	clean_man_gz_target=clean/${man_gz_target}
	@mkdir -p $$(dirname ${.TARGET})
	${MANCOMPRESS} ${.ALLSRC} >${.TARGET}
	@chmod ${MAN_MODE} ${.TARGET}
${clean_man_gz_target}:
	rm -f ${.TARGET:C/^clean\///}
	@rmdir -p ${.TARGET:H:C/^clean\///} 2>/dev/null || true
.endif

SHARE_SRCS=
SHARE_SUBDIR=
.-include "${src}/Makefile"
.OPTIONAL: ${share_targets} ${clean_share_targets}
share_targets=
clean_share_targets=
.if ${SHARE_SRCS}
share_targets=${SHARE_SRCS:T:C/^/${PREFIX}\/${SHAREDIR}\/${SHARE_SUBDIR}\//}
clean_share_targets=${share_targets:C/^/clean\//}
.for share_src in ${SHARE_SRCS}
share_src_base=${share_src:T}
share_target=${PREFIX}/${SHAREDIR}/${SHARE_SUBDIR}/${share_src_base}
clean_share_target=clean/${share_target}
${share_target}: ${share_src}
	@mkdir -p ${.TARGET:H}
	${INSTALL} ${INSTALL_MODE_OPT} ${SHARE_MODE} ${.ALLSRC} ${.TARGET}
${clean_share_target}:
	rm -f ${.TARGET:C/^clean\///}
	@rmdir -p ${.TARGET:H:C/^clean\///} 2>/dev/null || true
.endfor
.endif

.PHONY: ${src_handle}
${src_handle}: ${main_target} ${link_targets} ${man_gz_target} ${share_targets}

clean_src_handle=clean/${src_handle}
.PHONY: ${clean_src_handle}
${clean_src_handle}: ${clean_main_target} ${clean_link_targets} ${clean_man_gz_target}\
    ${clean_share_targets}
.endfor

all_clean_targets=${all_handles:C/^/clean\//}
.PHONY: clean
clean: ${all_clean_targets}
