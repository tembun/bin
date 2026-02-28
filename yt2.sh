#!/bin/sh

#
# yt2 -- download and convert files from YouTube.
#

progname=$(basename "${0}" .sh)
SETFIB="setfib"
YTDLP="yt-dlp"

usage()
{
	echo "usage: ${progname} [-F] [-f fib] [-o output_name] [-t format] URL" 1>&2
	exit 2
}

err()
{
	echo "${progname}: ${@}" 1>&2
	exit 1
}

ensure_prog()
{
	local prog="${1}"
	local path=$(which "${prog}" 2>/dev/null)
	test -n "${path}" && test -x "${path}" || err "You need ${prog} to run this"
}

check_fib()
{
	netstat -rF "${1}" >/dev/null 2>&1
}

run_setfib()
{
	fib="${1}"
	shift
	${SETFIB} -F "${fib}" "${@}"
}

handle_opts()
{
	local o
	while getopts "Ff:o:t:" o; do
		case "${o}" in
		F)	nofib="1" ;;
		f)	fib="${OPTARG}" ;;
		o)	output="${OPTARG}" ;;
		t)	target="${OPTARG}" ;;
		?)	usage ;;
		esac
	done
}

ensure_prog "${YTDLP}"
handle_opts ${@}
shift $((OPTIND - 1))
test ${#} -ne 1 && usage
url="${1}"
: ${fib:="1"}
test -n "${output}" && out_opt="-o ${output}"
test -n "${target}" && target_opt="-t ${target}"
cmd="${YTDLP} ${target_opt} ${out_opt} ${url}"
if [ "${nofib}" != "1" ] && check_fib "${fib}"; then
	ensure_prog "${SETFIB}"
	run_setfib "${fib}" ${cmd}
else
	${cmd}
fi
