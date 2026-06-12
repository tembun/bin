#!/bin/sh

#
# sizeof -- sizeof(7) of a C type.
#

progname=$(basename -- "${0}" .sh)
: ${TMPDIR:="/tmp"}
PROG_FILE_BASENAME="${progname}.c.XXXXXXXX"
OUT_FILE_BASENAME="${progname}.out.XXXXXXXX"

usage()
{
	echo "usage: ${progname} type ..."
	exit 2
}

err()
{
	echo "${progname}: ${@}" 1>&2
	exit 1
}

cleanup()
{
	rm -f "${prog_file}" "${prog_out}"
}
trap cleanup HUP INT TERM EXIT

test ${#} -gt 0 || usage
prog_file=$(mktemp -p "${TMPDIR}" "${PROG_FILE_BASENAME}")
test ${?} -ne 0 && err "Cannot mktemp(1) at ${TMPDIR}"
prog=$(cat >"${prog_file}" <<__EOF__
#include <sys/types.h>
#include <sys/stat.h>

#include <fcntl.h>
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int
main(void)
{
$(for type in ${@}; do
cat <<__EOF2__
	printf("%s: %zd\n", "${type}", sizeof(${type}));
__EOF2__
done)
	return (0);
}
__EOF__
)

prog_out=$(mktemp -p "${TMPDIR}" "${OUT_FILE_BASENAME}")
test ${?} -ne 0 && err "Cannot mktemp(1) at ${TMPDIR}"
cc -x c -o "${prog_out}" "${prog_file}" || err "Cannot compile the program"
"${prog_out}"
