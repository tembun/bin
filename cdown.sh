#!/bin/sh

#
# cdown -- countdown.
#
# I.e. visualization of sleep(1).
#

progname=$(basename "$0" .sh)
DEFAULT_DELAY=3
forever_flag=0

err()
{
	echo "$progname: $@" 1>&2
	exit 1
}

print_usage()
{
	cat 1>&2 <<__EOF__
usage: $progname [delay]
       $progname -f
       $progname -h
__EOF__
}

help()
{
	print_usage
	exit 0
}

usage()
{
	print_usage
	exit 2
}

do_count()
{
	local num="$1"
	echo "$num"
	sleep 1
}

count_finite()
{
	local delay="$1"
	for num in $(seq "$delay"); do
		do_count "$num"
	done
}

count_forever()
{
	local counter=1
	while true; do
		do_count "$counter"
		counter=$((counter+1))
	done
}

handle_finite_mode()
{
	local delay="$1"
	[ -z "$delay" ] && delay="$DEFAULT_DELAY"
	count_finite "$delay"
}

handle_forever_mode()
{
	count_forever
}

handle_opts()
{
	local o
	while getopts 'fh' o; do
		case $o in
		f)	setvar forever_flag 1 ;;
		h)	help ;;
		?)	usage ;;
		esac
	done
}

handle_opts $@
shift $((OPTIND - 1))

if [ "$forever_flag" = "1" ]; then
	handle_forever_mode
else
	handle_finite_mode $@
fi
