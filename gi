#!/bin/sh
#my git init.

if [ -d .git ];then
	echo "gi: already a git repository." 1>&2
	exit 1
fi

git init&&git checkout -b m&&rm -rf ./.git/hooks
