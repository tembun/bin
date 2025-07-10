#!/bin/sh

#
# tps -- toggle PS1.
#

if echo "$PS1" |grep -q '\$ $'; then
	export PS1="\u@\h> "
else
	export PS1="\u@\h:\w\\$ "
fi
