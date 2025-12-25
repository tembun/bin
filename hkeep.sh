#!/bin/sh

#
# hkeep -- remove garbage (unneeded files) from home directories.
#
# If no arguments are specified, the target directory is set to $HOME.
# Otherwise, the housekeeping will be done in directories, given as arguments.
#
# Options:
#     -v	-- Be verbose.
#
# This script is a good candidate for rc(8) startup task.
#

progname=$(basename "$0" .sh)

usage()
{
	echo "usage: $progname [-v] [path ...]" 1>&2
	exit 2
}

#
# Verbose logging.
#
vlog()
{
	[ $v_flg -eq 1 ] && echo "$prgname: $target_dir: $1"
}

#
# Verbose rm(1).
#
# -v option for rm(1) is non-standard.
#
vrm()
{
	for file in $@; do
		rm "$file" && echo "$file"
	done
}

#
# .serverauth.* files are created by Xserver(1) and should be deleted every
# time the server is closed properly.  Thus, if Xserver(1) is not running now,
# we can freely delete all of them.  And in case it is running, we should find
# the file that was created most recently and leave it the only one alive.
#
clean_serverauth()
{
	target_files=$(find "$target_dir" -depth 1 -maxdepth 1 -type f \
	    -name "\.serverauth*")
	
	if [ -z "$target_files" ]; then
		vlog "No .serverauth files found"
		return 0
	fi
	
	#
	# Xserver(1) creates a unix(4) socket for every active display in
	# /tmp/.X11-unix/X*.  If at least one such socket is found, we can tell
	# that server is currently running.
	#
	if [ -n "$(find /tmp/.X11-unix -type s 2>/dev/null)" ]; then
		x_running=1
	else
		x_running=0
	fi
	
	if [ $x_running -eq 0 ]; then
		vlog "X server is not running.  Remove all .serverauth files"
		vrm $target_files
		return 0
	fi
	
	# If we only have a .serverauth file for currently running server.
	if [ $(echo "$target_files" |wc -l) -eq 1 ]; then
		vlog "No unnecessary .serverauth files found"
		return 0
	fi
	
	most_recent_name=""
	most_recent_ts=0
	
	for target in $target_files; do
		ts=$(stat -f %B "$target")
		if [ $ts -ge $most_recent_ts ]; then
			most_recent_ts=$ts
			most_recent_name="$target"
		fi
	done
	
	vlog ".serverauth file for currently running server: $most_recent_name"
	
	for target in $target_files; do
		if [ "$target" = "$most_recent_name" ]; then
			continue
		fi
		vrm "$target"
	done
}

v_flg=0
while getopts "v" o; do
	case $o in
	v)
		v_flg=1
		;;
	?)
		usage
		;;
	esac
done
shift $((OPTIND - 1))

if [ $# -eq 0 ]; then
	target_dirs="$HOME"
else
	target_dirs="$@"
fi

for target_dir in $target_dirs; do
	if [ ! -d "$target_dir" ]; then
		echo "$target_dir is not a directory" 1>&2
		continue
	fi
	
	clean_serverauth "$target_dir"
done
