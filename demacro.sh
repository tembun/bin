#!/bin/sh

#
# demacro -- evaluate and print C-preprocessor #define's.
#

progname=$(basename "${0}")
: ${TMPDIR:="/tmp"}
FMT_SPEC_DEFAULT="lu"
usage()
{
	cat 1>&2 <<__EOF__
usage: ${progname} [-Ii header ...] [-f format-specifier] file-with-defines

Options:
    -I header		Local header file to include.
    -i header		Global header file to include.
    -f format-specifier	printf(3) specifier to use ('${FMT_SPEC_DEFAULT}' by default).
__EOF__
	exit 2
}

err()
{
	echo "${progname}: ${@}" 1>&2
	exit 1
}

cleanup()
{
	test -f "${prog_file}" || test -f "${prog_out}" || return
	rm -f "${prog_file}" "${prog_out}"
}
trap cleanup HUP INT TERM EXIT

handle_opts()
{
	local o
	while getopts "I:f:i:" o; do
		case "${o}" in
		I)	headers_loc=$(printf "${headers_loc}\n${OPTARG}") ;;
		f)	fmt_spec="${OPTARG}" ;;
		i)	headers=$(printf "${headers}\n${OPTARG}") ;;
		?)	usage ;;
		esac
	done
	: "${fmt_spec:="${FMT_SPEC_DEFAULT}"}"
	headers=$(echo "${headers}" |sed '/^ *$/d')
	headers_loc=$(echo "${headers_loc}" |sed '/^ *$/d')
}

handle_opts ${@}
shift $((OPTIND - 1))
test ${#} -ne 1 && usage
file="${1}"
test -f "${file}" || err "${file} is not a file}"
defines=$(sed -Ee 's/#define //' -e 's/^[A-Z0-9a-z_]+/"&"/' "${file}")

prog_file=$(mktemp -p "${TMPDIR}" demacro.c.XXXXXXXX)
test ${?} -ne 0 && err "Can't mktemp(1) at ${TMPDIR}"
prog=$(cat >"${prog_file}" <<__EOF__
#include <stdio.h>
$(for header in ${headers}; do
cat <<__EOF2__
#include <${header}>
__EOF2__
done)
$(for header_loc in ${headers_loc}; do
cat <<__EOF2__
#include "${header_loc}"
__EOF2__
done)
int
main(void)
{
$(IFS="
"
for define_line in ${defines}; do
	define=$(echo "${define_line}" |cut -d ' ' -f 1)
	value=$(echo "${define_line}" |cut -d ' ' -f 2-)
cat <<__EOF2__
	printf("%s %${fmt_spec}\n", ${define}, ${value});
__EOF2__
done
unset IFS)
	return (0);
}
__EOF__
)

prog_out=$(mktemp -p "${TMPDIR}" demacro.out.XXXXXXXX)
test ${?} -ne 0 && err "Can't mktemp(1) at ${TMPDIR}"
cc -x c -o "${prog_out}" "${prog_file}" -I/usr/local/include ||
    err "Can't compile the resulting program"
"${prog_out}"
