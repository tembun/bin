#!/bin/sh

#
# rec -- record a screencast in FreeBSD.
#
# Options:
# 	-m -- capture microphone sound.
# 	-s -- capture system (desktop) sound.
# 	-f -- framerate
# The output is in .mp4 extension (the extension should not be specified as
# part of the output name).
#

progname=$(basename "$0" .sh)
DEFAULT_FRAMERATE="30"
DEFAULT_OUT_EXT="mp4"
SND_SRC_MIC="mic"
SND_SRC_DESK="desk"

err()
{
	echo "${progname}: $@" 1>&2
	exit 1
}

usage()
{
	echo "usage: ${progname} [-f framerate] [-m | -s] mp4_output" 1>&2
	exit 2
}

check_freebsd()
{
	[ $(uname) = "FreeBSD" ]
}

# check_prog prog
check_prog()
{
	[ -x $(which "$1" 2>/dev/null) ]
}

# check_num value
check_num()
{
	echo "$1" |grep -Eq '^[0-9]+$'
}

restore_aud() {
	mixer "${orig_dev}".recsrc=set >/dev/null
}

restore_aud_if_needed()
{
	[ $need_aud_restore -ne 0 ] && restore_aud
}

# get_aud_opt snd_src
get_aud_opt()
{
	[ -n "$1" ] && echo "-f oss -i /dev/dsp"
}

# prepare_aud_dev snd_src
prepare_aud_dev()
{
	local snd_src="$1"
	local dev
	if [ "${snd_src}" = "${SND_SRC_MIC}" ]; then
		dev="monitor"
	elif [ "${snd_src}" = "${SND_SRC_DESK}" ]; then
		dev="mic"
	else
		return
	fi
	setvar orig_dev $(mixer \
	    |grep src \
	    |tr -s ' ' \
	    |cut -d ' ' -f 2)
	setvar need_aud_restore 1
	mixer "${dev}".recsrc=set >/dev/null || return 1
}

# do_rec framerate aud_opt out
do_rec()
{
	local framerate="$1"
	local aud_opt="$2"
	local out="$3"
	ffmpeg \
	    -video_size 1366x768 \
	    -framerate "${framerate}" \
	    -f x11grab -i :0 \
	    ${aud_opt} \
	    -crf 23 \
	    -vcodec libx264 \
	    -preset fast \
	    "${out}"
}

handle_opts()
{
	local o
	while getopts "f:ms" o; do
	case $o in
	f)
		check_num "$OPTARG" ||
		    err "Framerate should be a number: $OPTARG"
		setvar framerate "$OPTARG"
		;;
	m)	setvar snd_src "$SND_SRC_MIC" ;;
	s)	setvar snd_src "$SND_SRC_DESK" ;;
	?)	usage ;;
	esac
	done
}

framerate="${DEFAULT_FRAMERATE}"
snd_src=""
need_aud_restore=0
orig_dev=""
trap restore_aud_if_needed HUP INT TERM EXIT

check_freebsd || err "This script can be run only on FreeBSD"
check_prog mixer || err "mixer(8) not found"
check_prog ffmpeg || err "ffmpeg(1) not found"
handle_opts $@
shift $((OPTIND - 1))
out="$1"
[ -z "$out" ] && usage
aud_opt=$(get_aud_opt "${snd_src}")
prepare_aud_dev "${snd_src}"
out_full="${out}.${DEFAULT_OUT_EXT}"
do_rec "${framerate}" "${aud_opt}" "${out_full}" && echo "${out_full}"
