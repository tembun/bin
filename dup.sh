#!/bin/sh

#
# dup -- dumb backup (or duplicate).
#

progname=$(basename "$0" .sh)
dup_dir="$HOME/tmp"

if [ $# -eq 0 ]; then
	echo "Usage: $progname file ..." 1>&2
	exit 2
fi

ts=$(date +%y-%m-%d_%H-%M-%S)

for file in $@; do
	dup_name="$(basename $file)__$ts"
	dup_dest="$dup_dir/$dup_name"
	cp "$file" "$dup_dest"
	[ $? -ne 0 ] && continue
	echo "$dup_dest"
done
