#!/bin/sh

#
# cast -- do screencast in FreeBSD.
#
# An argument does specify a path for output file without extension.
# The output container is `.mp4'.
#
# Options:
#     -m: Capture microphone sound.
#     -s: Capture screen (desktop) sound.
# Only one of these options may be specified.
#

need_aud_restore=0
aud_restore() {
	mixer "$orig_rec.recsrc=set"
}

if echo "$1" |grep -q "^\-"; then
	if echo "$1" |grep -q "[ms]"; then
		aud="-f oss -i /dev/dsp"
		
		orig_rec=$(mixer \
		    |grep src \
		    |tr -s ' ' \
		    |sed 's/ \([a-z]*\) .*/\1/')
		need_aud_restore=1
		trap aud_restore 1 2 15
	fi
	
	if echo "$1" |grep -q "m"; then
		device="monitor"
	else if echo "$1" |grep -q "s"; then
		device="mic"
	fi
	fi
	shift
	
	mixer "$device.recsrc=set"
fi

out="$1"

if [ -z "$out" ]; then
	echo "[cast]: Which output name?" 1>&2
	exit 1
fi

ffmpeg \
    -video_size 1366x768 \
    -framerate 30 \
    -f x11grab -i :0 \
    $aud \
    -crf 22 \
    -vcodec libx264 \
    -preset fast \
    "$out.mp4"

if [ $need_aud_restore -ne 0 ]; then
	aud_restore
fi
