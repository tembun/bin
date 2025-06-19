#!/bin/sh

#
# f -- find and highlight pattern matches in files. Case-sensitive.
# fj -- case-insensitive version of `f'.
#

if [ -t 0 ]; then
	recurs_flag="-R"
	args=$@
else
	recurs_flag=""
	args=$1
fi

progname=$(printf "$0" |sed 's/.*\///')

if [ $# -eq 0 ]; then
	echo "Usage: $progname pattern [path ...]" 1>&2
	exit 1
fi

last_name_char=$(printf "$progname" |sed 's/\.sh//' |tail -c1)
if [ "$last_name_char" = "j" ]; then
	case_flag="-i"
else
	case_flag=""
fi

GREP_COLOR="1;7" grep \
    --exclude-dir=".git" \
    --color=always \
    $recurs_flag \
    $case_flag \
    -nI \
    $args
