#!/bin/sh

#
# mdf -- modify a file with a command.
#

progname=$(basename "$0" .sh)

file="$1"
com="$2"

if [ -z "$file" ] || [ -z "$com" ]; then
	echo "Usage: $progname file command" 1>&2
	exit 1
fi

tmpf="/tmp/$(basename $file).tmp"
{
	$com <"$file" >"$tmpf" && mv "$tmpf" "$file"
} || rm -f "$tmpf"
