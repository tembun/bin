#!/bin/sh

#
# yt2 -- download and convert files from YouTube.
#

. "$(dirname $(readlink -f "${0}"))/../libexec/subr.sh"

YTDLP="yt-dlp"
COOKIES_BROWSER="firefox"
PROXY="127.0.0.1"
PROXY_PORT="10808"

define_usage "[-CP] [-o output_name] [-t format] URL"

OPTS="CPo:t:"
handle_opts()
{
	case "${o}" in
	C)	set_flag no_cookies ;;
	P)	set_flag no_proxy ;;
	o)	output="${OPTARG}" ;;
	t)	target="${OPTARG}" ;;
	?)	usage ;;
	esac
}

ensure_prog "${YTDLP}"
eval "${HANDLE_OPTS_EVAL}"
test "${#}" -eq 1 || usage
url="${1}"
test -z "${output}" || out_opt="-o ${output}"
test -z "${target}" || target_opt="-t ${target}"
check_flag "${no_proxy}" || proxy_opt="--proxy socks5://${PROXY}:${PROXY_PORT}"
check_flag "${no_cookies}" || cookies_opt="--cookies-from-browser ${COOKIES_BROWSER}"
extra_opts="${proxy_opt} ${cookies_opt} ${target_opt} ${out_opt}"
"${YTDLP}" ${extra_opts} "${url}"
