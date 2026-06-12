#!/bin/sh

#
# nolf -- handle files without trailing newline (LF).
#

progname=$(basename -- "${0}" .sh)

warn()
{
	echo "${progname}: ${@}" 1>&2
}

usage()
{
	echo "usage: ${progname} [-n] [path ...]" 1>&2
	exit 2
}

check_lf()
{
	local file="${1}"
	test "$(tail -c 1 "${file}")"
}

add_lf()
{
	local file="${1}"
	echo >>"${file}"
}

handle_opts()
{
	local o
	while getopts "n" o; do
		case "${o}" in
		n)	n_flag=1 ;;
		?)	usage ;;
		esac
	done
}

handle_opts ${@}
shift $((OPTIND - 1))
paths="${@:-"."}"
files=$(grep -RIl "" "${paths}")
for file in ${files}; do
	check_lf "${file}" || continue
	if [ "${n_flag}" != "1" ]; then
		add_lf "${file}" || warn "Cannot add newline to file: ${file}"
	fi
	echo "${file}"
done
