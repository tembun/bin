SRCS:sh= ls |grep -v Makefile
PREFIX= /usr/local
BINDIR= bin
BIN_MODE= 0755
MANDIR= share/man/man1
MAN_MODE= 0644
INSTALL= install
INSTALL_LINK_OPT= -l h
INSTALL_MODE_OPT= -m

LINKS_fw= fwj
LINKS_r= rj
LINKS_ren= normalize

all: ${SRCS:C/\.[^.]*$//}

.for src in ${SRCS}
src_file=${src}
is_dir:sh= test -d ${src} && echo "1" || echo "0"
.if ${is_dir} == "1"
src_file:sh= ls ${src}/* |grep -v .*\.1
.endif
src_base=${src:C/\.[^.]*$//}

${PREFIX}/${BINDIR}/${src_base}: ${src_file}
	@mkdir -p $$(dirname ${.TARGET})
	${INSTALL} ${INSTALL_MODE_OPT} ${BIN_MODE} ${.ALLSRC} ${.TARGET}
.if defined(LINKS_${src_base})
	${INSTALL} ${INSTALL_LINK_OPT} ${INSTALL_MODE_OPT} ${BIN_MODE}\
	    ${.TARGET} ${PREFIX}/${BINDIR}/${LINKS_${.TARGET:T}}
.endif

src_man=${src}/${src_base}.1
.OPTIONAL: ${PREFIX}/${MANDIR}/${src_base}.1
.if ${is_dir} == "1" && exists(${src_man})
${PREFIX}/${MANDIR}/${src_base}.1: ${src_man}
	@mkdir -p $$(dirname ${.TARGET})
	${INSTALL} ${.ALLSRC} ${.TARGET}
.endif

.PHONY: ${src_base}
${src_base}: ${PREFIX}/${BINDIR}/${src_base} ${PREFIX}/${MANDIR}/${src_base}.1
.endfor
