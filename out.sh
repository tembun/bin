#!/bin/sh

#
# out -- print current date(1) to the stdout with specified delay.
#

delay="$1"
if [ -z "$delay" ]; then
	delay="1"
fi

while true; do
	echo "[out]: $(date)"
	sleep "$delay"
done
