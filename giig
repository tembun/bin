#!/bin/sh

#
# giig -- manage gitignore(5) file.
#

#
# Values for `mode':
#     - `a' - add files
#     - `d' - delete the files
#     - `l' - list .gitignore file contents
#
mode="a"

if [ $# -eq 0 ]; then
	mode="l"
fi

if [ "$1" = "-d" ]; then
	mode="d"
	shift
	if [ -z "$1" ]; then
		echo "[giig]: Name files to delete from .gitignore" 1>&2
		exit 1
	fi
fi

if [ ! -d .git ]; then
	echo "[giig]: Not a git repository" 1>&2
	exit 1
fi

if [ ! -f .gitignore ]; then
	if [ "$mode" = "l" ] || [ "$mode" = "d" ]; then
		echo "[giig]: no .gitignore file"
		exit 0
	else
		touch .gitignore
	fi
fi

if [ "$mode" = "l" ]; then
	cat .gitignore
	exit 0
fi

fls=$(echo -n "$@" |tr " " "\n")

if [ "$mode" = "a" ]; then
	echo "$fls" >>.gitignore
	exit 0
fi

if [ "$mode" = "d" ]; then
	cont=$(cat .gitignore)
	IFS="
"
	for fil in $fls; do
		cont=$(echo "$cont" |sed "/^$fil$/d")
	done
	
	echo "$cont" >.gitignore
	exit 0
fi
