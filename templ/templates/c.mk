CC=		cc
CFLAGS_CHECK=	-Wall
CFLAGS=
CFLAGS_RELEASE=	${CFLAGS_CHECK} -Oz
CFLAGS_DBG=	-DDEBUG
CFLAGS_DEBUG=	-g ${CFLAGS_DBG}
CFLAGS_DEV=	${CFLAGS_DBG}
INCS=		-I/usr/local/include
LIBS=		-L/usr/local/lib
PREFIX=		/usr/local
BINDIR=		bin
INSTALL=	install
INSTALL_STRIP=	-s
SRC=		
HEADERS=	
SRC_ALL=	${SRC} ${HEADERS}
BIN=		

all: dev

dev: ${SRC_ALL}
	${CC} ${CFLAGS} ${CFLAGS_DEV} -o ${BIN} ${INCS} ${LIBS} ${SRC}

debug: ${SRC_ALL}
	${CC} ${CFLAGS} ${CFLAGS_DEBUG} -o ${BIN} ${INCS} ${LIBS} ${SRC}

release: ${SRC_ALL}
	${CC} ${CFLAGS} ${CFLAGS_RELEASE} -o ${BIN} ${INCS} ${LIBS} ${SRC}

install: release
	mkdir -p ${PREFIX}/${BINDIR}
	${INSTALL} ${INSTALL_STRIP} ${BIN} ${PREFIX}/${BINDIR}

clean:
	rm -f ${BIN}
