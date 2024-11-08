#!/bin/sh
#gp-git push script for my repositories.

if [ ! -d .git ];then
	echo "gp: not a git repository." 1>&2
	exit 1
fi

if [ ! -d .git/refs/remotes ];then
	echo "gp: a repo doesn't have remote refs." 1>&2
	exit 1
fi

rems=$(ls .git/refs/remotes)

for rem in $rems;do
	git push $rem m &
done
