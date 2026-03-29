#!/bin/sh

#
# demacro -- evaluate and print C-preprocessor #define's.
#

progname=$(basename "${0}" .sh)
: ${TMPDIR:="/tmp"}
FMT_SPEC_DEFAULT="lu"
usage()
{
	cat 1>&2 <<__EOF__
usage: ${progname} [-Ii header ...] [-f format_specifier] <macro_names

Options:
    -I header		Local header file to include.
    -i header		Global header file to include.
    -f format_specifier	printf(3) specifier to use ('${FMT_SPEC_DEFAULT}' by default).
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
while read line; do
	defines="${defines}
$(echo "${line}" |sed -e 's/#define //' -e 's/	/ /g' |cut -d ' ' -f 1)"
done
defines=$(echo "${defines}" |sed '/^$/d')

prog_file=$(mktemp -p "${TMPDIR}" "${progname}.c.XXXXXXXX")
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
for define in ${defines}; do
cat <<__EOF2__
	printf("%s %${fmt_spec}\n", "${define}", ${define});
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
