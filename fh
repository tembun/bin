#!/bin/sh

#
# fh -- Find `typedef's through system header files.
#
# May be not 100% solution, but worth trying.
#

if [ -z "$1" ]; then
	echo "usage: fh <type>" 1>&2
	exit 1
fi

grep -Er "typedef.*$1;" /usr/include
