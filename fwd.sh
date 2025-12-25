#!/bin/sh

#
# fwd -- forward string into pipe.
#
# Alias to echo string |command.
#

progname=$(basename "$0" .sh)

usage()
{
	cat 1>&2 <<__EOF__
usage: $progname string command ...
__EOF__
	exit 2
}

[ $# -gt 2 ] || usage

data="$1"
shift
cmd="$@"

echo -n "$data" |$cmd
