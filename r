#!/bin/sh

#
# r -- replace string matches in-place in files. Case-sensitive.
# rj -- case-insensitive verion of `r'.
#

pat="$1"
shift
rep="$1"
shift
pths=$@

progname=$(printf "$0" |sed 's/.*\///')

if [ -z "$pat" ] || [ -z "$pths" ]; then
	echo "Usage: $progname pattern replacement path ..." 1>&2
	exit 1
fi

last_name_char=$(printf "$progname" |sed 's/\.sh//' |tail -c1)
if [ "$last_name_char" = "j" ]; then
	case_flag_name="i"
else
	case_flag_name=""
fi

if [ -n "$case_flag_name" ]; then
	case_flag="-$case_flag_name"
else
	case_flag=""
fi

matches=$(grep --exclude-dir=".git" -RIl $case_flag "$pat" $pths)

if [ -z "$matches" ]; then
	echo "[$progname]: No matches found" 1>&2
	exit 0
fi

echo "$matches" |xargs sed -i '' "s%${pat}%${rep}%g${case_flag_name}"
