#!/bin/sh

#
# pad -- open in visual editor.
#

if [ -z "$VISUAL" ]; then
	echo "[pad]: No \$VISUAL variable defined" 1>&2
	exit 1
fi

if [ -t 0 ]; then
	"$VISUAL" $@
else
	tmp_file=$(mktemp "/tmp/pad_$(date +%H-%M-%S).XXXXXX")
	if [ $? -ne 0 ]; then
		echo "[pad]: Can not create temporary file $tmp_file" 1>&2
		exit 1
	fi
	cat >"$tmp_file" && "$VISUAL" "$tmp_file"
fi
