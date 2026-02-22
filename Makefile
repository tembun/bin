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

SRCS:sh= ls |grep -v Makefile
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
LINKS_src= ksrc

all: ${SRCS:C/\.[^.]*$//}

.for src in ${SRCS}
src_file=${src}
is_dir:sh= test -d ${src} && echo "1" || echo "0"
.if ${is_dir} == "1"
src_file:sh= find ${src} -type f -name "*.sh" |head -n 1
.endif
src_base=${src:C/\.[^.]*$//}

${PREFIX}/${BINDIR}/${src_base}: ${src_file}
	@mkdir -p $$(dirname ${.TARGET})
	${INSTALL} ${INSTALL_MODE_OPT} ${BIN_MODE} ${.ALLSRC} ${.TARGET}
.if defined(LINKS_${src_base})
.for link in ${LINKS_${src_base}}
	${INSTALL} ${INSTALL_LINK_OPT} ${INSTALL_MODE_OPT} ${BIN_MODE}\
	    ${.TARGET} ${PREFIX}/${BINDIR}/${link}
.endfor
.endif

src_man=${src}/${src_base}.1
.OPTIONAL: ${PREFIX}/${MANDIR}/${src_base}.1.gz
.if ${is_dir} == "1" && exists(${src_man})
${PREFIX}/${MANDIR}/${src_base}.1.gz: ${src_man}
	@mkdir -p $$(dirname ${.TARGET})
	${MANCOMPRESS} ${.ALLSRC} >${.TARGET}
	@chmod ${MAN_MODE} ${.TARGET}
.endif

SHARE_SRCS=
SHARE_SUBDIR=
.-include "${src}/Makefile"
.if ${SHARE_SRCS}
.for share_src in ${SHARE_SRCS}
share_src_base=${share_src:T}
.OPTIONAL: ${PREFIX}/${SHAREDIR}/${SHARE_SUBDIR}/${share_src_base}
${PREFIX}/${SHAREDIR}/${SHARE_SUBDIR}/${share_src_base}: ${share_src}
	@mkdir -p $$(dirname ${.TARGET})
	${INSTALL} ${INSTALL_MODE_OPT} ${SHARE_MODE} ${.ALLSRC} ${.TARGET}
.endfor
.endif
share_targets=
.if ${SHARE_SRCS}
share_targets=${SHARE_SRCS:T:C/^/${PREFIX}\/${SHAREDIR}\/${SHARE_SUBDIR}\//}
.endif

.PHONY: ${src_base}
${src_base}: ${PREFIX}/${BINDIR}/${src_base} ${PREFIX}/${MANDIR}/${src_base}.1.gz\
    ${share_targets}
.endfor
