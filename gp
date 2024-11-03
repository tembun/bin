#!/bin/sh
#gp-git push script for my repositories.

if [ ! -d .git ];then
	echo "gp: not a git repository." 1>&2
	exit 1
fi

git push sh m&git push gh m
