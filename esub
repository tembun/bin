#!/bin/sh

#
# esub -- extract a zip(1) archive with subtitles for a film.
#
# A resulting text-file name may be passed as second argument.  `sub.srt' will
# be used by default.
#

file="$1"
if [ -z "$file" ]; then
	echo "[esub]: Specify an archive file" 1>&2
	exit 1
fi

out="$2"
if [ -z "$out" ]; then
	out="sub.srt"
fi

unzip "$file" >/dev/null
if [ $? -ne 0 ]; then
	exit
fi

rm -f *\.nfo
mv *\.srt "$out" && rm -f "$file"
