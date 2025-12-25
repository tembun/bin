#!/bin/sh

#
# ren -- bulk file renamer.
# normalize -- bulk filename normalizer.
#

progname=$(basename "$0")
REN_PROGNAME="ren"
NORMALIZE_PROGNAME="normalize"

warn()
{
	echo "$progname: $@" 1>&2
}

prompt()
{
	# Escape % (in case the prompt has it) to not confuse printf(1).
	local formatted=$(echo "$@" |sed 's/%/&&/g')
	
	printf "${formatted}:" 1>&2
}

err()
{
	warn "$@"
	exit 1
}

print_usage()
{
	cat <<__EOF__
usage: $REN_PROGNAME [-iqv] <-e command ...> file ...
       $NORMALIZE_PROGNAME [-iqv] file ...
__EOF__
}

usage()
{
	print_usage 1>&2
	exit 2
}

get_filepaths()
{
	local path paths
	
	miss=0
	for file in "$@"; do
		path=$(realpath "$file" 2>/dev/null)
		if [ $? -ne 0 ] || ([ ! -f "$path" ] && [ ! -d "$path" ]); then
			warn "$file not found"
			miss=1
		fi
		paths="$paths
$path"
	done
	[ $miss -eq 1 ] && return 1
	echo "$paths" |sed '/^$/d'
}

rename()
{
	local file="$1"
	local sure
	
	# Together with trailing '/'.
	# Empty if current directory (in order to tell if no changes were done).
	#
	olddir="$(dirname "$file")/"
	if [ "$olddir" = "./" ]; then
		olddir=""
	fi
	oldbase=$(basename "$file")
	newbase="$oldbase"
	IFS=$'\n'
	# Process sed(1) commands (-e options) in cycle: not only it helps to
	# avoid constructing a special string with '-e' options for sed(1)
	# (which by the way I couldn't manage to make work), but also allows
	# to have more exact error message in case the command is not valid
	# (we know exactly which command it is).
	#
	for cmd in $cmds; do
		newbase=$(echo "$newbase" |sed $cmd) || \
		    err "Wrong command: '$cmd'"
	done
	unset IFS
	# Since olddir already has a '/'.
	newfile="${olddir}${newbase}"
	if [ "$file" = "$newfile" ]; then
		[ $quiet -ne 1 ] && warn "$file is not affected"
		return
	fi
	if [ $confirm -eq 1 ]; then
		prompt "$file -> $newfile [y/N]"
		read sure
		if [ "$sure" != "y" ] && [ "$sure" != "Y" ]; then
			return
		fi
	fi
	# Even though mv(1) has -i option that does this, I believe it's better
	# not to rely on it.
	#
	if [ -f "$newfile" ] || [ -d "$newfile" ]; then
		prompt "$file -> $newfile, but it already exists. Are you sure? [y/N]"
		read sure
		if [ "$sure" != "y" ] && [ "$sure" != "Y" ]; then
			return
		fi
	fi
	mv "$file" "$newfile"
	if [ $verbose -eq 1 ] && [ $? -eq 0 ]; then
		echo "$file -> $newfile"
	fi
}

rename_files()
{
	IFS=$'\n'
	# $@ consists of newline-separated filenames (that may contain spaces).
	for file in $@; do
		unset IFS
		rename "$file"
		IFS=$'\n'
	done
}

handle_opts()
{
	local o
	
	while getopts "e:iqv" o; do
	case $o in
	e)
		[ $normalize -eq 1 ] && usage
		setvar cmds "$cmds
$OPTARG"
		;;
	i)	setvar confirm 1 ;;
	q)	setvar quiet 1 ;;
	v)	setvar verbose 1 ;;
	?)	usage ;;
	esac
	done
}

normalize=0
[ "$progname" = "$NORMALIZE_PROGNAME" ] && normalize=1
confirm=0
# Be verbose.  Print files as they renamed.
verbose=0
# Be quiet.  Don't inform about files that were not affected.
quiet=0

handle_opts "$@"
shift $((OPTIND - 1))
# If invoked as 'normalize', set commands for normalizing file names.
if [ $normalize -eq 1 ]; then
	cmds="s/ /_/g
s/[]\[()]/-/g
s/[!?@#%;:\"'\`]//g
s/,/./g
s/\&/8/g"
fi
[ -z "$cmds" ] && usage
cmds=$(echo "$cmds" |sed '/^$/d')
[ $# -lt 1 ] && usage
files=$(get_filepaths "$@") || exit 1
# Sort paths by depth (deepest path first).  This order will make sure that we
# won't change any part of the path that might be common to other paths in the
# list.
# Example: if we don't do that, we may have the following order of paths:
#     a/b a/b/c/d (expression is 's/b/B/')
# and if we process a/b first, then it would become a/B and the next path
# a/b/c could not be processed anymore because directory a/b does not exist now.
#
files=$(echo "$files" \
    |awk '{ln=$0; print gsub(/\//, "", ln) "\t" $0}' \
    |sort -rn \
    |cut -f 2)
rename_files "$sed_cmds" "$files"
