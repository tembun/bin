#!/bin/sh

#
# lf -- list file, i.e. watch it in pager (less(1)).
# 

if [ -t 0 ]; then
	less -FRXFi "$@"
else
	less -FRXFi
fi
