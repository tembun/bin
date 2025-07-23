#!/bin/sh

#
# sz -- sort files/directories by their disk space in human-readable format.
#

usage()
{
	echo "Usage: $(basename $0) <-fd> [path ...]" 1>&2
	exit 2
}

find_files=0
find_dirs=0

[ $# -eq 0 ] && usage

while getopts "fd" o; do
	case $o in
	f)
		find_files=1
		;;
	d)
		find_dirs=1
		;;
	?)
		usage
		;;
	esac
done
shift $((OPTIND-1))

[ $find_files -eq 1 ] && find_opts="-type f"

if [ $find_dirs -eq 1 ]; then
	[ $find_files -eq 1 ] && find_opts="$find_opts -or "
	find_opts="$find_opts( -type d -and -links 2 )"
fi

[ $find_files -eq 0 ] && [ $find_dirs -eq 0 ] && usage

paths=${@-'.'}
find $paths \( $find_opts \) -print0 |xargs -0 du -sh |sort -rh
